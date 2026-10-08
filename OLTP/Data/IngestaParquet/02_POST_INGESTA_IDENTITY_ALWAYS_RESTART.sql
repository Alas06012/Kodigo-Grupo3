/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
   MODO: POST-INGESTA DE DATOS DE PRUEBA (OLTP)
   OBJETIVO: 1. Consultar el MAX(ID) real insertado en cada tabla.
             2. Reiniciar la secuencia interna en (MAX + 1).
             3. Regresar la columna IDENTITY a 'GENERATED ALWAYS AS IDENTITY'.
   ESQUEMA: red_clinica_user | MOTOR: Oracle Database (XEPDB1)
   ============================================================================ */

ALTER SESSION SET CONTAINER = XEPDB1;

-- Conectarse como red_clinica_user o cambiar esquema:
-- ALTER SESSION SET CURRENT_SCHEMA = red_clinica_user;

SET SERVEROUTPUT ON;

DECLARE
    TYPE t_identity_rec IS RECORD (
        tabla_nombre  VARCHAR2(30),
        col_identity  VARCHAR2(30)
    );
    TYPE t_identity_list IS TABLE OF t_identity_rec;

    v_tablas t_identity_list := t_identity_list(
        t_identity_rec('UBICACIONES',              'ID_UBICACION'),
        t_identity_rec('EMPRESAS',                 'ID_EMPRESA'),
        t_identity_rec('ASEGURADORAS',             'ID_ASEGURADORA'),
        t_identity_rec('ESPECIALIDADES',           'ID_ESPECIALIDAD'),
        t_identity_rec('ENFERMEDADES',             'ID_ENFERMEDAD'),
        t_identity_rec('TIPOS_CONSULTA',           'ID_TIPO_CONSULTA'),
        t_identity_rec('PROCEDIMIENTOS',           'ID_PROCEDIMIENTO'),
        t_identity_rec('FORMAS_PAGO',              'ID_FORMA_PAGO'),
        t_identity_rec('CLINICAS',                 'ID_CLINICA'),
        t_identity_rec('MEDICOS',                  'ID_MEDICO'),
        t_identity_rec('PACIENTES',                'ID_PACIENTE'),
        t_identity_rec('MEDICOS_ESPECIALIDADES',   'ID_MEDICO_ESPECIALIDAD'),
        t_identity_rec('CONSULTAS',                'ID_CONSULTA'),
        t_identity_rec('DIAGNOSTICOS',             'ID_DIAGNOSTICO'),
        t_identity_rec('CONSULTAS_PROCEDIMIENTOS', 'ID_CONSULTA_PROCEDIMIENTO'),
        t_identity_rec('COBROS_CONSULTA',          'ID_COBRO'),
        t_identity_rec('DISTRIBUCION_COBRO',       'ID_DISTRIBUCION'),
        t_identity_rec('TRANSACCIONES_PAGO',       'ID_TRANSACCION')
    );

    v_max_val NUMBER := 0;
    v_sql     VARCHAR2(500);
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('INICIO POST-INGESTA: RESTABLECIENDO IDENTITY A ALWAYS (RESTART)');
    DBMS_OUTPUT.PUT_LINE('================================================================');

    FOR i IN 1..v_tablas.COUNT LOOP
        BEGIN
            -- 1. Obtener el maximo valor insertado
            v_sql := 'SELECT NVL(MAX(' || v_tablas(i).col_identity || '), 0) + 1 FROM ' || v_tablas(i).tabla_nombre;
            EXECUTE IMMEDIATE v_sql INTO v_max_val;

            -- Si no hay registros, reiniciar en 1
            IF v_max_val < 1 THEN
                v_max_val := 1;
            END IF;

            -- 2. Reiniciar la secuencia al límite máximo actual y restaurar a GENERATED ALWAYS
            EXECUTE IMMEDIATE 'ALTER TABLE ' || v_tablas(i).tabla_nombre || 
                              ' MODIFY ' || v_tablas(i).col_identity || ' GENERATED ALWAYS AS IDENTITY (START WITH LIMIT VALUE)';

            DBMS_OUTPUT.PUT_LINE('[OK] ' || RPAD(v_tablas(i).tabla_nombre, 26) || 
                                 ' -> ' || RPAD(v_tablas(i).col_identity, 24) || 
                                 ' | Reiniciado en: ' || v_max_val || ' (ALWAYS)');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('[ALERTA] ' || v_tablas(i).tabla_nombre || ': ' || SQLERRM);
        END;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('POST-INGESTA FINALIZADA: Secuencias sincronizadas y protegidas.');
    DBMS_OUTPUT.PUT_LINE('================================================================');
END;
/
