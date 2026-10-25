/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED ASISTENCIAL DE CLÍNICAS
   SCRIPT MAESTRO: EJECUTAR_TODO_MASTER.sql (DESPLIEGUE 100% SQL)
   MOTOR: Oracle Database 19c / 21c / 23ai (PDB: XEPDB1)
   HOST / PUERTO: localhost:1521
   ============================================================================
   OBJETIVO:
     Ejecutar de forma continua y meramente en SQL todo el ciclo de vida del
     Data Warehouse (del Paso 00 al Paso 07):
       - Paso 00: Limpieza total y reset previo del entorno (idempotente).
       - Paso 01: Tablespaces físicos, esquemas de usuario y permisos cruzados.
       - Paso 02: 18 Tablas relacionales OLTP, índices y triggers de integridad.
       - Paso 03: 18 Tablas de aterrizaje Staging con columnas técnicas SHA-256.
       - Paso 04: Modelo dimensional en estrella DWH + Auditoría + Grants a Staging.
       - Paso 05: 19 Procedimientos almacenados de extracción de Staging.
       - Paso 06: Ejecución orquestada del ETL Full Load (SP_LOAD_DWH_MASTER).
       - Paso 07: Validación analítica de los 12 KPIs de negocio y auditoría.

   UBICACIÓN BASE DE LOS SCRIPTS:
     D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/

   ℹ️ NOTA SOBRE INGESTA DE DATOS Y CONCILIACION (PYTHON):
     Este archivo es MERAMENTE SQL y no ejecuta scripts externos.
     - Si la base de datos es nueva o requiere poblar los 8.34M de registros
       desde los archivos Parquet, ejecuta en terminal (después del Paso 02):
       > python OLTP/Data/IngestaParquet/ingestar_parquets_oltp.py
     - Si deseas ejecutar la auditoría técnica de conciliación financiera centavo
       a centavo, ejecuta en terminal (después del Paso 07):
       > python audit_pipeline.py

   INSTRUCCIONES DE EJECUCIÓN:
     1. Inicia sesión en tu cliente SQL como SYS AS SYSDBA o SYSTEM.
     2. Compatibilidad de Clientes:
        - Oracle SQL Developer: Abrir este archivo y presionar [F5] (Ejecutar como Script).
        - SQL*Plus / SQLcl:     sqlplus / as sysdba @"D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/EJECUTAR_TODO_MASTER.sql"
     
     *NOTA PARA CLIENTES COMO DBEAVER O DATA-GRIP:
      Si utilizas un cliente que no soporte cambio de sesión dinámico mediante 'CONN',
      utiliza la opción manual paso a paso ejecutando los scripts numerados del 00 al 07
      con el usuario indicado en el encabezado de cada archivo.
   ============================================================================ */

SET FEEDBACK ON;
SET ECHO OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 100;

PROMPT ============================================================================
PROMPT ============================================================================
PROMPT  INICIANDO DESPLIEGUE MAESTRO SQL: RED DE CLINICAS DATA WAREHOUSE
PROMPT ============================================================================
PROMPT ============================================================================

-- ----------------------------------------------------------------------------
-- PASO 00: LIMPIEZA TOTAL Y RESET PREVIO DEL ENTORNO
-- EJECUCION: Conectado como SYS AS SYSDBA o SYSTEM
-- ----------------------------------------------------------------------------
PROMPT
PROMPT >>> [1/8] EJECUTANDO PASO 00: LIMPIEZA TOTAL Y RESET IDEMPOTENTE...
ALTER SESSION SET CONTAINER = XEPDB1;
@"D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/00_LIMPIEZA_TOTAL.sql"

-- ----------------------------------------------------------------------------
-- PASO 01: INFRAESTRUCTURA, TABLESPACES, USUARIOS Y PRIVILEGIOS
-- EJECUCION: Conectado como SYS AS SYSDBA o SYSTEM
-- ----------------------------------------------------------------------------
PROMPT
PROMPT >>> [2/8] EJECUTANDO PASO 01: INFRAESTRUCTURA Y USUARIOS...
ALTER SESSION SET CONTAINER = XEPDB1;
@"D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/01_INFRAESTRUCTURA_Y_USUARIOS.sql"

-- ----------------------------------------------------------------------------
-- PASO 02: CREACION DE TABLAS TRANSACCIONALES (OLTP)
-- EJECUCION: Conectado como red_clinica_user (Password2026)
-- ----------------------------------------------------------------------------
PROMPT
PROMPT >>> [3/8] CONECTANDO COMO red_clinica_user Y CREANDO TABLAS OLTP...
CONN red_clinica_user/Password2026@//localhost:1521/XEPDB1
ALTER SESSION SET CONTAINER = XEPDB1;
@"D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/02_CREAR_TABLAS_OLTP.sql"

-- ----------------------------------------------------------------------------
-- PASO 03: CREACION DE TABLAS DE ATERRIZAJE (STAGING)
-- EJECUCION: Conectado como stg_clinica_user (StagingPass2026)
-- ----------------------------------------------------------------------------
PROMPT
PROMPT >>> [4/8] CONECTANDO COMO stg_clinica_user Y CREANDO TABLAS STAGING...
CONN stg_clinica_user/StagingPass2026@//localhost:1521/XEPDB1
ALTER SESSION SET CONTAINER = XEPDB1;
@"D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/03_CREAR_TABLAS_STAGING.sql"

-- ----------------------------------------------------------------------------
-- PASO 04: MODELO DIMENSIONAL Y STORED PROCEDURES DE AUDITORIA Y CARGA DWH
-- EJECUCION: Conectado como dwh_clinica_user (DwhPass2026)
-- ----------------------------------------------------------------------------
PROMPT
PROMPT >>> [5/8] CONECTANDO COMO dwh_clinica_user Y CREANDO MODELO DWH + AUDITORIA...
CONN dwh_clinica_user/DwhPass2026@//localhost:1521/XEPDB1
ALTER SESSION SET CONTAINER = XEPDB1;
@"D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/04_CREAR_TABLAS_Y_PROCEDIMIENTOS_DWH.sql"

-- ----------------------------------------------------------------------------
-- PASO 05: PROCEDIMIENTOS DE EXTRACCION DE LA CAPA STAGING
-- EJECUCION: Conectado como stg_clinica_user (StagingPass2026)
-- ----------------------------------------------------------------------------
PROMPT
PROMPT >>> [6/8] CONECTANDO COMO stg_clinica_user Y COMPILANDO PROCEDIMIENTOS STAGING...
CONN stg_clinica_user/StagingPass2026@//localhost:1521/XEPDB1
ALTER SESSION SET CONTAINER = XEPDB1;
@"D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/05_CREAR_PROCEDIMIENTOS_STAGING.sql"

-- ----------------------------------------------------------------------------
-- PASO 06: EJECUCION DEL ETL MASTER (FULL LOAD)
-- EJECUCION: Conectado como dwh_clinica_user (DwhPass2026)
-- ----------------------------------------------------------------------------
PROMPT
PROMPT >>> [7/8] CONECTANDO COMO dwh_clinica_user Y EJECUTANDO SP_LOAD_DWH_MASTER...
CONN dwh_clinica_user/DwhPass2026@//localhost:1521/XEPDB1
ALTER SESSION SET CONTAINER = XEPDB1;
@"D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/06_EJECUTAR_ETL_DWH.sql"

-- ----------------------------------------------------------------------------
-- PASO 07: VALIDACION DE KPIS DE NEGOCIO Y CONCILIACION
-- EJECUCION: Conectado como dwh_clinica_user (DwhPass2026)
-- ----------------------------------------------------------------------------
PROMPT
PROMPT >>> [8/8] VALIDANDO LOS 12 KPIS DE NEGOCIO EN EL DATA WAREHOUSE...
@"D:/Diego/Cursos/KODIGO SQL IA/ProyectoFinal/PASOS_CREACION/07_VALIDAR_KPIS_Y_AUDITORIA.sql"

PROMPT
PROMPT ============================================================================
PROMPT ============================================================================
PROMPT  DESPLIEGUE SQL COMPLETO FINALIZADO EXITOSAMENTE AL 100%.
PROMPT ============================================================================
PROMPT ============================================================================



/*
    SI YA TIENSES LA BASE DE DATOS CREADA Y AUN NO TIENES DATOS EN EL OLTP.
    PRIMERO EJECUTA EL SCRIPT PYTHON PARA CARGAR DATOS DE PRUEBA EN EL OLTP.

    1. COMANDO PARA INSTALAR LAS DEPENDENCIAS DE PYTHON (SI NO LO HAS HECHO AUN):
    pip install -r "OLTP/Data/IngestaParquet/requirements.txt"

    2. Desde la carpeta raíz del proyecto o desde /OLTP/Data/IngestaParquet:
        python "OLTP/Data/IngestaParquet/ingestar_parquets_oltp.py" `
        --host localhost `
        --port 1521 `
        --service_name XEPDB1 `
        --user red_clinica_user `
        --password TU_PASSWORD_AQUI `
        --batch_size 25000
*/


/* 
    UNA VEZ CARGADOS LOS DATOS EN EL OLTP, EJECUTA EL SIGUIENTE SP PARA CARGAR LOS DATOS EN EL DWH:
        Conectase como dwh_clinica_user (DwhPass2026) y ejecuta:
*/
    -- EXECUTE SP_LOAD_DWH_MASTER('FULL');

/*
    CON ESTO YA QUEDARIA POBLADO TODO EL DWH CON LOS DATOS DE PRUEBA DEL OLTP.
    SI QUIERES HACER UNA CARGA INCREMENTAL, COLOCA INCREMENTAL COMO PRIMER PARAMETRO Y LUEGO EL NUMERO DE DIAS QUE QUIERES QUE EL SP BUSQUE REGISTROS NUEVOS EN EL OLTP. 
    EJEMPLO:   
*/
    -- EXECUTE SP_LOAD_DWH_MASTER('INCREMENTAL', 7);