-- ============================================================================
-- TABLA STAGING: STG_PROCEDIMIENTOS
-- ESQUEMA: stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE STG_PROCEDIMIENTOS (
    ID_PROCEDIMIENTO       NUMBER NOT NULL,
    CODIGO_PROCEDIMIENTO   VARCHAR2(20),
    NOMBRE_PROCEDIMIENTO   VARCHAR2(120) NOT NULL,
    DESCRIPCION            VARCHAR2(300),
    COSTO_BASE             NUMBER(10,2) NOT NULL,
    ESTADO                 VARCHAR2(10) NOT NULL,
    -- 6 Columnas Técnicas de Auditoría
    CURRENTFLAG            NUMBER(1)    DEFAULT 1 NOT NULL,
    TIPOCARGA              VARCHAR2(20) DEFAULT 'FULL' NOT NULL,
    FECHAINICIO            DATE         DEFAULT SYSDATE NOT NULL,
    FECHAFIN              DATE         DEFAULT DATE '2999-12-31' NOT NULL,
    TIPOTRANSACCION        CHAR(1)      DEFAULT 'I' NOT NULL,
    ROWHASHVALUE           VARCHAR2(64) NOT NULL,
    CONSTRAINT CK_STG_PRC_FLAG   CHECK (CURRENTFLAG IN (0, 1)),
    CONSTRAINT CK_STG_PRC_CARGA  CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL')),
    CONSTRAINT CK_STG_PRC_TRX    CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))
);

CREATE INDEX IX_STG_PRC_ID ON STG_PROCEDIMIENTOS (ID_PROCEDIMIENTO);
COMMENT ON TABLE STG_PROCEDIMIENTOS IS 'Staging: Catálogo de intervenciones y procedimientos clínicos';

