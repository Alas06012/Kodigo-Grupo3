-- ============================================================================
-- TABLA OLTP: ENFERMEDADES
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE ENFERMEDADES (
    ID_ENFERMEDAD          NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    CODIGO_CIE10           VARCHAR2(10),
    NOMBRE_ENFERMEDAD      VARCHAR2(120)  NOT NULL,
    CONSTRAINT PK_ENFERMEDADES PRIMARY KEY (ID_ENFERMEDAD)
);

COMMENT ON TABLE ENFERMEDADES IS 'Catálogo nosológico internacional de enfermedades (CIE-10)';

GRANT SELECT ON ENFERMEDADES TO stg_clinica_user, dwh_clinica_user;
