-- ============================================================================
-- TABLA STAGING: STG_EMPRESAS
-- ESQUEMA: stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE STG_EMPRESAS (
    ID_EMPRESA            NUMBER NOT NULL,
    NOMBRE_EMPRESA        VARCHAR2(120) NOT NULL,
    NIT                   VARCHAR2(20) NOT NULL,
    SECTOR                VARCHAR2(60),
    TELEFONO              VARCHAR2(20),
    DIRECCION             VARCHAR2(200),
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG           NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA             VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO           DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN              DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION       CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE          VARCHAR2(64) NOT NULL,
    CONSTRAINT CK_STG_EMP_FLAG   CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_STG_EMP_CARGA  CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_STG_EMP_TRX    CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_STG_EMP_ID ON STG_EMPRESAS (ID_EMPRESA);
COMMENT ON TABLE STG_EMPRESAS IS 'Staging: Empresas afiliadas con convenios de salud laboral';

GRANT SELECT ON STG_EMPRESAS TO dwh_clinica_user;
