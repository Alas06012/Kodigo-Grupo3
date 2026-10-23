-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_TIEMPO
-- OBJETIVO: Wrapper estándar para poblar o actualizar DIM_TIEMPO
-- ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_TIEMPO (
    p_anio_inicio IN NUMBER   DEFAULT 2024,
    p_anio_fin    IN NUMBER   DEFAULT 2030,
    p_batch_id    IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
BEGIN
    SP_POBLAR_DIM_TIEMPO(p_anio_inicio, p_anio_fin, p_batch_id);
END SP_LOAD_DIM_TIEMPO;
/
