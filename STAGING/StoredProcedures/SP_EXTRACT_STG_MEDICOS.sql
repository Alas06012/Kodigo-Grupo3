-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_MEDICOS
-- OBJETIVO:      Extracción directa desde red_clinica_user.MEDICOS hacia STG_MEDICOS
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_MEDICOS (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_MEDICOS';

    INSERT /*+ APPEND */ INTO STG_MEDICOS (
        ID_MEDICO, NOMBRES, APELLIDOS, ID_CLINICA, NUM_COLEGIADO, FECHA_INGRESO, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_MEDICO, o.NOMBRES, o.APELLIDOS, o.ID_CLINICA_BASE, o.NUM_COLEGIADO, o.FECHA_INGRESO, o.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRES, '~') || '|' ||
            NVL(o.APELLIDOS, '~') || '|' ||
            NVL(TO_CHAR(o.ID_CLINICA_BASE), '~') || '|' ||
            NVL(o.NUM_COLEGIADO, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_INGRESO, 'YYYY-MM-DD'), '~') || '|' ||
            NVL(o.ESTADO, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.MEDICOS o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_MEDICOS extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_MEDICOS: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_MEDICOS;
/

GRANT EXECUTE ON SP_EXTRACT_STG_MEDICOS TO dwh_clinica_user;
