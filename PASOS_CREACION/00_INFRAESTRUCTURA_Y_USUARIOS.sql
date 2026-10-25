/* ============================================================================
   PASO 00: INFRAESTRUCTURA, TABLESPACES, USUARIOS Y PRIVILEGIOS
   ============================================================================
   USUARIO DE CONEXION: SYS AS SYSDBA o SYSTEM
   CONTENEDOR (PDB):    XEPDB1
   HOST / PUERTO:       localhost:1521
   ============================================================================
   INSTRUCCIONES DE EJECUCION:
     1. Conectate a Oracle con tu cliente SQL (SQL Developer, DBeaver, VS Code
        o SQL*Plus) usando el usuario SYS (como SYSDBA) o SYSTEM.
     2. Asegurate de estar en el contenedor PDB: XEPDB1.
     3. Ejecuta este script completo para crear los 3 tablespaces fisicos
        y los 3 esquemas de base de datos con sus cuotas y permisos:
        - red_clinica_user  / Password2026   (Capa OLTP Transaccional)
        - stg_clinica_user  / StagingPass2026 (Capa Staging / Landing)
        - dwh_clinica_user  / DwhPass2026     (Capa Data Warehouse Kimball)
   ============================================================================ */

/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED ASISTENCIAL DE CLÍNICAS
   SCRIPT MAESTRO: CONFIGURACIÓN DE TABLESPACES, USUARIOS Y PRIVILEGIOS
   MOTOR: Oracle Database 19c / 21c / 23ai
   CONTENEDOR: XEPDB1
   EJECUCIÓN: Conectado como SYS AS SYSDBA o SYSTEM
   ============================================================================ */

-- 0. Conexión al contenedor de base de datos conectable (PDB)
ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT ============================================================================
PROMPT INICIANDO CONFIGURACIÓN DE INFRAESTRUCTURA (TABLESPACES, USUARIOS Y ROLES)
PROMPT ============================================================================


-- ============================================================================
-- 1. CREACIÓN DE TABLESPACES (ALMACENAMIENTO FÍSICO)
-- ============================================================================
-- En caso de requerir reinstalación limpia desde cero, descomentar los DROP:
-- DROP TABLESPACE red_clinicas_db INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;
-- DROP TABLESPACE stg_clinicas_db INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;
-- DROP TABLESPACE dwh_clinicas_db INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;

PROMPT >>> 1. Creando Tablespaces independientes...

-- 1.1 Tablespace exclusivo para OLTP (Base de datos transaccional productiva)
CREATE TABLESPACE red_clinicas_db
    DATAFILE 'red_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 500M MAXSIZE UNLIMITED;

-- 1.2 Tablespace exclusivo para STAGING (Capa intermedia de ingesta y hashes)
CREATE TABLESPACE stg_clinicas_db
    DATAFILE 'stg_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 500M MAXSIZE UNLIMITED;

-- 1.3 Tablespace exclusivo para DATA WAREHOUSE (Almacén analítico dimensional)
CREATE TABLESPACE dwh_clinicas_db
    DATAFILE 'dwh_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 500M MAXSIZE UNLIMITED;


-- ============================================================================
-- 2. CREACIÓN DE USUARIOS / ESQUEMAS Y ASIGNACIÓN DE CUOTAS
-- ============================================================================
-- En caso de requerir recrear los usuarios, descomentar los DROP:
-- DROP USER red_clinica_user CASCADE;
-- DROP USER stg_clinica_user CASCADE;
-- DROP USER dwh_clinica_user CASCADE;

PROMPT >>> 2. Creando Usuarios y asignando cuotas de almacenamiento...

-- 2.1 Esquema OLTP
CREATE USER red_clinica_user IDENTIFIED BY "Password2026"
    DEFAULT TABLESPACE red_clinicas_db
    TEMPORARY TABLESPACE temp
    QUOTA UNLIMITED ON red_clinicas_db;

-- 2.2 Esquema STAGING
CREATE USER stg_clinica_user IDENTIFIED BY "StagingPass2026"
    DEFAULT TABLESPACE stg_clinicas_db
    TEMPORARY TABLESPACE temp
    QUOTA UNLIMITED ON stg_clinicas_db;

-- 2.3 Esquema DATA WAREHOUSE
CREATE USER dwh_clinica_user IDENTIFIED BY "DwhPass2026"
    DEFAULT TABLESPACE dwh_clinicas_db
    TEMPORARY TABLESPACE temp
    QUOTA UNLIMITED ON dwh_clinicas_db;


-- ============================================================================
-- 3. PRIVILEGIOS DE SISTEMA Y ROLES DE DESARROLLO
-- ============================================================================
PROMPT >>> 3. Otorgando privilegios de sistema y roles a los 3 usuarios...

-- 3.1 Privilegios base para red_clinica_user
GRANT CONNECT, RESOURCE TO red_clinica_user;
GRANT CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE SEQUENCE, CREATE SYNONYM, CREATE TRIGGER TO red_clinica_user;
GRANT UNLIMITED TABLESPACE TO red_clinica_user;

-- 3.2 Privilegios base para stg_clinica_user
GRANT CONNECT, RESOURCE TO stg_clinica_user;
GRANT CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE SEQUENCE, CREATE SYNONYM TO stg_clinica_user;
GRANT UNLIMITED TABLESPACE TO stg_clinica_user;

-- 3.3 Privilegios base para dwh_clinica_user
GRANT CONNECT, RESOURCE TO dwh_clinica_user;
GRANT CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE SEQUENCE, CREATE SYNONYM, CREATE MATERIALIZED VIEW TO dwh_clinica_user;
GRANT UNLIMITED TABLESPACE TO dwh_clinica_user;


-- ============================================================================
-- 4. PRIVILEGIOS DE INTEGRACIÓN CRUZADA ENTRE ESQUEMAS
-- ============================================================================
-- Permite que Staging extraiga de OLTP y que DWH lea de Staging e invoque los
-- procedimientos almacenados, sin importar si las tablas ya fueron creadas o no:
PROMPT >>> 4. Otorgando privilegios de integración para ETL/ELT entre esquemas...

GRANT SELECT ANY TABLE TO stg_clinica_user;
GRANT SELECT ANY TABLE TO dwh_clinica_user;
GRANT EXECUTE ANY PROCEDURE TO dwh_clinica_user;


-- ============================================================================
-- 5. ASIGNACIÓN CONDICIONAL DE PERMISOS DE OBJETO (AUTO-APLICABLE)
-- ============================================================================
-- Este bloque detecta automáticamente si las tablas ya existen en el momento
-- de ejecutar este script y otorga los permisos objeto por objeto sin arrojar
-- errores ORA-00942 si aún no han sido creadas.
PROMPT >>> 5. Verificando y aplicando permisos de objeto (si existen tablas creadas)...

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_cnt_oltp NUMBER := 0;
    v_cnt_stg  NUMBER := 0;
    v_cnt_proc NUMBER := 0;
BEGIN
    -- 5.1 Permisos explícitos: red_clinica_user -> stg_clinica_user
    FOR t IN (
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = 'RED_CLINICA_USER'
    ) LOOP
        EXECUTE IMMEDIATE 'GRANT SELECT ON red_clinica_user.' || t.TABLE_NAME || ' TO stg_clinica_user';
        v_cnt_oltp := v_cnt_oltp + 1;
    END LOOP;

    -- 5.2 Permisos explícitos: stg_clinica_user -> dwh_clinica_user (Tablas)
    FOR t IN (
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = 'STG_CLINICA_USER'
    ) LOOP
        EXECUTE IMMEDIATE 'GRANT SELECT ON stg_clinica_user.' || t.TABLE_NAME || ' TO dwh_clinica_user';
        v_cnt_stg := v_cnt_stg + 1;
    END LOOP;

    -- 5.3 Permisos de ejecución: stg_clinica_user -> dwh_clinica_user (Procedimientos)
    FOR p IN (
        SELECT OBJECT_NAME FROM ALL_OBJECTS 
        WHERE OWNER = 'STG_CLINICA_USER' AND OBJECT_TYPE = 'PROCEDURE'
    ) LOOP
        EXECUTE IMMEDIATE 'GRANT EXECUTE ON stg_clinica_user.' || p.OBJECT_NAME || ' TO dwh_clinica_user';
        v_cnt_proc := v_cnt_proc + 1;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('   * Permisos aplicados: ' || v_cnt_oltp || ' tablas OLTP, ' || 
                         v_cnt_stg || ' tablas STAGING, ' || v_cnt_proc || ' procedimientos.');
    IF v_cnt_oltp = 0 AND v_cnt_stg = 0 THEN
        DBMS_OUTPUT.PUT_LINE('   * Nota: Las tablas aún no han sido creadas. Los permisos de sistema (Paso 4)');
        DBMS_OUTPUT.PUT_LINE('     garantizan el acceso inicial. Los permisos explícitos se activarán al crear las tablas.');
    END IF;
END;
/


-- ============================================================================
-- 6. VERIFICACIÓN FINAL DE LA INSTALACIÓN
-- ============================================================================
PROMPT ============================================================================
PROMPT VERIFICACIÓN DE TABLESPACES CREADOS EN XEPDB1:
PROMPT ============================================================================

SELECT 
    TABLESPACE_NAME, 
    STATUS, 
    CONTENTS, 
    EXTENT_MANAGEMENT, 
    ALLOCATION_TYPE
FROM DBA_TABLESPACES
WHERE TABLESPACE_NAME IN ('RED_CLINICAS_DB', 'STG_CLINICAS_DB', 'DWH_CLINICAS_DB')
ORDER BY TABLESPACE_NAME;

PROMPT ============================================================================
PROMPT VERIFICACIÓN DE USUARIOS CREADOS:
PROMPT ============================================================================

SELECT 
    USERNAME, 
    DEFAULT_TABLESPACE, 
    TEMPORARY_TABLESPACE, 
    ACCOUNT_STATUS, 
    CREATED
FROM DBA_USERS
WHERE USERNAME IN ('RED_CLINICA_USER', 'STG_CLINICA_USER', 'DWH_CLINICA_USER')
ORDER BY USERNAME;

PROMPT ============================================================================
PROMPT INFRAESTRUCTURA PREPARADA EXITOSAMENTE.
PROMPT Siguiente paso: Conectarse como red_clinica_user y ejecutar OLTP/01_CREAR_TODAS_LAS_TABLAS_OLTP.sql
PROMPT ============================================================================


/* ============================================================================
   ANEXO EDUCATIVO: LISTADO MANUAL DE GRANTS EXPLÍCITOS (OPCIONAL)
   grants estáticos individuales tabla por tabla, estos deben correrse ÚNICAMENTE 
   después de haber creado las tablas:

   -------------------------------------------------------------------------
   A. Ejecutar DESPUÉS de crear las tablas de OLTP (Paso 1):
   -------------------------------------------------------------------------
   GRANT SELECT ON red_clinica_user.UBICACIONES              TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.CLINICAS                 TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.EMPRESAS                 TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.ASEGURADORAS             TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.PACIENTES                TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.ESPECIALIDADES           TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.MEDICOS                  TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.MEDICOS_ESPECIALIDADES   TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.ENFERMEDADES             TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.TIPOS_CONSULTA           TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.PROCEDIMIENTOS           TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.CONSULTAS                TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.DIAGNOSTICOS             TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.CONSULTAS_PROCEDIMIENTOS TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.FORMAS_PAGO              TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.COBROS_CONSULTA          TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.DISTRIBUCION_COBRO       TO stg_clinica_user;
   GRANT SELECT ON red_clinica_user.TRANSACCIONES_PAGO       TO stg_clinica_user;

   -------------------------------------------------------------------------
   B. Ejecutar DESPUÉS de crear las tablas de STAGING (Paso 2):
   -------------------------------------------------------------------------
   GRANT SELECT ON stg_clinica_user.STG_UBICACIONES               TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_CLINICAS                  TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_EMPRESAS                  TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_ASEGURADORAS              TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_PACIENTES                 TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_ESPECIALIDADES            TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_MEDICOS                   TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_MEDICOS_ESPECIALIDADES    TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_ENFERMEDADES              TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_TIPOS_CONSULTA            TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_PROCEDIMIENTOS            TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_CONSULTAS                 TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_DIAGNOSTICOS              TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_CONSULTAS_PROCEDIMIENTOS  TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_FORMAS_PAGO               TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_COBROS_CONSULTA           TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_DISTRIBUCION_COBRO        TO dwh_clinica_user;
   GRANT SELECT ON stg_clinica_user.STG_TRANSACCIONES_PAGO        TO dwh_clinica_user;
   ============================================================================ */
