/* ============================================================================
   PASO 05: EJECUCION ORQUESTADA DEL PIPELINE ETL (FULL LOAD / INCREMENTAL)
   ============================================================================
   USUARIO DE CONEXION: dwh_clinica_user
   CONTRASEÑA:          DwhPass2026
   CONTENEDOR (PDB):    XEPDB1
   HOST / PUERTO:       localhost:1521
   ============================================================================
   INSTRUCCIONES DE EJECUCION:
     1. Conectate como 'dwh_clinica_user' (DwhPass2026) en XEPDB1.
     2. Ejecuta este script para disparar la carga end-to-end de los 8.34M de filas.
     3. Este script invoca 'SP_LOAD_DWH_MASTER', el cual automaticamente:
        a) Extrae desde OLTP hacia Staging (stg_clinica_user.SP_EXTRACT_OLTP_TO_STG)
        b) Carga la dimension conformada de Tiempo (2024 - 2030)
        c) Carga las dimensiones SCD Tipo 1 (Ubicacion, Especialidad, etc.)
        d) Carga las dimensiones SCD Tipo 2 historicas (Clinica, Medico, Paciente)
        e) Carga las 3 tablas de hechos con resolucion de Surrogate Keys
        f) Registra metricas y tiempos centavo a centavo en CTL_ETL_AUDIT.
   ============================================================================ */

SET FEEDBACK ON;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

PROMPT ============================================================================
PROMPT INICIANDO CARGA COMPLETA (FULL LOAD) DEL DATA WAREHOUSE...
PROMPT ============================================================================

BEGIN
    -- Modo 'FULL' para la carga inicial de todas las atenciones e historial
    SP_LOAD_DWH_MASTER(
        p_tipo_carga    => 'FULL',
        p_dias_lookback => 3,
        p_fecha_corte   => NULL,
        p_batch_id      => 'BATCH_INICIAL_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS')
    );
END;
/

PROMPT ============================================================================
PROMPT CARGA ETL FINALIZADA. VERIFICANDO RESUMEN EN CTL_ETL_AUDIT:
PROMPT ============================================================================

SELECT 
    ID_AUDIT,
    BATCH_ID,
    CAPA,
    OBJETO_DESTINO,
    PROCEDIMIENTO,
    TIPO_CARGA,
    TO_CHAR(FECHA_INICIO, 'YYYY-MM-DD HH24:MI:SS') AS FECHA_INICIO,
    DURACION_SEGUNDOS,
    FILAS_INSERTADAS,
    FILAS_ACTUALIZADAS,
    ESTADO
FROM CTL_ETL_AUDIT
WHERE BATCH_ID = (SELECT MAX(BATCH_ID) FROM CTL_ETL_AUDIT)
ORDER BY ID_AUDIT ASC;
