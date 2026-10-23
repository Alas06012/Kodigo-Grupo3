-- ============================================================================
-- PROYECTO DATA WAREHOUSE - RED ASISTENCIAL DE CLÍNICAS
-- SCRIPT DE ROLLBACK Y LIMPIEZA DE DATOS DE PRUEBA
-- ESQUEMAS: red_clinica_user (OLTP) y dwh_clinica_user (DWH)
-- MOTOR: Oracle Database 19c/21c/23ai
-- ============================================================================
-- OBJETIVO:
-- Revertir y purgar de manera segura todos los datos generados durante las pruebas
-- de simulación incremental, restaurando el estado original de la base de datos
-- transaccional (OLTP) y del Data Warehouse (DWH).
--
-- ALCANCE DE LA LIMPIEZA:
-- 1. OLTP:
--    - Elimina transacciones de pago, distribuciones, cobros, procedimientos, 
--      diagnósticos y consultas identificadas con '[PRUEBA]'.
--    - Elimina nuevos pacientes, médicos, clínicas y catálogos de prueba.
--    - Restaura los valores originales de las entidades mutadas por SCD 1 y SCD 2.
-- 2. DWH:
--    - Elimina hechos en FACT_CONSULTAS, FACT_CONSULTA_DIAGNOSTICOS y FACT_COBROS_DISTRIBUCION.
--    - Revierte la historización SCD Tipo 2 en DIM_PACIENTE, DIM_MEDICO y DIM_CLINICA
--      (elimina la versión nueva y reactiva la versión anterior con CURRENTFLAG = 1).
--    - Elimina registros de prueba en dimensiones maestras y revierte SCD 1.
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- ============================================================================
-- SECCIÓN 1: LIMPIEZA Y RESTAURACIÓN EN ESQUEMA OLTP (red_clinica_user)
-- (Ejecutar conectado como red_clinica_user)
-- ============================================================================
PROMPT ============================================================================
PROMPT INICIANDO LIMPIEZA EN BASE TRANSACCIONAL OLTP...
PROMPT ============================================================================

DECLARE
    v_filas_borradas NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- 1. Eliminando Transacciones y Facturación de Prueba ---');
    
    -- 1. Transacciones de pago de prueba
    DELETE FROM TRANSACCIONES_PAGO 
    WHERE OBSERVACIONES LIKE '%[PRUEBA]%'
       OR NUMERO_REFERENCIA IN ('TRF-ASEG-88992', 'POS-VISA-112233', 'QR-WALLET-778899', 'REC-EFECT-5544', 'REC-EFECT-AYER');
    DBMS_OUTPUT.PUT_LINE('   Transacciones de pago eliminadas: ' || SQL%ROWCOUNT);

    -- 2. Distribuciones de cobro de consultas de prueba
    DELETE FROM DISTRIBUCION_COBRO 
    WHERE ID_COBRO IN (
        SELECT ID_COBRO FROM COBROS_CONSULTA WHERE ID_CONSULTA IN (
            SELECT ID_CONSULTA FROM CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
        )
    );
    DBMS_OUTPUT.PUT_LINE('   Distribuciones de cobro eliminadas: ' || SQL%ROWCOUNT);

    -- 3. Cobros de consultas de prueba
    DELETE FROM COBROS_CONSULTA 
    WHERE ID_CONSULTA IN (
        SELECT ID_CONSULTA FROM CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    );
    DBMS_OUTPUT.PUT_LINE('   Cobros de consulta eliminados: ' || SQL%ROWCOUNT);

    -- 4. Procedimientos clínicos de consultas de prueba
    DELETE FROM CONSULTAS_PROCEDIMIENTOS 
    WHERE ID_CONSULTA IN (
        SELECT ID_CONSULTA FROM CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    );
    DBMS_OUTPUT.PUT_LINE('   Procedimientos clínicos eliminados: ' || SQL%ROWCOUNT);

    -- 5. Diagnósticos de consultas de prueba
    DELETE FROM DIAGNOSTICOS 
    WHERE ID_CONSULTA IN (
        SELECT ID_CONSULTA FROM CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    );
    DBMS_OUTPUT.PUT_LINE('   Diagnósticos eliminados: ' || SQL%ROWCOUNT);

    -- 6. Consultas de prueba
    DELETE FROM CONSULTAS 
    WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%';
    DBMS_OUTPUT.PUT_LINE('   Consultas médicas eliminadas: ' || SQL%ROWCOUNT);

    DBMS_OUTPUT.PUT_LINE('--- 2. Eliminando Nuevas Personas y Especialidades ---');

    -- 7. Especialidades de médico de prueba
    DELETE FROM MEDICOS_ESPECIALIDADES 
    WHERE ID_MEDICO IN (
        SELECT ID_MEDICO FROM MEDICOS WHERE NUM_COLEGIADO = 'COL-99881'
    );

    -- 8. Médico de prueba
    DELETE FROM MEDICOS 
    WHERE NUM_COLEGIADO = 'COL-99881' OR NOMBRES LIKE '%[PRUEBA]%';
    DBMS_OUTPUT.PUT_LINE('   Médicos de prueba eliminados: ' || SQL%ROWCOUNT);

    -- 9. Pacientes de prueba
    DELETE FROM PACIENTES 
    WHERE NUMERO_POLIZA = 'POL-INT-994411' 
       OR NOMBRES LIKE '%[PRUEBA]%' 
       OR APELLIDOS LIKE '%[PRUEBA]%';
    DBMS_OUTPUT.PUT_LINE('   Pacientes de prueba eliminados: ' || SQL%ROWCOUNT);

    DBMS_OUTPUT.PUT_LINE('--- 3. Restaurando Registros Originales de Entidades Mutadas (SCD1 / SCD2) ---');

    -- Reversión SCD 1 en Especialidades: ID 1
    UPDATE ESPECIALIDADES
    SET DESCRIPCION = 'Atención médica primaria integral, diagnóstico y tratamiento preventivo ambulatorio'
    WHERE ID_ESPECIALIDAD = 1;
    DBMS_OUTPUT.PUT_LINE('   Especialidad ID=1 restaurada (SCD1)');

    -- Reversión SCD 2 en Paciente 10: Restaurar valores originales
    UPDATE PACIENTES
    SET DIRECCION = 'Residencial Metrópolis Poniente, Pasaje 4 #19',
        ID_ASEGURADORA = 4,
        NUMERO_POLIZA = 'POL-PAC-33410'
    WHERE ID_PACIENTE = 10;
    DBMS_OUTPUT.PUT_LINE('   Paciente ID=10 restaurado a valores originales');

    -- Reversión SCD 2 en Médico 5: Restaurar clínica base original (ID 3)
    UPDATE MEDICOS
    SET ID_CLINICA_BASE = 3
    WHERE ID_MEDICO = 5;
    DBMS_OUTPUT.PUT_LINE('   Médico ID=5 restaurado a Clínica Base ID=3');

    -- Reversión SCD 2 en Clínica 2: Restaurar dirección y teléfono original
    UPDATE CLINICAS
    SET DIRECCION = 'Bulevar Orden de Malta, Edificio Mediplaza Local 102',
        TELEFONO = '2289-4500'
    WHERE ID_CLINICA = 2;
    DBMS_OUTPUT.PUT_LINE('   Clínica ID=2 restaurada a dirección y teléfono original');

    DBMS_OUTPUT.PUT_LINE('--- 4. Eliminando Nuevos Catálogos Maestros ---');

    -- 10. Clínica de prueba
    DELETE FROM CLINICAS WHERE NOMBRE_CLINICA = 'Clínica Médica Cayalá Élite';
    DBMS_OUTPUT.PUT_LINE('   Clínica nueva eliminada: ' || SQL%ROWCOUNT);

    -- 11. Forma de pago de prueba
    DELETE FROM FORMAS_PAGO WHERE NOMBRE_FORMA_PAGO = 'Billetera Digital / QR Interbancario';
    DBMS_OUTPUT.PUT_LINE('   Forma de pago eliminada: ' || SQL%ROWCOUNT);

    -- 12. Procedimiento de prueba
    DELETE FROM PROCEDIMIENTOS WHERE CODIGO_PROCEDIMIENTO = 'PR-ANGIO-01';
    DBMS_OUTPUT.PUT_LINE('   Procedimiento eliminado: ' || SQL%ROWCOUNT);

    -- 13. Tipo de consulta de prueba
    DELETE FROM TIPOS_CONSULTA WHERE NOMBRE_TIPO = 'Teleconsulta Especializada Digital HD';
    DBMS_OUTPUT.PUT_LINE('   Tipo de consulta eliminado: ' || SQL%ROWCOUNT);

    -- 14. Enfermedad de prueba
    DELETE FROM ENFERMEDADES WHERE CODIGO_CIE10 = 'U07.1';
    DBMS_OUTPUT.PUT_LINE('   Enfermedad CIE-10 eliminada: ' || SQL%ROWCOUNT);

    -- 15. Especialidad de prueba
    DELETE FROM ESPECIALIDADES WHERE NOMBRE_ESPECIALIDAD = 'Inmunología y Alergología Clínica Avanzada';
    DBMS_OUTPUT.PUT_LINE('   Especialidad nueva eliminada: ' || SQL%ROWCOUNT);

    -- 16. Aseguradora de prueba
    DELETE FROM ASEGURADORAS WHERE NIT = '88776655-4';
    DBMS_OUTPUT.PUT_LINE('   Aseguradora eliminada: ' || SQL%ROWCOUNT);

    -- 17. Empresa de prueba
    DELETE FROM EMPRESAS WHERE NIT = '99887766-5';
    DBMS_OUTPUT.PUT_LINE('   Empresa eliminada: ' || SQL%ROWCOUNT);

    -- 18. Ubicación de prueba
    DELETE FROM UBICACIONES WHERE PAIS = 'Guatemala' AND DISTRITO = 'Zona 16 - Paseo Cayalá';
    DBMS_OUTPUT.PUT_LINE('   Ubicación eliminada: ' || SQL%ROWCOUNT);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('>>> ROLLBACK EN OLTP COMPLETADO CON ÉXITO <<<');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR EN ROLLBACK OLTP: ' || SQLERRM);
        RAISE;
END;
/

-- ============================================================================
-- SECCIÓN 2: LIMPIEZA Y RESTAURACIÓN EN ESQUEMA DWH (dwh_clinica_user)
-- (Ejecutar conectado como dwh_clinica_user)
-- ============================================================================
PROMPT 
PROMPT ============================================================================
PROMPT INICIANDO LIMPIEZA EN DATA WAREHOUSE (DWH)...
PROMPT ============================================================================

DECLARE
    v_cont NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- 1. Eliminando Hechos de Pruebas ---');

    -- 1. Hechos de cobros y distribución
    DELETE FROM FACT_COBROS_DISTRIBUCION
    WHERE BK_ID_CONSULTA IN (
        SELECT BK_ID_CONSULTA FROM FACT_CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    );
    DBMS_OUTPUT.PUT_LINE('   FACT_COBROS_DISTRIBUCION eliminados: ' || SQL%ROWCOUNT);

    -- 2. Hechos de consulta diagnósticos
    DELETE FROM FACT_CONSULTA_DIAGNOSTICOS
    WHERE BK_ID_CONSULTA IN (
        SELECT BK_ID_CONSULTA FROM FACT_CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    );
    DBMS_OUTPUT.PUT_LINE('   FACT_CONSULTA_DIAGNOSTICOS eliminados: ' || SQL%ROWCOUNT);

    -- 3. Hechos de consultas médicas
    DELETE FROM FACT_CONSULTAS
    WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%';
    DBMS_OUTPUT.PUT_LINE('   FACT_CONSULTAS eliminados: ' || SQL%ROWCOUNT);

    DBMS_OUTPUT.PUT_LINE('--- 2. Revertiendo SCD Tipo 2 en Dimensiones ---');

    -- A. Revertir SCD 2 en DIM_PACIENTE (BK_ID_PACIENTE = 10)
    -- Eliminar la versión nueva (la que tiene SK mayor) si existen múltiples versiones
    SELECT COUNT(*) INTO v_cont FROM DIM_PACIENTE WHERE BK_ID_PACIENTE = 10;
    IF v_cont > 1 THEN
        DELETE FROM DIM_PACIENTE 
        WHERE BK_ID_PACIENTE = 10 
          AND CURRENTFLAG = 1 
          AND SK_PACIENTE > (SELECT MIN(SK_PACIENTE) FROM DIM_PACIENTE WHERE BK_ID_PACIENTE = 10);
        
        -- Reactivar la versión original
        UPDATE DIM_PACIENTE 
        SET CURRENTFLAG = 1, FECHAFIN = DATE '9999-12-31'
        WHERE BK_ID_PACIENTE = 10;
        DBMS_OUTPUT.PUT_LINE('   DIM_PACIENTE (BK=10) restaurado a versión única vigente');
    END IF;

    -- Eliminar nuevos pacientes creados en prueba
    DELETE FROM DIM_PACIENTE 
    WHERE NUMERO_POLIZA = 'POL-INT-994411' 
       OR NOMBRE_COMPLETO LIKE '%[PRUEBA]%';
    DBMS_OUTPUT.PUT_LINE('   DIM_PACIENTE nuevos eliminados: ' || SQL%ROWCOUNT);

    -- B. Revertir SCD 2 en DIM_MEDICO (BK_ID_MEDICO = 5)
    SELECT COUNT(*) INTO v_cont FROM DIM_MEDICO WHERE BK_ID_MEDICO = 5;
    IF v_cont > 1 THEN
        DELETE FROM DIM_MEDICO 
        WHERE BK_ID_MEDICO = 5 
          AND CURRENTFLAG = 1 
          AND SK_MEDICO > (SELECT MIN(SK_MEDICO) FROM DIM_MEDICO WHERE BK_ID_MEDICO = 5);

        UPDATE DIM_MEDICO 
        SET CURRENTFLAG = 1, FECHAFIN = DATE '9999-12-31'
        WHERE BK_ID_MEDICO = 5;
        DBMS_OUTPUT.PUT_LINE('   DIM_MEDICO (BK=5) restaurado a versión única vigente');
    END IF;

    -- Eliminar nuevo médico
    DELETE FROM DIM_MEDICO 
    WHERE NUM_COLEGIADO = 'COL-99881' OR NOMBRE_COMPLETO LIKE '%[PRUEBA]%';
    DBMS_OUTPUT.PUT_LINE('   DIM_MEDICO nuevos eliminados: ' || SQL%ROWCOUNT);

    -- C. Revertir SCD 2 en DIM_CLINICA (BK_ID_CLINICA = 2)
    SELECT COUNT(*) INTO v_cont FROM DIM_CLINICA WHERE BK_ID_CLINICA = 2;
    IF v_cont > 1 THEN
        DELETE FROM DIM_CLINICA 
        WHERE BK_ID_CLINICA = 2 
          AND CURRENTFLAG = 1 
          AND SK_CLINICA > (SELECT MIN(SK_CLINICA) FROM DIM_CLINICA WHERE BK_ID_CLINICA = 2);

        UPDATE DIM_CLINICA 
        SET CURRENTFLAG = 1, FECHAFIN = DATE '9999-12-31'
        WHERE BK_ID_CLINICA = 2;
        DBMS_OUTPUT.PUT_LINE('   DIM_CLINICA (BK=2) restaurado a versión única vigente');
    END IF;

    -- Eliminar nueva clínica
    DELETE FROM DIM_CLINICA WHERE NOMBRE_CLINICA = 'Clínica Médica Cayalá Élite';
    DBMS_OUTPUT.PUT_LINE('   DIM_CLINICA nuevos eliminados: ' || SQL%ROWCOUNT);

    DBMS_OUTPUT.PUT_LINE('--- 3. Eliminando Nuevos Catálogos Maestros en DWH ---');

    DELETE FROM DIM_UBICACION WHERE DISTRITO = 'Zona 16 - Paseo Cayalá';
    DBMS_OUTPUT.PUT_LINE('   DIM_UBICACION eliminada: ' || SQL%ROWCOUNT);

    DELETE FROM DIM_FORMA_PAGO WHERE NOMBRE_FORMA_PAGO = 'Billetera Digital / QR Interbancario';
    DBMS_OUTPUT.PUT_LINE('   DIM_FORMA_PAGO eliminada: ' || SQL%ROWCOUNT);

    DELETE FROM DIM_TIPO_CONSULTA WHERE NOMBRE_TIPO = 'Teleconsulta Especializada Digital HD';
    DBMS_OUTPUT.PUT_LINE('   DIM_TIPO_CONSULTA eliminada: ' || SQL%ROWCOUNT);

    DELETE FROM DIM_ENFERMEDAD WHERE CODIGO_CIE10 = 'U07.1';
    DBMS_OUTPUT.PUT_LINE('   DIM_ENFERMEDAD eliminada: ' || SQL%ROWCOUNT);

    DELETE FROM DIM_ESPECIALIDAD WHERE NOMBRE_ESPECIALIDAD = 'Inmunología y Alergología Clínica Avanzada';
    DBMS_OUTPUT.PUT_LINE('   DIM_ESPECIALIDAD nueva eliminada: ' || SQL%ROWCOUNT);

    -- Restaurar descripción original de DIM_ESPECIALIDAD BK=1 (SCD 1)
    UPDATE DIM_ESPECIALIDAD
    SET DESCRIPCION = 'Atención médica primaria integral, diagnóstico y tratamiento preventivo ambulatorio',
        ROWHASHVALUE = RAWTOHEX(STANDARD_HASH(NOMBRE_ESPECIALIDAD || '|Atención médica primaria integral, diagnóstico y tratamiento preventivo ambulatorio', 'SHA256'))
    WHERE BK_ID_ESPECIALIDAD = 1;
    DBMS_OUTPUT.PUT_LINE('   DIM_ESPECIALIDAD (BK=1) restaurada (SCD1)');

    DELETE FROM DIM_PAGADOR WHERE NUMERO_IDENTIFICACION IN ('88776655-4', '99887766-5');
    DBMS_OUTPUT.PUT_LINE('   DIM_PAGADOR eliminados: ' || SQL%ROWCOUNT);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('>>> ROLLBACK EN DWH COMPLETADO CON ÉXITO <<<');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR EN ROLLBACK DWH: ' || SQLERRM);
        RAISE;
END;
/
