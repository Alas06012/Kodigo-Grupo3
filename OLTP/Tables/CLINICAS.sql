-- ============================================================================
-- TABLA OLTP: CLINICAS
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE CLINICAS (
    ID_CLINICA           NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_CLINICA       VARCHAR2(100)  NOT NULL,
    ID_UBICACION         NUMBER         NOT NULL,
    DIRECCION            VARCHAR2(200),
    TELEFONO             VARCHAR2(20),
    FECHA_APERTURA       DATE,
    ESTADO               VARCHAR2(10)   DEFAULT 'ACTIVA' NOT NULL,
    CONSTRAINT PK_CLINICAS         PRIMARY KEY (ID_CLINICA),
    CONSTRAINT FK_CLINICAS_UBIC    FOREIGN KEY (ID_UBICACION) REFERENCES UBICACIONES (ID_UBICACION),
    CONSTRAINT CK_CLINICAS_ESTADO  CHECK (ESTADO IN ('ACTIVA','INACTIVA'))
);

COMMENT ON TABLE CLINICAS IS 'Sedes físicas asistenciales que integran la red médica';
