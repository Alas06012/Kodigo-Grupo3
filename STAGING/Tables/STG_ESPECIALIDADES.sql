-- ============================================================================
-- TABLA STAGING: STG_ESPECIALIDADES
-- ESQUEMA: stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE STG_ESPECIALIDADES (
    ID_ESPECIALIDAD        NUMBER NOT NULL,
    NOMBRE_ESPECIALIDAD    VARCHAR2(80) NOT NULL,
    DESCRIPCION            VARCHAR2(300),
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG            NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA              VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO            DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN               DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION        CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE           VARCHAR2(64) NOT NULL,
    CONSTRAINT CK_STG_ESP_FLAG   CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_STG_ESP_CARGA  CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_STG_ESP_TRX    CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_STG_ESP_ID ON STG_ESPECIALIDADES (ID_ESPECIALIDAD);
COMMENT ON TABLE STG_ESPECIALIDADES IS 'Staging: Catálogo maestro de especialidades médicas';

