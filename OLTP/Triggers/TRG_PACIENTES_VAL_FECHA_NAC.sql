-- ============================================================================
-- TRIGGER: TRG_PACIENTES_VAL_FECHA_NAC
-- OBJETIVO: Impedir fechas de nacimiento futuras en pacientes
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE TRIGGER TRG_PACIENTES_VAL_FECHA_NAC
BEFORE INSERT OR UPDATE OF FECHA_NACIMIENTO ON PACIENTES
FOR EACH ROW
BEGIN
    IF :NEW.FECHA_NACIMIENTO > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'La fecha de nacimiento no puede ser una fecha futura.');
    END IF;
END;
/
