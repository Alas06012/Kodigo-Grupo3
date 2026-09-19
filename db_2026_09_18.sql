/* ============================================================================
   PROYECTO: RED CLÍNICAS
   FASES 3-4: DISEÑO Y CREACIÓN DE LA BASE DE DATOS
   Motor: Oracle Database 23ai / 19c / 21c
   ============================================================================
   Convenciones:
   - Prefijo de PK: ID_<ENTIDAD>
   - Todas las PK usan GENERATED ALWAYS AS IDENTITY
   - Nombres de tablas en plural, en mayúsculas
   - Se agregan comentarios de tabla/columna para documentar el modelo
   ============================================================================ */
   
-- ============================================================================
-- CREACION DE TABLESPACE Y CONEXION
-- ============================================================================   
/*
    1. En el cmd de su pc:  
        sqlplus / as sysdba
    
    2. Dentro de sqlplus en el cmd, acceder a la sesion XEPDB1:
        ALTER SESSION SET CONTAINER = XEPDB1;
        
    3. Verificar que estamos en la conexion XEPDB1
        SHOW CON_NAME;
       
    4. Una vez dentro crear el tablespace y usuario:
        CREATE TABLESPACE red_clinicas_db
        DATAFILE 'red_clinicas_db.dbf' SIZE 250M AUTOEXTEND ON NEXT 2G MAXSIZE UNLIMITED;

        CREATE USER red_clinica_user IDENTIFIED BY "Password2026"
            DEFAULT TABLESPACE red_clinicas_db
            QUOTA UNLIMITED ON red_clinicas_db;

        GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE SYNONYM TO red_clinica_user;

    5. Crear la conexion en sql developer con ese usuario.
    
*/


-- ============================================================================
-- (OPCIONAL) LIMPIEZA PREVIA — descomentar solo si necesitas reiniciar todo
-- ============================================================================
 DROP TABLE PAGOS                         CASCADE CONSTRAINTS PURGE;
 DROP TABLE ADMINISTRACION_MEDICAMENTOS   CASCADE CONSTRAINTS PURGE;
 DROP TABLE DIAGNOSTICOS                  CASCADE CONSTRAINTS PURGE;
 DROP TABLE CONSULTAS                     CASCADE CONSTRAINTS PURGE;
 DROP TABLE PACIENTES                     CASCADE CONSTRAINTS PURGE;
 DROP TABLE MEDICOS                       CASCADE CONSTRAINTS PURGE;
 DROP TABLE ASEGURADORAS                  CASCADE CONSTRAINTS PURGE;
 DROP TABLE EMPRESAS                      CASCADE CONSTRAINTS PURGE;
 DROP TABLE MEDICAMENTOS                  CASCADE CONSTRAINTS PURGE;
 DROP TABLE ENFERMEDADES                  CASCADE CONSTRAINTS PURGE;
 DROP TABLE ESPECIALIDADES                CASCADE CONSTRAINTS PURGE;
 DROP TABLE CLINICAS                      CASCADE CONSTRAINTS PURGE;
 DROP TABLE REGIONES                      CASCADE CONSTRAINTS PURGE;


-- ============================================================================
-- 1. DATOS MAESTROS
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1.1 REGIONES
-- ---------------------------------------------------------------------------
CREATE TABLE REGIONES (
    ID_REGION            NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_REGION        VARCHAR2(60)   NOT NULL,
    ZONA                 VARCHAR2(30),
    CONSTRAINT PK_REGIONES        PRIMARY KEY (ID_REGION),
    CONSTRAINT UQ_REGIONES_NOMBRE UNIQUE (NOMBRE_REGION)
);

COMMENT ON TABLE  REGIONES IS 'Regiones geográficas donde opera la Red Clínicas';
COMMENT ON COLUMN REGIONES.ZONA IS 'Zona general: Metropolitana, Central, Occidental, Oriental, Paracentral';


-- ---------------------------------------------------------------------------
-- 1.2 CLINICAS
-- ---------------------------------------------------------------------------
CREATE TABLE CLINICAS (
    ID_CLINICA           NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_CLINICA       VARCHAR2(100)  NOT NULL,
    ID_REGION            NUMBER         NOT NULL,
    DIRECCION            VARCHAR2(200),
    TELEFONO             VARCHAR2(20),
    FECHA_APERTURA       DATE,
    ESTADO               VARCHAR2(10)   DEFAULT 'ACTIVA' NOT NULL,
    CONSTRAINT PK_CLINICAS        PRIMARY KEY (ID_CLINICA),
    CONSTRAINT FK_CLINICAS_REGION FOREIGN KEY (ID_REGION) REFERENCES REGIONES (ID_REGION),
    CONSTRAINT CK_CLINICAS_ESTADO CHECK (ESTADO IN ('ACTIVA','INACTIVA'))
);

COMMENT ON TABLE CLINICAS IS 'Clínicas que conforman la red';


-- ---------------------------------------------------------------------------
-- 1.3 ESPECIALIDADES
-- ---------------------------------------------------------------------------
CREATE TABLE ESPECIALIDADES (
    ID_ESPECIALIDAD        NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_ESPECIALIDAD    VARCHAR2(80)  NOT NULL,
    DESCRIPCION            VARCHAR2(300),
    CONSTRAINT PK_ESPECIALIDADES        PRIMARY KEY (ID_ESPECIALIDAD),
    CONSTRAINT UQ_ESPECIALIDADES_NOMBRE UNIQUE (NOMBRE_ESPECIALIDAD)
);

COMMENT ON TABLE ESPECIALIDADES IS 'Catálogo de especialidades médicas ofrecidas';


-- ---------------------------------------------------------------------------
-- 1.4 MEDICOS
-- ---------------------------------------------------------------------------
CREATE TABLE MEDICOS (
    ID_MEDICO               NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRES                 VARCHAR2(60)   NOT NULL,
    APELLIDOS               VARCHAR2(60)   NOT NULL,
    ID_ESPECIALIDAD         NUMBER         NOT NULL,
    ID_CLINICA              NUMBER         NOT NULL,
    NUM_COLEGIADO           VARCHAR2(20)   NOT NULL,
    FECHA_INGRESO           DATE           DEFAULT SYSDATE NOT NULL,
    ESTADO                  VARCHAR2(10)   DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT PK_MEDICOS               PRIMARY KEY (ID_MEDICO),
    CONSTRAINT UQ_MEDICOS_COLEGIADO     UNIQUE (NUM_COLEGIADO),
    CONSTRAINT FK_MEDICOS_ESPECIALIDAD  FOREIGN KEY (ID_ESPECIALIDAD) REFERENCES ESPECIALIDADES (ID_ESPECIALIDAD),
    CONSTRAINT FK_MEDICOS_CLINICA       FOREIGN KEY (ID_CLINICA) REFERENCES CLINICAS (ID_CLINICA),
    CONSTRAINT CK_MEDICOS_ESTADO        CHECK (ESTADO IN ('ACTIVO','INACTIVO'))
);

COMMENT ON TABLE MEDICOS IS 'Médicos que laboran en la red, con su clínica base y especialidad';


-- ---------------------------------------------------------------------------
-- 1.5 ENFERMEDADES
-- ---------------------------------------------------------------------------
CREATE TABLE ENFERMEDADES (
    ID_ENFERMEDAD          NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    CODIGO_CIE10           VARCHAR2(10),
    NOMBRE_ENFERMEDAD      VARCHAR2(120)  NOT NULL,
    CATEGORIA              VARCHAR2(60),
    CONSTRAINT PK_ENFERMEDADES PRIMARY KEY (ID_ENFERMEDAD)
);

COMMENT ON TABLE ENFERMEDADES IS 'Catálogo de diagnósticos/enfermedades (referencia estilo CIE-10)';
COMMENT ON COLUMN ENFERMEDADES.CATEGORIA IS 'Ej: Respiratorias, Hipertensión, Diabetes, Gastrointestinales, Infecciones, Musculoesqueléticas';


-- ---------------------------------------------------------------------------
-- 1.6 MEDICAMENTOS
-- ---------------------------------------------------------------------------
CREATE TABLE MEDICAMENTOS (
    ID_MEDICAMENTO         NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_MEDICAMENTO     VARCHAR2(100)  NOT NULL,
    CATEGORIA              VARCHAR2(60),
    PRESENTACION           VARCHAR2(60),
    UNIDAD_MEDIDA          VARCHAR2(20),
    COSTO_UNITARIO         NUMBER(10,2)   NOT NULL,
    CONSTRAINT PK_MEDICAMENTOS       PRIMARY KEY (ID_MEDICAMENTO),
    CONSTRAINT CK_MEDICAMENTOS_COSTO CHECK (COSTO_UNITARIO >= 0)
);

COMMENT ON TABLE MEDICAMENTOS IS 'Catálogo de medicamentos disponibles';


-- ---------------------------------------------------------------------------
-- 1.7 EMPRESAS
-- ---------------------------------------------------------------------------
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

COMMENT ON TABLE EMPRESAS IS 'Empresas que cubren servicios médicos de sus empleados';


-- ---------------------------------------------------------------------------
-- 1.8 ASEGURADORAS
-- ---------------------------------------------------------------------------
CREATE TABLE ASEGURADORAS (
    ID_ASEGURADORA          NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRE_ASEGURADORA      VARCHAR2(120)  NOT NULL,
    NIT                     VARCHAR2(20)   NOT NULL,
    TIPO_COBERTURA          VARCHAR2(60),
    TELEFONO                VARCHAR2(20),
    CONSTRAINT PK_ASEGURADORAS     PRIMARY KEY (ID_ASEGURADORA),
    CONSTRAINT UQ_ASEGURADORAS_NIT UNIQUE (NIT)
);

COMMENT ON TABLE ASEGURADORAS IS 'Aseguradoras que cubren total o parcialmente los servicios';


-- ---------------------------------------------------------------------------
-- 1.9 PACIENTES (Corregido: sin CHECK dinámico de SYSDATE)
-- ---------------------------------------------------------------------------
CREATE TABLE PACIENTES (
    ID_PACIENTE                 NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    NOMBRES                     VARCHAR2(60)   NOT NULL,
    APELLIDOS                   VARCHAR2(60)   NOT NULL,
    FECHA_NACIMIENTO            DATE           NOT NULL,
    SEXO                        CHAR(1)        NOT NULL,
    ID_REGION                   NUMBER         NOT NULL,
    ID_CLINICA_HABITUAL         NUMBER         NOT NULL,
    ID_EMPRESA                  NUMBER,
    ID_ASEGURADORA              NUMBER,
    TIPO_PAGADOR_PREFERIDO      VARCHAR2(15)   DEFAULT 'PACIENTE' NOT NULL,
    FECHA_REGISTRO              DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_PACIENTES                PRIMARY KEY (ID_PACIENTE),
    CONSTRAINT FK_PACIENTES_REGION         FOREIGN KEY (ID_REGION) REFERENCES REGIONES (ID_REGION),
    CONSTRAINT FK_PACIENTES_CLINICA        FOREIGN KEY (ID_CLINICA_HABITUAL) REFERENCES CLINICAS (ID_CLINICA),
    CONSTRAINT FK_PACIENTES_EMPRESA        FOREIGN KEY (ID_EMPRESA) REFERENCES EMPRESAS (ID_EMPRESA),
    CONSTRAINT FK_PACIENTES_ASEGURADORA    FOREIGN KEY (ID_ASEGURADORA) REFERENCES ASEGURADORAS (ID_ASEGURADORA),
    CONSTRAINT CK_PACIENTES_SEXO           CHECK (SEXO IN ('M','F')),
    CONSTRAINT CK_PACIENTES_TIPO_PAGADOR   CHECK (TIPO_PAGADOR_PREFERIDO IN ('PACIENTE','EMPRESA','ASEGURADORA'))
);

COMMENT ON TABLE PACIENTES IS 'Población de pacientes atendidos en la red';
COMMENT ON COLUMN PACIENTES.ID_EMPRESA IS 'Empresa que cubre al paciente, si aplica (opcional)';
COMMENT ON COLUMN PACIENTES.ID_ASEGURADORA IS 'Aseguradora que cubre al paciente, si aplica (opcional)';

-- Trigger para validar que la fecha de nacimiento no sea futura
CREATE OR REPLACE TRIGGER TRG_PACIENTES_VAL_FECHA_NAC
BEFORE INSERT OR UPDATE OF FECHA_NACIMIENTO ON PACIENTES
FOR EACH ROW
BEGIN
    IF :NEW.FECHA_NACIMIENTO > SYSDATE THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Error: La fecha de nacimiento no puede ser una fecha futura (' ||
            TO_CHAR(:NEW.FECHA_NACIMIENTO, 'YYYY-MM-DD') || ').'
        );
    END IF;
END;
/


-- ============================================================================
-- 2. DATOS TRANSACCIONALES
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 2.1 CONSULTAS
-- ---------------------------------------------------------------------------
CREATE TABLE CONSULTAS (
    ID_CONSULTA               NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    ID_PACIENTE               NUMBER        NOT NULL,
    ID_CLINICA                NUMBER        NOT NULL,
    ID_MEDICO                 NUMBER        NOT NULL,
    ID_ESPECIALIDAD           NUMBER        NOT NULL,
    FECHA_CONSULTA            DATE          DEFAULT SYSDATE NOT NULL,
    MOTIVO_CONSULTA           VARCHAR2(300),
    TIPO_CONSULTA             VARCHAR2(20)  DEFAULT 'GENERAL' NOT NULL,
    CONSTRAINT PK_CONSULTAS                PRIMARY KEY (ID_CONSULTA),
    CONSTRAINT FK_CONSULTAS_PACIENTE       FOREIGN KEY (ID_PACIENTE) REFERENCES PACIENTES (ID_PACIENTE),
    CONSTRAINT FK_CONSULTAS_CLINICA        FOREIGN KEY (ID_CLINICA) REFERENCES CLINICAS (ID_CLINICA),
    CONSTRAINT FK_CONSULTAS_MEDICO         FOREIGN KEY (ID_MEDICO) REFERENCES MEDICOS (ID_MEDICO),
    CONSTRAINT FK_CONSULTAS_ESPECIALIDAD   FOREIGN KEY (ID_ESPECIALIDAD) REFERENCES ESPECIALIDADES (ID_ESPECIALIDAD),
    CONSTRAINT CK_CONSULTAS_TIPO           CHECK (TIPO_CONSULTA IN ('GENERAL','EMERGENCIA','SEGUIMIENTO','ESPECIALIDAD'))
);

COMMENT ON TABLE CONSULTAS IS 'Historial de consultas médicas: paciente, clínica, médico, especialidad y fecha';


-- ---------------------------------------------------------------------------
-- 2.2 DIAGNOSTICOS  (Consulta N:M Enfermedad)
-- ---------------------------------------------------------------------------
CREATE TABLE DIAGNOSTICOS (
    ID_DIAGNOSTICO           NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    ID_CONSULTA              NUMBER        NOT NULL,
    ID_ENFERMEDAD            NUMBER        NOT NULL,
    FECHA_DIAGNOSTICO        DATE          DEFAULT SYSDATE NOT NULL,
    OBSERVACIONES            VARCHAR2(300),
    CONSTRAINT PK_DIAGNOSTICOS             PRIMARY KEY (ID_DIAGNOSTICO),
    CONSTRAINT FK_DIAGNOSTICOS_CONSULTA    FOREIGN KEY (ID_CONSULTA) REFERENCES CONSULTAS (ID_CONSULTA),
    CONSTRAINT FK_DIAGNOSTICOS_ENFERMEDAD  FOREIGN KEY (ID_ENFERMEDAD) REFERENCES ENFERMEDADES (ID_ENFERMEDAD),
    CONSTRAINT UQ_DIAGNOSTICOS_CONS_ENF    UNIQUE (ID_CONSULTA, ID_ENFERMEDAD)
);

COMMENT ON TABLE DIAGNOSTICOS IS 'Diagnósticos generados en una consulta (una consulta puede tener varios)';


-- ---------------------------------------------------------------------------
-- 2.3 ADMINISTRACION_MEDICAMENTOS  (Consulta N:M Medicamento + consumo)
-- ---------------------------------------------------------------------------
CREATE TABLE ADMINISTRACION_MEDICAMENTOS (
    ID_ADMINISTRACION          NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    ID_CONSULTA                NUMBER        NOT NULL,
    ID_MEDICAMENTO             NUMBER        NOT NULL,
    CANTIDAD                   NUMBER(8,2)   NOT NULL,
    DOSIS                      VARCHAR2(60),
    COSTO_TOTAL                NUMBER(10,2)  NOT NULL,
    FECHA_ADMINISTRACION       DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_ADMIN_MEDICAMENTOS         PRIMARY KEY (ID_ADMINISTRACION),
    CONSTRAINT FK_ADMIN_MED_CONSULTA         FOREIGN KEY (ID_CONSULTA) REFERENCES CONSULTAS (ID_CONSULTA),
    CONSTRAINT FK_ADMIN_MED_MEDICAMENTO      FOREIGN KEY (ID_MEDICAMENTO) REFERENCES MEDICAMENTOS (ID_MEDICAMENTO),
    CONSTRAINT CK_ADMIN_MED_CANTIDAD         CHECK (CANTIDAD > 0),
    CONSTRAINT CK_ADMIN_MED_COSTO            CHECK (COSTO_TOTAL >= 0)
);

COMMENT ON TABLE ADMINISTRACION_MEDICAMENTOS IS 'Medicamentos administrados por consulta: cantidad, dosis y costo (permite análisis de consumo)';


-- ---------------------------------------------------------------------------
-- 2.4 PAGOS
-- ---------------------------------------------------------------------------
CREATE TABLE PAGOS (
    ID_PAGO                   NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    ID_CONSULTA               NUMBER         NOT NULL,
    TIPO_PAGADOR              VARCHAR2(15)   NOT NULL,
    ID_EMPRESA                NUMBER,
    ID_ASEGURADORA            NUMBER,
    MONTO_FACTURADO           NUMBER(10,2)   NOT NULL,
    MONTO_PAGADO              NUMBER(10,2)   DEFAULT 0 NOT NULL,
    MONTO_PENDIENTE           NUMBER(10,2)   GENERATED ALWAYS AS (MONTO_FACTURADO - MONTO_PAGADO) VIRTUAL,
    FECHA_PAGO                DATE,
    ESTADO_PAGO               VARCHAR2(15)   DEFAULT 'PENDIENTE' NOT NULL,
    CONSTRAINT PK_PAGOS                   PRIMARY KEY (ID_PAGO),
    CONSTRAINT FK_PAGOS_CONSULTA          FOREIGN KEY (ID_CONSULTA) REFERENCES CONSULTAS (ID_CONSULTA),
    CONSTRAINT FK_PAGOS_EMPRESA           FOREIGN KEY (ID_EMPRESA) REFERENCES EMPRESAS (ID_EMPRESA),
    CONSTRAINT FK_PAGOS_ASEGURADORA       FOREIGN KEY (ID_ASEGURADORA) REFERENCES ASEGURADORAS (ID_ASEGURADORA),
    CONSTRAINT CK_PAGOS_TIPO_PAGADOR      CHECK (TIPO_PAGADOR IN ('PACIENTE','EMPRESA','ASEGURADORA')),
    CONSTRAINT CK_PAGOS_ESTADO            CHECK (ESTADO_PAGO IN ('PENDIENTE','PARCIAL','PAGADO','ANULADO')),
    CONSTRAINT CK_PAGOS_MONTOS            CHECK (MONTO_FACTURADO >= 0 AND MONTO_PAGADO >= 0),
    CONSTRAINT CK_PAGOS_PAGADOR_COHERENTE CHECK (
        (TIPO_PAGADOR = 'PACIENTE'     AND ID_EMPRESA IS NULL     AND ID_ASEGURADORA IS NULL) OR
        (TIPO_PAGADOR = 'EMPRESA'      AND ID_EMPRESA IS NOT NULL AND ID_ASEGURADORA IS NULL) OR
        (TIPO_PAGADOR = 'ASEGURADORA'  AND ID_ASEGURADORA IS NOT NULL AND ID_EMPRESA IS NULL)
    )
);

COMMENT ON TABLE PAGOS IS 'Pagos asociados a una consulta: quién paga (paciente/empresa/aseguradora), monto facturado/pagado/pendiente';
COMMENT ON COLUMN PAGOS.MONTO_PENDIENTE IS 'Columna calculada: MONTO_FACTURADO - MONTO_PAGADO';


-- ============================================================================
-- 3. ÍNDICES SOBRE LLAVES FORÁNEAS (Mejora de rendimiento en Joins)
-- ============================================================================
CREATE INDEX IX_CLINICAS_REGION          ON CLINICAS (ID_REGION);
CREATE INDEX IX_MEDICOS_ESPECIALIDAD     ON MEDICOS (ID_ESPECIALIDAD);
CREATE INDEX IX_MEDICOS_CLINICA          ON MEDICOS (ID_CLINICA);
CREATE INDEX IX_PACIENTES_REGION         ON PACIENTES (ID_REGION);
CREATE INDEX IX_PACIENTES_CLINICA        ON PACIENTES (ID_CLINICA_HABITUAL);
CREATE INDEX IX_PACIENTES_EMPRESA        ON PACIENTES (ID_EMPRESA);
CREATE INDEX IX_PACIENTES_ASEGURADORA    ON PACIENTES (ID_ASEGURADORA);
CREATE INDEX IX_CONSULTAS_PACIENTE       ON CONSULTAS (ID_PACIENTE);
CREATE INDEX IX_CONSULTAS_CLINICA        ON CONSULTAS (ID_CLINICA);
CREATE INDEX IX_CONSULTAS_MEDICO         ON CONSULTAS (ID_MEDICO);
CREATE INDEX IX_CONSULTAS_ESPECIALIDAD   ON CONSULTAS (ID_ESPECIALIDAD);
CREATE INDEX IX_CONSULTAS_FECHA          ON CONSULTAS (FECHA_CONSULTA);
CREATE INDEX IX_DIAGNOSTICOS_ENFERMEDAD  ON DIAGNOSTICOS (ID_ENFERMEDAD);
CREATE INDEX IX_ADMIN_MED_MEDICAMENTO    ON ADMINISTRACION_MEDICAMENTOS (ID_MEDICAMENTO);
CREATE INDEX IX_PAGOS_CONSULTA           ON PAGOS (ID_CONSULTA);
CREATE INDEX IX_PAGOS_EMPRESA            ON PAGOS (ID_EMPRESA);
CREATE INDEX IX_PAGOS_ASEGURADORA        ON PAGOS (ID_ASEGURADORA);
CREATE INDEX IX_PAGOS_ESTADO             ON PAGOS (ESTADO_PAGO);


-- ============================================================================
-- 4. VALIDACIÓN RÁPIDA DE LA ESTRUCTURA
-- ============================================================================
-- 1. Contar columnas por tabla creada
SELECT TABLE_NAME, COUNT(*) AS NUM_COLUMNAS
FROM   USER_TAB_COLUMNS
WHERE  TABLE_NAME IN (
    'REGIONES','CLINICAS','ESPECIALIDADES','MEDICOS','ENFERMEDADES',
    'MEDICAMENTOS','EMPRESAS','ASEGURADORAS','PACIENTES','CONSULTAS',
    'DIAGNOSTICOS','ADMINISTRACION_MEDICAMENTOS','PAGOS')
GROUP  BY TABLE_NAME
ORDER  BY TABLE_NAME;

-- 2. Listar todas las llaves foráneas creadas (integridad referencial)
SELECT A.TABLE_NAME, A.CONSTRAINT_NAME, C.TABLE_NAME AS TABLA_REFERENCIADA
FROM   USER_CONSTRAINTS A
JOIN   USER_CONSTRAINTS C ON A.R_CONSTRAINT_NAME = C.CONSTRAINT_NAME
WHERE  A.CONSTRAINT_TYPE = 'R'
ORDER  BY A.TABLE_NAME;