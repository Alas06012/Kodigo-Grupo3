-- ============================================================================
-- ACTIVIDAD 2 & 3: DETERMINACIÓN DE PENDIENTE (m), INTERSECCIÓN (b) Y PRONÓSTICO
-- Ecuación de la Recta: Y = mX + b
-- Pronóstico para Mes 13: Y_13 = (m * 13) + b
-- ============================================================================

WITH variables_estadisticas AS (
    SELECT
        COUNT(*)                   AS n,
        SUM(mes_id)                AS sum_x,
        SUM(total_ventas)          AS sum_y,
        SUM(mes_id * total_ventas) AS sum_xy,
        SUM(mes_id * mes_id)       AS sum_x2
    FROM historico_ventas
),
parametros_regresion AS (
    SELECT
        n,
        sum_x,
        sum_y,
        sum_xy,
        sum_x2,
        -- Fórmula de Pendiente m = [n*Σ(xy) - Σx*Σy] / [n*Σ(x^2) - (Σx)^2]
        ( (n * sum_xy) - (sum_x * sum_y) ) / ( (n * sum_x2) - (sum_x * sum_x) ) AS m,
        -- Fórmula de Intersección b = [Σy - m*Σx] / n
        ( sum_y - ( ( (n * sum_xy) - (sum_x * sum_y) ) / ( (n * sum_x2) - (sum_x * sum_x) ) ) * sum_x ) / n AS b
    FROM variables_estadisticas
)
SELECT
    n                                   AS N,
    sum_x                               AS SUM_X,
    ROUND(sum_y, 2)                     AS SUM_Y,
    ROUND(sum_xy, 2)                    AS SUM_XY,
    sum_x2                              AS SUM_X2,
    ROUND(m, 4)                         AS PENDIENTE_M,
    ROUND(b, 4)                         AS INTERSECCION_B,
    13                                  AS MES_PROYECTADO,
    ROUND((m * 13) + b, 2)              AS VENTA_PROYECTADA_MES_13
FROM parametros_regresion;
