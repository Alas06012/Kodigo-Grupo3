/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
   MASTER DDL: CREACIÓN ORDENADA DE LAS 13 TABLAS DEL DATA WAREHOUSE (DWH)
   ORDEN ESTRICTO: 10 DIMENSIONES (PADRES) -> 3 HECHOS (HIJOS CON FK)
   ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database (XEPDB1)
   ============================================================================ */

PROMPT ============================================================================
PROMPT 1. CREANDO 10 TABLAS DIMENSIONALES (SIN DEPENDENCIAS FK)
PROMPT ============================================================================

@@DimTables/DIM_TIEMPO.sql;
@@DimTables/DIM_UBICACION.sql;
@@DimTables/DIM_CLINICA.sql;
@@DimTables/DIM_ESPECIALIDAD.sql;
@@DimTables/DIM_ENFERMEDAD.sql;
@@DimTables/DIM_TIPO_CONSULTA.sql;
@@DimTables/DIM_FORMA_PAGO.sql;
@@DimTables/DIM_PAGADOR.sql;
@@DimTables/DIM_MEDICO.sql;
@@DimTables/DIM_PACIENTE.sql;

PROMPT ============================================================================
PROMPT 2. CREANDO 3 TABLAS DE HECHOS (CON DEPENDENCIAS FK HACIA DIMENSIONES)
PROMPT ============================================================================

@@FactTables/FACT_CONSULTAS.sql;
@@FactTables/FACT_CONSULTA_DIAGNOSTICOS.sql;
@@FactTables/FACT_COBROS_DISTRIBUCION.sql;

PROMPT ============================================================================
PROMPT 13 TABLAS DWH CREADAS EXITOSAMENTE (10 DIMENSIONES + 3 HECHOS CON 19 FKS).
PROMPT ============================================================================
