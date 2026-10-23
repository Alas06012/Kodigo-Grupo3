-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS
-- OBJETIVO:      Extracción de procedimientos aplicados desde 
--                red_clinica_user.CONSULTAS_PROCEDIMIENTOS hacia 
--                STG_CONSULTAS_PROCEDIMIENTOS con soporte de ventana incremental
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS (
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
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_CONSULTAS_PROCEDIMIENTOS', 'SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS', v_tipo, v_audit_id);
    IF v_tipo = 'INCREMENTAL' THEN
        IF p_fecha_corte IS NOT NULL THEN
            v_fecha_filtro := TRUNC(p_fecha_corte);
        ELSE
            v_fecha_filtro := TRUNC(SYSDATE) - v_dias;
        END IF;
    ELSE
        v_fecha_filtro := DATE '1900-01-01';
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_CONSULTAS_PROCEDIMIENTOS';

    INSERT /*+ APPEND */ INTO STG_CONSULTAS_PROCEDIMIENTOS (
        ID_CONSULTA_PROCEDIMIENTO, ID_CONSULTA, ID_PROCEDIMIENTO, CANTIDAD, PRECIO_UNITARIO, SUBTOTAL,
        OBSERVACIONES, FECHA_REALIZACION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_CONSULTA_PROCEDIMIENTO, o.ID_CONSULTA, o.ID_PROCEDIMIENTO, o.CANTIDAD, o.PRECIO_UNITARIO, o.SUBTOTAL,
        o.OBSERVACIONES, o.FECHA_REALIZACION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_CONSULTA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_PROCEDIMIENTO), '~') || '|' ||
            NVL(TO_CHAR(o.CANTIDAD), '~') || '|' ||
            NVL(TO_CHAR(o.PRECIO_UNITARIO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.SUBTOTAL, 'FM999999990.00'), '~') || '|' ||
            NVL(o.OBSERVACIONES, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_REALIZACION, 'YYYY-MM-DD HH24:MI:SS'), '~'),
            'SHA256'
        ))
    FROM red_clinica_user.CONSULTAS_PROCEDIMIENTOS o
    WHERE o.FECHA_REALIZACION >= v_fecha_filtro
       OR o.ID_CONSULTA IN (SELECT ID_CONSULTA FROM STG_CONSULTAS);

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_CONSULTAS_PROCEDIMIENTOS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS TO dwh_clinica_user;
