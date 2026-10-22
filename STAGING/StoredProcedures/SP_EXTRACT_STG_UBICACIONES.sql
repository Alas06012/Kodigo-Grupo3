-- ============================================================================
-- PROCEDIMIENTO: SP_EXTRACT_STG_UBICACIONES
-- OBJETIVO:      Extracción directa desde red_clinica_user.UBICACIONES hacia STG_UBICACIONES
-- ESQUEMA:       stg_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_EXTRACT_STG_UBICACIONES (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_filas NUMBER := 0;
    v_tipo  VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE STG_UBICACIONES';

    INSERT /*+ APPEND */ INTO STG_UBICACIONES (
        ID_UBICACION, PAIS, DEPARTAMENTO, MUNICIPIO, DISTRITO, CODIGO_POSTAL,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        o.ID_UBICACION, o.PAIS, o.DEPARTAMENTO, o.MUNICIPIO, o.DISTRITO, o.CODIGO_POSTAL,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(o.PAIS, '~') || '|' ||
            NVL(o.DEPARTAMENTO, '~') || '|' ||
            NVL(o.MUNICIPIO, '~') || '|' ||
            NVL(o.DISTRITO, '~') || '|' ||
            NVL(o.CODIGO_POSTAL, '~'),
            'SHA256'
        ))
    FROM red_clinica_user.UBICACIONES o;

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('STG_UBICACIONES extraída: ' || v_filas || ' registros.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_EXTRACT_STG_UBICACIONES: ' || SQLERRM);
        RAISE;
END SP_EXTRACT_STG_UBICACIONES;
/

GRANT EXECUTE ON SP_EXTRACT_STG_UBICACIONES TO dwh_clinica_user;
