-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_TIEMPO
-- OBJETIVO: Wrapper estándar para poblar o actualizar DIM_TIEMPO
-- ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_TIEMPO (
    p_anio_inicio IN NUMBER DEFAULT 2024,
    p_anio_fin    IN NUMBER DEFAULT 2030
)
AUTHID DEFINER
IS
BEGIN
    SP_POBLAR_DIM_TIEMPO(p_anio_inicio, p_anio_fin);
END SP_LOAD_DIM_TIEMPO;
/
