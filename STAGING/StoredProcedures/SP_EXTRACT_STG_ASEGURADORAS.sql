-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_ASEGURADORAS
-- OBJETIVO:      Extracción directa desde red_clinica_user.ASEGURADORAS hacia stg_clinica_user.STG_ASEGURADORAS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_ASEGURADORAS (
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
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_ASEGURADORAS', 'SP_EXTRACT_STG_ASEGURADORAS', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_ASEGURADORAS';

    INSERT /*+ APPEND */ INTO STG_ASEGURADORAS (
        ID_ASEGURADORA, 
        NOMBRE_ASEGURADORA, 
        NIT, TIPO_COBERTURA, 
        TELEFONO,
        CURRENTFLAG, 
        TIPOCARGA, 
        FECHAINICIO, 
        FECHAFIN, 
        TIPOTRANSACCION,
        ROWHASHVALUE
    )
    SELECT 
        o.ID_ASEGURADORA, 
        o.NOMBRE_ASEGURADORA, 
        o.NIT, 
        o.TIPO_COBERTURA, 
        o.TELEFONO,
        1, 
        v_tipo, 
        SYSDATE,
        DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_ASEGURADORA, '~') || '|' ||
            NVL(o.NIT, '~') || '|' ||
            NVL(o.TIPO_COBERTURA, '~') || '|' ||
            NVL(o.TELEFONO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.ASEGURADORAS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_ASEGURADORAS extraída: ' || v_filas || ' registros.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_ASEGURADORAS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_ASEGURADORAS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_ASEGURADORAS TO dwh_clinica_user;
