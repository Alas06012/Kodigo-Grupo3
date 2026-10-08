#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
============================================================================
PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
MÓDULO: INGESTA MASIVA PARQUET -> ORACLE OLTP
MOTOR: Oracle Database (XEPDB1) | ESQUEMA: red_clinica_user
============================================================================
DESCRIPCIÓN:
  Este script realiza la ingesta masiva y de alto rendimiento de los 18 archivos
  .parquet en la base de datos OLTP:
    1. Ejecuta la Pre-Ingesta (IDENTITY -> BY DEFAULT ON NULL).
    2. Inserta los datos tabla por tabla en estricto orden topológico de FKs.
    3. Excluye automáticamente columnas virtuales de Oracle.
    4. Utiliza arrays binds (cursor.executemany) por lotes de alto rendimiento.
    5. Ejecuta la Post-Ingesta (recalcula MAX(ID) + 1, RESTART WITH y regresa a ALWAYS).
    
    COMANDOS DE EJECUCIÓN:
    python "OLTP/Data/IngestaParquet/ingestar_parquets_oltp.py" --user red_clinica_user --password Password2026
============================================================================
"""

import os
import sys
import time
import argparse
from datetime import datetime, date
import pandas as pd
import numpy as np
import oracledb

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

# 3. COLUMNAS IDENTITY POR TABLA
COLUMNAS_IDENTITY = {
    "UBICACIONES": "ID_UBICACION",
    "EMPRESAS": "ID_EMPRESA",
    "ASEGURADORAS": "ID_ASEGURADORA",
    "ESPECIALIDADES": "ID_ESPECIALIDAD",
    "ENFERMEDADES": "ID_ENFERMEDAD",
    "TIPOS_CONSULTA": "ID_TIPO_CONSULTA",
    "PROCEDIMIENTOS": "ID_PROCEDIMIENTO",
    "FORMAS_PAGO": "ID_FORMA_PAGO",
    "CLINICAS": "ID_CLINICA",
    "MEDICOS": "ID_MEDICO",
    "PACIENTES": "ID_PACIENTE",
    "MEDICOS_ESPECIALIDADES": "ID_MEDICO_ESPECIALIDAD",
    "CONSULTAS": "ID_CONSULTA",
    "DIAGNOSTICOS": "ID_DIAGNOSTICO",
    "CONSULTAS_PROCEDIMIENTOS": "ID_CONSULTA_PROCEDIMIENTO",
    "COBROS_CONSULTA": "ID_COBRO",
    "DISTRIBUCION_COBRO": "ID_DISTRIBUCION",
    "TRANSACCIONES_PAGO": "ID_TRANSACCION"
}

def ejecutar_script_sql(cursor, ruta_sql):
    """Ejecuta un script PL/SQL (un bloque anónimo) leyendo el archivo."""
    with open(ruta_sql, 'r', encoding='utf-8') as f:
        contenido = f.read()
    
    # Extraer el bloque DECLARE ... END;
    inicio = contenido.find("DECLARE")
    if inicio != -1:
        fin = contenido.rfind("END;")
        if fin != -1:
            bloque = contenido[inicio:fin+4]
            cursor.execute(bloque)
            return True
    
    # Si no es bloque único, ejecutar comandos individuales
    comandos = [c.strip() for c in contenido.split(";") if c.strip() and not c.strip().startswith("--")]
    for cmd in comandos:
        if not cmd.upper().startswith("ALTER SESSION") and not cmd.upper().startswith("SET"):
            try:
                cursor.execute(cmd)
            except Exception as e:
                print(f"  [ALERTA SQL] {e}")
    return True

from decimal import Decimal

def preparar_datos_batch(df, columnas):
    """Convierte el DataFrame en una lista de tuplas limpias para oracledb executemany."""
    df_clean = df[columnas].copy()
    for col in columnas:
        s = df_clean[col]
        # Reemplazar NaN / NaT por None para evitar DPY-4004 en bindings numéricos de Oracle
        if s.hasnans:
            df_clean[col] = s.astype(object).where(s.notnull(), None)
    return list(df_clean.itertuples(index=False, name=None))

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_data_dir = os.path.dirname(script_dir)  # Ruta de OLTP/Data

    parser = argparse.ArgumentParser(description="Ingesta masiva de Parquets a Oracle OLTP")
    parser.add_argument("--host", default="localhost", help="Host de Oracle (default: localhost)")
    parser.add_argument("--port", type=int, default=1521, help="Puerto de Oracle (default: 1521)")
    parser.add_argument("--service_name", default="XEPDB1", help="Service name / PDB (default: XEPDB1)")
    parser.add_argument("--user", default="red_clinica_user", help="Usuario OLTP (default: red_clinica_user)")
    parser.add_argument("--password", default="red_clinica_user", help="Contraseña (default: red_clinica_user)")
    parser.add_argument("--data_dir", default=None, help="Ruta de los archivos parquet (default: OLTP/Data)")
    parser.add_argument("--batch_size", type=int, default=25000, help="Tamaño de lote para executemany (default: 25000)")
    parser.add_argument("--truncate", action="store_true", default=True, help="Limpiar/Truncar las 18 tablas antes de la ingesta (default: True)")
    parser.add_argument("--no_truncate", action="store_false", dest="truncate", help="No truncar las tablas antes de la ingesta")
    parser.add_argument("--disable_triggers", action="store_true", default=True, help="Deshabilitar triggers de fila durante la carga (default: True)")
    parser.add_argument("--keep_triggers", action="store_false", dest="disable_triggers", help="Mantener triggers activos durante la carga")
    parser.add_argument("--skip_pre_post", action="store_true", help="Omitir scripts de pre y post ingesta")
    args = parser.parse_args()

    # Si no se especificó o es relativo a la raíz, resolver inteligentemente
    if args.data_dir:
        data_dir = os.path.abspath(args.data_dir)
        # Si la ruta indicada no contiene parquets pero default_data_dir sí, usar default_data_dir
        if not any(f.endswith('.parquet') for f in os.listdir(data_dir) if os.path.isfile(os.path.join(data_dir, f))):
            if os.path.isdir(default_data_dir) and any(f.endswith('.parquet') for f in os.listdir(default_data_dir)):
                print(f"[INFO] No se encontraron parquets en {data_dir}. Usando carpeta detectada: {default_data_dir}")
                data_dir = default_data_dir
    else:
        data_dir = default_data_dir

    print("============================================================================")
    print("PROYECTO DATA WAREHOUSE - PIPELINE DE INGESTA MASIVA OLTP")
    print(f"Base de Datos: {args.host}:{args.port}/{args.service_name}")
    print(f"Esquema:       {args.user}")
    print(f"Carpeta Datos: {data_dir}")
    print(f"Lote Batch:    {args.batch_size:,} filas por commit")
    print(f"Truncar previo:{' SÍ (Evita ORA-00001)' if args.truncate else ' NO'}")
    print("============================================================================")

    # 1. Conexión a Oracle
    try:
        dsn = f"{args.host}:{args.port}/{args.service_name}"
        conn = oracledb.connect(user=args.user, password=args.password, dsn=dsn)
        cursor = conn.cursor()
        cursor.execute("ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,'")
        cursor.execute("ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'")
        print(f"[CONEXION OK] Conectado exitosamente como {args.user} a {dsn}\n")
    except Exception as e:
        print(f"[ERROR DE CONEXION] No se pudo conectar a Oracle: {e}")
        print("Verifica que la base de datos esté arriba y las credenciales sean correctas.")
        sys.exit(1)

    tiempo_total_inicio = time.time()

    # 2. FASE 0: LIMPIEZA / TRUNCATE SEGURO (Deshabilita FKs -> Truncate -> Rehabilita FKs)
    if args.truncate:
        print("----------------------------------------------------------------------------")
        print("FASE 0: LIMPIEZA PREVIA - TRUNCATE SEGURO DE TABLAS OLTP")
        print("----------------------------------------------------------------------------")
        clean_sql = os.path.join(script_dir, "00_LIMPIAR_TABLAS_OLTP.sql")
        if os.path.isfile(clean_sql):
            try:
                ejecutar_script_sql(cursor, clean_sql)
                conn.commit()
                print("[OK] Las 18 tablas OLTP han sido truncadas limpiamente (FKs protegidas).\n")
            except Exception as e:
                print(f"[ERROR LIMPIEZA] {e}\n")
        else:
            print("[AVISO] Script 00_LIMPIAR_TABLAS_OLTP.sql no encontrado. Continuando sin truncar.\n")

    # 3. GESTIÓN DE TRIGGERS (Deshabilitar para evitar ORA / cuellos de botella en millones de filas)
    if args.disable_triggers:
        try:
            cursor.execute("""
                BEGIN
                    FOR trg IN (SELECT trigger_name FROM user_triggers WHERE status = 'ENABLED') LOOP
                        EXECUTE IMMEDIATE 'ALTER TRIGGER ' || trg.trigger_name || ' DISABLE';
                    END LOOP;
                END;
            """)
            conn.commit()
            print("[INFO] Triggers de validación deshabilitados temporalmente para máxima velocidad de ingesta.")
        except Exception as e:
            print(f"[ALERTA TRIGGERS] {e}")

    # 4. FASE 1: PRE-INGESTA (IDENTITY -> BY DEFAULT ON NULL)
    if not args.skip_pre_post:
        print("----------------------------------------------------------------------------")
        print("FASE 1: PRE-INGESTA - CONFIGURANDO COLUMNAS IDENTITY A 'BY DEFAULT ON NULL'")
        print("----------------------------------------------------------------------------")
        pre_sql = os.path.join(script_dir, "01_PRE_INGESTA_IDENTITY_BY_DEFAULT.sql")
        if os.path.isfile(pre_sql):
            try:
                ejecutar_script_sql(cursor, pre_sql)
                conn.commit()
                print("[OK] Columnas IDENTITY modificadas a BY DEFAULT ON NULL.\n")
            except Exception as e:
                print(f"[ERROR PRE-INGESTA] {e}\n")
        else:
            # Ejecutar dinámicamente
            for tabla, col_id in COLUMNAS_IDENTITY.items():
                try:
                    cursor.execute(f"ALTER TABLE {tabla} MODIFY ({col_id} GENERATED BY DEFAULT ON NULL AS IDENTITY)")
                    print(f"  [OK] {tabla}.{col_id} -> BY DEFAULT ON NULL")
                except Exception as e:
                    print(f"  [ALERTA] {tabla}: {e}")
            conn.commit()

    # 3. FASE 2: INSERCIÓN MASIVA EN ORDEN TOPOLÓGICO
    print("----------------------------------------------------------------------------")
    print("FASE 2: INSERCIÓN MASIVA EN ORDEN TOPOLÓGICO DE CLAVES FORÁNEAS")
    print("----------------------------------------------------------------------------")

    total_filas_insertadas = 0

    for tabla in ORDEN_TABLAS:
        parquet_file = os.path.join(data_dir, f"{tabla}.parquet")
        if not os.path.isfile(parquet_file):
            parquet_file = os.path.join(data_dir, f"{tabla.lower()}.parquet")
        
        if not os.path.isfile(parquet_file):
            print(f"[OMITIDO] {tabla}: Archivo Parquet no encontrado.")
            continue

        t_inicio_tabla = time.time()
        print(f"\n>>> Procesando {tabla}...")

        try:
            df = pd.read_parquet(parquet_file)
            total_filas = len(df)
            print(f"    Leídos {total_filas:,} registros de {os.path.basename(parquet_file)}")

            # Consultar columnas reales no virtuales de la tabla en Oracle
            cursor.execute(f"SELECT column_name FROM user_tab_cols WHERE table_name = '{tabla}' AND virtual_column = 'NO' ORDER BY column_id")
            db_cols = [r[0] for r in cursor.fetchall()]

            # Mapeo de compatibilidad de nombres (ej. MEDICOS: ID_CLINICA -> ID_CLINICA_BASE)
            if tabla == "MEDICOS":
                if "ID_CLINICA_BASE" in db_cols and "ID_CLINICA" in df.columns:
                    df = df.rename(columns={"ID_CLINICA": "ID_CLINICA_BASE"})
                    print("    Alineando columna: ID_CLINICA -> ID_CLINICA_BASE")
                elif "ID_CLINICA" in db_cols and "ID_CLINICA_BASE" in df.columns:
                    df = df.rename(columns={"ID_CLINICA_BASE": "ID_CLINICA"})

            # Seleccionar únicamente columnas que existan tanto en la BD como en el parquet
            cols_virt = COLUMNAS_VIRTUALES.get(tabla, set())
            columnas_validas = [col for col in db_cols if col in df.columns]

            cols_omitidas = [col for col in df.columns if col not in columnas_validas and col.upper() not in cols_virt]
            if cols_omitidas:
                print(f"    Columnas omitidas (no presentes en la tabla Oracle): {cols_omitidas}")

            # Construir SQL de inserción con binds posicionales (:1, :2, ...)
            placeholders = ", ".join([f":{i+1}" for i in range(len(columnas_validas))])
            cols_sql = ", ".join(columnas_validas)
            insert_sql = f"INSERT INTO {tabla} ({cols_sql}) VALUES ({placeholders})"

            # Preparar datos
            datos = preparar_datos_batch(df, columnas_validas)

            # Inserción por lotes
            cursor.setinputsizes()
            insertadas_tabla = 0
            for start_idx in range(0, total_filas, args.batch_size):
                lote = datos[start_idx:start_idx + args.batch_size]
                cursor.executemany(insert_sql, lote)
                conn.commit()
                insertadas_tabla += len(lote)
                if total_filas > args.batch_size:
                    sys.stdout.write(f"\r    Progreso: {insertadas_tabla:,} / {total_filas:,} filas...")
                    sys.stdout.flush()

            t_tabla = time.time() - t_inicio_tabla
            vel = insertadas_tabla / t_tabla if t_tabla > 0 else 0
            print(f"\r    [COMPLETADO] {insertadas_tabla:,} filas insertadas en {t_tabla:.2f}s ({vel:,.0f} filas/seg)")
            total_filas_insertadas += insertadas_tabla

        except Exception as e:
            conn.rollback()
            print(f"\n    [ERROR EN {tabla}] {e}")
            print("    Cancelando pipeline para mantener integridad referencial.")
            break

    # 4. FASE 3: POST-INGESTA (REINICIAR SECUENCIAS IDENTITY EN MAX + 1 Y ALWAYS)
    if not args.skip_pre_post:
        print("\n----------------------------------------------------------------------------")
        print("FASE 3: POST-INGESTA - REINICIAR SECUENCIAS IDENTITY EN MAX + 1 Y ALWAYS")
        print("----------------------------------------------------------------------------")
        post_sql = os.path.join(script_dir, "02_POST_INGESTA_IDENTITY_ALWAYS_RESTART.sql")
        if os.path.isfile(post_sql):
            try:
                ejecutar_script_sql(cursor, post_sql)
                conn.commit()
                print("[OK] Secuencias de Identity recalculadas y protegidas a ALWAYS.")
            except Exception as e:
                print(f"[ERROR POST-INGESTA] {e}")
        else:
            for tabla, col_id in COLUMNAS_IDENTITY.items():
                try:
                    cursor.execute(f"SELECT NVL(MAX({col_id}), 0) + 1 FROM {tabla}")
                    next_val = cursor.fetchone()[0]
                    cursor.execute(f"ALTER TABLE {tabla} MODIFY {col_id} GENERATED ALWAYS AS IDENTITY (START WITH LIMIT VALUE)")
                    print(f"  [OK] {tabla}.{col_id} -> Reiniciado (ALWAYS)")
                except Exception as e:
                    print(f"  [ALERTA] {tabla}: {e}")
            conn.commit()

    # 5. REHABILITAR TRIGGERS
    if args.disable_triggers:
        try:
            cursor.execute("""
                BEGIN
                    FOR trg IN (SELECT trigger_name FROM user_triggers) LOOP
                        EXECUTE IMMEDIATE 'ALTER TRIGGER ' || trg.trigger_name || ' ENABLE';
                    END LOOP;
                END;
            """)
            conn.commit()
            print("[INFO] Triggers de validación rehabilitados exitosamente.")
        except Exception as e:
            print(f"[ALERTA REHABILITAR TRIGGERS] {e}")

    tiempo_total = time.time() - tiempo_total_inicio

    print("\n============================================================================")
    print("RESUMEN DE EJECUCIÓN DEL PIPELINE:")
    print(f"  Total Registros Insertados: {total_filas_insertadas:,}")
    print(f"  Tiempo Total de Ingesta:    {tiempo_total:.2f} segundos ({tiempo_total/60:.2f} minutos)")
    if tiempo_total > 0:
        print(f"  Velocidad Promedio Global:  {total_filas_insertadas/tiempo_total:,.0f} filas/segundo")
    print("============================================================================")

    cursor.close()
    conn.close()

if __name__ == "__main__":
    main()
