-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_ESPECIALIDADES
-- OBJETIVO:      Extracción directa desde red_clinica_user.ESPECIALIDADES hacia STG_ESPECIALIDADES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_ESPECIALIDADES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID CURRENT_USER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_ESPECIALIDADES';

    INSERT /*+ APPEND */ INTO STG_ESPECIALIDADES (
        ID_ESPECIALIDAD, NOMBRE_ESPECIALIDAD, DESCRIPCION,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_ESPECIALIDAD, o.NOMBRE_ESPECIALIDAD, o.DESCRIPCION,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRE_ESPECIALIDAD, '~') || '|' ||
            NVL(o.DESCRIPCION, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.ESPECIALIDADES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_ESPECIALIDADES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_ESPECIALIDADES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_ESPECIALIDADES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_ESPECIALIDADES TO dwh_clinica_user;
