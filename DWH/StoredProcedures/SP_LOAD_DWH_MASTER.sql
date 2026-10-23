-- ============================================================================
-- PROCEDIMIENTO MAESTRO: SP_LOAD_DWH_MASTER
-- OBJETIVO: Orquestador end-to-end de extracción y carga analítica en el DWH.
--           Invoca de forma modular y secuencial cada procedimiento individual
--           por cada tabla de dimensión y tabla de hechos.
--           Registra auditoría integral en CTL_ETL_AUDIT.
-- ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DWH_MASTER (
    p_tipo_carga    IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback IN NUMBER   DEFAULT 3,
    p_fecha_corte   IN DATE     DEFAULT NULL,
    p_batch_id      IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_inicio   TIMESTAMP := SYSTIMESTAMP;
    v_tipo     VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias     NUMBER := NVL(p_dias_lookback, 3);
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    SP_AUDIT_START(v_batch_id, 'ORCHESTRATOR', 'DWH_ALL', 'SP_LOAD_DWH_MASTER', v_tipo, v_audit_id);

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('INICIO DEL PIPELINE ANALÍTICO COMPLETO: DWH RED DE CLÍNICAS');
    DBMS_OUTPUT.PUT_LINE('Batch ID: ' || v_batch_id);
    DBMS_OUTPUT.PUT_LINE('Modo de Carga: ' || v_tipo || 
                         ' | Ventana Días Lookback: ' || v_dias);
    DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================');

    -- Paso 1: Extracción desde OLTP hacia Staging con ventana optimizada
    DBMS_OUTPUT.PUT_LINE('>>> 1. EJECUTANDO EXTRACCIÓN HACIA STAGING...');
    stg_clinica_user.SP_EXTRACT_OLTP_TO_STG(v_tipo, v_dias, p_fecha_corte, v_batch_id);

    -- Paso 2: Carga de Dimensiones SCD Tipo 1 y Tiempo (Sobreescritura con Hash)
    DBMS_OUTPUT.PUT_LINE('>>> 2. EJECUTANDO CARGA DE DIMENSIONES SCD TIPO 1 Y TIEMPO...');
    SP_LOAD_DIM_TIEMPO(2024, 2030, v_batch_id);
    SP_LOAD_DIM_UBICACION(v_tipo, v_batch_id);
    SP_LOAD_DIM_ESPECIALIDAD(v_tipo, v_batch_id);
    SP_LOAD_DIM_ENFERMEDAD(v_tipo, v_batch_id);
    SP_LOAD_DIM_TIPO_CONSULTA(v_tipo, v_batch_id);
    SP_LOAD_DIM_FORMA_PAGO(v_tipo, v_batch_id);
    SP_LOAD_DIM_PAGADOR(v_tipo, v_batch_id);

    -- Paso 3: Carga de Dimensiones SCD Tipo 2 (Históricas / Caducidad + Nueva Versión)
    DBMS_OUTPUT.PUT_LINE('>>> 3. EJECUTANDO CARGA DE DIMENSIONES SCD TIPO 2...');
    SP_LOAD_DIM_CLINICA(v_tipo, v_batch_id);
    SP_LOAD_DIM_MEDICO(v_tipo, v_batch_id);
    SP_LOAD_DIM_PACIENTE(v_tipo, v_batch_id);

    -- Paso 4: Carga de Tablas de Hechos (Fact Tables con SK Lookups)
    DBMS_OUTPUT.PUT_LINE('>>> 4. EJECUTANDO CARGA DE TABLAS DE HECHOS...');
    SP_LOAD_FACT_CONSULTAS(v_tipo, v_batch_id);
    SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS(v_tipo, v_batch_id);
    SP_LOAD_FACT_COBROS_DISTRIBUCION(v_tipo, v_batch_id);

    SP_AUDIT_END(v_audit_id, 0, 0, 0, 0, 'SUCCESS');

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('PIPELINE DWH MASTER FINALIZADO EXITOSAMENTE');
    DBMS_OUTPUT.PUT_LINE('Duración total: ' || TO_CHAR(SYSTIMESTAMP - v_inicio));
    DBMS_OUTPUT.PUT_LINE('================================================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('*** ERROR CRÍTICO EN SP_LOAD_DWH_MASTER: ' || SQLERRM || ' ***');
        RAISE;
END SP_LOAD_DWH_MASTER;
/
