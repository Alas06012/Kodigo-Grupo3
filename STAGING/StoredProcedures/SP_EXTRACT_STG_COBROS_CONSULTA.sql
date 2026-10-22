-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_COBROS_CONSULTA
-- OBJETIVO:      Extracción del estado de cuenta médico desde 
--                red_clinica_user.COBROS_CONSULTA hacia STG_COBROS_CONSULTA
--                con soporte de ventana incremental (Lookback)
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_COBROS_CONSULTA (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL
)
AUTHID DEFINER
IS
    v_filas        NUMBER := 0;
    v_tipo         VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias         NUMBER := NVL(p_dias_lookback, 3);
    v_fecha_filtro DATE;
BEGIN
    IF v_tipo = 'INCREMENTAL' THEN
        IF p_fecha_corte IS NOT NULL THEN
            v_fecha_filtro := TRUNC(p_fecha_corte);
        ELSE
            v_fecha_filtro := TRUNC(SYSDATE) - v_dias;
        END IF;
    ELSE
        v_fecha_filtro := DATE '1900-01-01';
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_COBROS_CONSULTA';

    INSERT /*+ APPEND */ INTO STG_COBROS_CONSULTA (
        ID_COBRO, ID_CONSULTA, MONTO_TOTAL_FACTURADO, MONTO_TOTAL_PAGADO, SALDO_PENDIENTE,
        ESTADO_COBRO, FECHA_EMISION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_COBRO, o.ID_CONSULTA, o.MONTO_TOTAL_FACTURADO, o.MONTO_TOTAL_PAGADO, o.SALDO_PENDIENTE,
        o.ESTADO_COBRO, o.FECHA_EMISION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_CONSULTA), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_TOTAL_FACTURADO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_TOTAL_PAGADO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.SALDO_PENDIENTE, 'FM999999990.00'), '~') || '|' ||
            NVL(o.ESTADO_COBRO, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_EMISION, 'YYYY-MM-DD HH24:MI:SS'), '~'),
            'SHA256'
        ))
    FROM red_clinica_user.COBROS_CONSULTA o
    WHERE o.FECHA_EMISION >= v_fecha_filtro
       OR o.ID_CONSULTA IN (SELECT ID_CONSULTA FROM STG_CONSULTAS)
       OR o.ID_COBRO IN (SELECT ID_COBRO FROM STG_TRANSACCIONES_PAGO);

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_COBROS_CONSULTA extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_COBROS_CONSULTA: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_COBROS_CONSULTA;
/

GRANT EXECUTE ON SP_EXTRACT_STG_COBROS_CONSULTA TO dwh_clinica_user;
