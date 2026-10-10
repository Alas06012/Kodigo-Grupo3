/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
   CAPA DWH: PIPELINE ETL / ELT MASTER ORCHESTRATOR
   MOTOR: Oracle Database 19c / 21c / 23ai (PDB: XEPDB1)
   ESQUEMA: dwh_clinica_user
   
   ARQUITECTURA DE CARGA OPTIMIZADA:
     1. Soporte de Modos:
        - 'FULL': Inicialización / Recalibración completa.
        - 'INCREMENTAL': Producción diaria. Utiliza ventana deslizante (ej. últimos N días)
          para extraer a Staging solo las transacciones recientes y modificadas.
     2. Carga de Dimensiones SCD Tipo 1 (MERGE + validación de ROWHASHVALUE):
        - Solo actualiza registros si el hash cambia, evitando escrituras redundantes.
     3. Carga de Dimensiones SCD Tipo 2 (UPDATE caducidad + INSERT versión activa):
        - Preserva vigencias históricas con ROWHASHVALUE SHA-256.
     4. Carga de Tablas de Hechos (Facts):
        - En modo INCREMENTAL, Staging contiene únicamente la ventana de N días.
        - El MERGE contra FACT_CONSULTAS y FACT_COBROS_DISTRIBUCION procesa de forma
          idempotente solo ese lote (insertando nuevas o actualizando pagos/saldos de
          cuentas recientes), dejando intactos los millones de registros pasados.
   ============================================================================ */

ALTER SESSION SET CONTAINER = XEPDB1;

-- Conectarse o ejecutar bajo el esquema: dwh_clinica_user
-- ALTER SESSION SET CURRENT_SCHEMA = dwh_clinica_user;

CREATE OR REPLACE PACKAGE PKG_DWH_ETL_PIPELINE AS
    PROCEDIMIENTO_VERSION CONSTANT VARCHAR2(10) := '2.1.0';
    
    PROCEDURE SP_CARGAR_DIM_SCD1(p_tipo_carga IN VARCHAR2);
    PROCEDURE SP_CARGAR_DIM_SCD2(p_tipo_carga IN VARCHAR2);
    PROCEDURE SP_CARGAR_FACTS(p_tipo_carga IN VARCHAR2);
    PROCEDURE SP_LOAD_DWH_MASTER(
        p_tipo_carga    IN VARCHAR2 DEFAULT 'INCREMENTAL',
        p_dias_lookback IN NUMBER   DEFAULT 3,
        p_fecha_corte   IN DATE     DEFAULT NULL
    );
END PKG_DWH_ETL_PIPELINE;
/

CREATE OR REPLACE PACKAGE BODY PKG_DWH_ETL_PIPELINE AS

    -- ========================================================================
    -- 1. CARGA DE DIMENSIONES SCD TIPO 1 (MERGE CON VALIDACIÓN DE HASH)
    -- ========================================================================
    PROCEDURE SP_CARGAR_DIM_SCD1(p_tipo_carga IN VARCHAR2) IS
        v_cant NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- 1. Cargando Dimensiones SCD Tipo 1 ---');

        -- 1.1 DIM_UBICACION
        MERGE INTO DIM_UBICACION d
        USING stg_clinica_user.STG_UBICACIONES s
        ON (d.BK_ID_UBICACION = s.ID_UBICACION)
        WHEN NOT MATCHED THEN
            INSERT (
                BK_ID_UBICACION, PAIS, DEPARTAMENTO, MUNICIPIO, DISTRITO, CODIGO_POSTAL,
                CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
            )
            VALUES (
                s.ID_UBICACION, s.PAIS, s.DEPARTAMENTO, s.MUNICIPIO, s.DISTRITO, s.CODIGO_POSTAL,
                1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
            )
        WHEN MATCHED THEN
            UPDATE SET
                d.PAIS            = s.PAIS,
                d.DEPARTAMENTO    = s.DEPARTAMENTO,
                d.MUNICIPIO       = s.MUNICIPIO,
                d.DISTRITO        = s.DISTRITO,
                d.CODIGO_POSTAL   = s.CODIGO_POSTAL,
                d.FECHAINICIO     = SYSDATE,
                d.TIPOTRANSACCION = 'U',
                d.ROWHASHVALUE    = s.ROWHASHVALUE
            WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;
        v_cant := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('DIM_UBICACION procesada: ' || v_cant || ' filas afectadas.');

        -- 1.2 DIM_ESPECIALIDAD
        MERGE INTO DIM_ESPECIALIDAD d
        USING stg_clinica_user.STG_ESPECIALIDADES s
        ON (d.BK_ID_ESPECIALIDAD = s.ID_ESPECIALIDAD)
        WHEN NOT MATCHED THEN
            INSERT (
                BK_ID_ESPECIALIDAD, NOMBRE_ESPECIALIDAD, DESCRIPCION,
                CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
            )
            VALUES (
                s.ID_ESPECIALIDAD, s.NOMBRE_ESPECIALIDAD, s.DESCRIPCION,
                1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
            )
        WHEN MATCHED THEN
            UPDATE SET
                d.NOMBRE_ESPECIALIDAD = s.NOMBRE_ESPECIALIDAD,
                d.DESCRIPCION         = s.DESCRIPCION,
                d.FECHAINICIO         = SYSDATE,
                d.TIPOTRANSACCION     = 'U',
                d.ROWHASHVALUE        = s.ROWHASHVALUE
            WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;
        v_cant := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('DIM_ESPECIALIDAD procesada: ' || v_cant || ' filas afectadas.');

        -- 1.3 DIM_ENFERMEDAD
        MERGE INTO DIM_ENFERMEDAD d
        USING stg_clinica_user.STG_ENFERMEDADES s
        ON (d.BK_ID_ENFERMEDAD = s.ID_ENFERMEDAD)
        WHEN NOT MATCHED THEN
            INSERT (
                BK_ID_ENFERMEDAD, CODIGO_CIE10, NOMBRE_ENFERMEDAD,
                CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
            )
            VALUES (
                s.ID_ENFERMEDAD, s.CODIGO_CIE10, s.NOMBRE_ENFERMEDAD,
                1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
            )
        WHEN MATCHED THEN
            UPDATE SET
                d.CODIGO_CIE10      = s.CODIGO_CIE10,
                d.NOMBRE_ENFERMEDAD = s.NOMBRE_ENFERMEDAD,
                d.FECHAINICIO       = SYSDATE,
                d.TIPOTRANSACCION   = 'U',
                d.ROWHASHVALUE      = s.ROWHASHVALUE
            WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;
        v_cant := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('DIM_ENFERMEDAD procesada: ' || v_cant || ' filas afectadas.');

        -- 1.4 DIM_TIPO_CONSULTA
        MERGE INTO DIM_TIPO_CONSULTA d
        USING stg_clinica_user.STG_TIPOS_CONSULTA s
        ON (d.BK_ID_TIPO_CONSULTA = s.ID_TIPO_CONSULTA)
        WHEN NOT MATCHED THEN
            INSERT (
                BK_ID_TIPO_CONSULTA, NOMBRE_TIPO, DESCRIPCION, PRECIO_BASE, ESTADO,
                CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
            )
            VALUES (
                s.ID_TIPO_CONSULTA, s.NOMBRE_TIPO, s.DESCRIPCION, s.PRECIO_BASE, s.ESTADO,
                1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
            )
        WHEN MATCHED THEN
            UPDATE SET
                d.NOMBRE_TIPO     = s.NOMBRE_TIPO,
                d.DESCRIPCION     = s.DESCRIPCION,
                d.PRECIO_BASE     = s.PRECIO_BASE,
                d.ESTADO          = s.ESTADO,
                d.FECHAINICIO     = SYSDATE,
                d.TIPOTRANSACCION = 'U',
                d.ROWHASHVALUE    = s.ROWHASHVALUE
            WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;
        v_cant := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('DIM_TIPO_CONSULTA procesada: ' || v_cant || ' filas afectadas.');

        -- 1.5 DIM_FORMA_PAGO
        MERGE INTO DIM_FORMA_PAGO d
        USING stg_clinica_user.STG_FORMAS_PAGO s
        ON (d.BK_ID_FORMA_PAGO = s.ID_FORMA_PAGO)
        WHEN NOT MATCHED THEN
            INSERT (
                BK_ID_FORMA_PAGO, NOMBRE_FORMA_PAGO, CATEGORIA, ESTADO,
                CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
            )
            VALUES (
                s.ID_FORMA_PAGO, s.NOMBRE_FORMA_PAGO, s.CATEGORIA, s.ESTADO,
                1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
            )
        WHEN MATCHED THEN
            UPDATE SET
                d.NOMBRE_FORMA_PAGO = s.NOMBRE_FORMA_PAGO,
                d.CATEGORIA         = s.CATEGORIA,
                d.ESTADO            = s.ESTADO,
                d.FECHAINICIO       = SYSDATE,
                d.TIPOTRANSACCION   = 'U',
                d.ROWHASHVALUE      = s.ROWHASHVALUE
            WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;
        v_cant := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('DIM_FORMA_PAGO procesada: ' || v_cant || ' filas afectadas.');

        -- 1.6 DIM_PAGADOR (Normaliza Pacientes, Empresas y Aseguradoras)
        MERGE INTO DIM_PAGADOR d
        USING (
            -- Pacientes Particulares
            SELECT 
                'PACIENTE' AS TIPO_PAGADOR,
                p.ID_PACIENTE AS BK_ID_ORIGEN,
                p.NOMBRES || ' ' || p.APELLIDOS AS NOMBRE_PAGADOR,
                NULL AS NUMERO_IDENTIFICACION,
                'PARTICULAR' AS CATEGORIA_PAGADOR,
                NULL AS TELEFONO,
                p.DIRECCION,
                RAWTOHEX(STANDARD_HASH('PACIENTE|' || TO_CHAR(p.ID_PACIENTE) || '|' || p.NOMBRES || '|' || p.APELLIDOS || '|' || NVL(p.DIRECCION, '~'), 'SHA256')) AS HASH_PAG
            FROM stg_clinica_user.STG_PACIENTES p
            UNION ALL
            -- Empresas Afiliadas
            SELECT 
                'EMPRESA' AS TIPO_PAGADOR,
                e.ID_EMPRESA AS BK_ID_ORIGEN,
                e.NOMBRE_EMPRESA AS NOMBRE_PAGADOR,
                e.NIT AS NUMERO_IDENTIFICACION,
                'CORPORATIVO' AS CATEGORIA_PAGADOR,
                e.TELEFONO,
                e.DIRECCION,
                RAWTOHEX(STANDARD_HASH('EMPRESA|' || TO_CHAR(e.ID_EMPRESA) || '|' || e.NOMBRE_EMPRESA || '|' || e.NIT || '|' || NVL(e.TELEFONO, '~'), 'SHA256')) AS HASH_PAG
            FROM stg_clinica_user.STG_EMPRESAS e
            UNION ALL
            -- Compañías Aseguradoras
            SELECT 
                'ASEGURADORA' AS TIPO_PAGADOR,
                a.ID_ASEGURADORA AS BK_ID_ORIGEN,
                a.NOMBRE_ASEGURADORA AS NOMBRE_PAGADOR,
                a.NIT AS NUMERO_IDENTIFICACION,
                'ASEGURADORA' AS CATEGORIA_PAGADOR,
                a.TELEFONO,
                NULL AS DIRECCION,
                RAWTOHEX(STANDARD_HASH('ASEGURADORA|' || TO_CHAR(a.ID_ASEGURADORA) || '|' || a.NOMBRE_ASEGURADORA || '|' || a.NIT || '|' || NVL(a.TELEFONO, '~'), 'SHA256')) AS HASH_PAG
            FROM stg_clinica_user.STG_ASEGURADORAS a
        ) s
        ON (d.TIPO_PAGADOR = s.TIPO_PAGADOR AND d.BK_ID_ORIGEN = s.BK_ID_ORIGEN)
        WHEN NOT MATCHED THEN
            INSERT (
                TIPO_PAGADOR, BK_ID_ORIGEN, NOMBRE_PAGADOR, NUMERO_IDENTIFICACION,
                CATEGORIA_PAGADOR, TELEFONO, DIRECCION,
                CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
            )
            VALUES (
                s.TIPO_PAGADOR, s.BK_ID_ORIGEN, s.NOMBRE_PAGADOR, s.NUMERO_IDENTIFICACION,
                s.CATEGORIA_PAGADOR, s.TELEFONO, s.DIRECCION,
                1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I', s.HASH_PAG
            )
        WHEN MATCHED THEN
            UPDATE SET
                d.NOMBRE_PAGADOR        = s.NOMBRE_PAGADOR,
                d.NUMERO_IDENTIFICACION = s.NUMERO_IDENTIFICACION,
                d.CATEGORIA_PAGADOR     = s.CATEGORIA_PAGADOR,
                d.TELEFONO              = s.TELEFONO,
                d.DIRECCION             = s.DIRECCION,
                d.FECHAINICIO           = SYSDATE,
                d.TIPOTRANSACCION       = 'U',
                d.ROWHASHVALUE          = s.HASH_PAG
            WHERE d.ROWHASHVALUE != s.HASH_PAG;
        v_cant := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('DIM_PAGADOR procesada: ' || v_cant || ' filas afectadas.');

        COMMIT;
    END SP_CARGAR_DIM_SCD1;

    -- ========================================================================
    -- 2. CARGA DE DIMENSIONES SCD TIPO 2 (UPDATE CADUCIDAD + INSERT VERSIÓN)
    -- ========================================================================
    PROCEDURE SP_CARGAR_DIM_SCD2(p_tipo_carga IN VARCHAR2) IS
        v_upd NUMBER := 0;
        v_ins NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- 2. Cargando Dimensiones SCD Tipo 2 ---');

        -- --------------------------------------------------------------------
        -- 2.1 DIM_CLINICA
        -- --------------------------------------------------------------------
        UPDATE DIM_CLINICA d
        SET d.CURRENTFLAG     = 0,
            d.FECHAFIN        = TRUNC(SYSDATE) - (1/86400),
            d.TIPOTRANSACCION = 'U'
        WHERE d.CURRENTFLAG = 1
          AND EXISTS (
              SELECT 1 
              FROM stg_clinica_user.STG_CLINICAS s
              WHERE s.ID_CLINICA = d.BK_ID_CLINICA
                AND RAWTOHEX(STANDARD_HASH(
                    NVL(s.NOMBRE_CLINICA, '~') || '|' ||
                    NVL(TO_CHAR(s.ID_UBICACION), '~') || '|' ||
                    NVL(s.DIRECCION, '~') || '|' ||
                    NVL(s.TELEFONO, '~') || '|' ||
                    NVL(s.ESTADO, '~'),
                    'SHA256'
                )) != d.ROWHASHVALUE
          );
        v_upd := SQL%ROWCOUNT;

        INSERT INTO DIM_CLINICA (
            BK_ID_CLINICA, NOMBRE_CLINICA, BK_ID_UBICACION, PAIS, DEPARTAMENTO,
            MUNICIPIO, DISTRITO, CODIGO_POSTAL, DIRECCION, TELEFONO, FECHA_APERTURA, ESTADO,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        SELECT 
            c.ID_CLINICA, c.NOMBRE_CLINICA, c.ID_UBICACION, u.PAIS, u.DEPARTAMENTO,
            u.MUNICIPIO, u.DISTRITO, u.CODIGO_POSTAL, c.DIRECCION, c.TELEFONO, c.FECHA_APERTURA, c.ESTADO,
            1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I',
            RAWTOHEX(STANDARD_HASH(
                NVL(c.NOMBRE_CLINICA, '~') || '|' ||
                NVL(TO_CHAR(c.ID_UBICACION), '~') || '|' ||
                NVL(c.DIRECCION, '~') || '|' ||
                NVL(c.TELEFONO, '~') || '|' ||
                NVL(c.ESTADO, '~'),
                'SHA256'
            ))
        FROM stg_clinica_user.STG_CLINICAS c
        INNER JOIN stg_clinica_user.STG_UBICACIONES u ON c.ID_UBICACION = u.ID_UBICACION
        WHERE NOT EXISTS (
            SELECT 1 FROM DIM_CLINICA d
            WHERE d.BK_ID_CLINICA = c.ID_CLINICA
              AND d.CURRENTFLAG = 1
              AND d.ROWHASHVALUE = RAWTOHEX(STANDARD_HASH(
                  NVL(c.NOMBRE_CLINICA, '~') || '|' ||
                  NVL(TO_CHAR(c.ID_UBICACION), '~') || '|' ||
                  NVL(c.DIRECCION, '~') || '|' ||
                  NVL(c.TELEFONO, '~') || '|' ||
                  NVL(c.ESTADO, '~'),
                  'SHA256'
              ))
        );
        v_ins := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('DIM_CLINICA procesada: ' || v_upd || ' caducadas (SCD2), ' || v_ins || ' activas insertadas.');

        -- --------------------------------------------------------------------
        -- 2.2 DIM_MEDICO
        -- --------------------------------------------------------------------
        UPDATE DIM_MEDICO d
        SET d.CURRENTFLAG     = 0,
            d.FECHAFIN        = TRUNC(SYSDATE) - (1/86400),
            d.TIPOTRANSACCION = 'U'
        WHERE d.CURRENTFLAG = 1
          AND EXISTS (
              SELECT 1 
              FROM stg_clinica_user.STG_MEDICOS s
              WHERE s.ID_MEDICO = d.BK_ID_MEDICO
                AND RAWTOHEX(STANDARD_HASH(
                    NVL(s.NOMBRES, '~') || '|' ||
                    NVL(s.APELLIDOS, '~') || '|' ||
                    NVL(TO_CHAR(s.ID_CLINICA), '~') || '|' ||
                    NVL(s.NUM_COLEGIADO, '~') || '|' ||
                    NVL(s.ESTADO, '~'),
                    'SHA256'
                )) != d.ROWHASHVALUE
          );
        v_upd := SQL%ROWCOUNT;

        INSERT INTO DIM_MEDICO (
            BK_ID_MEDICO, NOMBRES, APELLIDOS, NOMBRE_COMPLETO,
            BK_ID_CLINICA_BASE, NOMBRE_CLINICA_BASE, NUM_COLEGIADO, FECHA_INGRESO, ESTADO,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        SELECT 
            m.ID_MEDICO, m.NOMBRES, m.APELLIDOS, m.NOMBRES || ' ' || m.APELLIDOS,
            m.ID_CLINICA, c.NOMBRE_CLINICA, m.NUM_COLEGIADO, m.FECHA_INGRESO, m.ESTADO,
            1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I',
            RAWTOHEX(STANDARD_HASH(
                NVL(m.NOMBRES, '~') || '|' ||
                NVL(m.APELLIDOS, '~') || '|' ||
                NVL(TO_CHAR(m.ID_CLINICA), '~') || '|' ||
                NVL(m.NUM_COLEGIADO, '~') || '|' ||
                NVL(m.ESTADO, '~'),
                'SHA256'
            ))
        FROM stg_clinica_user.STG_MEDICOS m
        INNER JOIN stg_clinica_user.STG_CLINICAS c ON m.ID_CLINICA = c.ID_CLINICA
        WHERE NOT EXISTS (
            SELECT 1 FROM DIM_MEDICO d
            WHERE d.BK_ID_MEDICO = m.ID_MEDICO
              AND d.CURRENTFLAG = 1
              AND d.ROWHASHVALUE = RAWTOHEX(STANDARD_HASH(
                  NVL(m.NOMBRES, '~') || '|' ||
                  NVL(m.APELLIDOS, '~') || '|' ||
                  NVL(TO_CHAR(m.ID_CLINICA), '~') || '|' ||
                  NVL(m.NUM_COLEGIADO, '~') || '|' ||
                  NVL(m.ESTADO, '~'),
                  'SHA256'
              ))
        );
        v_ins := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('DIM_MEDICO procesada: ' || v_upd || ' caducadas (SCD2), ' || v_ins || ' activas insertadas.');

        -- --------------------------------------------------------------------
        -- 2.3 DIM_PACIENTE (Residencia, Convenios Empresa y Aseguradora)
        -- --------------------------------------------------------------------
        UPDATE DIM_PACIENTE d
        SET d.CURRENTFLAG     = 0,
            d.FECHAFIN        = TRUNC(SYSDATE) - (1/86400),
            d.TIPOTRANSACCION = 'U'
        WHERE d.CURRENTFLAG = 1
          AND EXISTS (
              SELECT 1 
              FROM stg_clinica_user.STG_PACIENTES s
              WHERE s.ID_PACIENTE = d.BK_ID_PACIENTE
                AND RAWTOHEX(STANDARD_HASH(
                    NVL(s.DIRECCION, '~') || '|' ||
                    NVL(TO_CHAR(s.ID_UBICACION), '~') || '|' ||
                    NVL(TO_CHAR(s.ID_CLINICA_HABITUAL), '~') || '|' ||
                    NVL(TO_CHAR(s.ID_EMPRESA), '~') || '|' ||
                    NVL(TO_CHAR(s.ID_ASEGURADORA), '~') || '|' ||
                    NVL(s.NUMERO_POLIZA, '~'),
                    'SHA256'
                )) != d.ROWHASHVALUE
          );
        v_upd := SQL%ROWCOUNT;

        INSERT INTO DIM_PACIENTE (
            BK_ID_PACIENTE, NOMBRES, APELLIDOS, NOMBRE_COMPLETO,
            FECHA_NACIMIENTO, EDAD, GRUPO_ETARIO, SEXO, DIRECCION,
            BK_ID_UBICACION, PAIS, DEPARTAMENTO, MUNICIPIO, DISTRITO, CODIGO_POSTAL,
            BK_ID_CLINICA_HABITUAL, NOMBRE_CLINICA_HABITUAL,
            BK_ID_EMPRESA, NOMBRE_EMPRESA, SECTOR_EMPRESA,
            BK_ID_ASEGURADORA, NOMBRE_ASEGURADORA, TIPO_COBERTURA_ASEGURADORA,
            NUMERO_POLIZA, FECHA_REGISTRO,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        SELECT 
            p.ID_PACIENTE, p.NOMBRES, p.APELLIDOS, p.NOMBRES || ' ' || p.APELLIDOS,
            p.FECHA_NACIMIENTO,
            TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) AS EDAD,
            CASE 
                WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) < 18 THEN '0-17 Pediátrico'
                WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) BETWEEN 18 AND 29 THEN '18-29 Joven'
                WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) BETWEEN 30 AND 49 THEN '30-49 Adulto'
                WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) BETWEEN 50 AND 64 THEN '50-64 Adulto Mayor'
                ELSE '65+ Tercera Edad'
            END AS GRUPO_ETARIO,
            p.SEXO, p.DIRECCION, p.ID_UBICACION, u.PAIS, u.DEPARTAMENTO, u.MUNICIPIO, u.DISTRITO, u.CODIGO_POSTAL,
            p.ID_CLINICA_HABITUAL, c.NOMBRE_CLINICA, p.ID_EMPRESA, e.NOMBRE_EMPRESA, e.SECTOR,
            p.ID_ASEGURADORA, a.NOMBRE_ASEGURADORA, a.TIPO_COBERTURA, p.NUMERO_POLIZA, p.FECHA_REGISTRO,
            1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I',
            RAWTOHEX(STANDARD_HASH(
                NVL(p.DIRECCION, '~') || '|' ||
                NVL(TO_CHAR(p.ID_UBICACION), '~') || '|' ||
                NVL(TO_CHAR(p.ID_CLINICA_HABITUAL), '~') || '|' ||
                NVL(TO_CHAR(p.ID_EMPRESA), '~') || '|' ||
                NVL(TO_CHAR(p.ID_ASEGURADORA), '~') || '|' ||
                NVL(p.NUMERO_POLIZA, '~'),
                'SHA256'
            ))
        FROM stg_clinica_user.STG_PACIENTES p
        LEFT JOIN stg_clinica_user.STG_UBICACIONES u ON p.ID_UBICACION = u.ID_UBICACION
        LEFT JOIN stg_clinica_user.STG_CLINICAS c    ON p.ID_CLINICA_HABITUAL = c.ID_CLINICA
        LEFT JOIN stg_clinica_user.STG_EMPRESAS e    ON p.ID_EMPRESA = e.ID_EMPRESA
        LEFT JOIN stg_clinica_user.STG_ASEGURADORAS a ON p.ID_ASEGURADORA = a.ID_ASEGURADORA
        WHERE NOT EXISTS (
            SELECT 1 FROM DIM_PACIENTE d
            WHERE d.BK_ID_PACIENTE = p.ID_PACIENTE
              AND d.CURRENTFLAG = 1
              AND d.ROWHASHVALUE = RAWTOHEX(STANDARD_HASH(
                  NVL(p.DIRECCION, '~') || '|' ||
                  NVL(TO_CHAR(p.ID_UBICACION), '~') || '|' ||
                  NVL(TO_CHAR(p.ID_CLINICA_HABITUAL), '~') || '|' ||
                  NVL(TO_CHAR(p.ID_EMPRESA), '~') || '|' ||
                  NVL(TO_CHAR(p.ID_ASEGURADORA), '~') || '|' ||
                  NVL(p.NUMERO_POLIZA, '~'),
                  'SHA256'
              ))
        );
        v_ins := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('DIM_PACIENTE procesada: ' || v_upd || ' caducadas (SCD2), ' || v_ins || ' activas insertadas.');

        COMMIT;
    END SP_CARGAR_DIM_SCD2;

    -- ========================================================================
    -- 3. CARGA DE TABLAS DE HECHOS (SURROGATE KEY LOOKUPS HACIA DIMENSIONES)
    -- ========================================================================
    PROCEDURE SP_CARGAR_FACTS(p_tipo_carga IN VARCHAR2) IS
        v_cant NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- 3. Cargando Tablas de Hechos (Fact Tables) ---');

        -- --------------------------------------------------------------------
        -- 3.1 FACT_CONSULTAS (Fact Snapshot Acumulativo de Atención y Facturación)
        -- --------------------------------------------------------------------
        MERGE INTO FACT_CONSULTAS f
        USING (
            WITH PROCEDIMIENTOS_AGREGADOS AS (
                SELECT 
                    ID_CONSULTA,
                    COUNT(*) AS CANTIDAD_PROCEDIMIENTOS,
                    NVL(SUM(SUBTOTAL), 0) AS TOTAL_PROCEDIMIENTOS
                FROM stg_clinica_user.STG_CONSULTAS_PROCEDIMIENTOS
                GROUP BY ID_CONSULTA
            )
            SELECT 
                c.ID_CONSULTA AS BK_ID_CONSULTA,
                NVL(t.SK_TIEMPO, 19000101) AS SK_TIEMPO,
                dp.SK_PACIENTE,
                dc.SK_CLINICA,
                dm.SK_MEDICO,
                de.SK_ESPECIALIDAD,
                dtc.SK_TIPO_CONSULTA,
                du.SK_UBICACION AS SK_UBICACION_PACIENTE,
                1 AS CANTIDAD_CONSULTAS,
                c.PRECIO_CONSULTA AS PRECIO_HONORARIOS,
                NVL(pa.CANTIDAD_PROCEDIMIENTOS, 0) AS CANTIDAD_PROCEDIMIENTOS,
                NVL(pa.TOTAL_PROCEDIMIENTOS, 0) AS TOTAL_PROCEDIMIENTOS,
                NVL(cob.MONTO_TOTAL_FACTURADO, (c.PRECIO_CONSULTA + NVL(pa.TOTAL_PROCEDIMIENTOS, 0))) AS MONTO_TOTAL_FACTURADO,
                NVL(cob.MONTO_TOTAL_PAGADO, 0) AS MONTO_TOTAL_PAGADO,
                NVL(cob.SALDO_PENDIENTE, (c.PRECIO_CONSULTA + NVL(pa.TOTAL_PROCEDIMIENTOS, 0) - NVL(cob.MONTO_TOTAL_PAGADO, 0))) AS SALDO_PENDIENTE,
                NVL(cob.ESTADO_COBRO, 'PENDIENTE') AS ESTADO_COBRO,
                CASE WHEN NVL(pa.CANTIDAD_PROCEDIMIENTOS, 0) > 0 THEN 'S' ELSE 'N' END AS TIENE_PROCEDIMIENTOS,
                c.MOTIVO_CONSULTA,
                RAWTOHEX(STANDARD_HASH(
                    TO_CHAR(c.ID_CONSULTA) || '|' ||
                    TO_CHAR(NVL(cob.MONTO_TOTAL_FACTURADO, 0), 'FM999999990.00') || '|' ||
                    TO_CHAR(NVL(cob.MONTO_TOTAL_PAGADO, 0), 'FM999999990.00') || '|' ||
                    NVL(cob.ESTADO_COBRO, 'PENDIENTE'),
                    'SHA256'
                )) AS HASH_HECHO
            FROM stg_clinica_user.STG_CONSULTAS c
            LEFT JOIN DIM_TIEMPO t 
                ON t.FECHA = TRUNC(c.FECHA_CONSULTA)
            INNER JOIN DIM_PACIENTE dp 
                ON dp.BK_ID_PACIENTE = c.ID_PACIENTE
               AND (c.FECHA_CONSULTA BETWEEN dp.FECHAINICIO AND dp.FECHAFIN OR dp.CURRENTFLAG = 1)
            INNER JOIN DIM_CLINICA dc 
                ON dc.BK_ID_CLINICA = c.ID_CLINICA
               AND (c.FECHA_CONSULTA BETWEEN dc.FECHAINICIO AND dc.FECHAFIN OR dc.CURRENTFLAG = 1)
            INNER JOIN DIM_MEDICO dm 
                ON dm.BK_ID_MEDICO = c.ID_MEDICO
               AND (c.FECHA_CONSULTA BETWEEN dm.FECHAINICIO AND dm.FECHAFIN OR dm.CURRENTFLAG = 1)
            INNER JOIN DIM_ESPECIALIDAD de 
                ON de.BK_ID_ESPECIALIDAD = c.ID_ESPECIALIDAD
            INNER JOIN DIM_TIPO_CONSULTA dtc 
                ON dtc.BK_ID_TIPO_CONSULTA = c.ID_TIPO_CONSULTA
            INNER JOIN DIM_UBICACION du 
                ON du.BK_ID_UBICACION = dp.BK_ID_UBICACION
            LEFT JOIN PROCEDIMIENTOS_AGREGADOS pa 
                ON pa.ID_CONSULTA = c.ID_CONSULTA
            LEFT JOIN stg_clinica_user.STG_COBROS_CONSULTA cob 
                ON cob.ID_CONSULTA = c.ID_CONSULTA
        ) s
        ON (f.BK_ID_CONSULTA = s.BK_ID_CONSULTA)
        WHEN NOT MATCHED THEN
            INSERT (
                BK_ID_CONSULTA, SK_TIEMPO, SK_PACIENTE, SK_CLINICA, SK_MEDICO,
                SK_ESPECIALIDAD, SK_TIPO_CONSULTA, SK_UBICACION_PACIENTE,
                CANTIDAD_CONSULTAS, PRECIO_HONORARIOS, CANTIDAD_PROCEDIMIENTOS, TOTAL_PROCEDIMIENTOS,
                MONTO_TOTAL_FACTURADO, MONTO_TOTAL_PAGADO, SALDO_PENDIENTE,
                ESTADO_COBRO, TIENE_PROCEDIMIENTOS, MOTIVO_CONSULTA,
                CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
            )
            VALUES (
                s.BK_ID_CONSULTA, s.SK_TIEMPO, s.SK_PACIENTE, s.SK_CLINICA, s.SK_MEDICO,
                s.SK_ESPECIALIDAD, s.SK_TIPO_CONSULTA, s.SK_UBICACION_PACIENTE,
                s.CANTIDAD_CONSULTAS, s.PRECIO_HONORARIOS, s.CANTIDAD_PROCEDIMIENTOS, s.TOTAL_PROCEDIMIENTOS,
                s.MONTO_TOTAL_FACTURADO, s.MONTO_TOTAL_PAGADO, s.SALDO_PENDIENTE,
                s.ESTADO_COBRO, s.TIENE_PROCEDIMIENTOS, s.MOTIVO_CONSULTA,
                1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I', s.HASH_HECHO
            )
        WHEN MATCHED THEN
            UPDATE SET
                f.MONTO_TOTAL_FACTURADO = s.MONTO_TOTAL_FACTURADO,
                f.MONTO_TOTAL_PAGADO    = s.MONTO_TOTAL_PAGADO,
                f.SALDO_PENDIENTE       = s.SALDO_PENDIENTE,
                f.ESTADO_COBRO          = s.ESTADO_COBRO,
                f.FECHAINICIO           = SYSDATE,
                f.TIPOTRANSACCION       = 'U',
                f.ROWHASHVALUE          = s.HASH_HECHO
            WHERE f.ROWHASHVALUE != s.HASH_HECHO;
        v_cant := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('FACT_CONSULTAS cargada: ' || v_cant || ' filas procesadas.');

        -- --------------------------------------------------------------------
        -- 3.2 FACT_CONSULTA_DIAGNOSTICOS (Frecuencia Epidemiológica y Costo Prorrateado)
        -- --------------------------------------------------------------------
        MERGE INTO FACT_CONSULTA_DIAGNOSTICOS f
        USING (
            WITH CONTEO_DIAG AS (
                SELECT 
                    ID_CONSULTA,
                    COUNT(*) AS TOTAL_DIAG
                FROM stg_clinica_user.STG_DIAGNOSTICOS
                GROUP BY ID_CONSULTA
            )
            SELECT 
                d.ID_DIAGNOSTICO AS BK_ID_DIAGNOSTICO,
                d.ID_CONSULTA    AS BK_ID_CONSULTA,
                fc.SK_TIEMPO,
                fc.SK_PACIENTE,
                fc.SK_CLINICA,
                fc.SK_MEDICO,
                fc.SK_ESPECIALIDAD,
                denf.SK_ENFERMEDAD,
                fc.SK_UBICACION_PACIENTE,
                1 AS CONTEO_DIAGNOSTICO,
                cd.TOTAL_DIAG AS TOTAL_DIAGNOSTICOS_CONS,
                fc.MONTO_TOTAL_FACTURADO AS MONTO_TOTAL_CONSULTA,
                ROUND(fc.MONTO_TOTAL_FACTURADO / cd.TOTAL_DIAG, 2) AS MONTO_PRORRATEADO,
                d.OBSERVACIONES,
                RAWTOHEX(STANDARD_HASH(
                    TO_CHAR(d.ID_DIAGNOSTICO) || '|' ||
                    TO_CHAR(denf.SK_ENFERMEDAD) || '|' ||
                    TO_CHAR(ROUND(fc.MONTO_TOTAL_FACTURADO / cd.TOTAL_DIAG, 2), 'FM999999990.00'),
                    'SHA256'
                )) AS HASH_HECHO
            FROM stg_clinica_user.STG_DIAGNOSTICOS d
            INNER JOIN CONTEO_DIAG cd 
                ON cd.ID_CONSULTA = d.ID_CONSULTA
            INNER JOIN FACT_CONSULTAS fc 
                ON fc.BK_ID_CONSULTA = d.ID_CONSULTA
            INNER JOIN DIM_ENFERMEDAD denf 
                ON denf.BK_ID_ENFERMEDAD = d.ID_ENFERMEDAD
        ) s
        ON (f.BK_ID_DIAGNOSTICO = s.BK_ID_DIAGNOSTICO)
        WHEN NOT MATCHED THEN
            INSERT (
                BK_ID_DIAGNOSTICO, BK_ID_CONSULTA, SK_TIEMPO, SK_PACIENTE, SK_CLINICA,
                SK_MEDICO, SK_ESPECIALIDAD, SK_ENFERMEDAD, SK_UBICACION_PACIENTE,
                CONTEO_DIAGNOSTICO, TOTAL_DIAGNOSTICOS_CONS, MONTO_TOTAL_CONSULTA, MONTO_PRORRATEADO,
                OBSERVACIONES,
                CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
            )
            VALUES (
                s.BK_ID_DIAGNOSTICO, s.BK_ID_CONSULTA, s.SK_TIEMPO, s.SK_PACIENTE, s.SK_CLINICA,
                s.SK_MEDICO, s.SK_ESPECIALIDAD, s.SK_ENFERMEDAD, s.SK_UBICACION_PACIENTE,
                s.CONTEO_DIAGNOSTICO, s.TOTAL_DIAGNOSTICOS_CONS, s.MONTO_TOTAL_CONSULTA, s.MONTO_PRORRATEADO,
                s.OBSERVACIONES,
                1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I', s.HASH_HECHO
            )
        WHEN MATCHED THEN
            UPDATE SET
                f.MONTO_TOTAL_CONSULTA = s.MONTO_TOTAL_CONSULTA,
                f.MONTO_PRORRATEADO    = s.MONTO_PRORRATEADO,
                f.OBSERVACIONES        = s.OBSERVACIONES,
                f.FECHAINICIO          = SYSDATE,
                f.TIPOTRANSACCION      = 'U',
                f.ROWHASHVALUE         = s.HASH_HECHO
            WHERE f.ROWHASHVALUE != s.HASH_HECHO;
        v_cant := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('FACT_CONSULTA_DIAGNOSTICOS cargada: ' || v_cant || ' filas procesadas.');

        -- --------------------------------------------------------------------
        -- 3.3 FACT_COBROS_DISTRIBUCION (Responsabilidad por Pagador y Coberturas)
        -- --------------------------------------------------------------------
        MERGE INTO FACT_COBROS_DISTRIBUCION f
        USING (
            WITH FORMA_PAGO_PREDOMINANTE AS (
                SELECT 
                    ID_DISTRIBUCION,
                    ID_FORMA_PAGO,
                    ROW_NUMBER() OVER (PARTITION BY ID_DISTRIBUCION ORDER BY MONTO_TRANSACCION DESC) AS RN
                FROM stg_clinica_user.STG_TRANSACCIONES_PAGO
            )
            SELECT 
                dist.ID_DISTRIBUCION AS BK_ID_DISTRIBUCION,
                dist.ID_COBRO        AS BK_ID_COBRO,
                cob.ID_CONSULTA      AS BK_ID_CONSULTA,
                fc.SK_TIEMPO,
                fc.SK_PACIENTE,
                fc.SK_CLINICA,
                dpag.SK_PAGADOR,
                NVL(dfp.SK_FORMA_PAGO, 1) AS SK_FORMA_PAGO_PREDOMINANTE,
                dist.PORCENTAJE      AS PORCENTAJE_COBERTURA,
                dist.MONTO_ASIGNADO,
                dist.MONTO_PAGADO,
                dist.SALDO_PENDIENTE,
                dist.ESTADO          AS ESTADO_DISTRIBUCION,
                dist.TIPO_PAGADOR,
                RAWTOHEX(STANDARD_HASH(
                    TO_CHAR(dist.ID_DISTRIBUCION) || '|' ||
                    TO_CHAR(dist.MONTO_ASIGNADO, 'FM999999990.00') || '|' ||
                    TO_CHAR(dist.MONTO_PAGADO, 'FM999999990.00') || '|' ||
                    dist.ESTADO,
                    'SHA256'
                )) AS HASH_HECHO
            FROM stg_clinica_user.STG_DISTRIBUCION_COBRO dist
            INNER JOIN stg_clinica_user.STG_COBROS_CONSULTA cob 
                ON cob.ID_COBRO = dist.ID_COBRO
            INNER JOIN FACT_CONSULTAS fc 
                ON fc.BK_ID_CONSULTA = cob.ID_CONSULTA
            INNER JOIN DIM_PAGADOR dpag 
                ON dpag.TIPO_PAGADOR = dist.TIPO_PAGADOR
               AND dpag.BK_ID_ORIGEN = CASE 
                   WHEN dist.TIPO_PAGADOR = 'PACIENTE'    THEN dist.ID_PACIENTE
                   WHEN dist.TIPO_PAGADOR = 'EMPRESA'     THEN dist.ID_EMPRESA
                   WHEN dist.TIPO_PAGADOR = 'ASEGURADORA' THEN dist.ID_ASEGURADORA
               END
            LEFT JOIN FORMA_PAGO_PREDOMINANTE fpp 
                ON fpp.ID_DISTRIBUCION = dist.ID_DISTRIBUCION AND fpp.RN = 1
            LEFT JOIN DIM_FORMA_PAGO dfp 
                ON dfp.BK_ID_FORMA_PAGO = fpp.ID_FORMA_PAGO
        ) s
        ON (f.BK_ID_DISTRIBUCION = s.BK_ID_DISTRIBUCION)
        WHEN NOT MATCHED THEN
            INSERT (
                BK_ID_DISTRIBUCION, BK_ID_COBRO, BK_ID_CONSULTA,
                SK_TIEMPO, SK_PACIENTE, SK_CLINICA, SK_PAGADOR, SK_FORMA_PAGO_PREDOMINANTE,
                PORCENTAJE_COBERTURA, MONTO_ASIGNADO, MONTO_PAGADO, SALDO_PENDIENTE,
                ESTADO_DISTRIBUCION, TIPO_PAGADOR,
                CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
            )
            VALUES (
                s.BK_ID_DISTRIBUCION, s.BK_ID_COBRO, s.BK_ID_CONSULTA,
                s.SK_TIEMPO, s.SK_PACIENTE, s.SK_CLINICA, s.SK_PAGADOR, s.SK_FORMA_PAGO_PREDOMINANTE,
                s.PORCENTAJE_COBERTURA, s.MONTO_ASIGNADO, s.MONTO_PAGADO, s.SALDO_PENDIENTE,
                s.ESTADO_DISTRIBUCION, s.TIPO_PAGADOR,
                1, p_tipo_carga, SYSDATE, DATE '2999-12-31', 'I', s.HASH_HECHO
            )
        WHEN MATCHED THEN
            UPDATE SET
                f.MONTO_PAGADO        = s.MONTO_PAGADO,
                f.SALDO_PENDIENTE     = s.SALDO_PENDIENTE,
                f.ESTADO_DISTRIBUCION = s.ESTADO_DISTRIBUCION,
                f.FECHAINICIO         = SYSDATE,
                f.TIPOTRANSACCION     = 'U',
                f.ROWHASHVALUE        = s.HASH_HECHO
            WHERE f.ROWHASHVALUE != s.HASH_HECHO;
        v_cant := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('FACT_COBROS_DISTRIBUCION cargada: ' || v_cant || ' filas procesadas.');

        COMMIT;
    END SP_CARGAR_FACTS;

    -- ========================================================================
    -- 4. PROCEDIMIENTO MAESTRO ORQUESTADOR DE TODA LA CARGA
    -- ========================================================================
    PROCEDURE SP_LOAD_DWH_MASTER(
        p_tipo_carga    IN VARCHAR2 DEFAULT 'INCREMENTAL',
        p_dias_lookback IN NUMBER   DEFAULT 3,
        p_fecha_corte   IN DATE     DEFAULT NULL
    ) IS
        v_inicio TIMESTAMP := SYSTIMESTAMP;
        v_tipo   VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    BEGIN
        DBMS_OUTPUT.PUT_LINE('================================================================');
        DBMS_OUTPUT.PUT_LINE('INICIO DEL PIPELINE ANALÍTICO COMPLETO: DWH RED DE CLÍNICAS');
        DBMS_OUTPUT.PUT_LINE('Modo de Carga: ' || v_tipo || 
                             ' | Ventana Días Lookback: ' || p_dias_lookback);
        DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('================================================================');

        -- Paso A: Extracción desde OLTP hacia Staging con ventana optimizada
        DBMS_OUTPUT.PUT_LINE('>>> EJECUTANDO EXTRACCIÓN HACIA STAGING...');
        stg_clinica_user.SP_EXTRACT_OLTP_TO_STG(v_tipo, p_dias_lookback, p_fecha_corte);

        -- Paso B: Carga de Dimensiones SCD Tipo 1
        DBMS_OUTPUT.PUT_LINE('>>> EJECUTANDO CARGA DE DIMENSIONES SCD TIPO 1...');
        SP_CARGAR_DIM_SCD1(v_tipo);

        -- Paso C: Carga de Dimensiones SCD Tipo 2
        DBMS_OUTPUT.PUT_LINE('>>> EJECUTANDO CARGA DE DIMENSIONES SCD TIPO 2 (HISTÓRICAS)...');
        SP_CARGAR_DIM_SCD2(v_tipo);

        -- Paso D: Carga de Tablas de Hechos (Facts)
        DBMS_OUTPUT.PUT_LINE('>>> EJECUTANDO CARGA DE TABLAS DE HECHOS (CON LOOKUPS)...');
        SP_CARGAR_FACTS(v_tipo);

        DBMS_OUTPUT.PUT_LINE('================================================================');
        DBMS_OUTPUT.PUT_LINE('PIPELINE DWH MASTER FINALIZADO EXITOSAMENTE');
        DBMS_OUTPUT.PUT_LINE('Duración total: ' || TO_CHAR(SYSTIMESTAMP - v_inicio));
        DBMS_OUTPUT.PUT_LINE('================================================================');

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('*** ERROR CRÍTICO EN SP_LOAD_DWH_MASTER: ' || SQLERRM || ' ***');
            RAISE;
    END SP_LOAD_DWH_MASTER;

END PKG_DWH_ETL_PIPELINE;
/

-- Wrapper público de compatibilidad directa
CREATE OR REPLACE PROCEDURE SP_LOAD_DWH_MASTER (
    p_tipo_carga    IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback IN NUMBER   DEFAULT 3,
    p_fecha_corte   IN DATE     DEFAULT NULL
)
AUTHID CURRENT_USER
IS
BEGIN
    PKG_DWH_ETL_PIPELINE.SP_LOAD_DWH_MASTER(p_tipo_carga, p_dias_lookback, p_fecha_corte);
END SP_LOAD_DWH_MASTER;
/

COMMIT;
