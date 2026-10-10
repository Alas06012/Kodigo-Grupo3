-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_ENFERMEDAD (SCD Tipo 1)
-- TABLA DESTINO: DIM_ENFERMEDAD
-- TABLA ORIGEN:  stg_clinica_user.STG_ENFERMEDADES
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_ENFERMEDAD (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID CURRENT_USER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    MERGE INTO DIM_ENFERMEDAD d
    USING stg_clinica_user.STG_ENFERMEDADES s
    ON (d.BK_ID_ENFERMEDAD = s.ID_ENFERMEDAD)
    WHEN NOT MATCHED THEN
        INSERT (
            BK_ID_ENFERMEDAD, CODIGO_CIE10, NOMBRE_ENFERMEDAD,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.ID_ENFERMEDAD, s.CODIGO_CIE10, s.NOMBRE_ENFERMEDAD,
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
        )
    WHEN MATCHED THEN
        UPDATE SET
            d.CODIGO_CIE10      = s.CODIGO_CIE10,
            d.NOMBRE_ENFERMEDAD = s.NOMBRE_ENFERMEDAD,
            d.FECHAINICIO       = SYSDATE,
            d.TIPOTRANSACCION   = 'U',
            d.ROWHASHVALUE      = s.ROWHASHVALUE
        WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;

    v_cant := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_ENFERMEDAD ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_ENFERMEDAD: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_ENFERMEDAD;
/
