-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_FORMA_PAGO (SCD Tipo 1)
-- TABLA DESTINO: DIM_FORMA_PAGO
-- TABLA ORIGEN:  stg_clinica_user.STG_FORMAS_PAGO
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_FORMA_PAGO (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID DEFINER
IS
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    MERGE INTO DIM_FORMA_PAGO d
    USING stg_clinica_user.STG_FORMAS_PAGO s
    ON (d.BK_ID_FORMA_PAGO = s.ID_FORMA_PAGO)
    WHEN NOT MATCHED THEN
        INSERT (
            BK_ID_FORMA_PAGO, NOMBRE_FORMA_PAGO, CATEGORIA, ESTADO,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.ID_FORMA_PAGO, s.NOMBRE_FORMA_PAGO, s.CATEGORIA, s.ESTADO,
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
        )
    WHEN MATCHED THEN
        UPDATE SET
            d.NOMBRE_FORMA_PAGO = s.NOMBRE_FORMA_PAGO,
            d.CATEGORIA         = s.CATEGORIA,
            d.ESTADO            = s.ESTADO,
            d.FECHAINICIO       = SYSDATE,
            d.TIPOTRANSACCION   = 'U',
            d.ROWHASHVALUE      = s.ROWHASHVALUE
        WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;

    v_cant := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_FORMA_PAGO ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_FORMA_PAGO: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_FORMA_PAGO;
/
