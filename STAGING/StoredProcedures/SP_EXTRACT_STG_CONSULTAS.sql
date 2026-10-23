-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_CONSULTAS
-- OBJETIVO:      Extracción de atenciones médicas desde red_clinica_user.CONSULTAS
--                hacia STG_CONSULTAS con soporte de ventana incremental (Lookback)
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_CONSULTAS (
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
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_CONSULTAS', 'SP_EXTRACT_STG_CONSULTAS', v_tipo, v_audit_id);
    IF v_tipo = 'INCREMENTAL' THEN
        IF p_fecha_corte IS NOT NULL THEN
            v_fecha_filtro := TRUNC(p_fecha_corte);
        ELSE
            v_fecha_filtro := TRUNC(SYSDATE) - v_dias;
        END IF;
    ELSE
        v_fecha_filtro := DATE '1900-01-01';
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_CONSULTAS';

    INSERT /*+ APPEND */ INTO STG_CONSULTAS (
        ID_CONSULTA, ID_PACIENTE, ID_CLINICA, ID_MEDICO, ID_ESPECIALIDAD, ID_TIPO_CONSULTA,
        FECHA_CONSULTA, PRECIO_CONSULTA, MOTIVO_CONSULTA, PRESCRIPCION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_CONSULTA, o.ID_PACIENTE, o.ID_CLINICA, o.ID_MEDICO, o.ID_ESPECIALIDAD, o.ID_TIPO_CONSULTA,
        o.FECHA_CONSULTA, o.PRECIO_CONSULTA, o.MOTIVO_CONSULTA, o.PRESCRIPCION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_PACIENTE), '~') || '|' ||
            NVL(TO_CHAR(o.ID_CLINICA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_MEDICO), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ESPECIALIDAD), '~') || '|' ||
            NVL(TO_CHAR(o.ID_TIPO_CONSULTA), '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_CONSULTA, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
            NVL(TO_CHAR(o.PRECIO_CONSULTA, 'FM999999990.00'), '~') || '|' ||
            NVL(o.MOTIVO_CONSULTA, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.CONSULTAS o
    WHERE o.FECHA_CONSULTA >= v_fecha_filtro;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_CONSULTAS extraída (Ventana >= ' || TO_CHAR(v_fecha_filtro, 'YYYY-MM-DD') || '): ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_CONSULTAS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_CONSULTAS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_CONSULTAS TO dwh_clinica_user;
