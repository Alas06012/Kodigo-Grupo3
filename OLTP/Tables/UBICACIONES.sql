-- ============================================================================
-- TABLA OLTP: UBICACIONES
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE UBICACIONES (
    ID_UBICACION          NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    PAIS                  VARCHAR2(60)   DEFAULT 'El Salvador' NOT NULL,
    DEPARTAMENTO          VARCHAR2(60)   NOT NULL,
    MUNICIPIO             VARCHAR2(60)   NOT NULL,
    DISTRITO              VARCHAR2(60)   NOT NULL,
    CODIGO_POSTAL         VARCHAR2(10),
    CONSTRAINT PK_UBICACIONES PRIMARY KEY (ID_UBICACION),
    CONSTRAINT UQ_UBICACIONES UNIQUE (PAIS, DEPARTAMENTO, MUNICIPIO, DISTRITO)
);

COMMENT ON TABLE  UBICACIONES IS 'Catálogo territorial para normalización de direcciones físicas';
COMMENT ON COLUMN UBICACIONES.DISTRITO IS 'Distrito municipal según reorganización territorial';

GRANT SELECT ON UBICACIONES TO stg_clinica_user, dwh_clinica_user;
