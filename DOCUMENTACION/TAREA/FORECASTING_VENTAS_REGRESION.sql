-----------------------------------------
-- Limpieza preventiva si la tabla ya existe, pero aca nomas pueden verificarla o ejecutarlo todo de una
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE historico_ventas';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE historico_ventas (
  mes_id INT PRIMARY KEY,
  mes_nombre VARCHAR2(20),
  total_ventas NUMBER(10, 2)
);

-- Inserción del histórico de 12 meses (compatible Oracle / ANSI SQL)
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (1, 'Enero', 1200.50);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (2, 'Febrero', 1350.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (3, 'Marzo', 1420.75);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (4, 'Abril', 1580.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (5, 'Mayo', 1700.20);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (6, 'Junio', 1650.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (7, 'Julio', 1820.40);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (8, 'Agosto', 1950.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (9, 'Septiembre', 2100.10);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (10, 'Octubre', 2050.50);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (11, 'Noviembre', 2300.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (12, 'Diciembre', 2550.00);
COMMIT;

-- ----------------------------------------------------------------------------
-- PASO 2.1: CÁLCULO DE VARIABLES ESTADÍSTICAS INDIVIDUALES
-- Componentes: n, sum(X), sum(Y), sum(XY), sum(X^2)
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(*) AS n,
    SUM(mes_id) AS sum_x,
    ROUND(SUM(total_ventas), 2) AS sum_y,
    ROUND(SUM(mes_id * total_ventas), 2) AS sum_xy,
    SUM(mes_id * mes_id) AS sum_x2,
    SUM(mes_id) * SUM(mes_id) AS sum_x_al_cuadrado
FROM historico_ventas;

-- ----------------------------------------------------------------------------
-- PASO 2.2, 2.3 y 3: QUERY INTEGRAL DE FORECASTING
-- Determina: Pendiente (m), Intersección (b) y Proyección para Mes 13
-- ----------------------------------------------------------------------------
WITH variables_estadisticas AS (
    SELECT
        COUNT(*) AS n,
        SUM(mes_id) AS sum_x,
        SUM(total_ventas) AS sum_y,
        SUM(mes_id * total_ventas) AS sum_xy,
        SUM(mes_id * mes_id) AS sum_x2
    FROM historico_ventas
),
parametros_regresion AS (
    SELECT
        n,
        sum_x,
        sum_y,
        sum_xy,
        sum_x2,
        -- Fórmula de la Pendiente (m): [n*Σ(xy) - Σx*Σy] / [n*Σ(x^2) - (Σx)^2]
        ( (n * sum_xy) - (sum_x * sum_y) ) / ( (n * sum_x2) - (sum_x * sum_x) ) AS m,
        -- Fórmula de la Intersección (b): [Σy - m*Σx] / n
        ( sum_y - ( ( (n * sum_xy) - (sum_x * sum_y) ) / ( (n * sum_x2) - (sum_x * sum_x) ) ) * sum_x ) / n AS b
    FROM variables_estadisticas
)
SELECT
    n,
    sum_x,
    ROUND(sum_y, 2) AS sum_y,
    ROUND(sum_xy, 2) AS sum_xy,
    sum_x2,
    ROUND(m, 4) AS pendiente_m,
    ROUND(b, 4) AS interseccion_b,
    13 AS mes_proyectado,
    ROUND((m * 13) + b, 2) AS venta_proyectada_mes_13
FROM parametros_regresion;

-- ----------------------------------------------------------------------------
-- VALIDACIÓN 
-- ----------------------------------------------------------------------------
SELECT 
    ROUND(REGR_SLOPE(total_ventas, mes_id), 4) AS m_validado,
    ROUND(REGR_INTERCEPT(total_ventas, mes_id), 4) AS b_validado,
    ROUND((REGR_SLOPE(total_ventas, mes_id) * 13) + REGR_INTERCEPT(total_ventas, mes_id), 2) AS proyeccion_mes_13_validada
FROM historico_ventas;
