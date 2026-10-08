-- ============================================================================
-- TABLA OLTP: ASEGURADORAS
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE ASEGURADORAS (
    ID_ASEGURADORA          NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_ASEGURADORA      VARCHAR2(120)  NOT NULL,
    NIT                     VARCHAR2(20)   NOT NULL,
    TIPO_COBERTURA          VARCHAR2(60),
    TELEFONO                VARCHAR2(20),
    CONSTRAINT PK_ASEGURADORAS     PRIMARY KEY (ID_ASEGURADORA),
    CONSTRAINT UQ_ASEGURADORAS_NIT UNIQUE (NIT)
);

COMMENT ON TABLE ASEGURADORAS IS 'Compañías aseguradoras que cubren pólizas de pacientes';
