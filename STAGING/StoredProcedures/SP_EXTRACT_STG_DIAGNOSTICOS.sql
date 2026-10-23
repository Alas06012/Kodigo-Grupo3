-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_DIAGNOSTICOS
-- OBJETIVO:      Extracción de diagnósticos clínicos desde red_clinica_user.DIAGNOSTICOS
--                hacia STG_DIAGNOSTICOS con soporte de ventana incremental
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_DIAGNOSTICOS (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL,
    p_batch_id       IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas        NUMBER := 0;
    v_tipo         VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias         NUMBER := NVL(p_dias_lookback, 3);
    v_fecha_filtro DATE;
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_DIAGNOSTICOS', 'SP_EXTRACT_STG_DIAGNOSTICOS', v_tipo, v_audit_id);
    IF v_tipo = 'INCREMENTAL' THEN
        IF p_fecha_corte IS NOT NULL THEN
            v_fecha_filtro := TRUNC(p_fecha_corte);
        ELSE
            v_fecha_filtro := TRUNC(SYSDATE) - v_dias;
        END IF;
    ELSE
        v_fecha_filtro := DATE '1900-01-01';
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_DIAGNOSTICOS';

    INSERT /*+ APPEND */ INTO STG_DIAGNOSTICOS (
        ID_DIAGNOSTICO, ID_CONSULTA, ID_ENFERMEDAD, FECHA_DIAGNOSTICO, OBSERVACIONES,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_DIAGNOSTICO, o.ID_CONSULTA, o.ID_ENFERMEDAD, o.FECHA_DIAGNOSTICO, o.OBSERVACIONES,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_CONSULTA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ENFERMEDAD), '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_DIAGNOSTICO, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
            NVL(o.OBSERVACIONES, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.DIAGNOSTICOS o
    WHERE o.FECHA_DIAGNOSTICO >= v_fecha_filtro
       OR o.ID_CONSULTA IN (SELECT ID_CONSULTA FROM STG_CONSULTAS);

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_DIAGNOSTICOS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_DIAGNOSTICOS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_DIAGNOSTICOS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_DIAGNOSTICOS TO dwh_clinica_user;
