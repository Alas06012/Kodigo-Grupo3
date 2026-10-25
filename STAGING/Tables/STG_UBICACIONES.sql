-- ============================================================================
-- TABLA STAGING: STG_UBICACIONES
-- ESQUEMA: stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE STG_UBICACIONES (
    ID_UBICACION          NUMBER NOT NULL,
    PAIS                  VARCHAR2(60) NOT NULL,
    DEPARTAMENTO          VARCHAR2(60) NOT NULL,
    MUNICIPIO             VARCHAR2(60) NOT NULL,
    DISTRITO              VARCHAR2(60) NOT NULL,
    CODIGO_POSTAL         VARCHAR2(10),
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG           NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA             VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO           DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN              DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION       CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE          VARCHAR2(64) NOT NULL,
    CONSTRAINT CK_STG_UBI_FLAG   CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_STG_UBI_CARGA  CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_STG_UBI_TRX    CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_STG_UBI_ID ON STG_UBICACIONES (ID_UBICACION);
COMMENT ON TABLE STG_UBICACIONES IS 'Staging: Catálogo territorial crudo';

GRANT SELECT ON STG_UBICACIONES TO dwh_clinica_user;
