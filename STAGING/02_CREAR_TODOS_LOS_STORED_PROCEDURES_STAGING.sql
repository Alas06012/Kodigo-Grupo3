/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED ASISTENCIAL DE CLÍNICAS
   COMPILACIÓN CONSOLIDADA DE TODOS LOS STORED PROCEDURES DE STAGING
   MOTOR: Oracle Database 19c / 21c / 23ai
   ESQUEMA: stg_clinica_user | TABLESPACE: stg_clinicas_db
   ============================================================================
   INSTRUCCIONES DE EJECUCIÓN:
     - Conectarse en SQL Developer, DBeaver, VS Code o SQL*Plus como: stg_clinica_user
     - Este script compila los 19 stored procedures de extracción (18 tablas + maestro)
       instrumentados con auditoría nativa en dwh_clinica_user.CTL_ETL_AUDIT.
   ============================================================================ */

SET FEEDBACK ON;
SET ECHO OFF;



-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_UBICACIONES
-- OBJETIVO:      Extracción directa desde red_clinica_user.UBICACIONES hacia STG_UBICACIONES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_UBICACIONES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_UBICACIONES', 'SP_EXTRACT_STG_UBICACIONES', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_UBICACIONES';

    INSERT /*+ APPEND */ INTO STG_UBICACIONES (
        ID_UBICACION, PAIS, DEPARTAMENTO, MUNICIPIO, DISTRITO, CODIGO_POSTAL,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_UBICACION, o.PAIS, o.DEPARTAMENTO, o.MUNICIPIO, o.DISTRITO, o.CODIGO_POSTAL,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.PAIS, '~') || '|' ||
            NVL(o.DEPARTAMENTO, '~') || '|' ||
            NVL(o.MUNICIPIO, '~') || '|' ||
            NVL(o.DISTRITO, '~') || '|' ||
            NVL(o.CODIGO_POSTAL, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.UBICACIONES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_UBICACIONES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_UBICACIONES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_UBICACIONES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_UBICACIONES TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_CLINICAS
-- OBJETIVO:      Extracción directa desde red_clinica_user.CLINICAS hacia STG_CLINICAS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_CLINICAS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_CLINICAS', 'SP_EXTRACT_STG_CLINICAS', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_CLINICAS';

    INSERT /*+ APPEND */ INTO STG_CLINICAS (
        ID_CLINICA, 
        NOMBRE_CLINICA, 
        ID_UBICACION, 
        DIRECCION, 
        TELEFONO, 
        FECHA_APERTURA, 
        ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_CLINICA, 
        o.NOMBRE_CLINICA, 
        o.ID_UBICACION, 
        o.DIRECCION, 
        o.TELEFONO,
        o.FECHA_APERTURA, 
        o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_CLINICA, '~') || '|' ||
            NVL(TO_CHAR(o.ID_UBICACION), '~') || '|' ||
            NVL(o.DIRECCION, '~') || '|' ||
            NVL(o.TELEFONO, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_APERTURA, 'YYYY-MM-DD'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.CLINICAS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_CLINICAS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_CLINICAS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_CLINICAS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_CLINICAS TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_EMPRESAS
-- OBJETIVO:      Extracción directa desde red_clinica_user.EMPRESAS hacia STG_EMPRESAS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_EMPRESAS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_EMPRESAS', 'SP_EXTRACT_STG_EMPRESAS', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_EMPRESAS';

    INSERT /*+ APPEND */ INTO STG_EMPRESAS (
        ID_EMPRESA, NOMBRE_EMPRESA, NIT, SECTOR, TELEFONO, DIRECCION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_EMPRESA, o.NOMBRE_EMPRESA, o.NIT, o.SECTOR, o.TELEFONO, o.DIRECCION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_EMPRESA, '~') || '|' ||
            NVL(o.NIT, '~') || '|' ||
            NVL(o.SECTOR, '~') || '|' ||
            NVL(o.TELEFONO, '~') || '|' ||
            NVL(o.DIRECCION, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.EMPRESAS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_EMPRESAS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_EMPRESAS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_EMPRESAS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_EMPRESAS TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_ASEGURADORAS
-- OBJETIVO:      Extracción directa desde red_clinica_user.ASEGURADORAS hacia stg_clinica_user.STG_ASEGURADORAS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_ASEGURADORAS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_ASEGURADORAS', 'SP_EXTRACT_STG_ASEGURADORAS', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_ASEGURADORAS';

    INSERT /*+ APPEND */ INTO STG_ASEGURADORAS (
        ID_ASEGURADORA, 
        NOMBRE_ASEGURADORA, 
        NIT, TIPO_COBERTURA, 
        TELEFONO,
        CURRENTFLAG, 
        TIPOCARGA, 
        FECHAINICIO, 
        FECHAFIN, 
        TIPOTRANSACCION,
        ROWHASHVALUE
    )
    SELECT 
        o.ID_ASEGURADORA, 
        o.NOMBRE_ASEGURADORA, 
        o.NIT, 
        o.TIPO_COBERTURA, 
        o.TELEFONO,
        1, 
        v_tipo, 
        SYSDATE,
        DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_ASEGURADORA, '~') || '|' ||
            NVL(o.NIT, '~') || '|' ||
            NVL(o.TIPO_COBERTURA, '~') || '|' ||
            NVL(o.TELEFONO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.ASEGURADORAS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_ASEGURADORAS extraída: ' || v_filas || ' registros.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_ASEGURADORAS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_ASEGURADORAS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_ASEGURADORAS TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_PACIENTES
-- OBJETIVO:      Extracción directa desde red_clinica_user.PACIENTES hacia STG_PACIENTES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_PACIENTES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_PACIENTES', 'SP_EXTRACT_STG_PACIENTES', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_PACIENTES';

    INSERT /*+ APPEND */ INTO STG_PACIENTES (
        ID_PACIENTE, NOMBRES, APELLIDOS, FECHA_NACIMIENTO, SEXO, ID_UBICACION,
        DIRECCION, ID_CLINICA_HABITUAL, ID_EMPRESA, ID_ASEGURADORA, NUMERO_POLIZA, FECHA_REGISTRO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_PACIENTE, o.NOMBRES, o.APELLIDOS, o.FECHA_NACIMIENTO, o.SEXO, o.ID_UBICACION,
        o.DIRECCION, o.ID_CLINICA_HABITUAL, o.ID_EMPRESA, o.ID_ASEGURADORA, o.NUMERO_POLIZA, o.FECHA_REGISTRO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRES, '~') || '|' ||
            NVL(o.APELLIDOS, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_NACIMIENTO, 'YYYY-MM-DD'), '~') || '|' ||
            NVL(o.SEXO, '~') || '|' ||
            NVL(TO_CHAR(o.ID_UBICACION), '~') || '|' ||
            NVL(o.DIRECCION, '~') || '|' ||
            NVL(TO_CHAR(o.ID_CLINICA_HABITUAL), '~') || '|' ||
            NVL(TO_CHAR(o.ID_EMPRESA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ASEGURADORA), '~') || '|' ||
            NVL(o.NUMERO_POLIZA, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.PACIENTES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_PACIENTES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_PACIENTES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_PACIENTES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_PACIENTES TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_ESPECIALIDADES
-- OBJETIVO:      Extracción directa desde red_clinica_user.ESPECIALIDADES hacia STG_ESPECIALIDADES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_ESPECIALIDADES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_ESPECIALIDADES', 'SP_EXTRACT_STG_ESPECIALIDADES', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_ESPECIALIDADES';

    INSERT /*+ APPEND */ INTO STG_ESPECIALIDADES (
        ID_ESPECIALIDAD, NOMBRE_ESPECIALIDAD, DESCRIPCION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_ESPECIALIDAD, o.NOMBRE_ESPECIALIDAD, o.DESCRIPCION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_ESPECIALIDAD, '~') || '|' ||
            NVL(o.DESCRIPCION, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.ESPECIALIDADES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_ESPECIALIDADES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_ESPECIALIDADES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_ESPECIALIDADES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_ESPECIALIDADES TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_MEDICOS
-- OBJETIVO:      Extracción directa desde red_clinica_user.MEDICOS hacia STG_MEDICOS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_MEDICOS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_MEDICOS', 'SP_EXTRACT_STG_MEDICOS', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_MEDICOS';

    INSERT /*+ APPEND */ INTO STG_MEDICOS (
        ID_MEDICO, NOMBRES, APELLIDOS, ID_CLINICA, NUM_COLEGIADO, FECHA_INGRESO, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_MEDICO, o.NOMBRES, o.APELLIDOS, o.ID_CLINICA_BASE, o.NUM_COLEGIADO, o.FECHA_INGRESO, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRES, '~') || '|' ||
            NVL(o.APELLIDOS, '~') || '|' ||
            NVL(TO_CHAR(o.ID_CLINICA_BASE), '~') || '|' ||
            NVL(o.NUM_COLEGIADO, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_INGRESO, 'YYYY-MM-DD'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.MEDICOS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_MEDICOS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_MEDICOS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_MEDICOS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_MEDICOS TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES
-- OBJETIVO:      Extracción directa desde red_clinica_user.MEDICOS_ESPECIALIDADES hacia STG_MEDICOS_ESPECIALIDADES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_MEDICOS_ESPECIALIDADES', 'SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_MEDICOS_ESPECIALIDADES';

    INSERT /*+ APPEND */ INTO STG_MEDICOS_ESPECIALIDADES (
        ID_MEDICO_ESPECIALIDAD, ID_MEDICO, ID_ESPECIALIDAD, NUM_REGISTRO_ESPECIAL, ES_PRINCIPAL,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_MEDICO_ESPECIALIDAD, o.ID_MEDICO, o.ID_ESPECIALIDAD, o.NUM_REGISTRO_ESPECIAL, o.ES_PRINCIPAL,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_MEDICO), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ESPECIALIDAD), '~') || '|' ||
            NVL(o.NUM_REGISTRO_ESPECIAL, '~') || '|' ||
            NVL(o.ES_PRINCIPAL, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.MEDICOS_ESPECIALIDADES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_MEDICOS_ESPECIALIDADES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_ENFERMEDADES
-- OBJETIVO:      Extracción directa desde red_clinica_user.ENFERMEDADES hacia STG_ENFERMEDADES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_ENFERMEDADES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_ENFERMEDADES', 'SP_EXTRACT_STG_ENFERMEDADES', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_ENFERMEDADES';

    INSERT /*+ APPEND */ INTO STG_ENFERMEDADES (
        ID_ENFERMEDAD, CODIGO_CIE10, NOMBRE_ENFERMEDAD,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_ENFERMEDAD, o.CODIGO_CIE10, o.NOMBRE_ENFERMEDAD,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.CODIGO_CIE10, '~') || '|' ||
            NVL(o.NOMBRE_ENFERMEDAD, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.ENFERMEDADES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_ENFERMEDADES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_ENFERMEDADES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_ENFERMEDADES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_ENFERMEDADES TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_TIPOS_CONSULTA
-- OBJETIVO:      Extracción directa desde red_clinica_user.TIPOS_CONSULTA hacia STG_TIPOS_CONSULTA
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_TIPOS_CONSULTA (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_TIPOS_CONSULTA', 'SP_EXTRACT_STG_TIPOS_CONSULTA', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_TIPOS_CONSULTA';

    INSERT /*+ APPEND */ INTO STG_TIPOS_CONSULTA (
        ID_TIPO_CONSULTA, NOMBRE_TIPO, DESCRIPCION, PRECIO_BASE, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_TIPO_CONSULTA, o.NOMBRE_TIPO, o.DESCRIPCION, o.PRECIO_BASE, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_TIPO, '~') || '|' ||
            NVL(o.DESCRIPCION, '~') || '|' ||
            NVL(TO_CHAR(o.PRECIO_BASE, 'FM999999990.00'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.TIPOS_CONSULTA o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_TIPOS_CONSULTA extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_TIPOS_CONSULTA: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_TIPOS_CONSULTA;
/

GRANT EXECUTE ON SP_EXTRACT_STG_TIPOS_CONSULTA TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_PROCEDIMIENTOS
-- OBJETIVO:      Extracción directa desde red_clinica_user.PROCEDIMIENTOS hacia STG_PROCEDIMIENTOS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_PROCEDIMIENTOS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_PROCEDIMIENTOS', 'SP_EXTRACT_STG_PROCEDIMIENTOS', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_PROCEDIMIENTOS';

    INSERT /*+ APPEND */ INTO STG_PROCEDIMIENTOS (
        ID_PROCEDIMIENTO, CODIGO_PROCEDIMIENTO, NOMBRE_PROCEDIMIENTO, DESCRIPCION, COSTO_BASE, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_PROCEDIMIENTO, o.CODIGO_PROCEDIMIENTO, o.NOMBRE_PROCEDIMIENTO, o.DESCRIPCION, o.COSTO_BASE, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.CODIGO_PROCEDIMIENTO, '~') || '|' ||
            NVL(o.NOMBRE_PROCEDIMIENTO, '~') || '|' ||
            NVL(o.DESCRIPCION, '~') || '|' ||
            NVL(TO_CHAR(o.COSTO_BASE, 'FM999999990.00'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.PROCEDIMIENTOS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_PROCEDIMIENTOS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_PROCEDIMIENTOS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_PROCEDIMIENTOS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_PROCEDIMIENTOS TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_FORMAS_PAGO
-- OBJETIVO:      Extracción directa desde red_clinica_user.FORMAS_PAGO hacia STG_FORMAS_PAGO
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_FORMAS_PAGO (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_FORMAS_PAGO', 'SP_EXTRACT_STG_FORMAS_PAGO', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_FORMAS_PAGO';

    INSERT /*+ APPEND */ INTO STG_FORMAS_PAGO (
        ID_FORMA_PAGO, NOMBRE_FORMA_PAGO, CATEGORIA, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_FORMA_PAGO, o.NOMBRE_FORMA_PAGO, o.CATEGORIA, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_FORMA_PAGO, '~') || '|' ||
            NVL(o.CATEGORIA, '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.FORMAS_PAGO o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_FORMAS_PAGO extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_FORMAS_PAGO: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_FORMAS_PAGO;
/

GRANT EXECUTE ON SP_EXTRACT_STG_FORMAS_PAGO TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_CONSULTAS
-- OBJETIVO:      Extracción de atenciones médicas desde red_clinica_user.CONSULTAS
--                hacia STG_CONSULTAS con soporte de ventana incremental (Lookback)
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_CONSULTAS (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL,
    p_batch_id       IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas        NUMBER := 0;
    v_tipo         VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias         NUMBER := NVL(p_dias_lookback, 3);
    v_fecha_filtro DATE;
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_CONSULTAS', 'SP_EXTRACT_STG_CONSULTAS', v_tipo, v_audit_id);
    IF v_tipo = 'INCREMENTAL' THEN
        IF p_fecha_corte IS NOT NULL THEN
            v_fecha_filtro := TRUNC(p_fecha_corte);
        ELSE
            v_fecha_filtro := TRUNC(SYSDATE) - v_dias;
        END IF;
    ELSE
        v_fecha_filtro := DATE '1900-01-01';
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_CONSULTAS';

    INSERT /*+ APPEND */ INTO STG_CONSULTAS (
        ID_CONSULTA, ID_PACIENTE, ID_CLINICA, ID_MEDICO, ID_ESPECIALIDAD, ID_TIPO_CONSULTA,
        FECHA_CONSULTA, PRECIO_CONSULTA, MOTIVO_CONSULTA, PRESCRIPCION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_CONSULTA, o.ID_PACIENTE, o.ID_CLINICA, o.ID_MEDICO, o.ID_ESPECIALIDAD, o.ID_TIPO_CONSULTA,
        o.FECHA_CONSULTA, o.PRECIO_CONSULTA, o.MOTIVO_CONSULTA, o.PRESCRIPCION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_PACIENTE), '~') || '|' ||
            NVL(TO_CHAR(o.ID_CLINICA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_MEDICO), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ESPECIALIDAD), '~') || '|' ||
            NVL(TO_CHAR(o.ID_TIPO_CONSULTA), '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_CONSULTA, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
            NVL(TO_CHAR(o.PRECIO_CONSULTA, 'FM999999990.00'), '~') || '|' ||
            NVL(o.MOTIVO_CONSULTA, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.CONSULTAS o
    WHERE o.FECHA_CONSULTA >= v_fecha_filtro;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_CONSULTAS extraída (Ventana >= ' || TO_CHAR(v_fecha_filtro, 'YYYY-MM-DD') || '): ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_CONSULTAS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_CONSULTAS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_CONSULTAS TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_DIAGNOSTICOS
-- OBJETIVO:      Extracción de diagnósticos clínicos desde red_clinica_user.DIAGNOSTICOS
--                hacia STG_DIAGNOSTICOS con soporte de ventana incremental
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_DIAGNOSTICOS (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL,
    p_batch_id       IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas        NUMBER := 0;
    v_tipo         VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias         NUMBER := NVL(p_dias_lookback, 3);
    v_fecha_filtro DATE;
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_DIAGNOSTICOS', 'SP_EXTRACT_STG_DIAGNOSTICOS', v_tipo, v_audit_id);
    IF v_tipo = 'INCREMENTAL' THEN
        IF p_fecha_corte IS NOT NULL THEN
            v_fecha_filtro := TRUNC(p_fecha_corte);
        ELSE
            v_fecha_filtro := TRUNC(SYSDATE) - v_dias;
        END IF;
    ELSE
        v_fecha_filtro := DATE '1900-01-01';
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_DIAGNOSTICOS';

    INSERT /*+ APPEND */ INTO STG_DIAGNOSTICOS (
        ID_DIAGNOSTICO, ID_CONSULTA, ID_ENFERMEDAD, FECHA_DIAGNOSTICO, OBSERVACIONES,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_DIAGNOSTICO, o.ID_CONSULTA, o.ID_ENFERMEDAD, o.FECHA_DIAGNOSTICO, o.OBSERVACIONES,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_CONSULTA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ENFERMEDAD), '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_DIAGNOSTICO, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
            NVL(o.OBSERVACIONES, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.DIAGNOSTICOS o
    WHERE o.FECHA_DIAGNOSTICO >= v_fecha_filtro
       OR o.ID_CONSULTA IN (SELECT ID_CONSULTA FROM STG_CONSULTAS);

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_DIAGNOSTICOS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_DIAGNOSTICOS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_DIAGNOSTICOS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_DIAGNOSTICOS TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS
-- OBJETIVO:      Extracción de procedimientos aplicados desde 
--                red_clinica_user.CONSULTAS_PROCEDIMIENTOS hacia 
--                STG_CONSULTAS_PROCEDIMIENTOS con soporte de ventana incremental
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL,
    p_batch_id       IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas        NUMBER := 0;
    v_tipo         VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias         NUMBER := NVL(p_dias_lookback, 3);
    v_fecha_filtro DATE;
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_CONSULTAS_PROCEDIMIENTOS', 'SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS', v_tipo, v_audit_id);
    IF v_tipo = 'INCREMENTAL' THEN
        IF p_fecha_corte IS NOT NULL THEN
            v_fecha_filtro := TRUNC(p_fecha_corte);
        ELSE
            v_fecha_filtro := TRUNC(SYSDATE) - v_dias;
        END IF;
    ELSE
        v_fecha_filtro := DATE '1900-01-01';
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_CONSULTAS_PROCEDIMIENTOS';

    INSERT /*+ APPEND */ INTO STG_CONSULTAS_PROCEDIMIENTOS (
        ID_CONSULTA_PROCEDIMIENTO, ID_CONSULTA, ID_PROCEDIMIENTO, CANTIDAD, PRECIO_UNITARIO, SUBTOTAL,
        OBSERVACIONES, FECHA_REALIZACION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_CONSULTA_PROCEDIMIENTO, o.ID_CONSULTA, o.ID_PROCEDIMIENTO, o.CANTIDAD, o.PRECIO_UNITARIO, o.SUBTOTAL,
        o.OBSERVACIONES, o.FECHA_REALIZACION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_CONSULTA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_PROCEDIMIENTO), '~') || '|' ||
            NVL(TO_CHAR(o.CANTIDAD), '~') || '|' ||
            NVL(TO_CHAR(o.PRECIO_UNITARIO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.SUBTOTAL, 'FM999999990.00'), '~') || '|' ||
            NVL(o.OBSERVACIONES, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_REALIZACION, 'YYYY-MM-DD HH24:MI:SS'), '~'),
            'SHA256'
        ))
    FROM red_clinica_user.CONSULTAS_PROCEDIMIENTOS o
    WHERE o.FECHA_REALIZACION >= v_fecha_filtro
       OR o.ID_CONSULTA IN (SELECT ID_CONSULTA FROM STG_CONSULTAS);

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_CONSULTAS_PROCEDIMIENTOS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_TRANSACCIONES_PAGO
-- OBJETIVO:      Extracción del libro diario de pagos desde 
--                red_clinica_user.TRANSACCIONES_PAGO hacia STG_TRANSACCIONES_PAGO
--                con soporte de ventana incremental (Lookback)
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_TRANSACCIONES_PAGO (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL,
    p_batch_id       IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas        NUMBER := 0;
    v_tipo         VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias         NUMBER := NVL(p_dias_lookback, 3);
    v_fecha_filtro DATE;
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_TRANSACCIONES_PAGO', 'SP_EXTRACT_STG_TRANSACCIONES_PAGO', v_tipo, v_audit_id);
    IF v_tipo = 'INCREMENTAL' THEN
        IF p_fecha_corte IS NOT NULL THEN
            v_fecha_filtro := TRUNC(p_fecha_corte);
        ELSE
            v_fecha_filtro := TRUNC(SYSDATE) - v_dias;
        END IF;
    ELSE
        v_fecha_filtro := DATE '1900-01-01';
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_TRANSACCIONES_PAGO';

    INSERT /*+ APPEND */ INTO STG_TRANSACCIONES_PAGO (
        ID_TRANSACCION, ID_COBRO, ID_DISTRIBUCION, ID_FORMA_PAGO, MONTO_TRANSACCION,
        FECHA_PAGO, NUMERO_REFERENCIA, OBSERVACIONES,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_TRANSACCION, d.ID_COBRO, o.ID_DISTRIBUCION, o.ID_FORMA_PAGO, o.MONTO_TRANSACCION,
        o.FECHA_PAGO, o.NUMERO_REFERENCIA, o.OBSERVACIONES,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(d.ID_COBRO), '~') || '|' ||
            NVL(TO_CHAR(o.ID_DISTRIBUCION), '~') || '|' ||
            NVL(TO_CHAR(o.ID_FORMA_PAGO), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_TRANSACCION, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_PAGO, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
            NVL(o.NUMERO_REFERENCIA, '~') || '|' ||
            NVL(o.OBSERVACIONES, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.TRANSACCIONES_PAGO o
    INNER JOIN red_clinica_user.DISTRIBUCION_COBRO d ON d.ID_DISTRIBUCION = o.ID_DISTRIBUCION
    WHERE o.FECHA_PAGO >= v_fecha_filtro;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_TRANSACCIONES_PAGO extraída (Ventana >= ' || TO_CHAR(v_fecha_filtro, 'YYYY-MM-DD') || '): ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_TRANSACCIONES_PAGO: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_TRANSACCIONES_PAGO;
/

GRANT EXECUTE ON SP_EXTRACT_STG_TRANSACCIONES_PAGO TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_COBROS_CONSULTA
-- OBJETIVO:      Extracción del estado de cuenta médico desde 
--                red_clinica_user.COBROS_CONSULTA hacia STG_COBROS_CONSULTA
--                con soporte de ventana incremental (Lookback)
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_COBROS_CONSULTA (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL,
    p_batch_id       IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas        NUMBER := 0;
    v_tipo         VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias         NUMBER := NVL(p_dias_lookback, 3);
    v_fecha_filtro DATE;
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_COBROS_CONSULTA', 'SP_EXTRACT_STG_COBROS_CONSULTA', v_tipo, v_audit_id);
    IF v_tipo = 'INCREMENTAL' THEN
        IF p_fecha_corte IS NOT NULL THEN
            v_fecha_filtro := TRUNC(p_fecha_corte);
        ELSE
            v_fecha_filtro := TRUNC(SYSDATE) - v_dias;
        END IF;
    ELSE
        v_fecha_filtro := DATE '1900-01-01';
    END IF;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_COBROS_CONSULTA';

    INSERT /*+ APPEND */ INTO STG_COBROS_CONSULTA (
        ID_COBRO, ID_CONSULTA, MONTO_TOTAL_FACTURADO, MONTO_TOTAL_PAGADO, SALDO_PENDIENTE,
        ESTADO_COBRO, FECHA_EMISION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_COBRO, o.ID_CONSULTA, o.MONTO_TOTAL_FACTURADO, o.MONTO_TOTAL_PAGADO, o.SALDO_PENDIENTE,
        o.ESTADO_COBRO, o.FECHA_EMISION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_CONSULTA), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_TOTAL_FACTURADO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_TOTAL_PAGADO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.SALDO_PENDIENTE, 'FM999999990.00'), '~') || '|' ||
            NVL(o.ESTADO_COBRO, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_EMISION, 'YYYY-MM-DD HH24:MI:SS'), '~'),
            'SHA256'
        ))
    FROM red_clinica_user.COBROS_CONSULTA o
    WHERE o.FECHA_EMISION >= v_fecha_filtro
       OR o.ID_CONSULTA IN (SELECT ID_CONSULTA FROM STG_CONSULTAS)
       OR o.ID_COBRO IN (SELECT ID_COBRO FROM STG_TRANSACCIONES_PAGO);

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_COBROS_CONSULTA extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_COBROS_CONSULTA: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_COBROS_CONSULTA;
/

GRANT EXECUTE ON SP_EXTRACT_STG_COBROS_CONSULTA TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_DISTRIBUCION_COBRO
-- OBJETIVO:      Extracción del desglose de cobro por pagador desde 
--                red_clinica_user.DISTRIBUCION_COBRO hacia STG_DISTRIBUCION_COBRO
--                con soporte de ventana incremental (Lookback)
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_DISTRIBUCION_COBRO (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL,
    p_batch_id       IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STG_DISTRIBUCION_COBRO', 'SP_EXTRACT_STG_DISTRIBUCION_COBRO', v_tipo, v_audit_id);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_DISTRIBUCION_COBRO';

    INSERT /*+ APPEND */ INTO STG_DISTRIBUCION_COBRO (
        ID_DISTRIBUCION, ID_COBRO, TIPO_PAGADOR, ID_PACIENTE, ID_ASEGURADORA, ID_EMPRESA,
        PORCENTAJE, MONTO_ASIGNADO, MONTO_PAGADO, SALDO_PENDIENTE, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_DISTRIBUCION, o.ID_COBRO, o.TIPO_PAGADOR, o.ID_PACIENTE, o.ID_ASEGURADORA, o.ID_EMPRESA,
        o.PORCENTAJE, o.MONTO_ASIGNADO, o.MONTO_PAGADO, o.SALDO_PENDIENTE, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(TO_CHAR(o.ID_COBRO), '~') || '|' ||
            NVL(o.TIPO_PAGADOR, '~') || '|' ||
            NVL(TO_CHAR(o.ID_PACIENTE), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ASEGURADORA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_EMPRESA), '~') || '|' ||
            NVL(TO_CHAR(o.PORCENTAJE, 'FM990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_ASIGNADO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.MONTO_PAGADO, 'FM999999990.00'), '~') || '|' ||
            NVL(TO_CHAR(o.SALDO_PENDIENTE, 'FM999999990.00'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.DISTRIBUCION_COBRO o
    WHERE o.ID_COBRO IN (SELECT ID_COBRO FROM STG_COBROS_CONSULTA);

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    dwh_clinica_user.SP_AUDIT_END(v_audit_id, v_filas, v_filas, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('STG_DISTRIBUCION_COBRO extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_DISTRIBUCION_COBRO: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_DISTRIBUCION_COBRO;
/

GRANT EXECUTE ON SP_EXTRACT_STG_DISTRIBUCION_COBRO TO dwh_clinica_user;

-- ============================================================================
-- PROCEDIMIENTO MAESTRO: SP_EXTRACT_OLTP_TO_STG
-- OBJETIVO: Orquestador general de la extracción OLTP -> Staging.
--           Invoca de forma modular y secuencial cada procedimiento individual
--           por cada tabla origen, preservando el cálculo de SHA-256 al vuelo
--           y la ventana incremental (Lookback).
--           Registra auditoría integral en CTL_ETL_AUDIT.
-- ESQUEMA:  stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_OLTP_TO_STG (
    p_tipo_carga     IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback  IN NUMBER   DEFAULT 3,
    p_fecha_corte    IN DATE     DEFAULT NULL,
    p_batch_id       IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_inicio_proc TIMESTAMP := SYSTIMESTAMP;
    v_tipo_carga  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias        NUMBER := NVL(p_dias_lookback, 3);
    v_batch_id    VARCHAR2(50);
    v_audit_id    NUMBER;
BEGIN
    IF v_tipo_carga NOT IN ('FULL', 'INCREMENTAL') THEN
        RAISE_APPLICATION_ERROR(-20010, 'Parámetro p_tipo_carga inválido. Debe ser FULL o INCREMENTAL.');
    END IF;

    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    dwh_clinica_user.SP_AUDIT_START(v_batch_id, 'STAGING', 'STAGING_ALL', 'SP_EXTRACT_OLTP_TO_STG', v_tipo_carga, v_audit_id);

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('INICIO PROCESO DE EXTRACCIÓN: OLTP (red_clinica_user) -> STAGING');
    DBMS_OUTPUT.PUT_LINE('Batch ID: ' || v_batch_id);
    DBMS_OUTPUT.PUT_LINE('Modo de Carga: ' || v_tipo_carga || ' | Ventana Días Lookback: ' || v_dias);
    DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================');

    -- BLOQUE 1: CATÁLOGOS Y ENTIDADES MAESTRAS
    DBMS_OUTPUT.PUT_LINE('>>> 1. Extrayendo Catálogos y Entidades Maestras...');
    SP_EXTRACT_STG_UBICACIONES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_CLINICAS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_EMPRESAS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_ASEGURADORAS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_PACIENTES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_ESPECIALIDADES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_MEDICOS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_ENFERMEDADES(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_TIPOS_CONSULTA(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_PROCEDIMIENTOS(v_tipo_carga, v_batch_id);
    SP_EXTRACT_STG_FORMAS_PAGO(v_tipo_carga, v_batch_id);

    -- BLOQUE 2: TABLAS TRANSACCIONALES MASIVAS (VENTANA INCREMENTAL)
    DBMS_OUTPUT.PUT_LINE('>>> 2. Extrayendo Transacciones Masivas (Ventana Lookback)...');
    SP_EXTRACT_STG_CONSULTAS(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_DIAGNOSTICOS(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_TRANSACCIONES_PAGO(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_COBROS_CONSULTA(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);
    SP_EXTRACT_STG_DISTRIBUCION_COBRO(v_tipo_carga, v_dias, p_fecha_corte, v_batch_id);

    dwh_clinica_user.SP_AUDIT_END(v_audit_id, 0, 0, 0, 0, 'SUCCESS');

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('EXTRACCIÓN OPTIMIZADA A STAGING COMPLETADA EXITOSAMENTE');
    DBMS_OUTPUT.PUT_LINE('Duración: ' || TO_CHAR(SYSTIMESTAMP - v_inicio_proc));
    DBMS_OUTPUT.PUT_LINE('================================================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            dwh_clinica_user.SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('*** ERROR CRÍTICO EN SP_EXTRACT_OLTP_TO_STG: ' || SQLERRM || ' ***');
        RAISE;
END SP_EXTRACT_OLTP_TO_STG;
/

GRANT EXECUTE ON SP_EXTRACT_OLTP_TO_STG TO dwh_clinica_user;
