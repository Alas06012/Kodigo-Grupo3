-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_FORMAS_PAGO
-- OBJETIVO:      Extracción directa desde red_clinica_user.FORMAS_PAGO hacia STG_FORMAS_PAGO
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_FORMAS_PAGO (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID CURRENT_USER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_FORMAS_PAGO';

    INSERT /*+ APPEND */ INTO STG_FORMAS_PAGO (
        ID_FORMA_PAGO, NOMBRE_FORMA_PAGO, CATEGORIA, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_FORMA_PAGO, o.NOMBRE_FORMA_PAGO, o.CATEGORIA, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_FORMA_PAGO, '~') || '|' ||
            NVL(o.CATEGORIA, '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.FORMAS_PAGO o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_FORMAS_PAGO extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_FORMAS_PAGO: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_FORMAS_PAGO;
/

GRANT EXECUTE ON SP_EXTRACT_STG_FORMAS_PAGO TO dwh_clinica_user;
