-- ============================================================================
-- TABLA OLTP: TIPOS_CONSULTA
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE TIPOS_CONSULTA (
    ID_TIPO_CONSULTA       NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_TIPO            VARCHAR2(60)   NOT NULL,
    DESCRIPCION            VARCHAR2(250),
    PRECIO_BASE            NUMBER(10,2)   DEFAULT 0 NOT NULL,
    ESTADO                 VARCHAR2(10)   DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT PK_TIPOS_CONSULTA        PRIMARY KEY (ID_TIPO_CONSULTA),
    CONSTRAINT UQ_TIPOS_CONSULTA_NOMBRE UNIQUE (NOMBRE_TIPO),
    CONSTRAINT CK_TIPOS_CONSULTA_PRECIO CHECK (PRECIO_BASE >= 0),
    CONSTRAINT CK_TIPOS_CONSULTA_ESTADO CHECK (ESTADO IN ('ACTIVO','INACTIVO'))
);

COMMENT ON TABLE TIPOS_CONSULTA IS 'Catálogo de modalidades de consulta con su tarifa base sugerida';
