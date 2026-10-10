-- ============================================================================
-- TABLA DIMENSIONAL: DIM_TIEMPO (Dimensión Conformada Especial)
-- ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE DIM_TIEMPO (
    SK_TIEMPO             NUMBER(8) NOT NULL, -- Formato numérico estructurado YYYYMMDD
    FECHA                 DATE NOT NULL,
    ANIO                  NUMBER(4) NOT NULL,
    SEMESTRE              NUMBER(1) NOT NULL,
    TRIMESTRE             NUMBER(1) NOT NULL,
    NOMBRE_TRIMESTRE      VARCHAR2(20) NOT NULL,
    MES                   NUMBER(2) NOT NULL,
    NOMBRE_MES            VARCHAR2(20) NOT NULL,
    MES_CORTO             VARCHAR2(10) NOT NULL,
    SEMANA_ANIO           NUMBER(2) NOT NULL,
    DIA_MES               NUMBER(2) NOT NULL,
    DIA_SEMANA            NUMBER(1) NOT NULL,
    NOMBRE_DIA            VARCHAR2(20) NOT NULL,
    ES_FIN_SEMANA         NUMBER(1) NOT NULL,
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG           NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA             VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO           DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN              DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION       CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE          VARCHAR2(64) NOT NULL,
    CONSTRAINT PK_DIM_TIEMPO    PRIMARY KEY (SK_TIEMPO),
    CONSTRAINT UQ_DIM_TIE_FECHA UNIQUE (FECHA),
    CONSTRAINT CK_DIM_TIE_FINS  CHECK (ES_FIN_SEMANA IN (0, 1)),
    CONSTRAINT CK_DIM_TIE_FLAG  CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_DIM_TIE_CARGA CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_DIM_TIE_TRX   CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_DIM_TIE_ANIO_MES ON DIM_TIEMPO (ANIO, MES);
CREATE INDEX IX_DIM_TIE_TRIMEST  ON DIM_TIEMPO (ANIO, TRIMESTRE);
COMMENT ON TABLE DIM_TIEMPO IS 'Dimensión de conformación temporal con grano diario continuo y desglose de atributos analíticos';
