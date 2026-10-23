-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS
-- OBJETIVO:      Carga del análisis epidemiológico y distribución del costo
--                prorrateado por patología diagnosticada
-- TABLA DESTINO: FACT_CONSULTA_DIAGNOSTICOS
-- TABLAS ORIGEN: stg_clinica_user.STG_DIAGNOSTICOS, FACT_CONSULTAS, DIM_ENFERMEDAD
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    SP_AUDIT_START(v_batch_id, 'DWH_FACT', 'FACT_CONSULTA_DIAGNOSTICOS', 'SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS', v_tipo, v_audit_id);
    MERGE INTO FACT_CONSULTA_DIAGNOSTICOS f
    USING (
        WITH CONTEO_DIAG AS (
            SELECT 
                ID_CONSULTA,
                COUNT(*) AS TOTAL_DIAG
            FROM stg_clinica_user.STG_DIAGNOSTICOS
            GROUP BY ID_CONSULTA
        )
        SELECT 
            d.ID_DIAGNOSTICO AS BK_ID_DIAGNOSTICO,
            d.ID_CONSULTA    AS BK_ID_CONSULTA,
            fc.SK_TIEMPO,
            fc.SK_PACIENTE,
            fc.SK_CLINICA,
            fc.SK_MEDICO,
            fc.SK_ESPECIALIDAD,
            denf.SK_ENFERMEDAD,
            fc.SK_UBICACION_PACIENTE,
            1 AS CONTEO_DIAGNOSTICO,
            cd.TOTAL_DIAG AS TOTAL_DIAGNOSTICOS_CONS,
            fc.MONTO_TOTAL_FACTURADO AS MONTO_TOTAL_CONSULTA,
            ROUND(fc.MONTO_TOTAL_FACTURADO / cd.TOTAL_DIAG, 2) AS MONTO_PRORRATEADO,
            d.OBSERVACIONES,
            RAWTOHEX(STANDARD_HASH(
                TO_CHAR(d.ID_DIAGNOSTICO) || '|' ||
                TO_CHAR(denf.SK_ENFERMEDAD) || '|' ||
                TO_CHAR(ROUND(fc.MONTO_TOTAL_FACTURADO / cd.TOTAL_DIAG, 2), 'FM999999990.00'),
                'SHA256'
            )) AS HASH_HECHO
        FROM stg_clinica_user.STG_DIAGNOSTICOS d
        INNER JOIN CONTEO_DIAG cd 
            ON cd.ID_CONSULTA = d.ID_CONSULTA
        INNER JOIN FACT_CONSULTAS fc 
            ON fc.BK_ID_CONSULTA = d.ID_CONSULTA
        INNER JOIN DIM_ENFERMEDAD denf 
            ON denf.BK_ID_ENFERMEDAD = d.ID_ENFERMEDAD
    ) s
    ON (f.BK_ID_DIAGNOSTICO = s.BK_ID_DIAGNOSTICO)
    WHEN NOT MATCHED THEN
        INSERT (
            BK_ID_DIAGNOSTICO, BK_ID_CONSULTA, SK_TIEMPO, SK_PACIENTE, SK_CLINICA,
            SK_MEDICO, SK_ESPECIALIDAD, SK_ENFERMEDAD, SK_UBICACION_PACIENTE,
            CONTEO_DIAGNOSTICO, TOTAL_DIAGNOSTICOS_CONS, MONTO_TOTAL_CONSULTA, MONTO_PRORRATEADO,
            OBSERVACIONES,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.BK_ID_DIAGNOSTICO, s.BK_ID_CONSULTA, s.SK_TIEMPO, s.SK_PACIENTE, s.SK_CLINICA,
            s.SK_MEDICO, s.SK_ESPECIALIDAD, s.SK_ENFERMEDAD, s.SK_UBICACION_PACIENTE,
            s.CONTEO_DIAGNOSTICO, s.TOTAL_DIAGNOSTICOS_CONS, s.MONTO_TOTAL_CONSULTA, s.MONTO_PRORRATEADO,
            s.OBSERVACIONES,
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.HASH_HECHO
        )
    WHEN MATCHED THEN
        UPDATE SET
            f.MONTO_TOTAL_CONSULTA = s.MONTO_TOTAL_CONSULTA,
            f.MONTO_PRORRATEADO    = s.MONTO_PRORRATEADO,
            f.OBSERVACIONES        = s.OBSERVACIONES,
            f.FECHAINICIO          = SYSDATE,
            f.TIPOTRANSACCION      = 'U',
            f.ROWHASHVALUE         = s.HASH_HECHO
        WHERE f.ROWHASHVALUE != s.HASH_HECHO;

    v_cant := SQL%ROWCOUNT;
    COMMIT;
    SP_AUDIT_END(v_audit_id, v_cant, v_cant, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS ejecutado: ' || v_cant || ' filas procesadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS: ' || SQLERRM);
        RAISE;
END SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS;
/
