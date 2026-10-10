/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
   MASTER DDL: CREACIÓN ORDENADA DE LAS 18 TABLAS DE STAGING
   ESQUEMA: stg_clinica_user | MOTOR: Oracle Database (XEPDB1)
   ============================================================================ */

-- Si se ejecuta desde SQL*Plus o SQLcl:
-- @Tables/STG_UBICACIONES.sql
-- @Tables/STG_EMPRESAS.sql
-- ...

PROMPT ============================================================================
PROMPT 1. CREANDO TABLAS DE CATÁLOGOS BASE (NIVEL 0)
PROMPT ============================================================================

@@Tables/STG_UBICACIONES.sql;
@@Tables/STG_EMPRESAS.sql;
@@Tables/STG_ASEGURADORAS.sql;
@@Tables/STG_ESPECIALIDADES.sql;
@@Tables/STG_ENFERMEDADES.sql;
@@Tables/STG_TIPOS_CONSULTA.sql;
@@Tables/STG_PROCEDIMIENTOS.sql;
@@Tables/STG_FORMAS_PAGO.sql;

PROMPT ============================================================================
PROMPT 2. CREANDO ENTIDADES BASE Y CUERPO MÉDICO (NIVELES 1 Y 2)
PROMPT ============================================================================

@@Tables/STG_CLINICAS.sql;
@@Tables/STG_MEDICOS.sql;
@@Tables/STG_PACIENTES.sql;

PROMPT ============================================================================
PROMPT 3. CREANDO CONSULTAS Y ASIGNACIONES (NIVELES 3 Y 4)
PROMPT ============================================================================

@@Tables/STG_MEDICOS_ESPECIALIDADES.sql;
@@Tables/STG_CONSULTAS.sql;
@@Tables/STG_DIAGNOSTICOS.sql;
@@Tables/STG_CONSULTAS_PROCEDIMIENTOS.sql;

PROMPT ============================================================================
PROMPT 4. CREANDO FACTURACIÓN, COBROS Y PAGOS (NIVELES 4, 5 Y 6)
PROMPT ============================================================================

@@Tables/STG_COBROS_CONSULTA.sql;
@@Tables/STG_DISTRIBUCION_COBRO.sql;
@@Tables/STG_TRANSACCIONES_PAGO.sql;

PROMPT ============================================================================
PROMPT 18 TABLAS DE STAGING CREADAS EXITOSAMENTE.
PROMPT ============================================================================
