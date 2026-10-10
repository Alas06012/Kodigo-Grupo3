-- ============================================================================
-- TABLA STAGING: STG_PACIENTES
-- ESQUEMA: stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE STG_PACIENTES (
    ID_PACIENTE            NUMBER NOT NULL,
    NOMBRES                VARCHAR2(60) NOT NULL,
    APELLIDOS              VARCHAR2(60) NOT NULL,
    FECHA_NACIMIENTO       DATE NOT NULL,
    SEXO                   CHAR(1) NOT NULL,
    ID_UBICACION           NUMBER NOT NULL,
    DIRECCION              VARCHAR2(200),
    ID_CLINICA_HABITUAL    NUMBER NOT NULL,
    ID_EMPRESA             NUMBER,
    ID_ASEGURADORA         NUMBER,
    NUMERO_POLIZA          VARCHAR2(40),
    FECHA_REGISTRO         DATE NOT NULL,
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG            NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA              VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO            DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN               DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION        CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE           VARCHAR2(64) NOT NULL,
    CONSTRAINT CK_STG_PAC_FLAG   CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_STG_PAC_CARGA  CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_STG_PAC_TRX    CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_STG_PAC_ID ON STG_PACIENTES (ID_PACIENTE);
COMMENT ON TABLE STG_PACIENTES IS 'Staging: Expediente maestro de pacientes';

