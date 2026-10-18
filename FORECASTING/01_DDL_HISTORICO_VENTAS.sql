-- ============================================================================
-- PASO 1: DEFINICIÓN DE ESTRUCTURA (DDL)
-- TABLA: historico_ventas
-- MOTOR: Oracle Database
-- ============================================================================

-- Limpieza preventiva si ya existía la tabla
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE historico_ventas CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

-- Creación de la tabla con tipos de datos nativos de Oracle
CREATE TABLE historico_ventas (
    mes_id       NUMBER(4) PRIMARY KEY,
    mes_nombre   VARCHAR2(20) NOT NULL,
    total_ventas NUMBER(10, 2) NOT NULL
);

COMMENT ON TABLE historico_ventas IS 'Histórico mensual de ventas para análisis de regresión y forecasting';
COMMENT ON COLUMN historico_ventas.mes_id IS 'Variable independiente (X): Orden cronológico del mes (1 a 12)';
COMMENT ON COLUMN historico_ventas.mes_nombre IS 'Nombre del mes';
COMMENT ON COLUMN historico_ventas.total_ventas IS 'Variable dependiente (Y): Ventas totales registradas en el mes';
