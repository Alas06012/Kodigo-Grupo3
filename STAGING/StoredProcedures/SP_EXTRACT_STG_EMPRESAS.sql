-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_EMPRESAS
-- OBJETIVO:      Extracción directa desde red_clinica_user.EMPRESAS hacia STG_EMPRESAS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_EMPRESAS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID CURRENT_USER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_EMPRESAS';

    INSERT /*+ APPEND */ INTO STG_EMPRESAS (
        ID_EMPRESA, NOMBRE_EMPRESA, NIT, SECTOR, TELEFONO, DIRECCION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_EMPRESA, o.NOMBRE_EMPRESA, o.NIT, o.SECTOR, o.TELEFONO, o.DIRECCION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_EMPRESA, '~') || '|' ||
            NVL(o.NIT, '~') || '|' ||
            NVL(o.SECTOR, '~') || '|' ||
            NVL(o.TELEFONO, '~') || '|' ||
            NVL(o.DIRECCION, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.EMPRESAS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_EMPRESAS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_EMPRESAS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_EMPRESAS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_EMPRESAS TO dwh_clinica_user;
