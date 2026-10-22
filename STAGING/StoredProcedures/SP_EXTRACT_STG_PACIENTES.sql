-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_PACIENTES
-- OBJETIVO:      Extracción directa desde red_clinica_user.PACIENTES hacia STG_PACIENTES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_PACIENTES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_PACIENTES';

    INSERT /*+ APPEND */ INTO STG_PACIENTES (
        ID_PACIENTE, NOMBRES, APELLIDOS, FECHA_NACIMIENTO, SEXO, ID_UBICACION,
        DIRECCION, ID_CLINICA_HABITUAL, ID_EMPRESA, ID_ASEGURADORA, NUMERO_POLIZA, FECHA_REGISTRO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_PACIENTE, o.NOMBRES, o.APELLIDOS, o.FECHA_NACIMIENTO, o.SEXO, o.ID_UBICACION,
        o.DIRECCION, o.ID_CLINICA_HABITUAL, o.ID_EMPRESA, o.ID_ASEGURADORA, o.NUMERO_POLIZA, o.FECHA_REGISTRO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.NOMBRES, '~') || '|' ||
            NVL(o.APELLIDOS, '~') || '|' ||
            NVL(TO_CHAR(o.FECHA_NACIMIENTO, 'YYYY-MM-DD'), '~') || '|' ||
            NVL(o.SEXO, '~') || '|' ||
            NVL(TO_CHAR(o.ID_UBICACION), '~') || '|' ||
            NVL(o.DIRECCION, '~') || '|' ||
            NVL(TO_CHAR(o.ID_CLINICA_HABITUAL), '~') || '|' ||
            NVL(TO_CHAR(o.ID_EMPRESA), '~') || '|' ||
            NVL(TO_CHAR(o.ID_ASEGURADORA), '~') || '|' ||
            NVL(o.NUMERO_POLIZA, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.PACIENTES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_PACIENTES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_PACIENTES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_PACIENTES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_PACIENTES TO dwh_clinica_user;
