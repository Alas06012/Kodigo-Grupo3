-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_TIPOS_CONSULTA
-- OBJETIVO:      Extracción directa desde red_clinica_user.TIPOS_CONSULTA hacia STG_TIPOS_CONSULTA
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_TIPOS_CONSULTA (
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
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_TIPOS_CONSULTA', 'SP_EXTRACT_STG_TIPOS_CONSULTA', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_TIPOS_CONSULTA';

    INSERT /*+ APPEND */ INTO STG_TIPOS_CONSULTA (
        ID_TIPO_CONSULTA, NOMBRE_TIPO, DESCRIPCION, PRECIO_BASE, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_TIPO_CONSULTA, o.NOMBRE_TIPO, o.DESCRIPCION, o.PRECIO_BASE, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_TIPO, '~') || '|' ||
            NVL(o.DESCRIPCION, '~') || '|' ||
            NVL(TO_CHAR(o.PRECIO_BASE, 'FM999999990.00'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.TIPOS_CONSULTA o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_TIPOS_CONSULTA extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_TIPOS_CONSULTA: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_TIPOS_CONSULTA;
/

GRANT EXECUTE ON SP_EXTRACT_STG_TIPOS_CONSULTA TO dwh_clinica_user;
