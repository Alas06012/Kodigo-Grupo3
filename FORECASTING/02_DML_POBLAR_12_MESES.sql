-- ============================================================================
-- PASO 2: CARGA DE DATOS HISTÓRICOS (DML)
-- INSERCIÓN: 12 meses de ventas
-- ============================================================================

INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (1,  'Enero',      1200.50);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (2,  'Febrero',    1350.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (3,  'Marzo',      1420.75);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (4,  'Abril',      1580.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (5,  'Mayo',       1700.20);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (6,  'Junio',      1650.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (7,  'Julio',      1820.40);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (8,  'Agosto',     1950.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (9,  'Septiembre', 2100.10);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (10, 'Octubre',    2050.50);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (11, 'Noviembre',  2300.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (12, 'Diciembre',  2550.00);

COMMIT;

-- Verificación visual de los registros cargados
SELECT mes_id, mes_nombre, total_ventas 
FROM historico_ventas 
ORDER BY mes_id ASC;
