-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_MEDICO (SCD Tipo 2)
-- TABLA DESTINO: DIM_MEDICO
-- TABLAS ORIGEN: stg_clinica_user.STG_MEDICOS, STG_CLINICAS
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_MEDICO (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID CURRENT_USER
IS
    v_upd  NUMBER := 0;
    v_ins  NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    -- 1. Caducar registros previos cuyos atributos cambiaron (SCD Tipo 2)
    UPDATE DIM_MEDICO d
    SET d.CURRENTFLAG     = 0,
        d.FECHAFIN        = TRUNC(SYSDATE) - (1/86400),
        d.TIPOTRANSACCION = 'U'
    WHERE d.CURRENTFLAG = 1
      AND EXISTS (
          SELECT 1 
          FROM stg_clinica_user.STG_MEDICOS s
          WHERE s.ID_MEDICO = d.BK_ID_MEDICO
            AND RAWTOHEX(STANDARD_HASH(
                NVL(s.NOMBRES, '~') || '|' ||
                NVL(s.APELLIDOS, '~') || '|' ||
                NVL(TO_CHAR(s.ID_CLINICA), '~') || '|' ||
                NVL(s.NUM_COLEGIADO, '~') || '|' ||
                NVL(s.ESTADO, '~'),
                'SHA256'
            )) != d.ROWHASHVALUE
      );
    v_upd := SQL%ROWCOUNT;

    -- 2. Insertar registros nuevos o nuevas versiones activas
    INSERT INTO DIM_MEDICO (
        BK_ID_MEDICO, NOMBRES, APELLIDOS, NOMBRE_COMPLETO,
        BK_ID_CLINICA_BASE, NOMBRE_CLINICA_BASE, NUM_COLEGIADO, FECHA_INGRESO, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        m.ID_MEDICO, m.NOMBRES, m.APELLIDOS, m.NOMBRES || ' ' || m.APELLIDOS,
        m.ID_CLINICA, c.NOMBRE_CLINICA, m.NUM_COLEGIADO, m.FECHA_INGRESO, m.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(m.NOMBRES, '~') || '|' ||
            NVL(m.APELLIDOS, '~') || '|' ||
            NVL(TO_CHAR(m.ID_CLINICA), '~') || '|' ||
            NVL(m.NUM_COLEGIADO, '~') || '|' ||
            NVL(m.ESTADO, '~'),
            'SHA256'
        ))
    FROM stg_clinica_user.STG_MEDICOS m
    INNER JOIN stg_clinica_user.STG_CLINICAS c ON m.ID_CLINICA = c.ID_CLINICA
    WHERE NOT EXISTS (
        SELECT 1 FROM DIM_MEDICO d
        WHERE d.BK_ID_MEDICO = m.ID_MEDICO
          AND d.CURRENTFLAG = 1
          AND d.ROWHASHVALUE = RAWTOHEX(STANDARD_HASH(
              NVL(m.NOMBRES, '~') || '|' ||
              NVL(m.APELLIDOS, '~') || '|' ||
              NVL(TO_CHAR(m.ID_CLINICA), '~') || '|' ||
              NVL(m.NUM_COLEGIADO, '~') || '|' ||
              NVL(m.ESTADO, '~'),
              'SHA256'
          ))
    );
    v_ins := SQL%ROWCOUNT;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_MEDICO ejecutado: ' || v_upd || ' caducadas (SCD2), ' || v_ins || ' activas insertadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_MEDICO: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_MEDICO;
/
