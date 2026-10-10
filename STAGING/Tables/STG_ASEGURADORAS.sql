-- ============================================================================
-- TABLA STAGING: STG_ASEGURADORAS
-- ESQUEMA: stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE STG_ASEGURADORAS (
    ID_ASEGURADORA         NUMBER NOT NULL,
    NOMBRE_ASEGURADORA     VARCHAR2(120) NOT NULL,
    NIT                    VARCHAR2(20) NOT NULL,
    TIPO_COBERTURA         VARCHAR2(60),
    TELEFONO               VARCHAR2(20),
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG            NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA              VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO            DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN               DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION        CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE           VARCHAR2(64) NOT NULL,
    CONSTRAINT CK_STG_ASE_FLAG   CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_STG_ASE_CARGA  CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_STG_ASE_TRX    CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_STG_ASE_ID ON STG_ASEGURADORAS (ID_ASEGURADORA);
COMMENT ON TABLE STG_ASEGURADORAS IS 'Staging: Compañías de seguros de salud';
