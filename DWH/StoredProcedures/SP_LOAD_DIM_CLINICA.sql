-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_CLINICA (SCD Tipo 2)
-- TABLA DESTINO: DIM_CLINICA
-- TABLAS ORIGEN: stg_clinica_user.STG_CLINICAS, STG_UBICACIONES
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_CLINICA (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID CURRENT_USER
IS
    v_upd  NUMBER := 0;
    v_ins  NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    -- 1. Caducar registros previos cuyos atributos descriptivos cambiaron (SCD Tipo 2)
    UPDATE DIM_CLINICA d
    SET d.CURRENTFLAG     = 0,
        d.FECHAFIN        = TRUNC(SYSDATE) - (1/86400),
        d.TIPOTRANSACCION = 'U'
    WHERE d.CURRENTFLAG = 1
      AND EXISTS (
          SELECT 1 
          FROM stg_clinica_user.STG_CLINICAS s
          WHERE s.ID_CLINICA = d.BK_ID_CLINICA
            AND RAWTOHEX(STANDARD_HASH(
                NVL(s.NOMBRE_CLINICA, '~') || '|' ||
                NVL(TO_CHAR(s.ID_UBICACION), '~') || '|' ||
                NVL(s.DIRECCION, '~') || '|' ||
                NVL(s.TELEFONO, '~') || '|' ||
                NVL(s.ESTADO, '~'),
                'SHA256'
            )) != d.ROWHASHVALUE
      );
    v_upd := SQL%ROWCOUNT;

    -- 2. Insertar registros nuevos o nuevas versiones activas
    INSERT INTO DIM_CLINICA (
        BK_ID_CLINICA, NOMBRE_CLINICA, BK_ID_UBICACION, PAIS, DEPARTAMENTO,
        MUNICIPIO, DISTRITO, CODIGO_POSTAL, DIRECCION, TELEFONO, FECHA_APERTURA, ESTADO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        c.ID_CLINICA, c.NOMBRE_CLINICA, c.ID_UBICACION, u.PAIS, u.DEPARTAMENTO,
        u.MUNICIPIO, u.DISTRITO, u.CODIGO_POSTAL, c.DIRECCION, c.TELEFONO, c.FECHA_APERTURA, c.ESTADO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(c.NOMBRE_CLINICA, '~') || '|' ||
            NVL(TO_CHAR(c.ID_UBICACION), '~') || '|' ||
            NVL(c.DIRECCION, '~') || '|' ||
            NVL(c.TELEFONO, '~') || '|' ||
            NVL(c.ESTADO, '~'),
            'SHA256'
        ))
    FROM stg_clinica_user.STG_CLINICAS c
    INNER JOIN stg_clinica_user.STG_UBICACIONES u ON c.ID_UBICACION = u.ID_UBICACION
    WHERE NOT EXISTS (
        SELECT 1 FROM DIM_CLINICA d
        WHERE d.BK_ID_CLINICA = c.ID_CLINICA
          AND d.CURRENTFLAG = 1
          AND d.ROWHASHVALUE = RAWTOHEX(STANDARD_HASH(
              NVL(c.NOMBRE_CLINICA, '~') || '|' ||
              NVL(TO_CHAR(c.ID_UBICACION), '~') || '|' ||
              NVL(c.DIRECCION, '~') || '|' ||
              NVL(c.TELEFONO, '~') || '|' ||
              NVL(c.ESTADO, '~'),
              'SHA256'
          ))
    );
    v_ins := SQL%ROWCOUNT;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_CLINICA ejecutado: ' || v_upd || ' caducadas (SCD2), ' || v_ins || ' activas insertadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_CLINICA: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_CLINICA;
/
