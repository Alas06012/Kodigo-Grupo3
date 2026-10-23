/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED ASISTENCIAL DE CLÍNICAS
   TABLA DE CONTROL Y PROCEDIMIENTOS DE AUDITORÍA: CTL_ETL_AUDIT
   MOTOR: Oracle Database 19c / 21c / 23ai
   ESQUEMA: dwh_clinica_user | TABLESPACE: dwh_clinicas_db
   ============================================================================
   OBJETIVO:
     Registro y monitoreo centralizado de la ejecución de todos los procesos ETL
     tanto de la capa STAGING como de la capa DATA WAREHOUSE.
     Implementa transacciones autónomas (PRAGMA AUTONOMOUS_TRANSACTION) para
     preservar logs de ejecución y errores incluso ante un ROLLBACK de datos.
   ============================================================================ */

SET FEEDBACK ON;
SET ECHO OFF;

-- ============================================================================
-- 1. CREACIÓN DE LA TABLA DE CONTROL DE AUDITORÍA (CTL_ETL_AUDIT)
-- ============================================================================
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE CTL_ETL_AUDIT CASCADE CONSTRAINTS PURGE';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE CTL_ETL_AUDIT (
    ID_AUDIT              NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    BATCH_ID              VARCHAR2(50)  NOT NULL,              -- Identificador único del lote (ej. BATCH_20261022_0200)
    CAPA                  VARCHAR2(20)  NOT NULL,              -- 'STAGING', 'DWH_DIM', 'DWH_FACT', 'ORCHESTRATOR'
    OBJETO_DESTINO        VARCHAR2(60)  NOT NULL,              -- Nombre de la tabla o entidad (ej. FACT_CONSULTAS)
    PROCEDIMIENTO         VARCHAR2(60)  NOT NULL,              -- Nombre del SP (ej. SP_LOAD_FACT_CONSULTAS)
    TIPO_CARGA            VARCHAR2(20)  DEFAULT 'INCREMENTAL', -- 'FULL' o 'INCREMENTAL'
    FECHA_INICIO          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    FECHA_FIN             TIMESTAMP,
    DURACION_SEGUNDOS     NUMBER(10,2),
    FILAS_LEIDAS          NUMBER(12)    DEFAULT 0,
    FILAS_INSERTADAS      NUMBER(12)    DEFAULT 0,
    FILAS_ACTUALIZADAS    NUMBER(12)    DEFAULT 0,
    FILAS_RECHAZADAS      NUMBER(12)    DEFAULT 0,
    ESTADO                VARCHAR2(20)  DEFAULT 'RUNNING',     -- 'RUNNING', 'SUCCESS', 'WARNING', 'FAILED'
    CODIGO_ERROR          VARCHAR2(30),
    MENSAJE_ERROR         VARCHAR2(4000),
    USUARIO_EJECUCION     VARCHAR2(60)  DEFAULT USER,
    HOST_NAME             VARCHAR2(100) DEFAULT SYS_CONTEXT('USERENV', 'HOST'),
    CONSTRAINT PK_CTL_ETL_AUDIT PRIMARY KEY (ID_AUDIT),
    CONSTRAINT CK_CTL_AUD_ESTADO CHECK (ESTADO IN ('RUNNING', 'SUCCESS', 'WARNING', 'FAILED'))
);

-- Índices de consulta rápida y monitoreo
CREATE INDEX IX_CTL_AUD_BATCH  ON CTL_ETL_AUDIT (BATCH_ID);
CREATE INDEX IX_CTL_AUD_FECHA  ON CTL_ETL_AUDIT (FECHA_INICIO);
CREATE INDEX IX_CTL_AUD_ESTADO ON CTL_ETL_AUDIT (ESTADO);

-- Otorgar permisos de lectura y escritura al esquema de Staging
GRANT SELECT, INSERT, UPDATE ON CTL_ETL_AUDIT TO stg_clinica_user;


-- ============================================================================
-- 2. PROCEDIMIENTOS DE AUDITORÍA CON TRANSACCIONES AUTÓNOMAS
-- ============================================================================

-- 2.1 SP_AUDIT_START: Registrar el inicio de la ejecución
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

-- 2.2 SP_AUDIT_END: Registrar la culminación exitosa
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

-- 2.3 SP_AUDIT_ERROR: Registrar fallo de ejecución y mensaje de excepción
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

-- Otorgar privilegios de ejecución a stg_clinica_user
GRANT EXECUTE ON SP_AUDIT_START TO stg_clinica_user;
GRANT EXECUTE ON SP_AUDIT_END   TO stg_clinica_user;
GRANT EXECUTE ON SP_AUDIT_ERROR TO stg_clinica_user;
