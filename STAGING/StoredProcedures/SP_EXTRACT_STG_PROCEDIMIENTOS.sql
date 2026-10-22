-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_PROCEDIMIENTOS
-- OBJETIVO:      Extracción directa desde red_clinica_user.PROCEDIMIENTOS hacia STG_PROCEDIMIENTOS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_PROCEDIMIENTOS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_PROCEDIMIENTOS';

    INSERT /*+ APPEND */ INTO STG_PROCEDIMIENTOS (
        ID_PROCEDIMIENTO, CODIGO_PROCEDIMIENTO, NOMBRE_PROCEDIMIENTO, DESCRIPCION, COSTO_BASE, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_PROCEDIMIENTO, o.CODIGO_PROCEDIMIENTO, o.NOMBRE_PROCEDIMIENTO, o.DESCRIPCION, o.COSTO_BASE, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.CODIGO_PROCEDIMIENTO, '~') || '|' ||
            NVL(o.NOMBRE_PROCEDIMIENTO, '~') || '|' ||
            NVL(o.DESCRIPCION, '~') || '|' ||
            NVL(TO_CHAR(o.COSTO_BASE, 'FM999999990.00'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.PROCEDIMIENTOS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_PROCEDIMIENTOS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_PROCEDIMIENTOS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_PROCEDIMIENTOS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_PROCEDIMIENTOS TO dwh_clinica_user;
