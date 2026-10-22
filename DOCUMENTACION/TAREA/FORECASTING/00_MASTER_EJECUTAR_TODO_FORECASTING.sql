-- ============================================================================
-- SCRIPT MASTER DE FORECASTING Y TOMA DE DECISIONES
-- Ejecuta ordenadamente DDL, DML y consultas analíticas
-- ============================================================================

PROMPT ======================================================================;
PROMPT 1. CREANDO TABLA HISTORICO_VENTAS;
PROMPT ======================================================================;
@@01_DDL_HISTORICO_VENTAS.sql;

PROMPT ======================================================================;
PROMPT 2. INSERTANDO LOS 12 MESES HISTORICOS;
PROMPT ======================================================================;
@@02_DML_POBLAR_12_MESES.sql;

PROMPT ======================================================================;
PROMPT 3. CALCULANDO VARIABLES ESTADISTICAS;
PROMPT ======================================================================;
@@03_CALCULO_VARIABLES_ESTADISTICAS.sql;

PROMPT ======================================================================;
PROMPT 4. CALCULANDO REGRESION LINEAL (m, b) Y PROYECCION MES 13;
PROMPT ======================================================================;
@@04_MODELO_REGRESION_Y_PRONOSTICO.sql;

PROMPT ======================================================================;
PROMPT 5. VALIDACION CON FUNCIONES NATIVAS DE ORACLE;
PROMPT ======================================================================;
@@05_VALIDACION_NATIVA_ORACLE.sql;
