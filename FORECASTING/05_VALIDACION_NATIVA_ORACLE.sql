-- ============================================================================
-- VALIDACIÓN NATIVA CON FUNCIONES ESTADÍSTICAS DE ORACLE
-- Comprueba los cálculos de mínimos cuadrados mediante REGR_SLOPE y REGR_INTERCEPT
-- ============================================================================

SELECT 
    ROUND(REGR_SLOPE(total_ventas, mes_id), 4)                                                 AS M_NATIVO_ORACLE,
    ROUND(REGR_INTERCEPT(total_ventas, mes_id), 4)                                             AS B_NATIVO_ORACLE,
    ROUND((REGR_SLOPE(total_ventas, mes_id) * 13) + REGR_INTERCEPT(total_ventas, mes_id), 2)  AS PROYECCION_MES_13_ORACLE
FROM historico_ventas;
