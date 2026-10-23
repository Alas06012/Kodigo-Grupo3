-- ============================================================================
-- PROYECTO DATA WAREHOUSE - RED ASISTENCIAL DE CLÍNICAS
-- SCRIPT DE PRUEBAS: INSERCIÓN Y SIMULACIÓN INTEGRAL EN BASE DE DATOS OLTP
-- ESQUEMA: red_clinica_user | MOTOR: Oracle Database 19c/21c/23ai
-- ============================================================================
-- OBJETIVO:
-- Inyectar transacciones y mutaciones de datos maestros en el sistema transaccional
-- (OLTP) simulando la operativa diaria real de una red hospitalaria.
--
-- ESCENARIOS INCLUIDOS:
-- 1. Nuevos Datos Maestros (Nuevos catálogos para Staging y DWH).
-- 2. SCD Tipo 1 (Actualización in-place sin duplicar registros).
-- 3. SCD Tipo 2 (Historización: cierra versión anterior y abre nueva versión activa).
-- 4. Nuevos Pacientes y Médicos (Incorporación a la red).
-- 5. Transacciones en la Ventana de Lookback Diaria (SYSDATE y días previos):
--    - Caso A: Pago 100% Paciente (Billetera Digital).
--    - Caso B: Copago Mixto 80% Aseguradora / 20% Paciente (Multidiagnóstico y Procedimiento).
--    - Caso C: Facturación Corporativa a Empresa con Cobro Pendiente (Crédito).
--    - Caso D: Pago Parcial / Abono con saldo pendiente de cobro.
--    - Caso E: Consulta histórica reciente (Lookback ventana deslizante).
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    -- IDs de Nuevos Datos Maestros
    v_id_ubicacion_nueva      NUMBER;
    v_id_clinica_nueva        NUMBER;
    v_id_empresa_nueva        NUMBER;
    v_id_aseguradora_nueva    NUMBER;
    v_id_especialidad_nueva   NUMBER;
    v_id_enfermedad_nueva     NUMBER;
    v_id_tipo_consulta_nuevo  NUMBER;
    v_id_procedimiento_nuevo  NUMBER;
    v_id_forma_pago_nueva     NUMBER;

    -- IDs de Nuevas Personas
    v_id_paciente_1           NUMBER;
    v_id_paciente_2           NUMBER;
    v_id_paciente_3           NUMBER;
    v_id_medico_nuevo         NUMBER;
    v_id_medesp_nuevo         NUMBER;

    -- IDs de Transacciones - Caso 1 (Copago Mixto 80/20)
    v_id_consulta_1           NUMBER;
    v_id_cobro_1              NUMBER;
    v_id_distrib_1_aseg       NUMBER;
    v_id_distrib_1_pac        NUMBER;
    v_id_trans_1_aseg         NUMBER;
    v_id_trans_1_pac          NUMBER;

    -- IDs de Transacciones - Caso 2 (Particular 100% Contado con Billetera Digital)
    v_id_consulta_2           NUMBER;
    v_id_cobro_2              NUMBER;
    v_id_distrib_2            NUMBER;
    v_id_trans_2              NUMBER;

    -- IDs de Transacciones - Caso 3 (Corporativo 100% Empresa Pendiente)
    v_id_consulta_3           NUMBER;
    v_id_cobro_3              NUMBER;
    v_id_distrib_3            NUMBER;

    -- IDs de Transacciones - Caso 4 (Pago Parcial con Saldo)
    v_id_consulta_4           NUMBER;
    v_id_cobro_4              NUMBER;
    v_id_distrib_4            NUMBER;
    v_id_trans_4              NUMBER;

    -- IDs de Transacciones - Caso 5 (Consulta de Ayer - Lookback)
    v_id_consulta_5           NUMBER;
    v_id_cobro_5              NUMBER;
    v_id_distrib_5            NUMBER;
    v_id_trans_5              NUMBER;

    -- Identificador del médico y paciente base para SCD2
    v_id_medico_scd2          NUMBER := 5;
    v_id_paciente_scd2        NUMBER := 10;
    v_id_clinica_scd2         NUMBER := 2;

BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================================');
    DBMS_OUTPUT.PUT_LINE('INICIO DE SIMULACIÓN Y CARGA DE DATOS DE PRUEBA EN OLTP (red_clinica_user)');
    DBMS_OUTPUT.PUT_LINE('Fecha y Hora del Sistema: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('============================================================================');

    -- ========================================================================
    -- 0. LIMPIEZA PREVENTIVA DE CORRIDAS PREVIAS DE PRUEBA (Idempotencia)
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('1. Limpiando registros de pruebas anteriores...');
    
    DELETE FROM TRANSACCIONES_PAGO WHERE OBSERVACIONES LIKE '%[PRUEBA]%';
    DELETE FROM DISTRIBUCION_COBRO WHERE ID_COBRO IN (
        SELECT ID_COBRO FROM COBROS_CONSULTA WHERE ID_CONSULTA IN (
            SELECT ID_CONSULTA FROM CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
        )
    );
    DELETE FROM COBROS_CONSULTA WHERE ID_CONSULTA IN (
        SELECT ID_CONSULTA FROM CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    );
    DELETE FROM CONSULTAS_PROCEDIMIENTOS WHERE ID_CONSULTA IN (
        SELECT ID_CONSULTA FROM CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    );
    DELETE FROM DIAGNOSTICOS WHERE ID_CONSULTA IN (
        SELECT ID_CONSULTA FROM CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    );
    DELETE FROM CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%';

    DELETE FROM MEDICOS_ESPECIALIDADES WHERE ID_MEDICO IN (
        SELECT ID_MEDICO FROM MEDICOS WHERE NUM_COLEGIADO = 'COL-99881'
    );
    DELETE FROM MEDICOS WHERE NUM_COLEGIADO = 'COL-99881';
    DELETE FROM PACIENTES WHERE NUMERO_POLIZA = 'POL-INT-994411' OR NOMBRES LIKE '%[PRUEBA]%' OR APELLIDOS LIKE '%[PRUEBA]%';
    DELETE FROM CLINICAS WHERE NOMBRE_CLINICA = 'Clínica Médica Cayalá Élite';
    DELETE FROM FORMAS_PAGO WHERE NOMBRE_FORMA_PAGO = 'Billetera Digital / QR Interbancario';
    DELETE FROM PROCEDIMIENTOS WHERE CODIGO_PROCEDIMIENTO = 'PR-ANGIO-01';
    DELETE FROM TIPOS_CONSULTA WHERE NOMBRE_TIPO = 'Teleconsulta Especializada Digital HD';
    DELETE FROM ENFERMEDADES WHERE CODIGO_CIE10 = 'U07.1';
    DELETE FROM ESPECIALIDADES WHERE NOMBRE_ESPECIALIDAD = 'Inmunología y Alergología Clínica Avanzada';
    DELETE FROM ASEGURADORAS WHERE NIT = '88776655-4';
    DELETE FROM EMPRESAS WHERE NIT = '99887766-5';
    DELETE FROM UBICACIONES WHERE PAIS = 'Guatemala' AND DISTRITO = 'Zona 16 - Paseo Cayalá';
    COMMIT;

    -- ========================================================================
    -- ESCENARIO 1: NUEVOS DATOS MAESTROS (CATÁLOGOS)
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('2. Insertando Nuevos Datos Maestros (Catálogos)...');

    -- 1.1 Nueva Ubicación
    INSERT INTO UBICACIONES (PAIS, DEPARTAMENTO, MUNICIPIO, DISTRITO, CODIGO_POSTAL)
    VALUES ('Guatemala', 'Guatemala', 'Guatemala', 'Zona 16 - Paseo Cayalá', '01016')
    RETURNING ID_UBICACION INTO v_id_ubicacion_nueva;

    -- 1.2 Nueva Clínica
    INSERT INTO CLINICAS (NOMBRE_CLINICA, ID_UBICACION, DIRECCION, TELEFONO, FECHA_APERTURA, ESTADO)
    VALUES ('Clínica Médica Cayalá Élite', v_id_ubicacion_nueva, 'Paseo Cayalá Edificio G3 Nivel 4', '502-2399-8800', DATE '2026-10-01', 'ACTIVA')
    RETURNING ID_CLINICA INTO v_id_clinica_nueva;

    -- 1.3 Nueva Empresa
    INSERT INTO EMPRESAS (NOMBRE_EMPRESA, NIT, SECTOR, TELEFONO, DIRECCION)
    VALUES ('Tech Solutions & Cloud Services S.A.', '99887766-5', 'Tecnología e Informática', '502-2200-1122', 'Boulevard Los Próceres Zona 10')
    RETURNING ID_EMPRESA INTO v_id_empresa_nueva;

    -- 1.4 Nueva Aseguradora
    INSERT INTO ASEGURADORAS (NOMBRE_ASEGURADORA, NIT, TIPO_COBERTURA, TELEFONO)
    VALUES ('Aseguradora Internacional del Caribe', '88776655-4', 'Plan Platinum Internacional', '502-2450-9900')
    RETURNING ID_ASEGURADORA INTO v_id_aseguradora_nueva;

    -- 1.5 Nueva Especialidad
    INSERT INTO ESPECIALIDADES (NOMBRE_ESPECIALIDAD, DESCRIPCION)
    VALUES ('Inmunología y Alergología Clínica Avanzada', 'Diagnóstico y tratamiento de patologías inmunes complejas, anafilaxia y terapia biológica')
    RETURNING ID_ESPECIALIDAD INTO v_id_especialidad_nueva;

    -- 1.6 Nueva Enfermedad (CIE-10)
    INSERT INTO ENFERMEDADES (CODIGO_CIE10, NOMBRE_ENFERMEDAD)
    VALUES ('U07.1', 'COVID-19 Infección Respiratoria Variante 2026')
    RETURNING ID_ENFERMEDAD INTO v_id_enfermedad_nueva;

    -- 1.7 Nuevo Tipo de Consulta
    INSERT INTO TIPOS_CONSULTA (NOMBRE_TIPO, DESCRIPCION, PRECIO_BASE, ESTADO)
    VALUES ('Teleconsulta Especializada Digital HD', 'Atención médica virtual sincrónica por videoconferencia clínica de alta definición', 350.00, 'ACTIVO')
    RETURNING ID_TIPO_CONSULTA INTO v_id_tipo_consulta_nuevo;

    -- 1.8 Nuevo Procedimiento
    INSERT INTO PROCEDIMIENTOS (CODIGO_PROCEDIMIENTO, NOMBRE_PROCEDIMIENTO, DESCRIPCION, COSTO_BASE, ESTADO)
    VALUES ('PR-ANGIO-01', 'Angiotomografía Coronaria Multicorte', 'Estudio tomográfico no invasivo con contraste para arterias coronarias', 1850.00, 'ACTIVO')
    RETURNING ID_PROCEDIMIENTO INTO v_id_procedimiento_nuevo;

    -- 1.9 Nueva Forma de Pago
    INSERT INTO FORMAS_PAGO (NOMBRE_FORMA_PAGO, CATEGORIA, ESTADO)
    VALUES ('Billetera Digital / QR Interbancario', 'CONTADO', 'ACTIVO')
    RETURNING ID_FORMA_PAGO INTO v_id_forma_pago_nueva;

    -- ========================================================================
    -- ESCENARIO 2: SCD TIPO 1 (ACTUALIZACIÓN IN-PLACE EN CATÁLOGO EXISTENTE)
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('3. Aplicando actualización SCD 1 en catálogo existente...');
    UPDATE ESPECIALIDADES
    SET DESCRIPCION = 'Atención médica primaria integral, diagnóstico y tratamiento preventivo ambulatorio (Certificación Internacional 2026)'
    WHERE ID_ESPECIALIDAD = 1;

    -- ========================================================================
    -- ESCENARIO 3: SCD TIPO 2 (MUTACIONES DE ENTIDADES HISTORIABLES)
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('4. Mutando entidades para disparar SCD Tipo 2 en DWH...');

    -- 3.1 Mutación de Paciente 10: Cambia de dirección y se afilia a la nueva aseguradora
    UPDATE PACIENTES
    SET DIRECCION = 'Boulevard Vista Hermosa 25-10 Zona 15, Edificio Reforma Nivel 8',
        ID_ASEGURADORA = v_id_aseguradora_nueva,
        NUMERO_POLIZA = 'POL-EXP-2026-X'
    WHERE ID_PACIENTE = v_id_paciente_scd2;

    -- 3.2 Mutación de Médico 5: Se traslada a la nueva clínica 'Clínica Médica Cayalá Élite'
    UPDATE MEDICOS
    SET ID_CLINICA_BASE = v_id_clinica_nueva
    WHERE ID_MEDICO = v_id_medico_scd2;

    -- 3.3 Mutación de Clínica 2: Actualiza su dirección y teléfono
    UPDATE CLINICAS
    SET DIRECCION = 'Bulevar Orden de Malta, Edificio Mediplaza Torre Médica Nivel 5',
        TELEFONO = '2289-4599'
    WHERE ID_CLINICA = v_id_clinica_scd2;

    -- ========================================================================
    -- ESCENARIO 4: NUEVOS PACIENTES Y MÉDICOS
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('5. Registrando nuevos Pacientes y Médicos...');

    -- 4.1 Paciente Particular (Sin seguro ni empresa)
    INSERT INTO PACIENTES (NOMBRES, APELLIDOS, FECHA_NACIMIENTO, SEXO, ID_UBICACION, DIRECCION, ID_CLINICA_HABITUAL, ID_EMPRESA, ID_ASEGURADORA, NUMERO_POLIZA, FECHA_REGISTRO)
    VALUES ('Carlos Eduardo [PRUEBA]', 'Mendoza Valenzuela', DATE '1985-06-15', 'M', v_id_ubicacion_nueva, 'Paseo Cayalá Manzana 4 Casa 12', v_id_clinica_nueva, NULL, NULL, NULL, TRUNC(SYSDATE))
    RETURNING ID_PACIENTE INTO v_id_paciente_1;

    -- 4.2 Paciente Corporativo (Con Empresa Convenio)
    INSERT INTO PACIENTES (NOMBRES, APELLIDOS, FECHA_NACIMIENTO, SEXO, ID_UBICACION, DIRECCION, ID_CLINICA_HABITUAL, ID_EMPRESA, ID_ASEGURADORA, NUMERO_POLIZA, FECHA_REGISTRO)
    VALUES ('Valeria Sofía [PRUEBA]', 'Gómez Cifuentes', DATE '1992-11-20', 'F', v_id_ubicacion_nueva, 'Residenciales Jacarandas Zona 16 #45', v_id_clinica_nueva, v_id_empresa_nueva, NULL, NULL, TRUNC(SYSDATE))
    RETURNING ID_PACIENTE INTO v_id_paciente_2;

    -- 4.3 Paciente Asegurado Internacional
    INSERT INTO PACIENTES (NOMBRES, APELLIDOS, FECHA_NACIMIENTO, SEXO, ID_UBICACION, DIRECCION, ID_CLINICA_HABITUAL, ID_EMPRESA, ID_ASEGURADORA, NUMERO_POLIZA, FECHA_REGISTRO)
    VALUES ('Alejandro José [PRUEBA]', 'Paredes Montenegro', DATE '1960-03-08', 'M', v_id_ubicacion_nueva, 'Condominio El Encinal Zona 16 Casa 8', v_id_clinica_nueva, NULL, v_id_aseguradora_nueva, 'POL-INT-994411', TRUNC(SYSDATE))
    RETURNING ID_PACIENTE INTO v_id_paciente_3;

    -- 4.4 Nuevo Médico Especialista
    INSERT INTO MEDICOS (NOMBRES, APELLIDOS, ID_CLINICA_BASE, NUM_COLEGIADO, FECHA_INGRESO, ESTADO)
    VALUES ('Mariana Elizabeth [PRUEBA]', 'Herrera Solares', v_id_clinica_nueva, 'COL-99881', DATE '2026-10-01', 'ACTIVO')
    RETURNING ID_MEDICO INTO v_id_medico_nuevo;

    INSERT INTO MEDICOS_ESPECIALIDADES (ID_MEDICO, ID_ESPECIALIDAD, NUM_REGISTRO_ESPECIAL, ES_PRINCIPAL)
    VALUES (v_id_medico_nuevo, v_id_especialidad_nueva, 'REG-INM-001', 'S')
    RETURNING ID_MEDICO_ESPECIALIDAD INTO v_id_medesp_nuevo;

    -- ========================================================================
    -- ESCENARIO 5: TRANSACCIONES EN VENTANA DE CARGA DIARIA (LOOKBACK)
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('6. Insertando Consultas y Transacciones Financieras en ventana activa...');

    -- ------------------------------------------------------------------------
    -- CASO 5.1: ALTA COMPLEJIDAD CON COPAGO MIXTO 80% ASEGURADORA / 20% PACIENTE
    -- Fecha: Hoy (TRUNC(SYSDATE))
    -- Consulta ($400) + Procedimiento Angiotomografía ($1,850) = Total $2,250
    -- 2 Diagnósticos (Isquemia Cardíaca + Hipertensión)
    -- ------------------------------------------------------------------------
    INSERT INTO CONSULTAS (ID_PACIENTE, ID_CLINICA, ID_MEDICO, ID_ESPECIALIDAD, ID_TIPO_CONSULTA, FECHA_CONSULTA, PRECIO_CONSULTA, MOTIVO_CONSULTA, PRESCRIPCION)
    VALUES (v_id_paciente_3, v_id_clinica_nueva, v_id_medico_nuevo, v_id_especialidad_nueva, v_id_tipo_consulta_nuevo, TRUNC(SYSDATE), 400.00, 'Dolor torácico opresivo y disnea de esfuerzo moderado [PRUEBA]', 'Monitoreo hemodinámico estricto + betabloqueantes 50mg cada 12h')
    RETURNING ID_CONSULTA INTO v_id_consulta_1;

    -- Diagnóstico 1
    INSERT INTO DIAGNOSTICOS (ID_CONSULTA, ID_ENFERMEDAD, FECHA_DIAGNOSTICO, OBSERVACIONES)
    VALUES (v_id_consulta_1, 1, TRUNC(SYSDATE), 'Diagnóstico primario de sospecha isquémica [PRUEBA]');

    -- Diagnóstico 2
    INSERT INTO DIAGNOSTICOS (ID_CONSULTA, ID_ENFERMEDAD, FECHA_DIAGNOSTICO, OBSERVACIONES)
    VALUES (v_id_consulta_1, 2, TRUNC(SYSDATE), 'Comorbilidad asociada: hipertensión en estadio II [PRUEBA]');

    -- Procedimiento asociado
    INSERT INTO CONSULTAS_PROCEDIMIENTOS (ID_CONSULTA, ID_PROCEDIMIENTO, CANTIDAD, PRECIO_UNITARIO, OBSERVACIONES, FECHA_REALIZACION)
    VALUES (v_id_consulta_1, v_id_procedimiento_nuevo, 1, 1850.00, 'Tomografía de alta resolución con contraste yodado [PRUEBA]', TRUNC(SYSDATE));

    -- Cobro General de la Consulta
    INSERT INTO COBROS_CONSULTA (ID_CONSULTA, MONTO_TOTAL_FACTURADO, MONTO_TOTAL_PAGADO, ESTADO_COBRO, FECHA_EMISION)
    VALUES (v_id_consulta_1, 2250.00, 0, 'PENDIENTE', TRUNC(SYSDATE))
    RETURNING ID_COBRO INTO v_id_cobro_1;

    -- Distribución 80% Aseguradora ($1,800.00)
    INSERT INTO DISTRIBUCION_COBRO (ID_COBRO, TIPO_PAGADOR, ID_PACIENTE, ID_ASEGURADORA, ID_EMPRESA, PORCENTAJE, MONTO_ASIGNADO, MONTO_PAGADO, ESTADO)
    VALUES (v_id_cobro_1, 'ASEGURADORA', NULL, v_id_aseguradora_nueva, NULL, 80, 1800.00, 0, 'PENDIENTE')
    RETURNING ID_DISTRIBUCION INTO v_id_distrib_1_aseg;

    -- Distribución 20% Paciente ($450.00)
    INSERT INTO DISTRIBUCION_COBRO (ID_COBRO, TIPO_PAGADOR, ID_PACIENTE, ID_ASEGURADORA, ID_EMPRESA, PORCENTAJE, MONTO_ASIGNADO, MONTO_PAGADO, ESTADO)
    VALUES (v_id_cobro_1, 'PACIENTE', v_id_paciente_3, NULL, NULL, 20, 450.00, 0, 'PENDIENTE')
    RETURNING ID_DISTRIBUCION INTO v_id_distrib_1_pac;

    -- Pagos:
    -- Aseguradora paga $1,800.00 (Forma de pago 4: Transferencia)
    INSERT INTO TRANSACCIONES_PAGO (ID_DISTRIBUCION, ID_FORMA_PAGO, MONTO_TRANSACCION, FECHA_PAGO, NUMERO_REFERENCIA, OBSERVACIONES)
    VALUES (v_id_distrib_1_aseg, 4, 1800.00, TRUNC(SYSDATE), 'TRF-ASEG-88992', 'Liquidación electrónica de siniestro ambulatorio [PRUEBA]')
    RETURNING ID_TRANSACCION INTO v_id_trans_1_aseg;

    -- Paciente paga copago $450.00 (Forma de pago 2: Tarjeta de Crédito)
    INSERT INTO TRANSACCIONES_PAGO (ID_DISTRIBUCION, ID_FORMA_PAGO, MONTO_TRANSACCION, FECHA_PAGO, NUMERO_REFERENCIA, OBSERVACIONES)
    VALUES (v_id_distrib_1_pac, 2, 450.00, TRUNC(SYSDATE), 'POS-VISA-112233', 'Pago de copago 20% en recepción clínica [PRUEBA]')
    RETURNING ID_TRANSACCION INTO v_id_trans_1_pac;

    -- ------------------------------------------------------------------------
    -- CASO 5.2: CONSULTA PARTICULAR PAGADA 100% CON NUEVA BILLETERA DIGITAL
    -- Fecha: Hoy (TRUNC(SYSDATE))
    -- Consulta Médica ($250.00)
    -- ------------------------------------------------------------------------
    INSERT INTO CONSULTAS (ID_PACIENTE, ID_CLINICA, ID_MEDICO, ID_ESPECIALIDAD, ID_TIPO_CONSULTA, FECHA_CONSULTA, PRECIO_CONSULTA, MOTIVO_CONSULTA, PRESCRIPCION)
    VALUES (v_id_paciente_1, v_id_clinica_nueva, v_id_medico_nuevo, v_id_especialidad_nueva, 1, TRUNC(SYSDATE), 250.00, 'Rinitis alérgica recurrente y conjuntivitis [PRUEBA]', 'Loratadina 10mg diaria + colirio oftálmico')
    RETURNING ID_CONSULTA INTO v_id_consulta_2;

    INSERT INTO DIAGNOSTICOS (ID_CONSULTA, ID_ENFERMEDAD, FECHA_DIAGNOSTICO, OBSERVACIONES)
    VALUES (v_id_consulta_2, v_id_enfermedad_nueva, TRUNC(SYSDATE), 'Diagnóstico confirmado con antígeno positivo [PRUEBA]');

    INSERT INTO COBROS_CONSULTA (ID_CONSULTA, MONTO_TOTAL_FACTURADO, MONTO_TOTAL_PAGADO, ESTADO_COBRO, FECHA_EMISION)
    VALUES (v_id_consulta_2, 250.00, 0, 'PENDIENTE', TRUNC(SYSDATE))
    RETURNING ID_COBRO INTO v_id_cobro_2;

    INSERT INTO DISTRIBUCION_COBRO (ID_COBRO, TIPO_PAGADOR, ID_PACIENTE, ID_ASEGURADORA, ID_EMPRESA, PORCENTAJE, MONTO_ASIGNADO, MONTO_PAGADO, ESTADO)
    VALUES (v_id_cobro_2, 'PACIENTE', v_id_paciente_1, NULL, NULL, 100, 250.00, 0, 'PENDIENTE')
    RETURNING ID_DISTRIBUCION INTO v_id_distrib_2;

    INSERT INTO TRANSACCIONES_PAGO (ID_DISTRIBUCION, ID_FORMA_PAGO, MONTO_TRANSACCION, FECHA_PAGO, NUMERO_REFERENCIA, OBSERVACIONES)
    VALUES (v_id_distrib_2, v_id_forma_pago_nueva, 250.00, TRUNC(SYSDATE), 'QR-WALLET-778899', 'Cobro inmediato por QR interoperable en app [PRUEBA]')
    RETURNING ID_TRANSACCION INTO v_id_trans_2;

    -- ------------------------------------------------------------------------
    -- CASO 5.3: CONVENIO CORPORATIVO A EMPRESA (100% FACTURADO A CRÉDITO PENDIENTE)
    -- Fecha: Hoy (TRUNC(SYSDATE))
    -- Teleconsulta ($350.00), Sin pagos aún (Saldo Pendiente = $350.00)
    -- ------------------------------------------------------------------------
    INSERT INTO CONSULTAS (ID_PACIENTE, ID_CLINICA, ID_MEDICO, ID_ESPECIALIDAD, ID_TIPO_CONSULTA, FECHA_CONSULTA, PRECIO_CONSULTA, MOTIVO_CONSULTA, PRESCRIPCION)
    VALUES (v_id_paciente_2, v_id_clinica_nueva, v_id_medico_scd2, 1, v_id_tipo_consulta_nuevo, TRUNC(SYSDATE), 350.00, 'Chequeo médico ocupacional y fatiga visual por teletrabajo [PRUEBA]', 'Pausas activas + gotas lubricantes oculares')
    RETURNING ID_CONSULTA INTO v_id_consulta_3;

    INSERT INTO DIAGNOSTICOS (ID_CONSULTA, ID_ENFERMEDAD, FECHA_DIAGNOSTICO, OBSERVACIONES)
    VALUES (v_id_consulta_3, 3, TRUNC(SYSDATE), 'Astenopía acomodativa y síndrome visual [PRUEBA]');

    INSERT INTO COBROS_CONSULTA (ID_CONSULTA, MONTO_TOTAL_FACTURADO, MONTO_TOTAL_PAGADO, ESTADO_COBRO, FECHA_EMISION)
    VALUES (v_id_consulta_3, 350.00, 0, 'PENDIENTE', TRUNC(SYSDATE))
    RETURNING ID_COBRO INTO v_id_cobro_3;

    INSERT INTO DISTRIBUCION_COBRO (ID_COBRO, TIPO_PAGADOR, ID_PACIENTE, ID_ASEGURADORA, ID_EMPRESA, PORCENTAJE, MONTO_ASIGNADO, MONTO_PAGADO, ESTADO)
    VALUES (v_id_cobro_3, 'EMPRESA', NULL, NULL, v_id_empresa_nueva, 100, 350.00, 0, 'PENDIENTE')
    RETURNING ID_DISTRIBUCION INTO v_id_distrib_3;
    -- NOTA: No se inserta transacción de pago (Permanecerá PENDIENTE para validar métricas de saldos pendientes en DWH)

    -- ------------------------------------------------------------------------
    -- CASO 5.4: PAGO PARCIAL / ABONO CON SALDO PENDIENTE
    -- Fecha: Hoy (TRUNC(SYSDATE))
    -- Consulta ($250) + Procedimiento ($350) = Facturado $600.00
    -- Abono inicial: $200.00 | Saldo pendiente: $400.00 | Estado: PARCIAL
    -- ------------------------------------------------------------------------
    INSERT INTO CONSULTAS (ID_PACIENTE, ID_CLINICA, ID_MEDICO, ID_ESPECIALIDAD, ID_TIPO_CONSULTA, FECHA_CONSULTA, PRECIO_CONSULTA, MOTIVO_CONSULTA, PRESCRIPCION)
    VALUES (v_id_paciente_scd2, v_id_clinica_scd2, v_id_medico_scd2, 1, 1, TRUNC(SYSDATE), 250.00, 'Control clínico posoperatorio ambulatorio [PRUEBA]', 'Curación de herida quirúrgica + analgesia')
    RETURNING ID_CONSULTA INTO v_id_consulta_4;

    INSERT INTO DIAGNOSTICOS (ID_CONSULTA, ID_ENFERMEDAD, FECHA_DIAGNOSTICO, OBSERVACIONES)
    VALUES (v_id_consulta_4, 4, TRUNC(SYSDATE), 'Control de herida limpia sin signos de infección [PRUEBA]');

    INSERT INTO CONSULTAS_PROCEDIMIENTOS (ID_CONSULTA, ID_PROCEDIMIENTO, CANTIDAD, PRECIO_UNITARIO, OBSERVACIONES, FECHA_REALIZACION)
    VALUES (v_id_consulta_4, 1, 1, 350.00, 'Curación avanzada con apósito hidrocoloide [PRUEBA]', TRUNC(SYSDATE));

    INSERT INTO COBROS_CONSULTA (ID_CONSULTA, MONTO_TOTAL_FACTURADO, MONTO_TOTAL_PAGADO, ESTADO_COBRO, FECHA_EMISION)
    VALUES (v_id_consulta_4, 600.00, 0, 'PENDIENTE', TRUNC(SYSDATE))
    RETURNING ID_COBRO INTO v_id_cobro_4;

    INSERT INTO DISTRIBUCION_COBRO (ID_COBRO, TIPO_PAGADOR, ID_PACIENTE, ID_ASEGURADORA, ID_EMPRESA, PORCENTAJE, MONTO_ASIGNADO, MONTO_PAGADO, ESTADO)
    VALUES (v_id_cobro_4, 'PACIENTE', v_id_paciente_scd2, NULL, NULL, 100, 600.00, 0, 'PENDIENTE')
    RETURNING ID_DISTRIBUCION INTO v_id_distrib_4;

    -- Abono de $200.00 (Efectivo)
    INSERT INTO TRANSACCIONES_PAGO (ID_DISTRIBUCION, ID_FORMA_PAGO, MONTO_TRANSACCION, FECHA_PAGO, NUMERO_REFERENCIA, OBSERVACIONES)
    VALUES (v_id_distrib_4, 1, 200.00, TRUNC(SYSDATE), 'REC-EFECT-5544', 'Abono parcial en caja clínica [PRUEBA]')
    RETURNING ID_TRANSACCION INTO v_id_trans_4;

    -- ------------------------------------------------------------------------
    -- CASO 5.5: CONSULTA DEL DÍA DE AYER (PRUEBA DE LOOKBACK INCREMENTAL 3 DÍAS)
    -- Fecha: Ayer (TRUNC(SYSDATE) - 1)
    -- Consulta Médica ($250.00), Pagada en Efectivo
    -- ------------------------------------------------------------------------
    INSERT INTO CONSULTAS (ID_PACIENTE, ID_CLINICA, ID_MEDICO, ID_ESPECIALIDAD, ID_TIPO_CONSULTA, FECHA_CONSULTA, PRECIO_CONSULTA, MOTIVO_CONSULTA, PRESCRIPCION)
    VALUES (v_id_paciente_1, v_id_clinica_nueva, v_id_medico_nuevo, v_id_especialidad_nueva, 1, TRUNC(SYSDATE) - 1, 250.00, 'Consulta de control y seguimiento 24 horas posteriores [PRUEBA]', 'Continuar esquema terapéutico indicado')
    RETURNING ID_CONSULTA INTO v_id_consulta_5;

    INSERT INTO DIAGNOSTICOS (ID_CONSULTA, ID_ENFERMEDAD, FECHA_DIAGNOSTICO, OBSERVACIONES)
    VALUES (v_id_consulta_5, v_id_enfermedad_nueva, TRUNC(SYSDATE) - 1, 'Evolución favorable de sintomatología [PRUEBA]');

    INSERT INTO COBROS_CONSULTA (ID_CONSULTA, MONTO_TOTAL_FACTURADO, MONTO_TOTAL_PAGADO, ESTADO_COBRO, FECHA_EMISION)
    VALUES (v_id_consulta_5, 250.00, 0, 'PENDIENTE', TRUNC(SYSDATE) - 1)
    RETURNING ID_COBRO INTO v_id_cobro_5;

    INSERT INTO DISTRIBUCION_COBRO (ID_COBRO, TIPO_PAGADOR, ID_PACIENTE, ID_ASEGURADORA, ID_EMPRESA, PORCENTAJE, MONTO_ASIGNADO, MONTO_PAGADO, ESTADO)
    VALUES (v_id_cobro_5, 'PACIENTE', v_id_paciente_1, NULL, NULL, 100, 250.00, 0, 'PENDIENTE')
    RETURNING ID_DISTRIBUCION INTO v_id_distrib_5;

    INSERT INTO TRANSACCIONES_PAGO (ID_DISTRIBUCION, ID_FORMA_PAGO, MONTO_TRANSACCION, FECHA_PAGO, NUMERO_REFERENCIA, OBSERVACIONES)
    VALUES (v_id_distrib_5, 1, 250.00, TRUNC(SYSDATE) - 1, 'REC-EFECT-AYER', 'Pago en efectivo caja recepción ayer [PRUEBA]')
    RETURNING ID_TRANSACCION INTO v_id_trans_5;

    COMMIT;

    -- ========================================================================
    -- RESUMEN DE LA CARGA DE PRUEBA
    -- ========================================================================
    DBMS_OUTPUT.PUT_LINE('============================================================================');
    DBMS_OUTPUT.PUT_LINE('SIMULACIÓN COMPLETADA EXITOSAMENTE EN BASE DE DATOS OLTP');
    DBMS_OUTPUT.PUT_LINE('============================================================================');
    DBMS_OUTPUT.PUT_LINE('DATOS MAESTROS CREADOS:');
    DBMS_OUTPUT.PUT_LINE('  * ID_UBICACION Nueva   : ' || v_id_ubicacion_nueva || ' (Zona 16 - Paseo Cayalá)');
    DBMS_OUTPUT.PUT_LINE('  * ID_CLINICA Nueva     : ' || v_id_clinica_nueva || ' (Clínica Médica Cayalá Élite)');
    DBMS_OUTPUT.PUT_LINE('  * ID_EMPRESA Nueva     : ' || v_id_empresa_nueva || ' (Tech Solutions & Cloud Services S.A.)');
    DBMS_OUTPUT.PUT_LINE('  * ID_ASEGURADORA Nueva : ' || v_id_aseguradora_nueva || ' (Aseguradora Internacional del Caribe)');
    DBMS_OUTPUT.PUT_LINE('  * ID_ESPECIALIDAD Nueva: ' || v_id_especialidad_nueva || ' (Inmunología y Alergología Avanzada)');
    DBMS_OUTPUT.PUT_LINE('  * ID_ENFERMEDAD Nueva  : ' || v_id_enfermedad_nueva || ' (CIE-10 U07.1 COVID-19 Variante 2026)');
    DBMS_OUTPUT.PUT_LINE('  * ID_TIPO_CONSULTA Nvo : ' || v_id_tipo_consulta_nuevo || ' (Teleconsulta Digital HD)');
    DBMS_OUTPUT.PUT_LINE('  * ID_PROCEDIMIENTO Nvo : ' || v_id_procedimiento_nuevo || ' (Angiotomografía Coronaria)');
    DBMS_OUTPUT.PUT_LINE('  * ID_FORMA_PAGO Nueva  : ' || v_id_forma_pago_nueva || ' (Billetera Digital / QR)');
    DBMS_OUTPUT.PUT_LINE('MUTACIONES SCD TIPO 2:');
    DBMS_OUTPUT.PUT_LINE('  * Paciente Mutado (SCD2) : ID_PACIENTE=' || v_id_paciente_scd2 || ' (Nueva dirección y aseguradora)');
    DBMS_OUTPUT.PUT_LINE('  * Médico Mutado (SCD2)   : ID_MEDICO=' || v_id_medico_scd2 || ' (Trasladado a Clínica ' || v_id_clinica_nueva || ')');
    DBMS_OUTPUT.PUT_LINE('  * Clínica Mutada (SCD2)  : ID_CLINICA=' || v_id_clinica_scd2 || ' (Nueva dirección y teléfono)');
    DBMS_OUTPUT.PUT_LINE('NUEVAS PERSONAS:');
    DBMS_OUTPUT.PUT_LINE('  * Paciente Particular   : ID_PACIENTE=' || v_id_paciente_1 || ' (Carlos Eduardo Mendoza)');
    DBMS_OUTPUT.PUT_LINE('  * Paciente Corporativo  : ID_PACIENTE=' || v_id_paciente_2 || ' (Valeria Sofía Gómez)');
    DBMS_OUTPUT.PUT_LINE('  * Paciente Asegurado    : ID_PACIENTE=' || v_id_paciente_3 || ' (Alejandro José Paredes)');
    DBMS_OUTPUT.PUT_LINE('  * Nuevo Médico          : ID_MEDICO=' || v_id_medico_nuevo || ' (Dra. Mariana Herrera)');
    DBMS_OUTPUT.PUT_LINE('TRANSACCIONES ACTIVAS EN VENTANA LOOKBACK:');
    DBMS_OUTPUT.PUT_LINE('  * Consulta 1 (Mixta 80/20) : ID_CONSULTA=' || v_id_consulta_1 || ' | Total=$2,250.00 | Pagado=$2,250.00 (PAGADO)');
    DBMS_OUTPUT.PUT_LINE('  * Consulta 2 (Billetera QR): ID_CONSULTA=' || v_id_consulta_2 || ' | Total=$250.00   | Pagado=$250.00   (PAGADO)');
    DBMS_OUTPUT.PUT_LINE('  * Consulta 3 (Empresa Cred): ID_CONSULTA=' || v_id_consulta_3 || ' | Total=$350.00   | Pagado=$0.00     (PENDIENTE)');
    DBMS_OUTPUT.PUT_LINE('  * Consulta 4 (Pago Parcial): ID_CONSULTA=' || v_id_consulta_4 || ' | Total=$600.00   | Pagado=$200.00   (PARCIAL, Saldo $400)');
    DBMS_OUTPUT.PUT_LINE('  * Consulta 5 (Día Anterior): ID_CONSULTA=' || v_id_consulta_5 || ' | Total=$250.00   | Pagado=$250.00   (PAGADO, Ayer)');
    DBMS_OUTPUT.PUT_LINE('============================================================================');
    DBMS_OUTPUT.PUT_LINE('SIGUIENTE PASO: Ejecutar el pipeline de Apache Hop (wf_dwh_master.hwf o .bat)');
    DBMS_OUTPUT.PUT_LINE('============================================================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR EN SIMULACIÓN OLTP: ' || SQLERRM);
        RAISE;
END;
/
