-- ============================================================================
-- TABLA STAGING: STG_ENFERMEDADES
-- ESQUEMA: stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE STG_ENFERMEDADES (
    ID_ENFERMEDAD          NUMBER NOT NULL,
    CODIGO_CIE10           VARCHAR2(10),
    NOMBRE_ENFERMEDAD      VARCHAR2(120) NOT NULL,
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG            NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA              VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO            DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN              DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION        CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE           VARCHAR2(64) NOT NULL,
    CONSTRAINT CK_STG_ENF_FLAG   CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_STG_ENF_CARGA  CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_STG_ENF_TRX    CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_STG_ENF_ID ON STG_ENFERMEDADES (ID_ENFERMEDAD);
COMMENT ON TABLE STG_ENFERMEDADES IS 'Staging: Catálogo nosológico internacional CIE-10';

GRANT SELECT ON STG_ENFERMEDADES TO dwh_clinica_user;
