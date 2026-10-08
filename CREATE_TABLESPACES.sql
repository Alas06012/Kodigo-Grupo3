/* ============================================================================
   CONFIGURACIÓN DE TABLESPACES PARA EL PROYECTO DE CLÍNICAS
     - Ejecutar los scripts bajo el usuario SYS o SYSTEM y bajo el contenedor XEPDB1
     - Se crean tres tablespaces y tres usuarios asociados a cada uno
   ============================================================================ */

ALTER SESSION SET CONTAINER = XEPDB1;

-- ============================================================================
-- 1. Tablespace exclusivo para OLTP (Base Productiva)
--DROP TABLESPACE red_clinicas_db INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;

CREATE TABLESPACE red_clinicas_db
    DATAFILE 'red_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED
    
CREATE USER red_clinica_user IDENTIFIED BY "Password2026"
    DEFAULT TABLESPACE red_clinicas_db
    QUOTA UNLIMITED ON red_clinicas_db;

GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE SYNONYM TO red_clinica_user;

-- ============================================================================
-- 2. Tablespace exclusivo para Staging (volátil / cargas temporales)
--DROP TABLESPACE stg_clinicas_tbs INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;

CREATE TABLESPACE stg_clinicas_db
    DATAFILE 'stg_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED;
    
CREATE USER stg_clinica_user IDENTIFIED BY "StagingPass2026"
    DEFAULT TABLESPACE stg_clinicas_db
    QUOTA UNLIMITED ON stg_clinicas_db;
    
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE SYNONYM TO stg_clinica_user;


-- ============================================================================
-- 3. Tablespace exclusivo para el Data Warehouse (histórico dimensional)
--DROP TABLESPACE dwh_clinicas_db INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;

CREATE TABLESPACE dwh_clinicas_db
    DATAFILE 'dwh_clinicas_db.dbf' SIZE 200M AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED;
    
CREATE USER dwh_clinica_user IDENTIFIED BY "DwhPass2026"
    DEFAULT TABLESPACE dwh_clinicas_db
    QUOTA UNLIMITED ON dwh_clinicas_db;
    
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE SYNONYM TO dwh_clinica_user;


-- ============================================================================
-- 4. Verificar los Tablespace creados
SELECT 
    TABLESPACE_NAME 
FROM DBA_TABLESPACES dba
WHERE dba.tablespace_name IN('RED_CLINICAS_DB','STG_CLINICAS_DB','DWH_CLINICAS_DB');