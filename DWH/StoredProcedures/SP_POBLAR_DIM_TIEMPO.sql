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
