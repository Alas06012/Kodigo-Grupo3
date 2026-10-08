/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
   SCRIPT DE AUDITORÍA Y CONTROL DE CALIDAD POST-INGESTA (OLTP)
   MOTOR: Oracle Database (XEPDB1) | ESQUEMA: red_clinica_user
   ============================================================================
   OBJETIVO:
     Verificar integralmente que la carga masiva de los 8.33 millones de
     registros se haya realizado con éxito, sin pérdidas de datos, sin
     registros huérfanos, con balance contable y con todas las restricciones
     e identities correctamente blindadas.
   ============================================================================ */

SET PAGESIZE 100;
SET LINESIZE 200;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT 1. VOLUMEN DE REGISTROS POR TABLA (ORDEN TOPOLÓGICO)
PROMPT ============================================================================

SELECT 
    RPAD(table_name, 28) AS tabla,
    TO_CHAR(num_rows, '999,999,999') AS total_filas,
    CASE 
        WHEN num_rows > 0 THEN 'OK - CARGADA' 
        ELSE 'ERROR - VACIA' 
    END AS estado
FROM (
    SELECT 1 AS orden, 'UBICACIONES' AS table_name, COUNT(*) AS num_rows FROM UBICACIONES UNION ALL
    SELECT 2, 'EMPRESAS', COUNT(*) FROM EMPRESAS UNION ALL
    SELECT 3, 'ASEGURADORAS', COUNT(*) FROM ASEGURADORAS UNION ALL
    SELECT 4, 'ESPECIALIDADES', COUNT(*) FROM ESPECIALIDADES UNION ALL
    SELECT 5, 'ENFERMEDADES', COUNT(*) FROM ENFERMEDADES UNION ALL
    SELECT 6, 'TIPOS_CONSULTA', COUNT(*) FROM TIPOS_CONSULTA UNION ALL
    SELECT 7, 'PROCEDIMIENTOS', COUNT(*) FROM PROCEDIMIENTOS UNION ALL
    SELECT 8, 'FORMAS_PAGO', COUNT(*) FROM FORMAS_PAGO UNION ALL
    SELECT 9, 'CLINICAS', COUNT(*) FROM CLINICAS UNION ALL
    SELECT 10, 'MEDICOS', COUNT(*) FROM MEDICOS UNION ALL
    SELECT 11, 'PACIENTES', COUNT(*) FROM PACIENTES UNION ALL
    SELECT 12, 'MEDICOS_ESPECIALIDADES', COUNT(*) FROM MEDICOS_ESPECIALIDADES UNION ALL
    SELECT 13, 'CONSULTAS', COUNT(*) FROM CONSULTAS UNION ALL
    SELECT 14, 'DIAGNOSTICOS', COUNT(*) FROM DIAGNOSTICOS UNION ALL
    SELECT 15, 'CONSULTAS_PROCEDIMIENTOS', COUNT(*) FROM CONSULTAS_PROCEDIMIENTOS UNION ALL
    SELECT 16, 'COBROS_CONSULTA', COUNT(*) FROM COBROS_CONSULTA UNION ALL
    SELECT 17, 'DISTRIBUCION_COBRO', COUNT(*) FROM DISTRIBUCION_COBRO UNION ALL
    SELECT 18, 'TRANSACCIONES_PAGO', COUNT(*) FROM TRANSACCIONES_PAGO
)
ORDER BY orden;

PROMPT
PROMPT ============================================================================
PROMPT 2. CONTROL DE INTEGRIDAD REFERENCIAL (REGISTROS HUÉRFANOS - DEBE DAR 0)
PROMPT ============================================================================

SELECT 
    'CONSULTAS sin PACIENTE válido' AS regla_fk,
    COUNT(*) AS registros_huerfanos
FROM CONSULTAS c
WHERE NOT EXISTS (SELECT 1 FROM PACIENTES p WHERE p.ID_PACIENTE = c.ID_PACIENTE)
UNION ALL
SELECT 
    'CONSULTAS sin MÉDICO válido',
    COUNT(*)
FROM CONSULTAS c
WHERE NOT EXISTS (SELECT 1 FROM MEDICOS m WHERE m.ID_MEDICO = c.ID_MEDICO)
UNION ALL
SELECT 
    'DIAGNOSTICOS sin CONSULTA válida',
    COUNT(*)
FROM DIAGNOSTICOS d
WHERE NOT EXISTS (SELECT 1 FROM CONSULTAS c WHERE c.ID_CONSULTA = d.ID_CONSULTA)
UNION ALL
SELECT 
    'COBROS sin CONSULTA válida',
    COUNT(*)
FROM COBROS_CONSULTA cb
WHERE NOT EXISTS (SELECT 1 FROM CONSULTAS c WHERE c.ID_CONSULTA = cb.ID_CONSULTA)
UNION ALL
SELECT 
    'DISTRIBUCIONES sin COBRO válido',
    COUNT(*)
FROM DISTRIBUCION_COBRO dc
WHERE NOT EXISTS (SELECT 1 FROM COBROS_CONSULTA cb WHERE cb.ID_COBRO = dc.ID_COBRO)
UNION ALL
SELECT 
    'TRANSACCIONES sin DISTRIBUCIÓN válida',
    COUNT(*)
FROM TRANSACCIONES_PAGO tp
WHERE NOT EXISTS (SELECT 1 FROM DISTRIBUCION_COBRO dc WHERE dc.ID_DISTRIBUCION = tp.ID_DISTRIBUCION);

PROMPT
PROMPT ============================================================================
PROMPT 3. CONSISTENCIA CONTABLE Y FINANCIERA (DEBE DAR 0 INCONSISTENCIAS)
PROMPT ============================================================================

SELECT 
    TO_CHAR(COUNT(*), '999,999,999') AS total_cobros_auditados,
    TO_CHAR(SUM(CASE WHEN ABS((MONTO_TOTAL_PAGADO + SALDO_PENDIENTE) - MONTO_TOTAL_FACTURADO) > 0.01 THEN 1 ELSE 0 END), '999,999,999') AS cobros_descuadrados,
    TO_CHAR(SUM(MONTO_TOTAL_FACTURADO), '$999,999,999,990.00') AS total_facturado,
    TO_CHAR(SUM(MONTO_TOTAL_PAGADO), '$999,999,999,990.00') AS total_pagado,
    TO_CHAR(SUM(SALDO_PENDIENTE), '$999,999,999,990.00') AS total_pendiente
FROM COBROS_CONSULTA;

PROMPT
PROMPT ============================================================================
PROMPT 4. AUDITORÍA DE OBJETOS: CONSTRAINTS, TRIGGERS Y COLUMNAS IDENTITY
PROMPT ============================================================================

SELECT 
    'CONSTRAINTS ACTIVAS (ENABLED)' AS objeto,
    COUNT(*) AS cantidad,
    CASE WHEN COUNT(*) = 159 THEN 'OK (Todas Habilitadas)' ELSE 'ALERTA' END AS diagnostico
FROM USER_CONSTRAINTS
WHERE STATUS = 'ENABLED'
UNION ALL
SELECT 
    'CONSTRAINTS DESHABILITADAS',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK (Cero Deshabilitadas)' ELSE 'ERROR' END
FROM USER_CONSTRAINTS
WHERE STATUS != 'ENABLED'
UNION ALL
SELECT 
    'TRIGGERS ACTIVOS (ENABLED)',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'OK (Activos)' ELSE 'ALERTA' END
FROM USER_TRIGGERS
WHERE STATUS = 'ENABLED'
UNION ALL
SELECT 
    'COLUMNAS IDENTITY (ALWAYS)',
    COUNT(*),
    CASE WHEN COUNT(*) = 18 THEN 'OK (18/18 Blindadas en ALWAYS)' ELSE 'ERROR' END
FROM USER_TAB_IDENTITY_COLS
WHERE GENERATION_TYPE = 'ALWAYS';

PROMPT
PROMPT ============================================================================
PROMPT AUDITORÍA COMPLETADA EXITOSAMENTE.
PROMPT ============================================================================
