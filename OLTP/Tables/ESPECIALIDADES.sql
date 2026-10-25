-- ============================================================================
-- TABLA OLTP: ESPECIALIDADES
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE ESPECIALIDADES (
    ID_ESPECIALIDAD        NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_ESPECIALIDAD    VARCHAR2(80)   NOT NULL,
    DESCRIPCION            VARCHAR2(300),
    CONSTRAINT PK_ESPECIALIDADES        PRIMARY KEY (ID_ESPECIALIDAD),
    CONSTRAINT UQ_ESPECIALIDADES_NOMBRE UNIQUE (NOMBRE_ESPECIALIDAD)
);

COMMENT ON TABLE ESPECIALIDADES IS 'Catálogo maestro de especialidades médicas';

GRANT SELECT ON ESPECIALIDADES TO stg_clinica_user, dwh_clinica_user;
