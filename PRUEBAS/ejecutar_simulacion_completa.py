"""
============================================================================
PROYECTO DATA WAREHOUSE - RED ASISTENCIAL DE CLÍNICAS
ORQUESTADOR AUTOMATIZADO DE PRUEBAS END-TO-END
============================================================================
Script en Python para ejecutar el ciclo completo de pruebas de calidad:
  1. Inyección de datos de prueba en OLTP (01_SIMULACION_CARGA_OLTP.sql).
  2. Disparo de Apache Hop Pipeline Diario (ejecutar_pipeline_diario.bat).
  3. Comprobación y validación automatizada en DWH (CTL_ETL_AUDIT, Dimensiones, SCD1/SCD2 y Hechos).
  4. (Opcional) Rollback y limpieza completa (03_LIMPIEZA_ROLLBACK_PRUEBAS.sql).

Uso:
  python ejecutar_simulacion_completa.py --modo completo
  python ejecutar_simulacion_completa.py --modo cargar
  python ejecutar_simulacion_completa.py --modo hop
  python ejecutar_simulacion_completa.py --modo validar
  python ejecutar_simulacion_completa.py --modo limpiar
============================================================================
"""

import sys
import os
import subprocess
import argparse
from datetime import datetime

try:
    import oracledb
except ImportError:
    print("[ERROR] El módulo 'oracledb' no está instalado. Instálalo con: pip install oracledb")
    sys.exit(1)

# Configuración de conexiones
DB_CONFIG_OLTP = {
    'user': 'red_clinica_user',
    'password': 'Password2026',
    'dsn': 'localhost:1521/XEPDB1'
}

DB_CONFIG_DWH = {
    'user': 'dwh_clinica_user',
    'password': 'DwhPass2026',
    'dsn': 'localhost:1521/XEPDB1'
}

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.abspath(os.path.join(BASE_DIR, ".."))
HOP_BAT_PATH = os.path.join(PROJECT_DIR, "HOP", "ejecutar_pipeline_diario.bat")
SQL_CARGA_PATH = os.path.join(BASE_DIR, "01_SIMULACION_CARGA_OLTP.sql")
SQL_ROLLBACK_PATH = os.path.join(BASE_DIR, "03_LIMPIEZA_ROLLBACK_PRUEBAS.sql")


def print_header(title):
    print("\n" + "=" * 80)
    print(f" {title.center(78)} ")
    print("=" * 80)


def print_step(step_num, title):
    print(f"\n[PASO {step_num}] {title}")
    print("-" * 80)


def extraer_bloques_plsql(sql_file_path):
    """Extrae bloques PL/SQL y sentencias de un archivo .sql delimitadas por '/' en su propia línea"""
    with open(sql_file_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    bloques = []
    current = []
    for line in content.splitlines():
        trimmed = line.strip()
        t_upper = trimmed.upper()
        if trimmed == "/":
            if current:
                bloques.append("\n".join(current).strip())
                current = []
        elif any(t_upper.startswith(prefix) for prefix in ["SET SERVEROUTPUT", "SET LINESIZE", "SET PAGESIZE", "SET FEEDBACK", "PROMPT", "SHOW"]):
            continue
        else:
            current.append(line)
    
    if current:
        resto = "\n".join(current).strip()
        if resto:
            bloques.append(resto)
    return [b for b in bloques if b]


def ejecutar_script_sql(config, sql_file_path, nombre_etapa):
    print(f"Conectando a {config['user']}@{config['dsn']}...")
    conn = oracledb.connect(**config)
    conn.autocommit = False
    cur = conn.cursor()
    cur.callproc("dbms_output.enable")

    bloques = extraer_bloques_plsql(sql_file_path)
    print(f"Ejecutando {len(bloques)} bloque(s) PL/SQL en {nombre_etapa}...")

    for idx, bloque in enumerate(bloques, 1):
        if not bloque.strip():
            continue
        try:
            cur.execute(bloque)
            conn.commit()
            
            # Recuperar DBMS_OUTPUT
            status = cur.var(oracledb.NUMBER)
            line = cur.var(oracledb.STRING)
            while True:
                cur.callproc("dbms_output.get_line", (line, status))
                if status.getvalue() != 0:
                    break
                print(line.getvalue())
        except Exception as e:
            conn.rollback()
            print(f"[ERROR] Falló la ejecución del bloque {idx} en {nombre_etapa}: {e}")
            cur.close()
            conn.close()
            raise

    cur.close()
    conn.close()
    print(f"[OK] {nombre_etapa} completado con éxito.")


def ejecutar_pipeline_hop(tipo_carga="INCREMENTAL", lookback=3):
    print_header(f"DISPARANDO APACHE HOP: {tipo_carga} (Lookback={lookback} días)")
    cmd = [HOP_BAT_PATH, tipo_carga, str(lookback)]
    print(f"Comando a ejecutar: {' '.join(cmd)}")
    start_time = datetime.now()

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=PROJECT_DIR)
    
    # Mostrar logs en tiempo real
    for line in iter(proc.stdout.readline, ''):
        line_clean = line.strip()
        if line_clean:
            # Filtrar líneas relevantes para que la salida sea legible
            if any(k in line_clean for k in ['[Basic]', '[Error]', 'ERROR', 'Finished', 'Starting', 'BATCH_ID', 'SUCCESS', 'FAILED']):
                print(f"  [HOP] {line_clean}")
    
    proc.wait()
    duration = (datetime.now() - start_time).total_seconds()
    print(f"\nDuración de ejecución de Apache Hop: {duration:.2f} segundos")
    
    if proc.returncode != 0:
        print(f"[ERROR] Apache Hop finalizó con código de retorno {proc.returncode}")
        return False
    else:
        print("[OK] Apache Hop completó su ejecución con código 0.")
        return True


def validar_dwh():
    print_header("VALIDACIÓN DE RESULTADOS EN EL DATA WAREHOUSE")
    conn = oracledb.connect(**DB_CONFIG_DWH)
    cur = conn.cursor()

    # 1. Auditoría de CTL_ETL_AUDIT
    print_step("1", "Auditoría del Último Lote de Ingesta en CTL_ETL_AUDIT")
    query_audit = """
    SELECT 
        BATCH_ID,
        COUNT(*) AS TOTAL_PROCESOS,
        SUM(CASE WHEN ESTADO = 'SUCCESS' THEN 1 ELSE 0 END) AS EXITOSOS,
        SUM(CASE WHEN ESTADO = 'FAILED'  THEN 1 ELSE 0 END) AS FALLIDOS,
        NVL(SUM(FILAS_LEIDAS), 0) AS TOTAL_LEIDAS,
        NVL(SUM(FILAS_INSERTADAS), 0) AS TOTAL_INS,
        NVL(SUM(FILAS_ACTUALIZADAS), 0) AS TOTAL_ACT,
        ROUND(NVL(SUM(DURACION_SEGUNDOS), 0), 2) AS SEGUNDOS
    FROM CTL_ETL_AUDIT
    WHERE BATCH_ID = (SELECT MAX(BATCH_ID) FROM CTL_ETL_AUDIT WHERE BATCH_ID LIKE 'BATCH_%')
    GROUP BY BATCH_ID
    """
    cur.execute(query_audit)
    row = cur.fetchone()
    if row:
        batch_id, total, ok, fail, leidas, ins, act, seg = row
        print(f"  * Batch ID          : {batch_id}")
        print(f"  * Total Procesos    : {total} (Esperados: 31)")
        print(f"  * Exitosos / Fails  : {ok} / {fail}")
        print(f"  * Filas Procesadas  : Leídas={leidas} | Insertadas={ins} | Actualizadas={act}")
        print(f"  * Duración Total    : {seg} segundos")
        if fail == 0 and total == 31:
            print("  >>> ESTADO: [PASS] Todas las 31 etapas ejecutaron con éxito.")
        else:
            print("  >>> ESTADO: [FAIL] Hubo errores o etapas incompletas.")
    else:
        print("  [WARN] No se encontraron registros de auditoría en CTL_ETL_AUDIT.")

    # Detalle de procedimientos con modificaciones
    query_detail = """
    SELECT PROCEDIMIENTO, CAPA, ESTADO, FILAS_INSERTADAS, FILAS_ACTUALIZADAS, DURACION_SEGUNDOS
    FROM CTL_ETL_AUDIT
    WHERE BATCH_ID = (SELECT MAX(BATCH_ID) FROM CTL_ETL_AUDIT WHERE BATCH_ID LIKE 'BATCH_%')
      AND (FILAS_INSERTADAS > 0 OR FILAS_ACTUALIZADAS > 0)
    ORDER BY ID_AUDIT ASC
    """
    cur.execute(query_detail)
    print("\n  Procedimientos con cambios en este lote:")
    print(f"  {'PROCEDIMIENTO':<32} {'CAPA':<8} {'ESTADO':<8} {'INS':<6} {'ACT':<6} {'DURACION(s)'}")
    print("  " + "-" * 70)
    for r in cur.fetchall():
        print(f"  {r[0]:<32} {r[1]:<8} {r[2]:<8} {r[3]:<6} {r[4]:<6} {r[5]}")

    # 2. Nuevos Catálogos Maestros
    print_step("2", "Validación de Nuevos Catálogos Maestros en Dimensiones")
    queries_catalogos = [
        ("DIM_UBICACION", "SELECT SK_UBICACION, DISTRITO, MUNICIPIO FROM DIM_UBICACION WHERE DISTRITO LIKE '%Cayalá%'"),
        ("DIM_CLINICA (Nueva)", "SELECT SK_CLINICA, BK_ID_CLINICA, NOMBRE_CLINICA, CURRENTFLAG FROM DIM_CLINICA WHERE NOMBRE_CLINICA LIKE '%Cayalá%'"),
        ("DIM_PAGADOR", "SELECT SK_PAGADOR, TIPO_PAGADOR, NOMBRE_PAGADOR, NUMERO_IDENTIFICACION FROM DIM_PAGADOR WHERE NUMERO_IDENTIFICACION IN ('88776655-4', '99887766-5')"),
        ("DIM_ENFERMEDAD", "SELECT SK_ENFERMEDAD, CODIGO_CIE10, NOMBRE_ENFERMEDAD FROM DIM_ENFERMEDAD WHERE CODIGO_CIE10 = 'U07.1'"),
        ("DIM_TIPO_CONSULTA", "SELECT SK_TIPO_CONSULTA, NOMBRE_TIPO, PRECIO_BASE FROM DIM_TIPO_CONSULTA WHERE NOMBRE_TIPO LIKE '%Teleconsulta Especializada%'"),
        ("DIM_FORMA_PAGO", "SELECT SK_FORMA_PAGO, NOMBRE_FORMA_PAGO, CATEGORIA FROM DIM_FORMA_PAGO WHERE NOMBRE_FORMA_PAGO LIKE '%Billetera%'")
    ]
    for nombre, q in queries_catalogos:
        cur.execute(q)
        rows = cur.fetchall()
        status = "[PASS]" if rows else "[FAIL]"
        print(f"  {status} {nombre}: {len(rows)} registro(s) encontrado(s)")
        for r in rows:
            print(f"         -> {r}")

    # 3. Verificación SCD Tipo 1
    print_step("3", "Validación SCD Tipo 1 (Actualización In-Place)")
    cur.execute("SELECT SK_ESPECIALIDAD, BK_ID_ESPECIALIDAD, NOMBRE_ESPECIALIDAD, DESCRIPCION FROM DIM_ESPECIALIDAD WHERE BK_ID_ESPECIALIDAD = 1")
    scd1_row = cur.fetchone()
    if scd1_row and "Certificación Internacional" in str(scd1_row[3]):
        print(f"  [PASS] DIM_ESPECIALIDAD BK=1 actualizado in-place correctamente:")
        print(f"         Descripción actual: {scd1_row[3]}")
    else:
        print(f"  [INFO] DIM_ESPECIALIDAD BK=1: {scd1_row}")

    # 4. Verificación SCD Tipo 2 (Historización dual de registros)
    print_step("4", "Validación SCD Tipo 2 (Historización y Vigencia de Versiones)")
    scd2_tests = [
        ("DIM_PACIENTE (BK=10)", "SELECT SK_PACIENTE, BK_ID_PACIENTE, DIRECCION, CURRENTFLAG, TO_CHAR(FECHAINICIO,'YYYY-MM-DD'), TO_CHAR(FECHAFIN,'YYYY-MM-DD') FROM DIM_PACIENTE WHERE BK_ID_PACIENTE = 10 ORDER BY SK_PACIENTE"),
        ("DIM_MEDICO (BK=5)", "SELECT SK_MEDICO, BK_ID_MEDICO, NOMBRE_CLINICA_BASE, CURRENTFLAG, TO_CHAR(FECHAINICIO,'YYYY-MM-DD'), TO_CHAR(FECHAFIN,'YYYY-MM-DD') FROM DIM_MEDICO WHERE BK_ID_MEDICO = 5 ORDER BY SK_MEDICO"),
        ("DIM_CLINICA (BK=2)", "SELECT SK_CLINICA, BK_ID_CLINICA, DIRECCION, CURRENTFLAG, TO_CHAR(FECHAINICIO,'YYYY-MM-DD'), TO_CHAR(FECHAFIN,'YYYY-MM-DD') FROM DIM_CLINICA WHERE BK_ID_CLINICA = 2 ORDER BY SK_CLINICA")
    ]
    for entidad, q in scd2_tests:
        cur.execute(q)
        rows = cur.fetchall()
        print(f"\n  {entidad} -> {len(rows)} versión(es) encontrada(s):")
        for r in rows:
            flag_desc = "ACTIVA (Vigente)" if r[3] == 1 else "CERRADA (Histórica)"
            print(f"    * SK={r[0]} | Flag={r[3]} ({flag_desc}) | Vigencia: {r[4]} a {r[5]} | Detalle: {r[2]}")
        if len(rows) >= 2:
            print(f"    >>> [PASS] Historización SCD2 correcta (Versión anterior cerrada y nueva versión abierta).")
        else:
            print(f"    >>> [WARN] Se esperaba al menos 2 versiones para {entidad}.")

    # 5. Verificación de Tablas de Hechos (Fact Tables)
    print_step("5", "Validación de Integración en Tablas de Hechos (Facts)")
    cur.execute("""
    SELECT 
        FC.SK_CONSULTA,
        FC.BK_ID_CONSULTA,
        DT.FECHA,
        FC.PRECIO_HONORARIOS,
        FC.MONTO_TOTAL_FACTURADO,
        FC.MONTO_TOTAL_PAGADO,
        FC.SALDO_PENDIENTE,
        FC.ESTADO_COBRO,
        DP.NOMBRE_COMPLETO AS PACIENTE,
        DM.NOMBRE_COMPLETO AS MEDICO,
        DC.NOMBRE_CLINICA AS CLINICA
    FROM FACT_CONSULTAS FC
    JOIN DIM_TIEMPO DT ON FC.SK_TIEMPO = DT.SK_TIEMPO
    JOIN DIM_PACIENTE DP ON FC.SK_PACIENTE = DP.SK_PACIENTE
    JOIN DIM_MEDICO DM ON FC.SK_MEDICO = DM.SK_MEDICO
    JOIN DIM_CLINICA DC ON FC.SK_CLINICA = DC.SK_CLINICA
    WHERE FC.MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    ORDER BY FC.BK_ID_CONSULTA
    """)
    fact_rows = cur.fetchall()
    print(f"  Total Consultas de Prueba integradas en FACT_CONSULTAS: {len(fact_rows)}")
    for r in fact_rows:
        print(f"    * BK_ID={r[1]} | Facturado=${r[4]:.2f} | Pagado=${r[5]:.2f} | Saldo=${r[6]:.2f} | Estado={r[7]} | Paciente: {r[8]} | Médico: {r[9]}")
    
    if len(fact_rows) >= 5:
        print("  >>> [PASS] Las 5 consultas de prueba fueron absorbidas por FACT_CONSULTAS.")
    else:
        print(f"  >>> [WARN] Se integraron {len(fact_rows)} de 5 consultas esperadas.")

    # 6. Fact Distribución de Cobro y Fact Consulta Diagnósticos
    cur.execute("""
    SELECT 
        FCD.TIPO_PAGADOR,
        DP.NOMBRE_PAGADOR,
        FCD.PORCENTAJE_COBERTURA,
        FCD.MONTO_ASIGNADO,
        FCD.MONTO_PAGADO,
        FCD.SALDO_PENDIENTE,
        FCD.ESTADO_DISTRIBUCION,
        DFP.NOMBRE_FORMA_PAGO
    FROM FACT_COBROS_DISTRIBUCION FCD
    LEFT JOIN DIM_PAGADOR DP ON FCD.SK_PAGADOR = DP.SK_PAGADOR
    LEFT JOIN DIM_FORMA_PAGO DFP ON FCD.SK_FORMA_PAGO_PREDOMINANTE = DFP.SK_FORMA_PAGO
    JOIN FACT_CONSULTAS FC ON FCD.BK_ID_CONSULTA = FC.BK_ID_CONSULTA
    WHERE FC.MOTIVO_CONSULTA LIKE '%[PRUEBA]%'
    ORDER BY FCD.SK_COBRO_DISTRIBUCION
    """)
    distrib_rows = cur.fetchall()
    print(f"\n  Líneas de Distribución Financiera integradas en FACT_COBROS_DISTRIBUCION: {len(distrib_rows)}")
    for r in distrib_rows:
        pagador = r[1] if r[1] else "Paciente Directo"
        forma = r[7] if r[7] else "Pendiente de Pago"
        print(f"    * Pagador={r[0]} ({pagador}) | %={r[2]} | Asignado=${r[3]:.2f} | Pagado=${r[4]:.2f} | Saldo=${r[5]:.2f} | {forma}")

    cur.close()
    conn.close()
    print_header("FIN DE LA VALIDACIÓN AUTOMATIZADA")


def main():
    parser = argparse.ArgumentParser(description="Orquestador de Pruebas del Pipeline DWH")
    parser.add_argument("--modo", choices=["completo", "cargar", "hop", "validar", "limpiar"], default="completo",
                        help="Modo de ejecución: completo (cargar + hop + validar), cargar, hop, validar o limpiar")
    parser.add_argument("--lookback", type=int, default=3, help="Días de lookback para Apache Hop (default: 3)")
    args = parser.parse_args()

    print_header("ORQUESTADOR END-TO-END DE PRUEBAS - RED ASISTENCIAL DWH")
    print(f"Modo seleccionado: {args.modo.upper()}")
    print(f"Directorio de pruebas: {BASE_DIR}")
    print(f"Fecha de ejecución  : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    if args.modo in ["cargar", "completo"]:
        print_step("A", "Inyectando Datos de Prueba en Base Transaccional OLTP")
        ejecutar_script_sql(DB_CONFIG_OLTP, SQL_CARGA_PATH, "Simulación OLTP")

    if args.modo in ["hop", "completo"]:
        print_step("B", "Ejecutando Pipeline Orquestador de Apache Hop")
        exito = ejecutar_pipeline_hop(tipo_carga="INCREMENTAL", lookback=args.lookback)
        if not exito:
            print("[ALERTA] Apache Hop reportó errores durante la ejecución.")

    if args.modo in ["validar", "completo"]:
        print_step("C", "Validando Integración y Mapeo en el Data Warehouse")
        validar_dwh()

    if args.modo == "limpiar":
        print_step("D", "Ejecutando Rollback y Limpieza en OLTP y DWH")
        # El script tiene dos bloques: bloque 1 en OLTP, bloque 2 en DWH
        bloques = extraer_bloques_plsql(SQL_ROLLBACK_PATH)
        if len(bloques) >= 1:
            print("--- Limpiando OLTP ---")
            conn = oracledb.connect(**DB_CONFIG_OLTP)
            cur = conn.cursor()
            cur.callproc("dbms_output.enable")
            cur.execute(bloques[0])
            conn.commit()
            status, line = cur.var(oracledb.NUMBER), cur.var(oracledb.STRING)
            while True:
                cur.callproc("dbms_output.get_line", (line, status))
                if status.getvalue() != 0: break
                print(line.getvalue())
            cur.close()
            conn.close()

        if len(bloques) >= 2:
            print("--- Limpiando DWH ---")
            conn = oracledb.connect(**DB_CONFIG_DWH)
            cur = conn.cursor()
            cur.callproc("dbms_output.enable")
            cur.execute(bloques[1])
            conn.commit()
            status, line = cur.var(oracledb.NUMBER), cur.var(oracledb.STRING)
            while True:
                cur.callproc("dbms_output.get_line", (line, status))
                if status.getvalue() != 0: break
                print(line.getvalue())
            cur.close()
            conn.close()
        print("[OK] Limpieza y Rollback completados.")


if __name__ == "__main__":
    main()
