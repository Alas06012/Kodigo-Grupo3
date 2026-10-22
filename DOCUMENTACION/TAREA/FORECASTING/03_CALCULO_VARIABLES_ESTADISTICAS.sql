-- ============================================================================
-- ACTIVIDAD 1: CÁLCULO DE VARIABLES ESTADÍSTICAS
-- Componentes requeridos: n, ΣX, ΣY, ΣXY, ΣX² y (ΣX)²
-- ============================================================================

SELECT 
    COUNT(*)                             AS N,
    SUM(mes_id)                          AS SUM_X,
    ROUND(SUM(total_ventas), 2)          AS SUM_Y,
    ROUND(SUM(mes_id * total_ventas), 2) AS SUM_XY,
    SUM(mes_id * mes_id)                 AS SUM_X2,
    SUM(mes_id) * SUM(mes_id)            AS SUM_X_AL_CUADRADO,
    (COUNT(*) * SUM(mes_id * mes_id)) - (SUM(mes_id) * SUM(mes_id)) AS DENOMINADOR_COMUN
FROM historico_ventas;
