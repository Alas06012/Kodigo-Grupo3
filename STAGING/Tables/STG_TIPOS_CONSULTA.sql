-- ============================================================================
-- TABLA STAGING: STG_TIPOS_CONSULTA
-- ESQUEMA: stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE STG_TIPOS_CONSULTA (
    ID_TIPO_CONSULTA       NUMBER NOT NULL,
    NOMBRE_TIPO            VARCHAR2(60) NOT NULL,
    DESCRIPCION            VARCHAR2(250),
    PRECIO_BASE            NUMBER(10,2) NOT NULL,
    ESTADO                 VARCHAR2(10) NOT NULL,
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG            NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA              VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO            DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN              DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION        CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE           VARCHAR2(64) NOT NULL,
    CONSTRAINT CK_STG_TPC_FLAG   CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_STG_TPC_CARGA  CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_STG_TPC_TRX    CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_STG_TPC_ID ON STG_TIPOS_CONSULTA (ID_TIPO_CONSULTA);
COMMENT ON TABLE STG_TIPOS_CONSULTA IS 'Staging: Modalidades de consulta médica y tarifas base';
