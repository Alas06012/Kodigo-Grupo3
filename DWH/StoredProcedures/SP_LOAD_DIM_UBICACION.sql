-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_UBICACION (SCD Tipo 1)
-- TABLA DESTINO: DIM_UBICACION
-- TABLA ORIGEN:  stg_clinica_user.STG_UBICACIONES
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_UBICACION (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    MERGE INTO DIM_UBICACION d
    USING stg_clinica_user.STG_UBICACIONES s
    ON (d.BK_ID_UBICACION = s.ID_UBICACION)
    WHEN NOT MATCHED THEN
        INSERT (
            BK_ID_UBICACION, PAIS, DEPARTAMENTO, MUNICIPIO, DISTRITO, CODIGO_POSTAL,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.ID_UBICACION, s.PAIS, s.DEPARTAMENTO, s.MUNICIPIO, s.DISTRITO, s.CODIGO_POSTAL,
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
        )
    WHEN MATCHED THEN
        UPDATE SET
            d.PAIS            = s.PAIS,
            d.DEPARTAMENTO    = s.DEPARTAMENTO,
            d.MUNICIPIO       = s.MUNICIPIO,
            d.DISTRITO        = s.DISTRITO,
            d.CODIGO_POSTAL   = s.CODIGO_POSTAL,
            d.FECHAINICIO     = SYSDATE,
            d.TIPOTRANSACCION = 'U',
            d.ROWHASHVALUE    = s.ROWHASHVALUE
        WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;

    v_cant := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_UBICACION ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_UBICACION: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_UBICACION;
/
