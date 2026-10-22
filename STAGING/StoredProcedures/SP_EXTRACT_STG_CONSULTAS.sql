-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_CONSULTAS
-- OBJETIVO:      Extracción de atenciones médicas desde red_clinica_user.CONSULTAS
--                hacia STG_CONSULTAS con soporte de ventana incremental (Lookback)
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_CONSULTAS (
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
    DBMS_OUTPUT.PUT_LINE('STG_CONSULTAS extraída (Ventana >= ' || TO_CHAR(v_fecha_filtro, 'YYYY-MM-DD') || '): ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_CONSULTAS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_CONSULTAS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_CONSULTAS TO dwh_clinica_user;
