-- ============================================================================
-- TABLA OLTP: FORMAS_PAGO
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE TABLE FORMAS_PAGO (
    ID_FORMA_PAGO          NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_FORMA_PAGO      VARCHAR2(50)  NOT NULL,
    CATEGORIA              VARCHAR2(20)  NOT NULL,
    ESTADO                 VARCHAR2(10)  DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT PK_FORMAS_PAGO         PRIMARY KEY (ID_FORMA_PAGO),
    CONSTRAINT UQ_FORMAS_PAGO_NOMBRE  UNIQUE (NOMBRE_FORMA_PAGO),
    CONSTRAINT CK_FORMAS_PAGO_CAT     CHECK (CATEGORIA IN ('CONTADO','CREDITO')),
    CONSTRAINT CK_FORMAS_PAGO_ESTADO  CHECK (ESTADO IN ('ACTIVO','INACTIVO'))
);

COMMENT ON TABLE FORMAS_PAGO IS 'Catálogo de medios de pago (Efectivo, Tarjeta, Cheque, Transferencia)';
