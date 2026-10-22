/* ============================================================================
   CONFIGURACIÓN INICIAL DE TABLESPACES PARA EL PROYECTO DE CLÍNICAS
     - Ejecutar los scripts bajo el usuario SYS o SYSTEM y bajo el contenedor XEPDB1
     - Se crean tres tablespaces y tres usuarios asociados a cada uno
   ============================================================================ */

ALTER SESSION SET CONTAINER = XEPDB1;
/*
    MODIFICAR LA SESION ACTUAL PARA QUE APUNTE AL CONTENEDOR QUE USAS EN TU MAQUINA, YA QUE LOS TABLESPACES SE CREAN DENTRO DE UN CONTENEDOR ESPECÍFICO
*/

-- ============================================================================
-- 1. Tablespace exclusivo para OLTP (Base Productiva)
--DROP TABLESPACE red_clinicas_db INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;

CREATE TABLESPACE red_clinicas_db
    DATAFILE 'red_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED
    /*  
        Modificar la ruta del archivo de datos según la configuración de tu máquina, por ejemplo:
        DATAFILE 'C:\oracle\oradata\XEPDB1\red_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED   
    */
    
CREATE USER red_clinica_user IDENTIFIED BY "Password2026"
    DEFAULT TABLESPACE red_clinicas_db
    QUOTA UNLIMITED ON red_clinicas_db;

GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE SYNONYM TO red_clinica_user;

-- ============================================================================
-- 2. Tablespace exclusivo para Staging (volátil / cargas temporales)
--DROP TABLESPACE stg_clinicas_tbs INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;

CREATE TABLESPACE stg_clinicas_db
    DATAFILE 'stg_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED;
     /*  
        Modificar la ruta del archivo de datos según la configuración de tu máquina, por ejemplo:
        DATAFILE 'C:\oracle\oradata\XEPDB1\red_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED   
    */
    
CREATE USER stg_clinica_user IDENTIFIED BY "StagingPass2026"
    DEFAULT TABLESPACE stg_clinicas_db
    QUOTA UNLIMITED ON stg_clinicas_db;
    
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE PROCEDURE, CREATE TABLE TO stg_clinica_user;

-- ============================================================================
-- PERMISOS DE LECTURA: OLTP (red_clinica_user) -> STAGING (stg_clinica_user)
--    Permite que los procesos de Staging extraigan la información transaccional
--    REQUIERE PRIMERO CREAR TODAS LAS TABLAS DE OLTP ANTES DE EJECUTAR ESTOS GRANTS
-- ============================================================================
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

-- ============================================================================
-- 3. Tablespace exclusivo para el Data Warehouse (histórico dimensional)
--DROP TABLESPACE dwh_clinicas_db INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;

CREATE TABLESPACE dwh_clinicas_db
    DATAFILE 'dwh_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED;
     /*  
        Modificar la ruta del archivo de datos según la configuración de tu máquina, por ejemplo:
        DATAFILE 'C:\oracle\oradata\XEPDB1\red_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED   
    */
    
CREATE USER dwh_clinica_user IDENTIFIED BY "DwhPass2026"
    DEFAULT TABLESPACE dwh_clinicas_db
    QUOTA UNLIMITED ON dwh_clinicas_db;
    
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE PROCEDURE, CREATE TABLE, CREATE MATERIALIZED VIEW TO dwh_clinica_user;


-- ============================================================================
-- PERMISOS DE LECTURA: STAGING (red_clinica_user) -> DWH (stg_clinica_user)
--    Permite que los procesos de DWH extraigan la información de Staging
--    REQUIERE PRIMERO CREAR TODAS LAS TABLAS DE STAGING ANTES DE EJECUTAR ESTOS GRANTS
-- ============================================================================

GRANT SELECT ON stg_clinica_user.STG_ASEGURADORAS                            TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_CLINICAS                                TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_COBROS_CONSULTA                         TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_CONSULTAS_PROCEDIMIENTOS                TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_CONSULTAS                               TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_DIAGNOSTICOS                            TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_DISTRIBUCION_COBRO                      TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_EMPRESAS                                TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_ENFERMEDADES                            TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_ESPECIALIDADES                          TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_FORMAS_PAGO                             TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_MEDICOS_ESPECIALIDADES                  TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_MEDICOS                                 TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_PACIENTES                               TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_PROCEDIMIENTOS                          TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_TIPOS_CONSULTA                          TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_TRANSACCIONES_PAGO                      TO dwh_clinica_user;
GRANT SELECT ON stg_clinica_user.STG_UBICACIONES                             TO dwh_clinica_user;

-- ============================================================================
-- 4. Verificar los Tablespace creados
SELECT 
    TABLESPACE_NAME 
FROM DBA_TABLESPACES dba
WHERE dba.tablespace_name IN('RED_CLINICAS_DB','STG_CLINICAS_DB','DWH_CLINICAS_DB');