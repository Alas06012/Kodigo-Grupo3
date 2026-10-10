-- ============================================================================
-- PROCEDIMIENTO MAESTRO: SP_LOAD_DWH_MASTER
-- OBJETIVO: Orquestador end-to-end de extracción y carga analítica en el DWH.
--           Invoca de forma modular y secuencial cada procedimiento individual
--           por cada tabla de dimensión y tabla de hechos.
-- ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DWH_MASTER (
    p_tipo_carga    IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback IN NUMBER   DEFAULT 3,
    p_fecha_corte   IN DATE     DEFAULT NULL
)
AUTHID CURRENT_USER
IS
    v_inicio TIMESTAMP := SYSTIMESTAMP;
    v_tipo   VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias   NUMBER := NVL(p_dias_lookback, 3);
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('INICIO DEL PIPELINE ANALÍTICO COMPLETO: DWH RED DE CLÍNICAS');
    DBMS_OUTPUT.PUT_LINE('Modo de Carga: ' || v_tipo || 
                         ' | Ventana Días Lookback: ' || v_dias);
    DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================');

    -- Paso 1: Extracción desde OLTP hacia Staging con ventana optimizada
    DBMS_OUTPUT.PUT_LINE('>>> 1. EJECUTANDO EXTRACCIÓN HACIA STAGING...');
    stg_clinica_user.SP_EXTRACT_OLTP_TO_STG(v_tipo, v_dias, p_fecha_corte);

    -- Paso 2: Carga de Dimensiones SCD Tipo 1 (Sobreescritura con Hash)
    DBMS_OUTPUT.PUT_LINE('>>> 2. EJECUTANDO CARGA DE DIMENSIONES SCD TIPO 1...');
    SP_LOAD_DIM_UBICACION(v_tipo);
    SP_LOAD_DIM_ESPECIALIDAD(v_tipo);
    SP_LOAD_DIM_ENFERMEDAD(v_tipo);
    SP_LOAD_DIM_TIPO_CONSULTA(v_tipo);
    SP_LOAD_DIM_FORMA_PAGO(v_tipo);
    SP_LOAD_DIM_PAGADOR(v_tipo);

    -- Paso 3: Carga de Dimensiones SCD Tipo 2 (Históricas / Caducidad + Nueva Versión)
    DBMS_OUTPUT.PUT_LINE('>>> 3. EJECUTANDO CARGA DE DIMENSIONES SCD TIPO 2...');
    SP_LOAD_DIM_CLINICA(v_tipo);
    SP_LOAD_DIM_MEDICO(v_tipo);
    SP_LOAD_DIM_PACIENTE(v_tipo);

    -- Paso 4: Carga de Tablas de Hechos (Fact Tables con SK Lookups)
    DBMS_OUTPUT.PUT_LINE('>>> 4. EJECUTANDO CARGA DE TABLAS DE HECHOS...');
    SP_LOAD_FACT_CONSULTAS(v_tipo);
    SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS(v_tipo);
    SP_LOAD_FACT_COBROS_DISTRIBUCION(v_tipo);

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('PIPELINE DWH MASTER FINALIZADO EXITOSAMENTE');
    DBMS_OUTPUT.PUT_LINE('Duración total: ' || TO_CHAR(SYSTIMESTAMP - v_inicio));
    DBMS_OUTPUT.PUT_LINE('================================================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('*** ERROR CRÍTICO EN SP_LOAD_DWH_MASTER: ' || SQLERRM || ' ***');
        RAISE;
END SP_LOAD_DWH_MASTER;
/
