-- ============================================================================
-- TABLA STAGING: STG_MEDICOS
-- ESQUEMA: stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE STG_MEDICOS (
    ID_MEDICO              NUMBER NOT NULL,
    NOMBRES                VARCHAR2(60) NOT NULL,
    APELLIDOS              VARCHAR2(60) NOT NULL,
    ID_CLINICA             NUMBER NOT NULL,
    NUM_COLEGIADO          VARCHAR2(20) NOT NULL,
    FECHA_INGRESO          DATE NOT NULL,
    ESTADO                 VARCHAR2(10) NOT NULL,
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG            NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA              VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO            DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN               DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION        CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE           VARCHAR2(64) NOT NULL,
    CONSTRAINT CK_STG_MED_FLAG   CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_STG_MED_CARGA  CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_STG_MED_TRX    CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_STG_MED_ID ON STG_MEDICOS (ID_MEDICO);
COMMENT ON TABLE STG_MEDICOS IS 'Staging: Médicos adscritos a la red asistencial';

GRANT SELECT ON STG_MEDICOS TO dwh_clinica_user;
