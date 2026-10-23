-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_ESPECIALIDAD (SCD Tipo 1)
-- TABLA DESTINO: DIM_ESPECIALIDAD
-- TABLA ORIGEN:  stg_clinica_user.STG_ESPECIALIDADES
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_ESPECIALIDAD (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL',
    p_batch_id   IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
IS
    v_batch_id VARCHAR2(50);
    v_audit_id NUMBER;
    v_cant NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    v_batch_id := NVL(p_batch_id, 'BATCH_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    SP_AUDIT_START(v_batch_id, 'DWH_DIM', 'DIM_ESPECIALIDAD', 'SP_LOAD_DIM_ESPECIALIDAD', v_tipo, v_audit_id);
    MERGE INTO DIM_ESPECIALIDAD d
    USING stg_clinica_user.STG_ESPECIALIDADES s
    ON (d.BK_ID_ESPECIALIDAD = s.ID_ESPECIALIDAD)
    WHEN NOT MATCHED THEN
        INSERT (
            BK_ID_ESPECIALIDAD, NOMBRE_ESPECIALIDAD, DESCRIPCION,
            CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
        )
        VALUES (
            s.ID_ESPECIALIDAD, s.NOMBRE_ESPECIALIDAD, s.DESCRIPCION,
            1, v_tipo, SYSDATE, DATE '2999-12-31', 'I', s.ROWHASHVALUE
        )
    WHEN MATCHED THEN
        UPDATE SET
            d.NOMBRE_ESPECIALIDAD = s.NOMBRE_ESPECIALIDAD,
            d.DESCRIPCION         = s.DESCRIPCION,
            d.FECHAINICIO         = SYSDATE,
            d.TIPOTRANSACCION     = 'U',
            d.ROWHASHVALUE        = s.ROWHASHVALUE
        WHERE d.ROWHASHVALUE != s.ROWHASHVALUE;

    v_cant := SQL%ROWCOUNT;
    COMMIT;
    SP_AUDIT_END(v_audit_id, v_cant, v_cant, 0, 0, 'SUCCESS');
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_ESPECIALIDAD ejecutado: ' || v_cant || ' filas afectadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF v_audit_id IS NOT NULL THEN
            SP_AUDIT_ERROR(v_audit_id, TO_CHAR(SQLCODE), SQLERRM);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_ESPECIALIDAD: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_ESPECIALIDAD;
/
