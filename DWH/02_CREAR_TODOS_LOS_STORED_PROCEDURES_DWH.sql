/* ============================================================================
   PROYECTO DATA WAREHOUSE - RED DE CLINICAS
   MASTER DDL/PLSQL: COMPILACION DE TODOS LOS STORED PROCEDURES DE DWH (15)
   ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database (XEPDB1)
   ============================================================================ */

-- Permite ver los mensajes de DBMS_OUTPUT en consolas SQL*Plus / SQLcl / DBeaver
SET SERVEROUTPUT ON SIZE UNLIMITED;


-- ============================================================================
-- (1/15) PROCEDIMIENTO: SP_POBLAR_DIM_TIEMPO.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_POBLAR_DIM_TIEMPO
-- OBJETIVO: Generar y cargar el calendario dimensional continuo (2024 al 2030)
-- ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_POBLAR_DIM_TIEMPO (
    p_anio_inicio IN NUMBER DEFAULT 2024,
    p_anio_fin    IN NUMBER DEFAULT 2030
)
AUTHID DEFINER
IS
    v_fecha_inicio DATE;
    v_fecha_fin    DATE;
    v_total_dias   NUMBER;
    v_insertados   NUMBER := 0;
BEGIN
    v_fecha_inicio := TO_DATE(p_anio_inicio || '-01-01', 'YYYY-MM-DD');
    v_fecha_fin    := TO_DATE(p_anio_fin || '-12-31', 'YYYY-MM-DD');
    v_total_dias   := (v_fecha_fin - v_fecha_inicio) + 1;

    DBMS_OUTPUT.PUT_LINE('Iniciando poblamiento de DIM_TIEMPO desde ' || 
                         TO_CHAR(v_fecha_inicio, 'YYYY-MM-DD') || ' hasta ' || 
                         TO_CHAR(v_fecha_fin, 'YYYY-MM-DD') || ' (' || v_total_dias || ' días)...');

    -- 1. Insertar Registro Miembro Desconocido / No Asignado (Kimball Best Practice)
    MERGE INTO DIM_TIEMPO d
    USING (
        SELECT 
            19000101 AS SK_TIEMPO,
            DATE '1900-01-01' AS FECHA,
            1900 AS ANIO,
            1 AS SEMESTRE,
            1 AS TRIMESTRE,
            'No Aplica' AS NOMBRE_TRIMESTRE,
            1 AS MES,
            'No Aplica' AS NOMBRE_MES,
            'N/A' AS MES_CORTO,
            1 AS SEMANA_ANIO,
            1 AS DIA_MES,
            1 AS DIA_SEMANA,
            'No Aplica' AS NOMBRE_DIA,
            0 AS ES_FIN_SEMANA,
            1 AS CURRENTFLAG,
            'FULL' AS TIPOCARGA,
            SYSDATE AS FECHAINICIO,
            DATE '2999-12-31' AS FECHAFIN,
            'I' AS TIPOTRANSACCION,
            RAWTOHEX(STANDARD_HASH('1900-01-01|No Aplica|1900', 'SHA256')) AS ROWHASHVALUE
        FROM DUAL
    ) s
    ON (d.SK_TIEMPO = s.SK_TIEMPO)
    WHEN NOT MATCHED THEN
        INSERT (
            SK_TIEMPO, FECHA, ANIO, SEMESTRE, TRIMESTRE, NOMBRE_TRIMESTRE,
            MES, NOMBRE_MES, MES_CORTO, SEMANA_ANIO, DIA_MES, DIA_SEMANA,
            NOMBRE_DIA, ES_FIN_SEMANA,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.SK_TIEMPO, s.FECHA, s.ANIO, s.SEMESTRE, s.TRIMESTRE, s.NOMBRE_TRIMESTRE,
            s.MES, s.NOMBRE_MES, s.MES_CORTO, s.SEMANA_ANIO, s.DIA_MES, s.DIA_SEMANA,
            s.NOMBRE_DIA, s.ES_FIN_SEMANA,
            s.CURRENTFLAG, s.TIPOCARGA, s.FECHAINICIO, s.FECHAFIN, s.TIPOTRANSACCION, s.ROWHASHVALUE
        );

    -- 2. Inserción Masiva del Rango de Fechas
    MERGE INTO DIM_TIEMPO d
    USING (
        WITH GENERADOR_FECHAS AS (
            SELECT v_fecha_inicio + LEVEL - 1 AS F
            FROM DUAL
            CONNECT BY LEVEL <= (v_fecha_fin - v_fecha_inicio + 1)
        )
        SELECT 
            TO_NUMBER(TO_CHAR(F, 'YYYYMMDD')) AS SK_TIEMPO,
            F AS FECHA,
            TO_NUMBER(TO_CHAR(F, 'YYYY')) AS ANIO,
            CASE WHEN TO_NUMBER(TO_CHAR(F, 'MM')) <= 6 THEN 1 ELSE 2 END AS SEMESTRE,
            TO_NUMBER(TO_CHAR(F, 'Q')) AS TRIMESTRE,
            'Trimestre ' || TO_CHAR(F, 'Q') AS NOMBRE_TRIMESTRE,
            TO_NUMBER(TO_CHAR(F, 'MM')) AS MES,
            CASE TO_NUMBER(TO_CHAR(F, 'MM'))
                WHEN 1  THEN 'Enero'
                WHEN 2  THEN 'Febrero'
                WHEN 3  THEN 'Marzo'
                WHEN 4  THEN 'Abril'
                WHEN 5  THEN 'Mayo'
                WHEN 6  THEN 'Junio'
                WHEN 7  THEN 'Julio'
                WHEN 8  THEN 'Agosto'
                WHEN 9  THEN 'Septiembre'
                WHEN 10 THEN 'Octubre'
                WHEN 11 THEN 'Noviembre'
                WHEN 12 THEN 'Diciembre'
            END AS NOMBRE_MES,
            CASE TO_NUMBER(TO_CHAR(F, 'MM'))
                WHEN 1  THEN 'Ene'
                WHEN 2  THEN 'Feb'
                WHEN 3  THEN 'Mar'
                WHEN 4  THEN 'Abr'
                WHEN 5  THEN 'May'
                WHEN 6  THEN 'Jun'
                WHEN 7  THEN 'Jul'
                WHEN 8  THEN 'Ago'
                WHEN 9  THEN 'Sep'
                WHEN 10 THEN 'Oct'
                WHEN 11 THEN 'Nov'
                WHEN 12 THEN 'Dic'
            END AS MES_CORTO,
            TO_NUMBER(TO_CHAR(F, 'IW')) AS SEMANA_ANIO,
            TO_NUMBER(TO_CHAR(F, 'DD')) AS DIA_MES,
            TO_NUMBER(TO_CHAR(F, 'D'))  AS DIA_SEMANA,
            CASE TO_CHAR(F, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN')
                WHEN 'MON' THEN 'Lunes'
                WHEN 'TUE' THEN 'Martes'
                WHEN 'WED' THEN 'Miércoles'
                WHEN 'THU' THEN 'Jueves'
                WHEN 'FRI' THEN 'Viernes'
                WHEN 'SAT' THEN 'Sábado'
                WHEN 'SUN' THEN 'Domingo'
            END AS NOMBRE_DIA,
            CASE WHEN TO_CHAR(F, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') IN ('SAT', 'SUN') THEN 1 ELSE 0 END AS ES_FIN_SEMANA,
            1 AS CURRENTFLAG,
            'FULL' AS TIPOCARGA,
            SYSDATE AS FECHAINICIO,
            DATE '2999-12-31' AS FECHAFIN,
            'I' AS TIPOTRANSACCION,
            RAWTOHEX(STANDARD_HASH(
                TO_CHAR(F, 'YYYY-MM-DD') || '|' ||
                TO_CHAR(F, 'YYYY') || '|' ||
                TO_CHAR(F, 'MM') || '|' ||
                TO_CHAR(F, 'Q') || '|' ||
                TO_CHAR(F, 'IW'),
                'SHA256'
            )) AS ROWHASHVALUE
        FROM GENERADOR_FECHAS
    ) s
    ON (d.SK_TIEMPO = s.SK_TIEMPO)
    WHEN NOT MATCHED THEN
        INSERT (
            SK_TIEMPO, FECHA, ANIO, SEMESTRE, TRIMESTRE, NOMBRE_TRIMESTRE,
            MES, NOMBRE_MES, MES_CORTO, SEMANA_ANIO, DIA_MES, DIA_SEMANA,
            NOMBRE_DIA, ES_FIN_SEMANA,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.SK_TIEMPO, s.FECHA, s.ANIO, s.SEMESTRE, s.TRIMESTRE, s.NOMBRE_TRIMESTRE,
            s.MES, s.NOMBRE_MES, s.MES_CORTO, s.SEMANA_ANIO, s.DIA_MES, s.DIA_SEMANA,
            s.NOMBRE_DIA, s.ES_FIN_SEMANA,
            s.CURRENTFLAG, s.TIPOCARGA, s.FECHAINICIO, s.FECHAFIN, s.TIPOTRANSACCION, s.ROWHASHVALUE
        )
    WHEN MATCHED THEN
        UPDATE SET
            d.FECHA            = s.FECHA,
            d.ANIO             = s.ANIO,
            d.SEMESTRE         = s.SEMESTRE,
            d.TRIMESTRE        = s.TRIMESTRE,
            d.NOMBRE_TRIMESTRE = s.NOMBRE_TRIMESTRE,
            d.MES              = s.MES,
            d.NOMBRE_MES       = s.NOMBRE_MES,
            d.MES_CORTO        = s.MES_CORTO,
            d.SEMANA_ANIO      = s.SEMANA_ANIO,
            d.DIA_MES          = s.DIA_MES,
            d.DIA_SEMANA       = s.DIA_SEMANA,
            d.NOMBRE_DIA       = s.NOMBRE_DIA,
            d.ES_FIN_SEMANA    = s.ES_FIN_SEMANA,
            d.FECHAINICIO      = SYSDATE,
            d.TIPOTRANSACCION  = 'U',
            d.ROWHASHVALUE     = s.ROWHASHVALUE;

    v_insertados := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('DIM_TIEMPO poblada exitosamente: ' || v_insertados || ' días registrados.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error poblando DIM_TIEMPO: ' || SQLERRM);
        RAISE;
END SP_POBLAR_DIM_TIEMPO;
/


-- ============================================================================
-- (2/15) PROCEDIMIENTO: SP_LOAD_DIM_TIEMPO.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_TIEMPO
-- OBJETIVO: Wrapper estándar para poblar o actualizar DIM_TIEMPO
-- ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_TIEMPO (
    p_anio_inicio IN NUMBER DEFAULT 2024,
    p_anio_fin    IN NUMBER DEFAULT 2030
)
AUTHID DEFINER
IS
BEGIN
    SP_POBLAR_DIM_TIEMPO(p_anio_inicio, p_anio_fin);
END SP_LOAD_DIM_TIEMPO;
/


-- ============================================================================
-- (3/15) PROCEDIMIENTO: SP_LOAD_DIM_UBICACION.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_UBICACION (SCD Tipo 1)
-- TABLA DESTINO: DIM_UBICACION
-- TABLA ORIGEN:  stg_clinica_user.STG_UBICACIONES
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_UBICACION (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
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
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
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
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_UBICACION ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_UBICACION: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_UBICACION;
/


-- ============================================================================
-- (4/15) PROCEDIMIENTO: SP_LOAD_DIM_ESPECIALIDAD.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_ESPECIALIDAD (SCD Tipo 1)
-- TABLA DESTINO: DIM_ESPECIALIDAD
-- TABLA ORIGEN:  stg_clinica_user.STG_ESPECIALIDADES
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_ESPECIALIDAD (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
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
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
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
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_ESPECIALIDAD ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_ESPECIALIDAD: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_ESPECIALIDAD;
/


-- ============================================================================
-- (5/15) PROCEDIMIENTO: SP_LOAD_DIM_ENFERMEDAD.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_ENFERMEDAD (SCD Tipo 1)
-- TABLA DESTINO: DIM_ENFERMEDAD
-- TABLA ORIGEN:  stg_clinica_user.STG_ENFERMEDADES
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_ENFERMEDAD (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
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
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
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
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_ENFERMEDAD ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_ENFERMEDAD: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_ENFERMEDAD;
/


-- ============================================================================
-- (6/15) PROCEDIMIENTO: SP_LOAD_DIM_TIPO_CONSULTA.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_TIPO_CONSULTA (SCD Tipo 1)
-- TABLA DESTINO: DIM_TIPO_CONSULTA
-- TABLA ORIGEN:  stg_clinica_user.STG_TIPOS_CONSULTA
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_TIPO_CONSULTA (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
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
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
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
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_TIPO_CONSULTA ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_TIPO_CONSULTA: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_TIPO_CONSULTA;
/


-- ============================================================================
-- (7/15) PROCEDIMIENTO: SP_LOAD_DIM_FORMA_PAGO.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_FORMA_PAGO (SCD Tipo 1)
-- TABLA DESTINO: DIM_FORMA_PAGO
-- TABLA ORIGEN:  stg_clinica_user.STG_FORMAS_PAGO
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_FORMA_PAGO (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
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
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
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
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_FORMA_PAGO ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_FORMA_PAGO: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_FORMA_PAGO;
/


-- ============================================================================
-- (8/15) PROCEDIMIENTO: SP_LOAD_DIM_PAGADOR.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_PAGADOR (SCD Tipo 1)
-- TABLA DESTINO: DIM_PAGADOR
-- TABLAS ORIGEN: stg_clinica_user.STG_PACIENTES, STG_EMPRESAS, STG_ASEGURADORAS
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_PAGADOR (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
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
            TIPO_PAGADOR, 
            BK_ID_ORIGEN, 
            NOMBRE_PAGADOR, 
            NUMERO_IDENTIFICACION,
            CATEGORIA_PAGADOR, 
            TELEFONO, 
            DIRECCION,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.TIPO_PAGADOR, 
            s.BK_ID_ORIGEN, 
            s.NOMBRE_PAGADOR, 
            s.NUMERO_IDENTIFICACION,
            s.CATEGORIA_PAGADOR, 
            s.TELEFONO, 
            s.DIRECCION,
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.HASH_PAG
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
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_PAGADOR ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_PAGADOR: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_PAGADOR;
/


-- ============================================================================
-- (9/15) PROCEDIMIENTO: SP_LOAD_DIM_CLINICA.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_CLINICA (SCD Tipo 2)
-- TABLA DESTINO: DIM_CLINICA
-- TABLAS ORIGEN: stg_clinica_user.STG_CLINICAS, STG_UBICACIONES
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_CLINICA (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_upd  NUMBER := 0;
    v_ins  NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    -- 1. Caducar registros previos cuyos atributos descriptivos cambiaron (SCD Tipo 2)
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

    -- 2. Insertar registros nuevos o nuevas versiones activas
    INSERT INTO DIM_CLINICA (
        BK_ID_CLINICA, NOMBRE_CLINICA, BK_ID_UBICACION, PAIS, DEPARTAMENTO,
        MUNICIPIO, DISTRITO, CODIGO_POSTAL, DIRECCION, TELEFONO, FECHA_APERTURA, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        c.ID_CLINICA, c.NOMBRE_CLINICA, c.ID_UBICACION, u.PAIS, u.DEPARTAMENTO,
        u.MUNICIPIO, u.DISTRITO, u.CODIGO_POSTAL, c.DIRECCION, c.TELEFONO, c.FECHA_APERTURA, c.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
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

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_CLINICA ejecutado: ' || v_upd || ' caducadas (SCD2), ' || v_ins || ' activas insertadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_CLINICA: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_CLINICA;
/


-- ============================================================================
-- (10/15) PROCEDIMIENTO: SP_LOAD_DIM_MEDICO.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_MEDICO (SCD Tipo 2)
-- TABLA DESTINO: DIM_MEDICO
-- TABLAS ORIGEN: stg_clinica_user.STG_MEDICOS, STG_CLINICAS
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_MEDICO (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_upd  NUMBER := 0;
    v_ins  NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    -- 1. Caducar registros previos cuyos atributos cambiaron (SCD Tipo 2)
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

    -- 2. Insertar registros nuevos o nuevas versiones activas
    INSERT INTO DIM_MEDICO (
        BK_ID_MEDICO, NOMBRES, APELLIDOS, NOMBRE_COMPLETO,
        BK_ID_CLINICA_BASE, NOMBRE_CLINICA_BASE, NUM_COLEGIADO, FECHA_INGRESO, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        m.ID_MEDICO, m.NOMBRES, m.APELLIDOS, m.NOMBRES || ' ' || m.APELLIDOS,
        m.ID_CLINICA, c.NOMBRE_CLINICA, m.NUM_COLEGIADO, m.FECHA_INGRESO, m.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
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

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_MEDICO ejecutado: ' || v_upd || ' caducadas (SCD2), ' || v_ins || ' activas insertadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_MEDICO: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_MEDICO;
/


-- ============================================================================
-- (11/15) PROCEDIMIENTO: SP_LOAD_DIM_PACIENTE.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_PACIENTE (SCD Tipo 2)
-- TABLA DESTINO: DIM_PACIENTE
-- TABLAS ORIGEN: stg_clinica_user.STG_PACIENTES, STG_UBICACIONES, 
--                STG_CLINICAS, STG_EMPRESAS, STG_ASEGURADORAS
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_PACIENTE (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_upd  NUMBER := 0;
    v_ins  NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    -- 1. Caducar registros previos cuyos atributos cambiaron (SCD Tipo 2: Residencia, Convenios Empresa/Aseguradora)
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

    -- 2. Insertar registros nuevos o nuevas versiones activas
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
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
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
    LEFT JOIN stg_clinica_user.STG_UBICACIONES u  ON p.ID_UBICACION = u.ID_UBICACION
    LEFT JOIN stg_clinica_user.STG_CLINICAS c     ON p.ID_CLINICA_HABITUAL = c.ID_CLINICA
    LEFT JOIN stg_clinica_user.STG_EMPRESAS e     ON p.ID_EMPRESA = e.ID_EMPRESA
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

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_PACIENTE ejecutado: ' || v_upd || ' caducadas (SCD2), ' || v_ins || ' activas insertadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_PACIENTE: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_PACIENTE;
/


-- ============================================================================
-- (12/15) PROCEDIMIENTO: SP_LOAD_FACT_CONSULTAS.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_FACT_CONSULTAS
-- OBJETIVO:      Carga analítica de atenciones médicas y facturación acumulada
--                con Surrogate Key Lookups y ventana incremental
-- TABLA DESTINO: FACT_CONSULTAS
-- TABLAS ORIGEN: stg_clinica_user.STG_CONSULTAS, STG_CONSULTAS_PROCEDIMIENTOS,
--                STG_COBROS_CONSULTA, DIM_TIEMPO, DIM_PACIENTE, DIM_CLINICA,
--                DIM_MEDICO, DIM_ESPECIALIDAD, DIM_TIPO_CONSULTA, DIM_UBICACION
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_FACT_CONSULTAS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'INCREMENTAL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
BEGIN
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
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.HASH_HECHO
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
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_FACT_CONSULTAS ejecutado: ' || v_cant || ' filas procesadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_FACT_CONSULTAS: ' || SQLERRM);
        RAISE;
END SP_LOAD_FACT_CONSULTAS;
/


-- ============================================================================
-- (13/15) PROCEDIMIENTO: SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS
-- OBJETIVO:      Carga del análisis epidemiológico y distribución del costo
--                prorrateado por patología diagnosticada
-- TABLA DESTINO: FACT_CONSULTA_DIAGNOSTICOS
-- TABLAS ORIGEN: stg_clinica_user.STG_DIAGNOSTICOS, FACT_CONSULTAS, DIM_ENFERMEDAD
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'INCREMENTAL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
BEGIN
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
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.HASH_HECHO
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
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS ejecutado: ' || v_cant || ' filas procesadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS: ' || SQLERRM);
        RAISE;
END SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS;
/


-- ============================================================================
-- (14/15) PROCEDIMIENTO: SP_LOAD_FACT_COBROS_DISTRIBUCION.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_FACT_COBROS_DISTRIBUCION
-- OBJETIVO:      Carga del análisis de recaudación, saldos por pagador
--                (Particular, Empresa, Aseguradora) y forma de pago
-- TABLA DESTINO: FACT_COBROS_DISTRIBUCION
-- TABLAS ORIGEN: stg_clinica_user.STG_DISTRIBUCION_COBRO, STG_COBROS_CONSULTA,
--                FACT_CONSULTAS, DIM_PAGADOR, STG_TRANSACCIONES_PAGO, DIM_FORMA_PAGO
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_FACT_COBROS_DISTRIBUCION (
    p_tipo_carga IN VARCHAR2 DEFAULT 'INCREMENTAL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
BEGIN
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
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.HASH_HECHO
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
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_FACT_COBROS_DISTRIBUCION ejecutado: ' || v_cant || ' filas procesadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_FACT_COBROS_DISTRIBUCION: ' || SQLERRM);
        RAISE;
END SP_LOAD_FACT_COBROS_DISTRIBUCION;
/


-- ============================================================================
-- (15/15) PROCEDIMIENTO: SP_LOAD_DWH_MASTER.sql
-- ============================================================================
-- ============================================================================
-- PROCEDIMIENTO MAESTRO: SP_LOAD_DWH_MASTER
-- OBJETIVO: Orquestador end-to-end de extracción y carga analítica en el DWH.
--           Invoca de forma modular y secuencial cada procedimiento individual
--           por cada tabla de dimensión y tabla de hechos.
-- ESQUEMA: dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DWH_MASTER (
    p_tipo_carga    IN VARCHAR2 DEFAULT 'INCREMENTAL',
    p_dias_lookback IN NUMBER   DEFAULT 3,
    p_fecha_corte   IN DATE     DEFAULT NULL
)
AUTHID DEFINER
IS
    v_inicio TIMESTAMP := SYSTIMESTAMP;
    v_tipo   VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'INCREMENTAL'));
    v_dias   NUMBER := NVL(p_dias_lookback, 3);
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('INICIO DEL PIPELINE ANALÍTICO COMPLETO: DWH RED DE CLÍNICAS');
    DBMS_OUTPUT.PUT_LINE('Modo de Carga: ' || v_tipo || 
                         ' | Ventana Días Lookback: ' || v_dias);
    DBMS_OUTPUT.PUT_LINE('Timestamp: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================');

    -- Paso 1: Extracción desde OLTP hacia Staging con ventana optimizada
    DBMS_OUTPUT.PUT_LINE('>>> 1. EJECUTANDO EXTRACCIÓN HACIA STAGING...');
    stg_clinica_user.SP_EXTRACT_OLTP_TO_STG(v_tipo, v_dias, p_fecha_corte);

    -- Paso 2: Carga de Dimensiones SCD Tipo 1 (Sobreescritura con Hash)
    DBMS_OUTPUT.PUT_LINE('>>> 2. EJECUTANDO CARGA DE DIMENSIONES SCD TIPO 1...');
    SP_LOAD_DIM_UBICACION(v_tipo);
    SP_LOAD_DIM_ESPECIALIDAD(v_tipo);
    SP_LOAD_DIM_ENFERMEDAD(v_tipo);
    SP_LOAD_DIM_TIPO_CONSULTA(v_tipo);
    SP_LOAD_DIM_FORMA_PAGO(v_tipo);
    SP_LOAD_DIM_PAGADOR(v_tipo);

    -- Paso 3: Carga de Dimensiones SCD Tipo 2 (Históricas / Caducidad + Nueva Versión)
    DBMS_OUTPUT.PUT_LINE('>>> 3. EJECUTANDO CARGA DE DIMENSIONES SCD TIPO 2...');
    SP_LOAD_DIM_CLINICA(v_tipo);
    SP_LOAD_DIM_MEDICO(v_tipo);
    SP_LOAD_DIM_PACIENTE(v_tipo);

    -- Paso 4: Carga de Tablas de Hechos (Fact Tables con SK Lookups)
    DBMS_OUTPUT.PUT_LINE('>>> 4. EJECUTANDO CARGA DE TABLAS DE HECHOS...');
    SP_LOAD_FACT_CONSULTAS(v_tipo);
    SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS(v_tipo);
    SP_LOAD_FACT_COBROS_DISTRIBUCION(v_tipo);

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
/

