-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_CLINICAS
-- OBJETIVO:      Extracción directa desde red_clinica_user.CLINICAS hacia STG_CLINICAS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_CLINICAS (
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
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_CLINICAS', 'SP_EXTRACT_STG_CLINICAS', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_CLINICAS';

    INSERT /*+ APPEND */ INTO STG_CLINICAS (
        ID_CLINICA, 
        NOMBRE_CLINICA, 
        ID_UBICACION, 
        DIRECCION, 
        TELEFONO, 
        FECHA_APERTURA, 
        ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_CLINICA, 
        o.NOMBRE_CLINICA, 
        o.ID_UBICACION, 
        o.DIRECCION, 
        o.TELEFONO,
        o.FECHA_APERTURA, 
        o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_CLINICA, '~') || '|' ||
            NVL(TO_CHAR(o.ID_UBICACION), '~') || '|' ||
            NVL(o.DIRECCION, '~') || '|' ||
            NVL(o.TELEFONO, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_APERTURA, 'YYYY-MM-DD'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.CLINICAS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_CLINICAS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_CLINICAS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_CLINICAS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_CLINICAS TO dwh_clinica_user;
