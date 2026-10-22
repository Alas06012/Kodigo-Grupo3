-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_TIPOS_CONSULTA
-- OBJETIVO:      Extracción directa desde red_clinica_user.TIPOS_CONSULTA hacia STG_TIPOS_CONSULTA
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_TIPOS_CONSULTA (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_TIPOS_CONSULTA';

    INSERT /*+ APPEND */ INTO STG_TIPOS_CONSULTA (
        ID_TIPO_CONSULTA, NOMBRE_TIPO, DESCRIPCION, PRECIO_BASE, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_TIPO_CONSULTA, o.NOMBRE_TIPO, o.DESCRIPCION, o.PRECIO_BASE, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_TIPO, '~') || '|' ||
            NVL(o.DESCRIPCION, '~') || '|' ||
            NVL(TO_CHAR(o.PRECIO_BASE, 'FM999999990.00'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.TIPOS_CONSULTA o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_TIPOS_CONSULTA extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_TIPOS_CONSULTA: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_TIPOS_CONSULTA;
/

GRANT EXECUTE ON SP_EXTRACT_STG_TIPOS_CONSULTA TO dwh_clinica_user;
