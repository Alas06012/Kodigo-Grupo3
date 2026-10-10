-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_TIPO_CONSULTA (SCD Tipo 1)
-- TABLA DESTINO: DIM_TIPO_CONSULTA
-- TABLA ORIGEN:  stg_clinica_user.STG_TIPOS_CONSULTA
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_TIPO_CONSULTA (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID CURRENT_USER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    MERGE INTO DIM_TIPO_CONSULTA d
    USING stg_clinica_user.STG_TIPOS_CONSULTA s
    ON (d.BK_ID_TIPO_CONSULTA = s.ID_TIPO_CONSULTA)
    WHEN NOT MATCHED THEN
        INSERT (
            BK_ID_TIPO_CONSULTA, NOMBRE_TIPO, DESCRIPCION, PRECIO_BASE, ESTADO,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.ID_TIPO_CONSULTA, s.NOMBRE_TIPO, s.DESCRIPCION, s.PRECIO_BASE, s.ESTADO,
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
        )
    WHEN MATCHED THEN
        UPDATE SET
            d.NOMBRE_TIPO     = s.NOMBRE_TIPO,
            d.DESCRIPCION     = s.DESCRIPCION,
            d.PRECIO_BASE     = s.PRECIO_BASE,
            d.ESTADO          = s.ESTADO,
            d.FECHAINICIO     = SYSDATE,
            d.TIPOTRANSACCION = 'U',
            d.ROWHASHVALUE    = s.ROWHASHVALUE
        WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;

    v_cant := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_TIPO_CONSULTA ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_TIPO_CONSULTA: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_TIPO_CONSULTA;
/
