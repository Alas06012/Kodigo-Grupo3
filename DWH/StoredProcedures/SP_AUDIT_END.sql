-- ============================================================================
-- PROCEDIMIENTO: SP_AUDIT_END
-- OBJETIVO:      Registrar la finalización exitosa de un proceso ETL en CTL_ETL_AUDIT
--                calculando la duración en segundos y filas procesadas.
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_AUDIT_END (
    p_id_audit           IN NUMBER,
    p_filas_leidas       IN NUMBER DEFAULT 0,
    p_filas_insertadas   IN NUMBER DEFAULT 0,
    p_filas_actualizadas IN NUMBER DEFAULT 0,
    p_filas_rechazadas   IN NUMBER DEFAULT 0,
    p_estado             IN VARCHAR2 DEFAULT 'SUCCESS'
)
AUTHID DEFINER
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_inicio TIMESTAMP;
BEGIN
    SELECT FECHA_INICIO INTO v_inicio
    FROM CTL_ETL_AUDIT
    WHERE ID_AUDIT = p_id_audit;

    UPDATE CTL_ETL_AUDIT
    SET FECHA_FIN          = SYSTIMESTAMP,
        DURACION_SEGUNDOS  = ROUND(
            EXTRACT(DAY FROM (SYSTIMESTAMP - v_inicio)) * 86400 +
            EXTRACT(HOUR FROM (SYSTIMESTAMP - v_inicio)) * 3600 +
            EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_inicio)) * 60 +
            EXTRACT(SECOND FROM (SYSTIMESTAMP - v_inicio)),
            2
        ),
        FILAS_LEIDAS       = NVL(p_filas_leidas, 0),
        FILAS_INSERTADAS   = NVL(p_filas_insertadas, 0),
        FILAS_ACTUALIZADAS = NVL(p_filas_actualizadas, 0),
        FILAS_RECHAZADAS   = NVL(p_filas_rechazadas, 0),
        ESTADO             = NVL(p_estado, 'SUCCESS')
    WHERE ID_AUDIT = p_id_audit;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
END SP_AUDIT_END;
/

GRANT EXECUTE ON SP_AUDIT_END TO stg_clinica_user;
