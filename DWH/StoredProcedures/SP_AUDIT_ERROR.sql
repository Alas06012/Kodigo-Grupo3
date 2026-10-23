-- ============================================================================
-- PROCEDIMIENTO: SP_AUDIT_ERROR
-- OBJETIVO:      Registrar el fallo de ejecución en CTL_ETL_AUDIT preservando
--                el código y mensaje de error incluso ante un ROLLBACK de datos.
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_AUDIT_ERROR (
    p_id_audit      IN NUMBER,
    p_codigo_error  IN VARCHAR2,
    p_mensaje_error IN VARCHAR2
)
AUTHID DEFINER
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_inicio TIMESTAMP;
BEGIN
    BEGIN
        SELECT FECHA_INICIO INTO v_inicio
        FROM CTL_ETL_AUDIT
        WHERE ID_AUDIT = p_id_audit;
    EXCEPTION
        WHEN OTHERS THEN
            v_inicio := SYSTIMESTAMP;
    END;

    UPDATE CTL_ETL_AUDIT
    SET FECHA_FIN         = SYSTIMESTAMP,
        DURACION_SEGUNDOS = ROUND(
            EXTRACT(DAY FROM (SYSTIMESTAMP - v_inicio)) * 86400 +
            EXTRACT(HOUR FROM (SYSTIMESTAMP - v_inicio)) * 3600 +
            EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_inicio)) * 60 +
            EXTRACT(SECOND FROM (SYSTIMESTAMP - v_inicio)),
            2
        ),
        ESTADO            = 'FAILED',
        CODIGO_ERROR      = SUBSTR(p_codigo_error, 1, 30),
        MENSAJE_ERROR     = SUBSTR(p_mensaje_error, 1, 4000)
    WHERE ID_AUDIT = p_id_audit;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
END SP_AUDIT_ERROR;
/

GRANT EXECUTE ON SP_AUDIT_ERROR TO stg_clinica_user;
