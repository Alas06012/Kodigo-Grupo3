/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
   CAPA DWH: VALIDACIÓN ANALÍTICA DE KPIS DE NEGOCIO Y AUDITORÍA
   MOTOR: Oracle Database 19c / 21c / 23ai (PDB: XEPDB1)
   ESQUEMA: dwh_clinica_user
   
   OBJETIVO:
     Comprobar que el modelo dimensional en estrella responde de manera óptima,
     precisa y performante a las 12 preguntas analíticas del requerimiento institucional.
   ============================================================================ */

ALTER SESSION SET CONTAINER = XEPDB1;
-- ALTER SESSION SET CURRENT_SCHEMA = dwh_clinica_user;

SET LINESIZE 200;
SET PAGESIZE 100;

PROMPT ============================================================================
PROMPT CONTROL DE AUDITORÍA: TOTAL DE REGISTROS POR TABLA EN DATA WAREHOUSE
PROMPT ============================================================================

SELECT 'DIM_UBICACION' AS TABLA, COUNT(*) AS TOTAL_FILAS, SUM(CURRENTFLAG) AS VIGENTES FROM DIM_UBICACION UNION ALL
SELECT 'DIM_ESPECIALIDAD', COUNT(*), SUM(CURRENTFLAG) FROM DIM_ESPECIALIDAD UNION ALL
SELECT 'DIM_ENFERMEDAD', COUNT(*), SUM(CURRENTFLAG) FROM DIM_ENFERMEDAD UNION ALL
SELECT 'DIM_TIPO_CONSULTA', COUNT(*), SUM(CURRENTFLAG) FROM DIM_TIPO_CONSULTA UNION ALL
SELECT 'DIM_FORMA_PAGO', COUNT(*), SUM(CURRENTFLAG) FROM DIM_FORMA_PAGO UNION ALL
SELECT 'DIM_PAGADOR', COUNT(*), SUM(CURRENTFLAG) FROM DIM_PAGADOR UNION ALL
SELECT 'DIM_CLINICA', COUNT(*), SUM(CURRENTFLAG) FROM DIM_CLINICA UNION ALL
SELECT 'DIM_MEDICO', COUNT(*), SUM(CURRENTFLAG) FROM DIM_MEDICO UNION ALL
SELECT 'DIM_PACIENTE', COUNT(*), SUM(CURRENTFLAG) FROM DIM_PACIENTE UNION ALL
SELECT 'DIM_TIEMPO', COUNT(*), SUM(CURRENTFLAG) FROM DIM_TIEMPO UNION ALL
SELECT 'FACT_CONSULTAS', COUNT(*), SUM(CURRENTFLAG) FROM FACT_CONSULTAS UNION ALL
SELECT 'FACT_CONSULTA_DIAGNOSTICOS', COUNT(*), SUM(CURRENTFLAG) FROM FACT_CONSULTA_DIAGNOSTICOS UNION ALL
SELECT 'FACT_COBROS_DISTRIBUCION', COUNT(*), SUM(CURRENTFLAG) FROM FACT_COBROS_DISTRIBUCION;


PROMPT ============================================================================
PROMPT KPI 1: ¿Cuántos pacientes atiende cada clínica?
PROMPT Muestra pacientes únicos atendidos por sede asistencial
PROMPT ============================================================================
SELECT 
    c.NOMBRE_CLINICA,
    c.DEPARTAMENTO AS DEPARTAMENTO_SEDE,
    COUNT(DISTINCT f.SK_PACIENTE) AS TOTAL_PACIENTES_UNICOS,
    SUM(f.CANTIDAD_CONSULTAS)     AS TOTAL_ATENCIONES_BRUTAS
FROM FACT_CONSULTAS f
INNER JOIN DIM_CLINICA c ON f.SK_CLINICA = c.SK_CLINICA
GROUP BY c.NOMBRE_CLINICA, c.DEPARTAMENTO
ORDER BY TOTAL_PACIENTES_UNICOS DESC;


PROMPT ============================================================================
PROMPT KPI 2: ¿De qué regiones provienen los pacientes?
PROMPT Muestra la procedencia demográfica de los pacientes atendidos
PROMPT ============================================================================
SELECT 
    u.DEPARTAMENTO,
    u.MUNICIPIO,
    COUNT(DISTINCT f.SK_PACIENTE) AS PACIENTES_UNICOS,
    SUM(f.CANTIDAD_CONSULTAS)     AS VOLUMEN_CONSULTAS,
    ROUND(COUNT(DISTINCT f.SK_PACIENTE) * 100.0 / SUM(COUNT(DISTINCT f.SK_PACIENTE)) OVER(), 2) AS PORC_PACIENTES
FROM FACT_CONSULTAS f
INNER JOIN DIM_UBICACION u ON f.SK_UBICACION_PACIENTE = u.SK_UBICACION
GROUP BY u.DEPARTAMENTO, u.MUNICIPIO
ORDER BY PACIENTES_UNICOS DESC;


PROMPT ============================================================================
PROMPT KPI 3: ¿Cuál es la distribución por edad de los pacientes?
PROMPT Segmentación por grupos etarios epidemiológicos
PROMPT ============================================================================
SELECT 
    p.GRUPO_ETARIO,
    COUNT(DISTINCT f.SK_PACIENTE) AS PACIENTES_UNICOS,
    SUM(f.CANTIDAD_CONSULTAS)     AS TOTAL_CONSULTAS,
    ROUND(AVG(p.EDAD), 1)         AS EDAD_PROMEDIO,
    ROUND(SUM(f.MONTO_TOTAL_FACTURADO), 2) AS FACTURACION_TOTAL
FROM FACT_CONSULTAS f
INNER JOIN DIM_PACIENTE p ON f.SK_PACIENTE = p.SK_PACIENTE
GROUP BY p.GRUPO_ETARIO
ORDER BY PACIENTES_UNICOS DESC;


PROMPT ============================================================================
PROMPT KPI 4: ¿Qué enfermedades son más frecuentes? (Top Epidemiológico)
PROMPT Ranking de diagnósticos confirmados según CIE-10
PROMPT ============================================================================
SELECT 
    e.CODIGO_CIE10,
    e.NOMBRE_ENFERMEDAD,
    SUM(fd.CONTEO_DIAGNOSTICO) AS FRECUENCIA_CASOS,
    COUNT(DISTINCT fd.SK_PACIENTE) AS PACIENTES_AFECTADOS,
    ROUND(SUM(fd.CONTEO_DIAGNOSTICO) * 100.0 / SUM(SUM(fd.CONTEO_DIAGNOSTICO)) OVER(), 2) AS PORCENTAJE_INCIDENCIA
FROM FACT_CONSULTA_DIAGNOSTICOS fd
INNER JOIN DIM_ENFERMEDAD e ON fd.SK_ENFERMEDAD = e.SK_ENFERMEDAD
GROUP BY e.CODIGO_CIE10, e.NOMBRE_ENFERMEDAD
ORDER BY FRECUENCIA_CASOS DESC;


PROMPT ============================================================================
PROMPT KPI 5: ¿Cuánto cuesta atender cada tipo de enfermedad?
PROMPT Costo total y costo promedio por evento patológico (Prorrateo Exacto)
PROMPT ============================================================================
SELECT 
    e.NOMBRE_ENFERMEDAD,
    e.CODIGO_CIE10,
    SUM(fd.CONTEO_DIAGNOSTICO)            AS TOTAL_CASOS,
    ROUND(SUM(fd.MONTO_PRORRATEADO), 2)   AS COSTO_TOTAL_ATENCION,
    ROUND(AVG(fd.MONTO_PRORRATEADO), 2)   AS COSTO_PROMEDIO_POR_CASO,
    ROUND(MIN(fd.MONTO_PRORRATEADO), 2)   AS COSTO_MINIMO,
    ROUND(MAX(fd.MONTO_PRORRATEADO), 2)   AS COSTO_MAXIMO
FROM FACT_CONSULTA_DIAGNOSTICOS fd
INNER JOIN DIM_ENFERMEDAD e ON fd.SK_ENFERMEDAD = e.SK_ENFERMEDAD
GROUP BY e.NOMBRE_ENFERMEDAD, e.CODIGO_CIE10
ORDER BY COSTO_TOTAL_ATENCION DESC;


PROMPT ============================================================================
PROMPT KPI 6: ¿Cuántas consultas se realizan en total y por especialidad?
PROMPT Volumen global de atenciones médicas
PROMPT ============================================================================
SELECT 
    esp.NOMBRE_ESPECIALIDAD,
    tc.NOMBRE_TIPO AS MODALIDAD_CONSULTA,
    SUM(f.CANTIDAD_CONSULTAS) AS TOTAL_CONSULTAS,
    SUM(f.CANTIDAD_PROCEDIMIENTOS) AS TOTAL_PROCEDIMIENTOS_REALIZADOS
FROM FACT_CONSULTAS f
INNER JOIN DIM_ESPECIALIDAD esp ON f.SK_ESPECIALIDAD = esp.SK_ESPECIALIDAD
INNER JOIN DIM_TIPO_CONSULTA tc ON f.SK_TIPO_CONSULTA = tc.SK_TIPO_CONSULTA
GROUP BY esp.NOMBRE_ESPECIALIDAD, tc.NOMBRE_TIPO
ORDER BY TOTAL_CONSULTAS DESC;


PROMPT ============================================================================
PROMPT KPI 7: ¿Cuánto se factura en total, cuánto se ha cobrado y cuánto está pendiente?
PROMPT Balance financiero global de la red médica
PROMPT ============================================================================
SELECT 
    SUM(f.CANTIDAD_CONSULTAS)              AS TOTAL_CONSULTAS,
    ROUND(SUM(f.PRECIO_HONORARIOS), 2)     AS TOTAL_HONORARIOS,
    ROUND(SUM(f.TOTAL_PROCEDIMIENTOS), 2)  AS TOTAL_PROCEDIMIENTOS,
    ROUND(SUM(f.MONTO_TOTAL_FACTURADO), 2) AS MONTO_TOTAL_FACTURADO,
    ROUND(SUM(f.MONTO_TOTAL_PAGADO), 2)    AS MONTO_TOTAL_RECAUDADO,
    ROUND(SUM(f.SALDO_PENDIENTE), 2)       AS CARTERA_PENDIENTE_COBRO,
    ROUND(SUM(f.MONTO_TOTAL_PAGADO) * 100.0 / NULLIF(SUM(f.MONTO_TOTAL_FACTURADO), 0), 2) AS TASA_RECUPERACION_PCT
FROM FACT_CONSULTAS f;


PROMPT ============================================================================
PROMPT KPI 8: ¿Quién paga: paciente, empresa o aseguradora?
PROMPT Participación económica por categoría de pagador
PROMPT ============================================================================
SELECT 
    dp.CATEGORIA_PAGADOR,
    dp.TIPO_PAGADOR,
    COUNT(fcd.SK_COBRO_DISTRIBUCION)         AS TOTAL_CUOTAS_COBRO,
    ROUND(SUM(fcd.MONTO_ASIGNADO), 2)        AS MONTO_TOTAL_RESPONSABILIDAD,
    ROUND(SUM(fcd.MONTO_PAGADO), 2)          AS MONTO_EFECTIVAMENTE_PAGADO,
    ROUND(SUM(fcd.SALDO_PENDIENTE), 2)       AS SALDO_POR_COBRAR,
    ROUND(SUM(fcd.MONTO_ASIGNADO) * 100.0 / SUM(SUM(fcd.MONTO_ASIGNADO)) OVER(), 2) AS PARTICIPACION_PCT
FROM FACT_COBROS_DISTRIBUCION fcd
INNER JOIN DIM_PAGADOR dp ON fcd.SK_PAGADOR = dp.SK_PAGADOR
GROUP BY dp.CATEGORIA_PAGADOR, dp.TIPO_PAGADOR
ORDER BY MONTO_TOTAL_RESPONSABILIDAD DESC;


PROMPT ============================================================================
PROMPT KPI 9: ¿Qué clínica tiene mayor volumen de atención médica y facturación?
PROMPT Productividad y eficiencia por sucursal
PROMPT ============================================================================
SELECT 
    c.NOMBRE_CLINICA,
    c.ESTADO AS ESTADO_OPERATIVO,
    SUM(f.CANTIDAD_CONSULTAS)              AS TOTAL_CONSULTAS,
    SUM(f.CANTIDAD_PROCEDIMIENTOS)         AS TOTAL_PROCEDIMIENTOS,
    ROUND(SUM(f.MONTO_TOTAL_FACTURADO), 2) AS MONTO_FACTURADO,
    ROUND(SUM(f.MONTO_TOTAL_PAGADO), 2)    AS MONTO_RECAUDADO,
    ROUND(AVG(f.MONTO_TOTAL_FACTURADO), 2) AS TICKET_PROMEDIO_CLINICA
FROM FACT_CONSULTAS f
INNER JOIN DIM_CLINICA c ON f.SK_CLINICA = c.SK_CLINICA
GROUP BY c.NOMBRE_CLINICA, c.ESTADO
ORDER BY TOTAL_CONSULTAS DESC;


PROMPT ============================================================================
PROMPT KPI 10: ¿Qué enfermedades generan mayores costos globales para la red médica?
PROMPT Ranking de impacto económico por patología
PROMPT ============================================================================
SELECT 
    e.CODIGO_CIE10,
    e.NOMBRE_ENFERMEDAD,
    ROUND(SUM(fd.MONTO_PRORRATEADO), 2)   AS COSTO_TOTAL_ACUMULADO,
    SUM(fd.CONTEO_DIAGNOSTICO)            AS TOTAL_DIAGNOSTICOS,
    ROUND(AVG(fd.MONTO_PRORRATEADO), 2)   AS COSTO_MEDIO_INDIVIDUAL,
    ROUND(SUM(fd.MONTO_PRORRATEADO) * 100.0 / SUM(SUM(fd.MONTO_PRORRATEADO)) OVER(), 2) AS PORCENTAJE_COSTO_GLOBAL
FROM FACT_CONSULTA_DIAGNOSTICOS fd
INNER JOIN DIM_ENFERMEDAD e ON fd.SK_ENFERMEDAD = e.SK_ENFERMEDAD
GROUP BY e.CODIGO_CIE10, e.NOMBRE_ENFERMEDAD
ORDER BY COSTO_TOTAL_ACUMULADO DESC;


PROMPT ============================================================================
PROMPT KPI 11: ¿Cuál es el costo promedio por consulta (Ticket Promedio)?
PROMPT Análisis por Tipo de Consulta y Especialidad
PROMPT ============================================================================
SELECT 
    tc.NOMBRE_TIPO AS MODALIDAD_CONSULTA,
    esp.NOMBRE_ESPECIALIDAD,
    COUNT(*)                               AS TOTAL_CITAS,
    ROUND(AVG(f.MONTO_TOTAL_FACTURADO), 2) AS COSTO_PROMEDIO_TOTAL,
    ROUND(AVG(f.PRECIO_HONORARIOS), 2)     AS HONORARIO_MEDICO_PROMEDIO,
    ROUND(AVG(f.TOTAL_PROCEDIMIENTOS), 2)  AS PROCEDIMIENTOS_PROMEDIO
FROM FACT_CONSULTAS f
INNER JOIN DIM_TIPO_CONSULTA tc ON f.SK_TIPO_CONSULTA = tc.SK_TIPO_CONSULTA
INNER JOIN DIM_ESPECIALIDAD esp ON f.SK_ESPECIALIDAD = esp.SK_ESPECIALIDAD
GROUP BY tc.NOMBRE_TIPO, esp.NOMBRE_ESPECIALIDAD
ORDER BY COSTO_PROMEDIO_TOTAL DESC;


PROMPT ============================================================================
PROMPT KPI 12: ¿Qué comportamiento tienen los servicios a lo largo del tiempo?
PROMPT Evolución cronológica (Año / Mes / Trimestre)
PROMPT ============================================================================
SELECT 
    t.ANIO,
    t.TRIMESTRE,
    t.NOMBRE_MES,
    SUM(f.CANTIDAD_CONSULTAS)              AS VOLUMEN_CONSULTAS,
    SUM(f.CANTIDAD_PROCEDIMIENTOS)         AS VOLUMEN_PROCEDIMIENTOS,
    ROUND(SUM(f.MONTO_TOTAL_FACTURADO), 2) AS FACTURACION_MENSUAL,
    ROUND(SUM(f.MONTO_TOTAL_PAGADO), 2)    AS RECAUDO_MENSUAL,
    ROUND(SUM(f.SALDO_PENDIENTE), 2)       AS CARTERA_MENSUAL
FROM FACT_CONSULTAS f
INNER JOIN DIM_TIEMPO t ON f.SK_TIEMPO = t.SK_TIEMPO
WHERE t.SK_TIEMPO != 19000101
GROUP BY t.ANIO, t.TRIMESTRE, t.MES, t.NOMBRE_MES
ORDER BY t.ANIO, t.MES;

PROMPT ============================================================================
PROMPT FIN DE VALIDACIONES ANALÍTICAS DE KPIS
PROMPT ============================================================================
