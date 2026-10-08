-- ============================================================================
-- TABLA OLTP: MEDICOS
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE MEDICOS (
    ID_MEDICO               NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRES                 VARCHAR2(60)   NOT NULL,
    APELLIDOS               VARCHAR2(60)   NOT NULL,
    ID_CLINICA_BASE         NUMBER         NOT NULL,
    NUM_COLEGIADO           VARCHAR2(20)   NOT NULL,
    FECHA_INGRESO           DATE           DEFAULT SYSDATE NOT NULL,
    ESTADO                  VARCHAR2(10)   DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT PK_MEDICOS           PRIMARY KEY (ID_MEDICO),
    CONSTRAINT UQ_MEDICOS_COLEGIADO UNIQUE (NUM_COLEGIADO),
    CONSTRAINT FK_MEDICOS_CLINICA   FOREIGN KEY (ID_CLINICA_BASE) REFERENCES CLINICAS (ID_CLINICA),
    CONSTRAINT CK_MEDICOS_ESTADO    CHECK (ESTADO IN ('ACTIVO','INACTIVO'))
);

COMMENT ON TABLE MEDICOS IS 'Médicos adscritos a la red de clínicas';
