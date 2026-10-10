-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_DISTRIBUCION_COBRO
-- OBJETIVO:      Extracción del desglose de cobro por pagador desde 
--                red_clinica_user.DISTRIBUCION_COBRO hacia STG_DISTRIBUCION_COBRO
--                con soporte de ventana incremental (Lookback)
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_DISTRIBUCION_COBRO (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL
)
AUTHID CURRENT_USER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_DISTRIBUCION_COBRO';

    INSERT /*+ APPEND */ INTO STG_DISTRIBUCION_COBRO (
        ID_DISTRIBUCION, ID_COBRO, TIPO_PAGADOR, ID_PACIENTE, ID_ASEGURADORA, ID_EMPRESA,
        PORCENTAJE, MONTO_ASIGNADO, MONTO_PAGADO, SALDO_PENDIENTE, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_DISTRIBUCION, o.ID_COBRO, o.TIPO_PAGADOR, o.ID_PACIENTE, o.ID_ASEGURADORA, o.ID_EMPRESA,
        o.PORCENTAJE, o.MONTO_ASIGNADO, o.MONTO_PAGADO, o.SALDO_PENDIENTE, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_COBRO), '~') || '|' ||
            NVL(o.TIPO_PAGADOR, '~') || '|' ||
            NVL(TO_CHAR(o.ID_PACIENTE), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ASEGURADORA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_EMPRESA), '~') || '|' ||
            NVL(TO_CHAR(o.PORCENTAJE, 'FM990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_ASIGNADO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_PAGADO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.SALDO_PENDIENTE, 'FM999999990.00'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.DISTRIBUCION_COBRO o
    WHERE o.ID_COBRO IN (SELECT ID_COBRO FROM STG_COBROS_CONSULTA);

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_DISTRIBUCION_COBRO extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_DISTRIBUCION_COBRO: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_DISTRIBUCION_COBRO;
/

GRANT EXECUTE ON SP_EXTRACT_STG_DISTRIBUCION_COBRO TO dwh_clinica_user;
