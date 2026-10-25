"""
============================================================================
PROYECTO DATA WAREHOUSE - RED ASISTENCIAL DE CLÍNICAS
EXPORTADOR DE MODELO DIMENSIONAL A ARCHIVOS CSV PARA POWER BI
============================================================================
Script en Python para extraer todas las Dimensiones y Tablas de Hechos
desde el esquema 'dwh_clinica_user' hacia archivos CSV optimizados para Power BI.

Características:
  - Formato de codificación: UTF-8-SIG (BOM) para compatibilidad nativa en
    Power BI Desktop y Microsoft Excel (respetando tildes y caracteres especiales).
  - Encabezados limpios con los nombres exactos de las columnas.
  - Opciones de exportación: todas las dimensiones completas y hechos (con o sin límite de filas).

Uso:
  python exportar_csv_powerbi.py
  python exportar_csv_powerbi.py --destino ./POWER_BI_DATA
  python exportar_csv_powerbi.py --limite-hechos 50000
============================================================================
"""

import sys
import os
import csv
import argparse
from datetime import datetime

try:
    import oracledb
except ImportError:
    print("[ERROR] El módulo 'oracledb' no está instalado. Instálalo con: pip install oracledb")
    sys.exit(1)

DB_CONFIG_DWH = {
    'user': 'dwh_clinica_user',
    'password': 'DwhPass2026',
    'dsn': 'localhost:1521/XEPDB1'
}

TABLAS_DIMENSIONES = [
    'DIM_TIEMPO',
    'DIM_PACIENTE',
    'DIM_MEDICO',
    'DIM_CLINICA',
    'DIM_ESPECIALIDAD',
    'DIM_TIPO_CONSULTA',
    'DIM_ENFERMEDAD',
    'DIM_FORMA_PAGO',
    'DIM_UBICACION',
    'DIM_PAGADOR'
]

TABLAS_HECHOS = [
    'FACT_CONSULTAS',
    'FACT_CONSULTA_DIAGNOSTICOS',
    'FACT_COBROS_DISTRIBUCION'
]

TABLAS_CONTROL = [
    'CTL_ETL_AUDIT'
]


def exportar_tabla(cur, table_name, output_dir, limite_filas=None):
    os.makedirs(output_dir, exist_ok=True)
    file_path = os.path.join(output_dir, f"{table_name}.csv")

    query = f"SELECT * FROM {table_name}"
    if limite_filas and table_name.startswith("FACT_"):
        query += f" FETCH FIRST {limite_filas} ROWS ONLY"

    print(f"  * Exportando {table_name}...", end="", flush=True)
    start_t = datetime.now()

    cur.execute(query)
    columns = [desc[0] for desc in cur.description]

    row_count = 0
    with open(file_path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f, delimiter=",", quoting=csv.QUOTE_MINIMAL)
        writer.writerow(columns)
        
        while True:
            rows = cur.fetchmany(5000)
            if not rows:
                break
            for r in rows:
                # Formatear fechas como string ISO para PBI
                formatted_row = [
                    val.strftime("%Y-%m-%d %H:%M:%S") if isinstance(val, datetime) else val
                    for val in r
                ]
                writer.writerow(formatted_row)
            row_count += len(rows)

    duration = (datetime.now() - start_t).total_seconds()
    file_size_kb = os.path.getsize(file_path) / 1024
    if file_size_kb >= 1024:
        size_str = f"{file_size_kb / 1024:.2f} MB"
    else:
        size_str = f"{file_size_kb:.1f} KB"

    print(f" OK -> {row_count:>8,} filas | {size_str:>8} | {duration:.2f}s")
    return row_count, file_size_kb


def main():
    parser = argparse.ArgumentParser(description="Exportar Modelo Dimensional a CSV para Power BI")
    parser.add_argument("--destino", default="POWER_BI_DATA", help="Carpeta de destino para los CSV (default: POWER_BI_DATA)")
    parser.add_argument("--limite-hechos", type=int, default=None, help="Límite opcional de filas para tablas de hechos")
    parser.add_argument("--incluir-auditoria", action="store_true", help="Incluir tabla CTL_ETL_AUDIT")
    args = parser.parse_args()

    print("\n" + "=" * 80)
    print(" EXPORTADOR DE DATA WAREHOUSE A CSV PARA POWER BI ".center(80))
    print("=" * 80)
    print(f"Destino de exportación : {os.path.abspath(args.destino)}")
    print(f"Límite en Hechos       : {'Sin límite (Todas las filas)' if not args.limite_hechos else f'{args.limite_hechos:,} filas'}")
    print(f"Fecha de inicio        : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

    conn = oracledb.connect(**DB_CONFIG_DWH)
    cur = conn.cursor()

    total_filas = 0
    total_kb = 0

    print("[1/2] EXPORTANDO TABLAS DIMENSIONALES (DIM_*)")
    print("-" * 80)
    for dim in TABLAS_DIMENSIONES:
        filas, kb = exportar_tabla(cur, dim, args.destino)
        total_filas += filas
        total_kb += kb

    print("\n[2/2] EXPORTANDO TABLAS DE HECHOS (FACT_*)")
    print("-" * 80)
    for fact in TABLAS_HECHOS:
        filas, kb = exportar_tabla(cur, fact, args.destino, args.limite_hechos)
        total_filas += filas
        total_kb += kb

    if args.incluir_auditoria:
        print("\n[EXTRA] EXPORTANDO TABLA DE AUDITORÍA Y CONTROL")
        print("-" * 80)
        for ctl in TABLAS_CONTROL:
            filas, kb = exportar_tabla(cur, ctl, args.destino)
            total_filas += filas
            total_kb += kb

    cur.close()
    conn.close()

    total_mb = total_kb / 1024
    print("\n" + "=" * 80)
    print(f"EXPORTACIÓN COMPLETADA CON ÉXITO")
    print(f"Total registros exportados : {total_filas:,}")
    print(f"Tamaño total en disco      : {total_mb:.2f} MB")
    print(f"Directorio de salida       : {os.path.abspath(args.destino)}")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
