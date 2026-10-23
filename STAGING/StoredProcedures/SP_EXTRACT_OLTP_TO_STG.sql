-- ============================================================================
-- PROCEDIMIENTO MAESTRO: SP_EXTRACT_OLTP_TO_STG
-- OBJETIVO: Orquestador general de la extracción OLTP -> Staging.
--           Invoca de forma modular y secuencial cada procedimiento individual
--           por cada tabla origen, preservando el cálculo de SHA-256 al vuelo
--           y la ventana incremental (Lookback).
--           Registra auditoría integral en CTL_ETL_AUDIT.
-- ESQUEMA:  stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_OLTP_TO_STG (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL,
    p_batch_id       IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_inicio_proc TIMESTAMP := SYSTIMESTAMP;
    v_tipo_carga  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias        NUMBER := NVL(p_dias_lookback, 3);
    v_batch_id    VARCHAR2(50);
    v_audit_id    NUMBER;
BEGIN
    IF v_tipo_carga NOT IN ('FULL', 'INCREMENTAL') THEN
        RAISE_APPLICATION_ERROR(-20010, 'Parámetro p_tipo_carga inválido. Debe ser FULL o INCREMENTAL.');
    END IF;

    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STAGING_ALL', 'SP_EXTRACT_OLTP_TO_STG', v_tipo_carga, v_audit_id);

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('INICIO PROCESO DE EXTRACCIÓN: OLTP (red_clinica_user) -> STAGING');
    DBMS_OUTPUT.PUT_LINE('Batch ID: ' || v_batch_id);
    DBMS_OUTPUT.PUT_LINE('Modo de Carga: ' || v_tipo_carga || ' | Ventana Días Lookback: ' || v_dias);
    DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================');

    -- BLOQUE 1: CATÁLOGOS Y ENTIDADES MAESTRAS
    DBMS_OUTPUT.PUT_LINE('>>> 1. Extrayendo Catálogos y Entidades Maestras...');
    SP_EXTRACT_STG_UBICACIONES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_CLINICAS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_EMPRESAS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_ASEGURADORAS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_PACIENTES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_ESPECIALIDADES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_MEDICOS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_ENFERMEDADES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_TIPOS_CONSULTA(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_PROCEDIMIENTOS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_FORMAS_PAGO(v_tipo_carga, v_batch_id);

    -- BLOQUE 2: TABLAS TRANSACCIONALES MASIVAS (VENTANA INCREMENTAL)
    DBMS_OUTPUT.PUT_LINE('>>> 2. Extrayendo Transacciones Masivas (Ventana Lookback)...');
    SP_EXTRACT_STG_CONSULTAS(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_DIAGNOSTICOS(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_TRANSACCIONES_PAGO(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_COBROS_CONSULTA(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_DISTRIBUCION_COBRO(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);

    dwh_clinica_user.SP_AUDIT_END(v_audit_id, 0, 0, 0, 0, 'SUCCESS');

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('EXTRACCIÓN OPTIMIZADA A STAGING COMPLETADA EXITOSAMENTE');
    DBMS_OUTPUT.PUT_LINE('Duración: ' || TO_CHAR(SYSTIMESTAMP - v_inicio_proc));
    DBMS_OUTPUT.PUT_LINE('================================================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('*** ERROR CRÍTICO EN SP_EXTRACT_OLTP_TO_STG: ' || SQLERRM || ' ***');
        RAISE;
END SP_EXTRACT_OLTP_TO_STG;
/

GRANT EXECUTE ON SP_EXTRACT_OLTP_TO_STG TO dwh_clinica_user;
