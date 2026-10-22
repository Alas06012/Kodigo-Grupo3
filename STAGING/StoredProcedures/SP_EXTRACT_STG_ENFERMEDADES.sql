-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_ENFERMEDADES
-- OBJETIVO:      Extracción directa desde red_clinica_user.ENFERMEDADES hacia STG_ENFERMEDADES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_ENFERMEDADES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_ENFERMEDADES';

    INSERT /*+ APPEND */ INTO STG_ENFERMEDADES (
        ID_ENFERMEDAD, CODIGO_CIE10, NOMBRE_ENFERMEDAD,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_ENFERMEDAD, o.CODIGO_CIE10, o.NOMBRE_ENFERMEDAD,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.CODIGO_CIE10, '~') || '|' ||
            NVL(o.NOMBRE_ENFERMEDAD, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.ENFERMEDADES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_ENFERMEDADES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_ENFERMEDADES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_ENFERMEDADES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_ENFERMEDADES TO dwh_clinica_user;
