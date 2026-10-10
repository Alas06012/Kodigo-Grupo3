-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_FACT_COBROS_DISTRIBUCION
-- OBJETIVO:      Carga del análisis de recaudación, saldos por pagador
--                (Particular, Empresa, Aseguradora) y forma de pago
-- TABLA DESTINO: FACT_COBROS_DISTRIBUCION
-- TABLAS ORIGEN: stg_clinica_user.STG_DISTRIBUCION_COBRO, STG_COBROS_CONSULTA,
--                FACT_CONSULTAS, DIM_PAGADOR, STG_TRANSACCIONES_PAGO, DIM_FORMA_PAGO
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_FACT_COBROS_DISTRIBUCION (
    p_tipo_carga IN VARCHAR2 DEFAULT 'INCREMENTAL'
)
AUTHID CURRENT_USER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
BEGIN
    MERGE INTO FACT_COBROS_DISTRIBUCION f
    USING (
        WITH FORMA_PAGO_PREDOMINANTE AS (
            SELECT 
                ID_DISTRIBUCION,
                ID_FORMA_PAGO,
                ROW_NUMBER() OVER (PARTITION BY ID_DISTRIBUCION ORDER BY MONTO_TRANSACCION DESC) AS RN
            FROM stg_clinica_user.STG_TRANSACCIONES_PAGO
        )
        SELECT 
            dist.ID_DISTRIBUCION AS BK_ID_DISTRIBUCION,
            dist.ID_COBRO        AS BK_ID_COBRO,
            cob.ID_CONSULTA      AS BK_ID_CONSULTA,
            fc.SK_TIEMPO,
            fc.SK_PACIENTE,
            fc.SK_CLINICA,
            dpag.SK_PAGADOR,
            NVL(dfp.SK_FORMA_PAGO, 1) AS SK_FORMA_PAGO_PREDOMINANTE,
            dist.PORCENTAJE      AS PORCENTAJE_COBERTURA,
            dist.MONTO_ASIGNADO,
            dist.MONTO_PAGADO,
            dist.SALDO_PENDIENTE,
            dist.ESTADO          AS ESTADO_DISTRIBUCION,
            dist.TIPO_PAGADOR,
            RAWTOHEX(STANDARD_HASH(
                TO_CHAR(dist.ID_DISTRIBUCION) || '|' ||
                TO_CHAR(dist.MONTO_ASIGNADO, 'FM999999990.00') || '|' ||
                TO_CHAR(dist.MONTO_PAGADO, 'FM999999990.00') || '|' ||
                dist.ESTADO,
                'SHA256'
            )) AS HASH_HECHO
        FROM stg_clinica_user.STG_DISTRIBUCION_COBRO dist
        INNER JOIN stg_clinica_user.STG_COBROS_CONSULTA cob 
            ON cob.ID_COBRO = dist.ID_COBRO
        INNER JOIN FACT_CONSULTAS fc 
            ON fc.BK_ID_CONSULTA = cob.ID_CONSULTA
        INNER JOIN DIM_PAGADOR dpag 
            ON dpag.TIPO_PAGADOR = dist.TIPO_PAGADOR
           AND dpag.BK_ID_ORIGEN = CASE 
               WHEN dist.TIPO_PAGADOR = 'PACIENTE'    THEN dist.ID_PACIENTE
               WHEN dist.TIPO_PAGADOR = 'EMPRESA'     THEN dist.ID_EMPRESA
               WHEN dist.TIPO_PAGADOR = 'ASEGURADORA' THEN dist.ID_ASEGURADORA
           END
        LEFT JOIN FORMA_PAGO_PREDOMINANTE fpp 
            ON fpp.ID_DISTRIBUCION = dist.ID_DISTRIBUCION AND fpp.RN = 1
        LEFT JOIN DIM_FORMA_PAGO dfp 
            ON dfp.BK_ID_FORMA_PAGO = fpp.ID_FORMA_PAGO
    ) s
    ON (f.BK_ID_DISTRIBUCION = s.BK_ID_DISTRIBUCION)
    WHEN NOT MATCHED THEN
        INSERT (
            BK_ID_DISTRIBUCION, BK_ID_COBRO, BK_ID_CONSULTA,
            SK_TIEMPO, SK_PACIENTE, SK_CLINICA, SK_PAGADOR, SK_FORMA_PAGO_PREDOMINANTE,
            PORCENTAJE_COBERTURA, MONTO_ASIGNADO, MONTO_PAGADO, SALDO_PENDIENTE,
            ESTADO_DISTRIBUCION, TIPO_PAGADOR,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.BK_ID_DISTRIBUCION, s.BK_ID_COBRO, s.BK_ID_CONSULTA,
            s.SK_TIEMPO, s.SK_PACIENTE, s.SK_CLINICA, s.SK_PAGADOR, s.SK_FORMA_PAGO_PREDOMINANTE,
            s.PORCENTAJE_COBERTURA, s.MONTO_ASIGNADO, s.MONTO_PAGADO, s.SALDO_PENDIENTE,
            s.ESTADO_DISTRIBUCION, s.TIPO_PAGADOR,
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.HASH_HECHO
        )
    WHEN MATCHED THEN
        UPDATE SET
            f.MONTO_PAGADO        = s.MONTO_PAGADO,
            f.SALDO_PENDIENTE     = s.SALDO_PENDIENTE,
            f.ESTADO_DISTRIBUCION = s.ESTADO_DISTRIBUCION,
            f.FECHAINICIO         = SYSDATE,
            f.TIPOTRANSACCION     = 'U',
            f.ROWHASHVALUE        = s.HASH_HECHO
        WHERE f.ROWHASHVALUE != s.HASH_HECHO;

    v_cant := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_FACT_COBROS_DISTRIBUCION ejecutado: ' || v_cant || ' filas procesadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_FACT_COBROS_DISTRIBUCION: ' || SQLERRM);
        RAISE;
END SP_LOAD_FACT_COBROS_DISTRIBUCION;
/
