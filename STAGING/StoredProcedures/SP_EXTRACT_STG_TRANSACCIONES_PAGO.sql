-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_TRANSACCIONES_PAGO
-- OBJETIVO:      Extracción del libro diario de pagos desde 
--                red_clinica_user.TRANSACCIONES_PAGO hacia STG_TRANSACCIONES_PAGO
--                con soporte de ventana incremental (Lookback)
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_TRANSACCIONES_PAGO (
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

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_TRANSACCIONES_PAGO';

    INSERT /*+ APPEND */ INTO STG_TRANSACCIONES_PAGO (
        ID_TRANSACCION, ID_COBRO, ID_DISTRIBUCION, ID_FORMA_PAGO, MONTO_TRANSACCION,
        FECHA_PAGO, NUMERO_REFERENCIA, OBSERVACIONES,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_TRANSACCION, d.ID_COBRO, o.ID_DISTRIBUCION, o.ID_FORMA_PAGO, o.MONTO_TRANSACCION,
        o.FECHA_PAGO, o.NUMERO_REFERENCIA, o.OBSERVACIONES,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(d.ID_COBRO), '~') || '|' ||
            NVL(TO_CHAR(o.ID_DISTRIBUCION), '~') || '|' ||
            NVL(TO_CHAR(o.ID_FORMA_PAGO), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_TRANSACCION, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_PAGO, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
            NVL(o.NUMERO_REFERENCIA, '~') || '|' ||
            NVL(o.OBSERVACIONES, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.TRANSACCIONES_PAGO o
    INNER JOIN red_clinica_user.DISTRIBUCION_COBRO d ON d.ID_DISTRIBUCION = o.ID_DISTRIBUCION
    WHERE o.FECHA_PAGO >= v_fecha_filtro;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_TRANSACCIONES_PAGO extraída (Ventana >= ' || TO_CHAR(v_fecha_filtro, 'YYYY-MM-DD') || '): ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_TRANSACCIONES_PAGO: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_TRANSACCIONES_PAGO;
/

GRANT EXECUTE ON SP_EXTRACT_STG_TRANSACCIONES_PAGO TO dwh_clinica_user;
