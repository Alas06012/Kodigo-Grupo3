-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_PAGADOR (SCD Tipo 1)
-- TABLA DESTINO: DIM_PAGADOR
-- TABLAS ORIGEN: stg_clinica_user.STG_PACIENTES, STG_EMPRESAS, STG_ASEGURADORAS
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_PAGADOR (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID CURRENT_USER
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
