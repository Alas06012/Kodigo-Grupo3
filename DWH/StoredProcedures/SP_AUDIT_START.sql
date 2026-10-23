-- ============================================================================
-- PROCEDIMIENTO: SP_AUDIT_START
-- OBJETIVO:      Registrar el inicio de un proceso ETL en CTL_ETL_AUDIT
--                usando transacciones autónomas para no depender del commit de datos.
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_AUDIT_START (
    p_batch_id       IN  VARCHAR2,
    p_capa           IN  VARCHAR2,
    p_objeto_destino IN  VARCHAR2,
    p_procedimiento  IN  VARCHAR2,
    p_tipo_carga     IN  VARCHAR2,
    o_id_audit       OUT NUMBER
)
AUTHID DEFINER
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO CTL_ETL_AUDIT (
        BATCH_ID,
        CAPA,
        OBJETO_DESTINO,
        PROCEDIMIENTO,
        TIPO_CARGA,
        FECHA_INICIO,
        ESTADO
    ) VALUES (
        p_batch_id,
        UPPER(p_capa),
        UPPER(p_objeto_destino),
        UPPER(p_procedimiento),
        UPPER(p_tipo_carga),
        SYSTIMESTAMP,
        'RUNNING'
    )
    RETURNING ID_AUDIT INTO o_id_audit;

    COMMIT;
END SP_AUDIT_START;
/

GRANT EXECUTE ON SP_AUDIT_START TO stg_clinica_user;
