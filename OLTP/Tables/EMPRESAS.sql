-- ============================================================================
-- TABLA OLTP: EMPRESAS
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE EMPRESAS (
    ID_EMPRESA             NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_EMPRESA         VARCHAR2(120)  NOT NULL,
    NIT                    VARCHAR2(20)   NOT NULL,
    SECTOR                 VARCHAR2(60),
    TELEFONO               VARCHAR2(20),
    DIRECCION              VARCHAR2(200),
    CONSTRAINT PK_EMPRESAS      PRIMARY KEY (ID_EMPRESA),
    CONSTRAINT UQ_EMPRESAS_NIT  UNIQUE (NIT)
);

COMMENT ON TABLE EMPRESAS IS 'Empresas afiliadas con convenios de salud laboral';
