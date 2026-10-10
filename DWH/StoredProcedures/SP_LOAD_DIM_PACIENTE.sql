-- ============================================================================
-- PROCEDIMIENTO: SP_LOAD_DIM_PACIENTE (SCD Tipo 2)
-- TABLA DESTINO: DIM_PACIENTE
-- TABLAS ORIGEN: stg_clinica_user.STG_PACIENTES, STG_UBICACIONES, 
--                STG_CLINICAS, STG_EMPRESAS, STG_ASEGURADORAS
-- ESQUEMA:       dwh_clinica_user | MOTOR: Oracle Database
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_DIM_PACIENTE (
    p_tipo_carga IN VARCHAR2 DEFAULT 'FULL'
)
AUTHID CURRENT_USER
IS
    v_upd  NUMBER := 0;
    v_ins  NUMBER := 0;
    v_tipo VARCHAR2(20) := UPPER(NVL(p_tipo_carga, 'FULL'));
BEGIN
    -- 1. Caducar registros previos cuyos atributos cambiaron (SCD Tipo 2: Residencia, Convenios Empresa/Aseguradora)
    UPDATE DIM_PACIENTE d
    SET d.CURRENTFLAG     = 0,
        d.FECHAFIN        = TRUNC(SYSDATE) - (1/86400),
        d.TIPOTRANSACCION = 'U'
    WHERE d.CURRENTFLAG = 1
      AND EXISTS (
          SELECT 1 
          FROM stg_clinica_user.STG_PACIENTES s
          WHERE s.ID_PACIENTE = d.BK_ID_PACIENTE
            AND RAWTOHEX(STANDARD_HASH(
                NVL(s.DIRECCION, '~') || '|' ||
                NVL(TO_CHAR(s.ID_UBICACION), '~') || '|' ||
                NVL(TO_CHAR(s.ID_CLINICA_HABITUAL), '~') || '|' ||
                NVL(TO_CHAR(s.ID_EMPRESA), '~') || '|' ||
                NVL(TO_CHAR(s.ID_ASEGURADORA), '~') || '|' ||
                NVL(s.NUMERO_POLIZA, '~'),
                'SHA256'
            )) != d.ROWHASHVALUE
      );
    v_upd := SQL%ROWCOUNT;

    -- 2. Insertar registros nuevos o nuevas versiones activas
    INSERT INTO DIM_PACIENTE (
        BK_ID_PACIENTE, NOMBRES, APELLIDOS, NOMBRE_COMPLETO,
        FECHA_NACIMIENTO, EDAD, GRUPO_ETARIO, SEXO, DIRECCION,
        BK_ID_UBICACION, PAIS, DEPARTAMENTO, MUNICIPIO, DISTRITO, CODIGO_POSTAL,
        BK_ID_CLINICA_HABITUAL, NOMBRE_CLINICA_HABITUAL,
        BK_ID_EMPRESA, NOMBRE_EMPRESA, SECTOR_EMPRESA,
        BK_ID_ASEGURADORA, NOMBRE_ASEGURADORA, TIPO_COBERTURA_ASEGURADORA,
        NUMERO_POLIZA, FECHA_REGISTRO,
        CURRENTFLAG, TIPOCARGA, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE
    )
    SELECT 
        p.ID_PACIENTE, p.NOMBRES, p.APELLIDOS, p.NOMBRES || ' ' || p.APELLIDOS,
        p.FECHA_NACIMIENTO,
        TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) AS EDAD,
        CASE 
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) < 18 THEN '0-17 Pediátrico'
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) BETWEEN 18 AND 29 THEN '18-29 Joven'
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) BETWEEN 30 AND 49 THEN '30-49 Adulto'
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, p.FECHA_NACIMIENTO)/12) BETWEEN 50 AND 64 THEN '50-64 Adulto Mayor'
            ELSE '65+ Tercera Edad'
        END AS GRUPO_ETARIO,
        p.SEXO, p.DIRECCION, p.ID_UBICACION, u.PAIS, u.DEPARTAMENTO, u.MUNICIPIO, u.DISTRITO, u.CODIGO_POSTAL,
        p.ID_CLINICA_HABITUAL, c.NOMBRE_CLINICA, p.ID_EMPRESA, e.NOMBRE_EMPRESA, e.SECTOR,
        p.ID_ASEGURADORA, a.NOMBRE_ASEGURADORA, a.TIPO_COBERTURA, p.NUMERO_POLIZA, p.FECHA_REGISTRO,
        1, v_tipo, SYSDATE, DATE '2999-12-31', 'I',
        RAWTOHEX(STANDARD_HASH(
            NVL(p.DIRECCION, '~') || '|' ||
            NVL(TO_CHAR(p.ID_UBICACION), '~') || '|' ||
            NVL(TO_CHAR(p.ID_CLINICA_HABITUAL), '~') || '|' ||
            NVL(TO_CHAR(p.ID_EMPRESA), '~') || '|' ||
            NVL(TO_CHAR(p.ID_ASEGURADORA), '~') || '|' ||
            NVL(p.NUMERO_POLIZA, '~'),
            'SHA256'
        ))
    FROM stg_clinica_user.STG_PACIENTES p
    LEFT JOIN stg_clinica_user.STG_UBICACIONES u  ON p.ID_UBICACION = u.ID_UBICACION
    LEFT JOIN stg_clinica_user.STG_CLINICAS c     ON p.ID_CLINICA_HABITUAL = c.ID_CLINICA
    LEFT JOIN stg_clinica_user.STG_EMPRESAS e     ON p.ID_EMPRESA = e.ID_EMPRESA
    LEFT JOIN stg_clinica_user.STG_ASEGURADORAS a ON p.ID_ASEGURADORA = a.ID_ASEGURADORA
    WHERE NOT EXISTS (
        SELECT 1 FROM DIM_PACIENTE d
        WHERE d.BK_ID_PACIENTE = p.ID_PACIENTE
          AND d.CURRENTFLAG = 1
          AND d.ROWHASHVALUE = RAWTOHEX(STANDARD_HASH(
              NVL(p.DIRECCION, '~') || '|' ||
              NVL(TO_CHAR(p.ID_UBICACION), '~') || '|' ||
              NVL(TO_CHAR(p.ID_CLINICA_HABITUAL), '~') || '|' ||
              NVL(TO_CHAR(p.ID_EMPRESA), '~') || '|' ||
              NVL(TO_CHAR(p.ID_ASEGURADORA), '~') || '|' ||
              NVL(p.NUMERO_POLIZA, '~'),
              'SHA256'
          ))
    );
    v_ins := SQL%ROWCOUNT;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SP_LOAD_DIM_PACIENTE ejecutado: ' || v_upd || ' caducadas (SCD2), ' || v_ins || ' activas insertadas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en SP_LOAD_DIM_PACIENTE: ' || SQLERRM);
        RAISE;
END SP_LOAD_DIM_PACIENTE;
/
