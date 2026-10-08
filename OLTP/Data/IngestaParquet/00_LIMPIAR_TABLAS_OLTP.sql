/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
   MODO: LIMPIEZA DE DATOS PREVIOS (OLTP TRUNCATE SEGURO)
   OBJETIVO: 1. Deshabilitar temporalmente todas las FKs del esquema.
             2. Truncar las 18 tablas para evitar conflictos ORA-00001 (PK duplicada).
             3. Rehabilitar todas las restricciones de integridad FK.
   ESQUEMA: red_clinica_user | MOTOR: Oracle Database (XEPDB1)
   ============================================================================ */

ALTER SESSION SET CONTAINER = XEPDB1;

-- Conectarse como red_clinica_user o cambiar esquema:
-- ALTER SESSION SET CURRENT_SCHEMA = red_clinica_user;

SET SERVEROUTPUT ON;

DECLARE
    TYPE t_tablas_list IS TABLE OF VARCHAR2(35);
    v_tablas t_tablas_list := t_tablas_list(
        'TRANSACCIONES_PAGO',
        'DISTRIBUCION_COBRO',
        'COBROS_CONSULTA',
        'CONSULTAS_PROCEDIMIENTOS',
        'DIAGNOSTICOS',
        'CONSULTAS',
        'MEDICOS_ESPECIALIDADES',
        'PACIENTES',
        'MEDICOS',
        'CLINICAS',
        'FORMAS_PAGO',
        'PROCEDIMIENTOS',
        'TIPOS_CONSULTA',
        'ENFERMEDADES',
        'ESPECIALIDADES',
        'ASEGURADORAS',
        'EMPRESAS',
        'UBICACIONES'
    );
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('INICIO LIMPIEZA: TRUNCATE SEGURO DE TABLAS OLTP');
    DBMS_OUTPUT.PUT_LINE('================================================================');

    -- Paso 1: Deshabilitar todas las Claves Foráneas (FK)
    DBMS_OUTPUT.PUT_LINE('>>> 1. Deshabilitando Foreign Keys...');
    FOR c IN (SELECT table_name, constraint_name 
              FROM user_constraints 
              WHERE constraint_type = 'R' AND status = 'ENABLED') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || ' DISABLE CONSTRAINT ' || c.constraint_name;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  [ALERTA DESHABILITAR] ' || c.constraint_name || ': ' || SQLERRM);
        END;
    END LOOP;

    -- Paso 2: Truncar las tablas en orden inverso de dependencias
    DBMS_OUTPUT.PUT_LINE('>>> 2. Truncando las 18 tablas OLTP...');
    FOR i IN 1..v_tablas.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || v_tablas(i);
            DBMS_OUTPUT.PUT_LINE('  [OK] ' || RPAD(v_tablas(i), 26) || ' -> Truncada exitosamente');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  [ERROR] ' || v_tablas(i) || ': ' || SQLERRM);
        END;
    END LOOP;

    -- Paso 3: Rehabilitar todas las Claves Foráneas (FK)
    DBMS_OUTPUT.PUT_LINE('>>> 3. Rehabilitando Foreign Keys...');
    FOR c IN (SELECT table_name, constraint_name 
              FROM user_constraints 
              WHERE constraint_type = 'R') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || ' ENABLE CONSTRAINT ' || c.constraint_name;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  [ALERTA REHABILITAR] ' || c.constraint_name || ': ' || SQLERRM);
        END;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('LIMPIEZA COMPLETADA: Tablas vacias y listas para carga masiva.');
    DBMS_OUTPUT.PUT_LINE('================================================================');
END;
/
