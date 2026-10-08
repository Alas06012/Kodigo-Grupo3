#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
============================================================================
PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
MÓDULO: GENERADOR DE INGESTA MASIVA PARQUET -> ORACLE OLTP
MOTOR: Oracle Database 19c / 21c / 23ai (PDB: XEPDB1)
ESQUEMA: red_clinica_user

DESCRIPCIÓN:
  Lee todos los archivos .parquet disponibles en la carpeta de datos,
  aplica ordenamiento topológico estricto por dependencias de Claves Foráneas (FK),
  excluye columnas virtuales calculadas automáticamente por Oracle,
  formatea tipos de datos (fechas, nulos, strings escapados),
  y genera scripts SQL modulares de inserción masiva junto con un maestro orquestador.
============================================================================
"""

import os
import sys
import argparse
from datetime import datetime, date
import pandas as pd
import numpy as np

# 1. ORDEN TOPOLÓGICO ESTRICTO POR CLAVES FORÁNEAS (18 TABLAS)
ORDEN_TABLAS = [
    # Nivel 0: Catálogos y Entidades Maestras (Sin Dependencias)
    "UBICACIONES",
    "EMPRESAS",
    "ASEGURADORAS",
    "ESPECIALIDADES",
    "ENFERMEDADES",
    "TIPOS_CONSULTA",
    "PROCEDIMIENTOS",
    "FORMAS_PAGO",

    # Nivel 1: Depende de UBICACIONES
    "CLINICAS",

    # Nivel 2: Depende de CLINICAS, UBICACIONES, EMPRESAS, ASEGURADORAS
    "MEDICOS",
    "PACIENTES",

    # Nivel 3: Depende de MEDICOS, ESPECIALIDADES, PACIENTES, CLINICAS, TIPOS_CONSULTA
    "MEDICOS_ESPECIALIDADES",
    "CONSULTAS",

    # Nivel 4: Depende de CONSULTAS, ENFERMEDADES, PROCEDIMIENTOS
    "DIAGNOSTICOS",
    "CONSULTAS_PROCEDIMIENTOS",
    "COBROS_CONSULTA",

    # Nivel 5: Depende de COBROS_CONSULTA, PACIENTES, ASEGURADORAS, EMPRESAS
    "DISTRIBUCION_COBRO",

    # Nivel 6: Depende de COBROS_CONSULTA, DISTRIBUCION_COBRO, FORMAS_PAGO
    "TRANSACCIONES_PAGO"
]

# 2. COLUMNAS VIRTUALES (PROHIBIDO INSERTAR EN ORACLE)
COLUMNAS_VIRTUALES = {
    "COBROS_CONSULTA": {"SALDO_PENDIENTE"},
    "CONSULTAS_PROCEDIMIENTOS": {"SUBTOTAL"},
    "DISTRIBUCION_COBRO": {"SALDO_PENDIENTE"}
}

def formatear_valor_sql(val):
    """Convierte un valor de celda de Pandas a su representación literal en Oracle SQL."""
    if val is None or pd.isna(val):
        return "NULL"
    
    if isinstance(val, (datetime, date, pd.Timestamp)):
        ts = pd.to_datetime(val)
        if ts.hour == 0 and ts.minute == 0 and ts.second == 0:
            return f"TO_DATE('{ts.strftime('%Y-%m-%d')}', 'YYYY-MM-DD')"
        else:
            return f"TO_DATE('{ts.strftime('%Y-%m-%d %H:%M:%S')}', 'YYYY-MM-DD HH24:MI:SS')"
    
    if isinstance(val, (int, np.integer)):
        return str(val)
    
    if isinstance(val, (float, np.floating)):
        return f"{val:.2f}" if val % 1 != 0 else str(int(val))
    
    if isinstance(val, bool):
        return "1" if val else "0"
    
    # Texto / Strings
    s_val = str(val).strip()
    s_escaped = s_val.replace("'", "''")
    return f"'{s_escaped}'"

def procesar_archivo_parquet(tabla_nombre, ruta_parquet, output_dir, batch_size=500):
    """Lee un parquet y genera el archivo SQL de inserción."""
    print(f"\n[PROCESANDO] {tabla_nombre} desde: {ruta_parquet}")
    try:
        df = pd.read_parquet(ruta_parquet)
    except Exception as e:
        print(f"  [ERROR] No se pudo leer {ruta_parquet}: {e}")
        return None, 0

    total_filas = len(df)
    print(f"  Filas encontradas: {total_filas}")

    # Filtrar columnas virtuales
    cols_virtuales = COLUMNAS_VIRTUALES.get(tabla_nombre, set())
    columnas_validas = [col for col in df.columns if col.upper() not in cols_virtuales]
    
    if cols_virtuales:
        omitidas = [col for col in df.columns if col.upper() in cols_virtuales]
        if omitidas:
            print(f"  Columnas virtuales omitidas (calculadas por Oracle): {omitidas}")

    df_clean = df[columnas_validas]
    cols_sql_str = ", ".join(columnas_validas)

    sql_filename = f"CARGA_{tabla_nombre}.sql"
    sql_path = os.path.join(output_dir, sql_filename)

    with open(sql_path, "w", encoding="utf-8") as f:
        f.write(f"-- ============================================================================\n")
        f.write(f"-- TABLA: {tabla_nombre}\n")
        f.write(f"-- REGISTROS A INSERTAR: {total_filas}\n")
        f.write(f"-- FECHA DE GENERACIÓN: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"-- ============================================================================\n\n")
        f.write(f"PROMPT Insertando registros en {tabla_nombre}...\n\n")

        insert_count = 0
        for idx, row in df_clean.iterrows():
            valores = [formatear_valor_sql(row[col]) for col in columnas_validas]
            vals_str = ", ".join(valores)
            f.write(f"INSERT INTO {tabla_nombre} ({cols_sql_str}) VALUES ({vals_str});\n")
            insert_count += 1

            if insert_count % batch_size == 0:
                f.write("COMMIT;\n")

        if insert_count % batch_size != 0:
            f.write("COMMIT;\n")
        
        f.write(f"\nPROMPT {tabla_nombre} completada: {insert_count} registros insertados.\n")

    print(f"  [OK] Generado script SQL: {sql_filename} ({insert_count} sentencias INSERT)")
    return sql_filename, insert_count

def generar_script_maestro(archivos_generados, output_dir):
    """Crea el script maestro 00_EJECUTAR_CARGA_MASIVA.sql."""
    maestro_path = os.path.join(output_dir, "00_EJECUTAR_CARGA_MASIVA.sql")
    with open(maestro_path, "w", encoding="utf-8") as f:
        f.write("/* ============================================================================\n")
        f.write("   PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS\n")
        f.write("   ORQUESTADOR MAESTRO DE INGESTA DE DATOS DE PRUEBA (OLTP)\n")
        f.write("   MOTOR: Oracle Database (XEPDB1) | ESQUEMA: red_clinica_user\n")
        f.write("   ============================================================================ */\n\n")
        f.write("ALTER SESSION SET CONTAINER = XEPDB1;\n")
        f.write("SET DEFINE OFF;\n")
        f.write("SET SERVEROUTPUT ON;\n")
        f.write("ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';\n\n")

        f.write("PROMPT =====================================================================\n")
        f.write("PROMPT FASE 1: PRE-INGESTA - PREPARAR COLUMNAS IDENTITY\n")
        f.write("PROMPT =====================================================================\n")
        f.write("@@01_PRE_INGESTA_IDENTITY_BY_DEFAULT.sql\n\n")

        f.write("PROMPT =====================================================================\n")
        f.write("PROMPT FASE 2: INSERCIÓN DE DATOS EN ORDEN TOPOLÓGICO DE CLAVES FORÁNEAS\n")
        f.write("PROMPT =====================================================================\n")
        for sql_file, count in archivos_generados:
            f.write(f"@@{sql_file}\n")

        f.write("\nPROMPT =====================================================================\n")
        f.write("PROMPT FASE 3: POST-INGESTA - REINICIAR SECUENCIAS IDENTITY EN MAX + 1\n")
        f.write("PROMPT =====================================================================\n")
        f.write("@@02_POST_INGESTA_IDENTITY_ALWAYS_RESTART.sql\n\n")

        f.write("PROMPT =====================================================================\n")
        f.write("PROMPT CARGA MASIVA FINALIZADA EXITOSAMENTE\n")
        f.write("PROMPT =====================================================================\n")
        f.write("COMMIT;\n")

    print(f"\n[OK] Script maestro generado con éxito: 00_EJECUTAR_CARGA_MASIVA.sql")

def main():
    parser = argparse.ArgumentParser(description="Generador de Scripts de Ingesta Masiva desde Parquet para Oracle OLTP")
    parser.add_argument("--data_dir", default="..", help="Directorio donde residen los archivos .parquet (default: ..)")
    parser.add_argument("--output_dir", default=".", help="Directorio destino para los scripts .sql (default: .)")
    parser.add_argument("--batch_size", type=int, default=500, help="Tamaño de lote para sentencias COMMIT (default: 500)")
    args = parser.parse_args()

    data_dir = os.path.abspath(args.data_dir)
    output_dir = os.path.abspath(args.output_dir)
    os.makedirs(output_dir, exist_ok=True)

    print("============================================================================")
    print("INICIO: GENERADOR DE INGESTA PARQUET -> ORACLE OLTP")
    print(f"Directorio Origen Parquets: {data_dir}")
    print(f"Directorio Destino Scripts: {output_dir}")
    print("============================================================================")

    archivos_generados = []
    total_registros_global = 0

    # Procesar según el orden topológico estricto
    for tabla in ORDEN_TABLAS:
        # Buscar el archivo parquet coincidente (mayúsculas o minúsculas)
        posibles_rutas = [
            os.path.join(data_dir, f"{tabla}.parquet"),
            os.path.join(data_dir, f"{tabla.lower()}.parquet"),
            os.path.join(data_dir, f"{tabla.capitalize()}.parquet")
        ]
        
        parquet_encontrado = None
        for ruta in posibles_rutas:
            if os.path.isfile(ruta):
                parquet_encontrado = ruta
                break

        if parquet_encontrado:
            sql_file, count = procesar_archivo_parquet(tabla, parquet_encontrado, output_dir, args.batch_size)
            if sql_file:
                archivos_generados.append((sql_file, count))
                total_registros_global += count
        else:
            print(f"[OMITIDO] {tabla}: No se encontró archivo .parquet en {data_dir}")

    if archivos_generados:
        generar_script_maestro(archivos_generados, output_dir)
        print("\n============================================================================")
        print(f"RESUMEN GLOBAL:")
        print(f"  Tablas procesadas: {len(archivos_generados)} de {len(ORDEN_TABLAS)}")
        print(f"  Total registros generados: {total_registros_global}")
        print("============================================================================")
    else:
        print("\n[AVISO] No se encontró ningún archivo .parquet para procesar.")

if __name__ == "__main__":
    main()
