-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES
-- OBJETIVO:      Extracción directa desde red_clinica_user.MEDICOS_ESPECIALIDADES hacia STG_MEDICOS_ESPECIALIDADES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_MEDICOS_ESPECIALIDADES', 'SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_MEDICOS_ESPECIALIDADES';

    INSERT /*+ APPEND */ INTO STG_MEDICOS_ESPECIALIDADES (
        ID_MEDICO_ESPECIALIDAD, ID_MEDICO, ID_ESPECIALIDAD, NUM_REGISTRO_ESPECIAL, ES_PRINCIPAL,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_MEDICO_ESPECIALIDAD, o.ID_MEDICO, o.ID_ESPECIALIDAD, o.NUM_REGISTRO_ESPECIAL, o.ES_PRINCIPAL,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_MEDICO), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ESPECIALIDAD), '~') || '|' ||
            NVL(o.NUM_REGISTRO_ESPECIAL, '~') || '|' ||
            NVL(o.ES_PRINCIPAL, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.MEDICOS_ESPECIALIDADES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_MEDICOS_ESPECIALIDADES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES TO dwh_clinica_user;
