-- ============================================================================
-- TRIGGER: TRG_CONSULTAS_VAL_ESP_MED
-- OBJETIVO: Garantizar que el médico tenga la especialidad acreditada
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE TRIGGER TRG_CONSULTAS_VAL_ESP_MED
BEFORE INSERT OR UPDATE OF ID_MEDICO, ID_ESPECIALIDAD ON CONSULTAS
FOR EACH ROW
DECLARE
    v_existe NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO   v_existe
    FROM   MEDICOS_ESPECIALIDADES
    WHERE  ID_MEDICO       = :NEW.ID_MEDICO
      AND  ID_ESPECIALIDAD = :NEW.ID_ESPECIALIDAD;

    IF v_existe = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20002, 
            'El médico ID ' || :NEW.ID_MEDICO || 
            ' no cuenta con la especialidad ID ' || :NEW.ID_ESPECIALIDAD || ' acreditada.'
        );
    END IF;
END;
/
