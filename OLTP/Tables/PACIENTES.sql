-- ============================================================================
-- TABLA OLTP: PACIENTES
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE PACIENTES (
    ID_PACIENTE                 NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRES                     VARCHAR2(60)   NOT NULL,
    APELLIDOS                   VARCHAR2(60)   NOT NULL,
    FECHA_NACIMIENTO            DATE           NOT NULL,
    SEXO                        CHAR(1)        NOT NULL,
    ID_UBICACION                NUMBER         NOT NULL,
    DIRECCION                   VARCHAR2(200),
    ID_CLINICA_HABITUAL         NUMBER         NOT NULL,
    ID_EMPRESA                  NUMBER,
    ID_ASEGURADORA              NUMBER,
    NUMERO_POLIZA               VARCHAR2(40),
    FECHA_REGISTRO              DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_PACIENTES             PRIMARY KEY (ID_PACIENTE),
    CONSTRAINT FK_PACIENTES_UBIC        FOREIGN KEY (ID_UBICACION) REFERENCES UBICACIONES (ID_UBICACION),
    CONSTRAINT FK_PACIENTES_CLINICA     FOREIGN KEY (ID_CLINICA_HABITUAL) REFERENCES CLINICAS (ID_CLINICA),
    CONSTRAINT FK_PACIENTES_EMPRESA     FOREIGN KEY (ID_EMPRESA) REFERENCES EMPRESAS (ID_EMPRESA),
    CONSTRAINT FK_PACIENTES_ASEGURADORA FOREIGN KEY (ID_ASEGURADORA) REFERENCES ASEGURADORAS (ID_ASEGURADORA),
    CONSTRAINT CK_PACIENTES_SEXO        CHECK (SEXO IN ('M','F'))
);

COMMENT ON TABLE PACIENTES IS 'Registro maestro de expedientes de pacientes';
COMMENT ON COLUMN PACIENTES.DIRECCION IS 'Dirección exacta declarada por el paciente (calle, polígono, casa)';

GRANT SELECT ON PACIENTES TO stg_clinica_user, dwh_clinica_user;
