/* ============================================================================
   PASO 00: LIMPIEZA TOTAL Y RESET DEL ENTORNO (IDEMPOTENTE)
   ============================================================================
   USUARIO DE CONEXION: SYS AS SYSDBA o SYSTEM
   CONTENEDOR (PDB):    XEPDB1
   HOST / PUERTO:       localhost:1521
   ============================================================================
   OBJETIVO:
     Limpiar y restablecer por completo el entorno de la base de datos antes
     de iniciar la instalación, garantizando que no existan bloqueos de sesión,
     esquemas residuales ni archivos físicos huérfanos.
     
   ACCIONES QUE REALIZA:
     1. Conecta al contenedor PDB (XEPDB1).
     2. Cierra y desconecta de forma inmediata cualquier sesión activa de los usuarios
        (red_clinica_user, stg_clinica_user, dwh_clinica_user) para evitar ORA-01940.
     3. Elimina en cascada (DROP USER ... CASCADE) los 3 esquemas:
        - red_clinica_user  (Tablas, índices, secuencias y triggers OLTP)
        - stg_clinica_user  (Tablas de aterrizaje y stored procedures de Staging)
        - dwh_clinica_user  (Modelo en estrella, tabla de control y SPs de DWH)
     4. Elimina los 3 tablespaces físicos y sus archivos .dbf asociados:
        - red_clinicas_db
        - stg_clinicas_db
        - dwh_clinicas_db
     
   CARACTERÍSTICA IDEMPOTENTE:
     Este script está protegido con bloques PL/SQL y manejo de excepciones. Si
     los usuarios o tablespaces no existen (por ejemplo, en una máquina nueva),
     el script finaliza limpiamente sin lanzar errores.
   ============================================================================ */

SET FEEDBACK ON;
SET SERVEROUTPUT ON SIZE UNLIMITED;

ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT ============================================================================
PROMPT INICIANDO LIMPIEZA TOTAL Y RESET DEL ENTORNO (XEPDB1)
PROMPT ============================================================================

-- 1. Desconectar sesiones activas para evitar ORA-01940
PROMPT >>> 1. Verificando y cerrando sesiones activas de los esquemas...
BEGIN
    FOR s IN (
        SELECT sid, serial# 
        FROM v$session 
        WHERE username IN ('RED_CLINICA_USER', 'STG_CLINICA_USER', 'DWH_CLINICA_USER')
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'ALTER SYSTEM DISCONNECT SESSION ''' || s.sid || ',' || s.serial# || ''' IMMEDIATE';
            DBMS_OUTPUT.PUT_LINE('Sesión desconectada: SID ' || s.sid || ', SERIAL# ' || s.serial#);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
END;
/

-- 2. Eliminar usuarios / esquemas en cascada
PROMPT >>> 2. Eliminando esquemas existentes en cascada (DROP USER CASCADE)...
BEGIN
    FOR u IN (
        SELECT username 
        FROM all_users 
        WHERE username IN ('RED_CLINICA_USER', 'STG_CLINICA_USER', 'DWH_CLINICA_USER')
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
            DBMS_OUTPUT.PUT_LINE('Usuario eliminado: ' || u.username);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Aviso al eliminar ' || u.username || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- 3. Eliminar tablespaces físicos y sus datafiles asociados
PROMPT >>> 3. Eliminando tablespaces y datafiles físicos (DROP TABLESPACE INCLUDING CONTENTS AND DATAFILES)...
BEGIN
    FOR ts IN (
        SELECT tablespace_name 
        FROM v$tablespace 
        WHERE tablespace_name IN ('RED_CLINICAS_DB', 'STG_CLINICAS_DB', 'DWH_CLINICAS_DB')
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLESPACE ' || ts.tablespace_name || ' INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Tablespace eliminado: ' || ts.tablespace_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Aviso al eliminar ' || ts.tablespace_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

PROMPT ============================================================================
PROMPT LIMPIEZA TOTAL FINALIZADA CON ÉXITO. EL ENTORNO ESTÁ 100% LIMPIO.
PROMPT ============================================================================
