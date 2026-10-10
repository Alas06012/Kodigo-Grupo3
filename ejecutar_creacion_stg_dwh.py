#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
============================================================================
PROYECTO DATA WAREHOUSE - RED DE CLÍNICAS
CREACIÓN ORDENADA DE TABLAS: STAGING (18 TABLAS) Y DWH (13 TABLAS)
MOTOR: Oracle Database (XEPDB1)
============================================================================
"""

import os
import sys
import time
import argparse
import oracledb

# ============================================================================
# 1. ORDEN TOPOLÓGICO DE ARCHIVOS
# ============================================================================

ARCHIVOS_STAGING = [
    # Nivel 0: Catálogos maestros independientes
    "STG_UBICACIONES.sql",
    "STG_EMPRESAS.sql",
    "STG_ASEGURADORAS.sql",
    "STG_ESPECIALIDADES.sql",
    "STG_ENFERMEDADES.sql",
    "STG_TIPOS_CONSULTA.sql",
    "STG_PROCEDIMIENTOS.sql",
    "STG_FORMAS_PAGO.sql",
    # Nivel 1: Clínicas (depende de ubicaciones)
    "STG_CLINICAS.sql",
    # Nivel 2: Personas (Médicos y Pacientes)
    "STG_MEDICOS.sql",
    "STG_PACIENTES.sql",
    # Nivel 3: Relaciones y Consultas
    "STG_MEDICOS_ESPECIALIDADES.sql",
    "STG_CONSULTAS.sql",
    # Nivel 4: Detalles clínicos y cobros
    "STG_DIAGNOSTICOS.sql",
    "STG_CONSULTAS_PROCEDIMIENTOS.sql",
    "STG_COBROS_CONSULTA.sql",
    # Nivel 5: Distribución de cobro
    "STG_DISTRIBUCION_COBRO.sql",
    # Nivel 6: Transacciones de pago
    "STG_TRANSACCIONES_PAGO.sql"
]

ARCHIVOS_DWH_DIMENSIONES = [
    "DIM_TIEMPO.sql",
    "DIM_UBICACION.sql",
    "DIM_CLINICA.sql",
    "DIM_ESPECIALIDAD.sql",
    "DIM_ENFERMEDAD.sql",
    "DIM_TIPO_CONSULTA.sql",
    "DIM_FORMA_PAGO.sql",
    "DIM_PAGADOR.sql",
    "DIM_MEDICO.sql",
    "DIM_PACIENTE.sql"
]

ARCHIVOS_DWH_HECHOS = [
    "FACT_CONSULTAS.sql",
    "FACT_CONSULTA_DIAGNOSTICOS.sql",
    "FACT_COBROS_DISTRIBUCION.sql"
]

TABLAS_OLTP = [
    "UBICACIONES", "EMPRESAS", "ASEGURADORAS", "ESPECIALIDADES", "ENFERMEDADES",
    "TIPOS_CONSULTA", "PROCEDIMIENTOS", "FORMAS_PAGO", "CLINICAS", "MEDICOS",
    "PACIENTES", "MEDICOS_ESPECIALIDADES", "CONSULTAS", "DIAGNOSTICOS",
    "CONSULTAS_PROCEDIMIENTOS", "COBROS_CONSULTA", "DISTRIBUCION_COBRO", "TRANSACCIONES_PAGO"
]

TABLAS_STAGING = [
    "STG_UBICACIONES", "STG_EMPRESAS", "STG_ASEGURADORAS", "STG_ESPECIALIDADES", "STG_ENFERMEDADES",
    "STG_TIPOS_CONSULTA", "STG_PROCEDIMIENTOS", "STG_FORMAS_PAGO", "STG_CLINICAS", "STG_MEDICOS",
    "STG_PACIENTES", "STG_MEDICOS_ESPECIALIDADES", "STG_CONSULTAS", "STG_DIAGNOSTICOS",
    "STG_CONSULTAS_PROCEDIMIENTOS", "STG_COBROS_CONSULTA", "STG_DISTRIBUCION_COBRO", "STG_TRANSACCIONES_PAGO"
]

TABLAS_DWH_DROP_ORDER = [
    # Hechos primero (tablas hijas con FK)
    "FACT_COBROS_DISTRIBUCION",
    "FACT_CONSULTA_DIAGNOSTICOS",
    "FACT_CONSULTAS",
    # Dimensiones después (tablas maestras)
    "DIM_PACIENTE",
    "DIM_MEDICO",
    "DIM_PAGADOR",
    "DIM_FORMA_PAGO",
    "DIM_TIPO_CONSULTA",
    "DIM_ENFERMEDAD",
    "DIM_ESPECIALIDAD",
    "DIM_CLINICA",
    "DIM_UBICACION",
    "DIM_TIEMPO"
]


def ejecutar_archivo_ddl(cursor, ruta_archivo):
    """Lee y ejecuta un archivo DDL que contiene una o varias sentencias SQL."""
    with open(ruta_archivo, 'r', encoding='utf-8') as f:
        sql_text = f.read()

    # Filtrar comentarios de línea completa para evitar residuos
    lineas = []
    for l in sql_text.splitlines():
        strip_l = l.strip()
        if not strip_l.startswith('--'):
            lineas.append(l)
    limpio = '\n'.join(lineas)

    # Separar por punto y coma
    sentencias = [s.strip() for s in limpio.split(';') if s.strip()]
    for stmt in sentencias:
        if stmt.upper().startswith("SET ") or stmt.upper().startswith("PROMPT "):
            continue
        try:
            cursor.execute(stmt)
        except Exception as e:
            raise RuntimeError(f"Error en sentencia:\n{stmt[:100]}...\nDetalle: {e}")


def main():
    parser = argparse.ArgumentParser(description="Ejecución ordenada de DDLs STAGING y DWH")
    parser.add_argument("--host", default="localhost", help="Host Oracle (default: localhost)")
    parser.add_argument("--port", type=int, default=1521, help="Puerto Oracle (default: 1521)")
    parser.add_argument("--service_name", default="XEPDB1", help="PDB (default: XEPDB1)")
    parser.add_argument("--stg_user", default="stg_clinica_user", help="Usuario Staging (default: stg_clinica_user)")
    parser.add_argument("--stg_password", default="StagingPass2026", help="Password Staging")
    parser.add_argument("--dwh_user", default="dwh_clinica_user", help="Usuario DWH (default: dwh_clinica_user)")
    parser.add_argument("--dwh_password", default="DwhPass2026", help="Password DWH")
    parser.add_argument("--oltp_user", default="red_clinica_user", help="Usuario OLTP (default: red_clinica_user)")
    parser.add_argument("--oltp_password", default="Password2026", help="Password OLTP")
    args = parser.parse_args()

    base_dir = os.path.dirname(os.path.abspath(__file__))
    stg_tables_dir = os.path.join(base_dir, "STAGING", "Tables")
    dwh_dims_dir = os.path.join(base_dir, "DWH", "DimTables")
    dwh_facts_dir = os.path.join(base_dir, "DWH", "FactTables")

    dsn = f"{args.host}:{args.port}/{args.service_name}"

    print("============================================================================")
    print("PROYECTO DATA WAREHOUSE - CREACIÓN DE ESQUEMAS STAGING & DWH")
    print(f"Base de Datos:  {dsn}")
    print(f"Esquema STG:    {args.stg_user}")
    print(f"Esquema DWH:    {args.dwh_user}")
    print("============================================================================\n")

    # ============================================================================
    # FASE 1: CREACIÓN DE TABLAS EN STAGING
    # ============================================================================
    print("----------------------------------------------------------------------------")
    print(f"FASE 1: CREACIÓN DE 18 TABLAS EN STAGING ({args.stg_user})")
    print("----------------------------------------------------------------------------")

    try:
        conn_stg = oracledb.connect(user=args.stg_user, password=args.stg_password, dsn=dsn)
        cur_stg = conn_stg.cursor()
        print(f"[CONECTADO] {args.stg_user}")

        # Limpieza previa si existen
        for t in TABLAS_STAGING:
            try:
                cur_stg.execute(f"DROP TABLE {t} CASCADE CONSTRAINTS PURGE")
            except Exception:
                pass
        conn_stg.commit()

        # Creación en orden topológico
        stg_creadas = 0
        for archivo in ARCHIVOS_STAGING:
            ruta = os.path.join(stg_tables_dir, archivo)
            if not os.path.isfile(ruta):
                print(f"  [ERROR] Archivo no encontrado: {archivo}")
                continue
            ejecutar_archivo_ddl(cur_stg, ruta)
            conn_stg.commit()
            tabla = os.path.splitext(archivo)[0]
            print(f"  [OK] {tabla:<28} creado exitosamente desde {archivo}")
            stg_creadas += 1

        print(f"\n[COMPLETADO] {stg_creadas}/18 tablas de Staging creadas con éxito.\n")
        conn_stg.close()
    except Exception as e:
        print(f"[ERROR FATAL EN STAGING] {e}")
        sys.exit(1)

    # ============================================================================
    # FASE 2: GESTIÓN DE PERMISOS / GRANTS ENTRE ESQUEMAS
    # ============================================================================
    print("----------------------------------------------------------------------------")
    print("FASE 2: CONFIGURACIÓN DE PERMISOS ENTRE ESQUEMAS (GRANTS)")
    print("----------------------------------------------------------------------------")

    try:
        # 1. OLTP -> STAGING
        conn_oltp = oracledb.connect(user=args.oltp_user, password=args.oltp_password, dsn=dsn)
        cur_oltp = conn_oltp.cursor()
        for t in TABLAS_OLTP:
            cur_oltp.execute(f"GRANT SELECT ON {t} TO {args.stg_user}")
        conn_oltp.commit()
        conn_oltp.close()
        print(f"  [OK] Concedidos 18 permisos SELECT: {args.oltp_user} -> {args.stg_user}")

        # 2. STAGING -> DWH
        conn_stg = oracledb.connect(user=args.stg_user, password=args.stg_password, dsn=dsn)
        cur_stg = conn_stg.cursor()
        for t in TABLAS_STAGING:
            cur_stg.execute(f"GRANT SELECT ON {t} TO {args.dwh_user}")
        conn_stg.commit()
        conn_stg.close()
        print(f"  [OK] Concedidos 18 permisos SELECT: {args.stg_user} -> {args.dwh_user}\n")
    except Exception as e:
        print(f"[ALERTA PERMISOS] {e}\n")

    # ============================================================================
    # FASE 3: CREACIÓN DE TABLAS EN DATA WAREHOUSE (DWH)
    # ============================================================================
    print("----------------------------------------------------------------------------")
    print(f"FASE 3: CREACIÓN DE 13 TABLAS EN DWH ({args.dwh_user})")
    print("----------------------------------------------------------------------------")

    try:
        conn_dwh = oracledb.connect(user=args.dwh_user, password=args.dwh_password, dsn=dsn)
        cur_dwh = conn_dwh.cursor()
        print(f"[CONECTADO] {args.dwh_user}")

        # Limpieza previa en orden inverso de dependencias de FK
        print("\n  >> Limpiando tablas previas en orden inverso de claves foráneas...")
        for t in TABLAS_DWH_DROP_ORDER:
            try:
                cur_dwh.execute(f"DROP TABLE {t} CASCADE CONSTRAINTS PURGE")
            except Exception:
                pass
        conn_dwh.commit()
        print("  [OK] Limpieza DWH completada.")

        # Subfase 3.1: Dimensiones (10 tablas)
        print("\n  >> Creando 10 Tablas Dimensionales (Maestras / Sin FKs)...")
        dims_creadas = 0
        for archivo in ARCHIVOS_DWH_DIMENSIONES:
            ruta = os.path.join(dwh_dims_dir, archivo)
            if not os.path.isfile(ruta):
                print(f"    [ERROR] Archivo no encontrado: {archivo}")
                continue
            ejecutar_archivo_ddl(cur_dwh, ruta)
            conn_dwh.commit()
            tabla = os.path.splitext(archivo)[0]
            print(f"    [OK] {tabla:<26} creada desde {archivo}")
            dims_creadas += 1

        # Subfase 3.2: Hechos (3 tablas con Foreign Keys)
        print("\n  >> Creando 3 Tablas de Hechos (Facts con FKs referenciadas)...")
        facts_creadas = 0
        for archivo in ARCHIVOS_DWH_HECHOS:
            ruta = os.path.join(dwh_facts_dir, archivo)
            if not os.path.isfile(ruta):
                print(f"    [ERROR] Archivo no encontrado: {archivo}")
                continue
            ejecutar_archivo_ddl(cur_dwh, ruta)
            conn_dwh.commit()
            tabla = os.path.splitext(archivo)[0]
            print(f"    [OK] {tabla:<26} creada desde {archivo}")
            facts_creadas += 1

        print(f"\n[COMPLETADO] {dims_creadas}/10 Dimensiones y {facts_creadas}/3 Hechos creados con éxito.\n")
        conn_dwh.close()
    except Exception as e:
        print(f"[ERROR FATAL EN DWH] {e}")
        sys.exit(1)

    # ============================================================================
    # FASE 4: AUDITORÍA Y VERIFICACIÓN FINAL
    # ============================================================================
    print("----------------------------------------------------------------------------")
    print("FASE 4: AUDITORÍA Y VERIFICACIÓN DE OBJETOS EN BD")
    print("----------------------------------------------------------------------------")

    try:
        # Auditoría Staging
        conn_stg = oracledb.connect(user=args.stg_user, password=args.stg_password, dsn=dsn)
        cur_stg = conn_stg.cursor()
        cur_stg.execute("SELECT COUNT(*) FROM user_tables")
        total_stg_tablas = cur_stg.fetchone()[0]
        cur_stg.execute("SELECT COUNT(*) FROM user_indexes")
        total_stg_indices = cur_stg.fetchone()[0]
        conn_stg.close()

        # Auditoría DWH
        conn_dwh = oracledb.connect(user=args.dwh_user, password=args.dwh_password, dsn=dsn)
        cur_dwh = conn_dwh.cursor()
        cur_dwh.execute("SELECT COUNT(*) FROM user_tables")
        total_dwh_tablas = cur_dwh.fetchone()[0]
        cur_dwh.execute("SELECT COUNT(*) FROM user_constraints WHERE constraint_type = 'R' AND status = 'ENABLED'")
        total_dwh_fks = cur_dwh.fetchone()[0]
        cur_dwh.execute("SELECT COUNT(*) FROM user_indexes")
        total_dwh_indices = cur_dwh.fetchone()[0]
        conn_dwh.close()

        print(f"  Esquema STAGING ({args.stg_user}):")
        print(f"    - Tablas creadas:    {total_stg_tablas} / 18  {'[OK]' if total_stg_tablas == 18 else '[ALERTA]'}")
        print(f"    - Índices creados:   {total_stg_indices}")
        print(f"  Esquema DWH ({args.dwh_user}):")
        print(f"    - Tablas creadas:    {total_dwh_tablas} / 13  {'[OK]' if total_dwh_tablas == 13 else '[ALERTA]'}")
        print(f"    - Foreign Keys:      {total_dwh_fks} / 19  {'[OK - Integridad 100%]' if total_dwh_fks == 19 else '[ALERTA]'}")
        print(f"    - Índices creados:   {total_dwh_indices}")

    except Exception as e:
        print(f"[ERROR EN AUDITORIA] {e}")

    print("\n============================================================================")
    print("EJECUCIÓN DEL PLAN FINALIZADA CON ÉXITO")
    print("============================================================================")


if __name__ == "__main__":
    main()
