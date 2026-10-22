import oracledb

c_oltp = oracledb.connect(user='red_clinica_user', password='Password2026', dsn='localhost:1521/XEPDB1')
c_stg  = oracledb.connect(user='stg_clinica_user', password='StagingPass2026', dsn='localhost:1521/XEPDB1')
c_dwh  = oracledb.connect(user='dwh_clinica_user', password='DwhPass2026', dsn='localhost:1521/XEPDB1')

cur_o = c_oltp.cursor()
cur_s = c_stg.cursor()
cur_d = c_dwh.cursor()

print("=" * 70)
print("1. AUDITORIA EXTRACCION: OLTP vs STAGING (18 TABLAS)")
print("=" * 70)
stg_tables = [
    'UBICACIONES', 'CLINICAS', 'EMPRESAS', 'ASEGURADORAS', 'PACIENTES', 'ESPECIALIDADES',
    'MEDICOS', 'MEDICOS_ESPECIALIDADES', 'ENFERMEDADES', 'TIPOS_CONSULTA', 'PROCEDIMIENTOS',
    'FORMAS_PAGO', 'CONSULTAS', 'DIAGNOSTICOS', 'CONSULTAS_PROCEDIMIENTOS', 'TRANSACCIONES_PAGO',
    'COBROS_CONSULTA', 'DISTRIBUCION_COBRO'
]

diff_count = 0
tot_oltp = 0
tot_stg = 0
for t in stg_tables:
    cur_o.execute(f"SELECT COUNT(*) FROM {t}")
    no = cur_o.fetchone()[0]
    tot_oltp += no
    cur_s.execute(f"SELECT COUNT(*) FROM STG_{t}")
    ns = cur_s.fetchone()[0]
    tot_stg += ns
    status = "OK" if no == ns else "DIFERENCIA"
    if no != ns: diff_count += 1
    print(f"  {t:<26} | OLTP: {no:>10,} | STG: {ns:>10,} | [{status}]")

print(f"\nTOTAL FILAS EXTRAIDAS -> OLTP: {tot_oltp:,} | STAGING: {tot_stg:,} | Discrepancias: {diff_count}")

print("\n" + "=" * 70)
print("2. AUDITORIA DATA WAREHOUSE: 10 DIMENSIONES + 3 TABLAS DE HECHOS")
print("=" * 70)
cur_d.execute("SELECT TABLE_NAME FROM USER_TABLES WHERE TABLE_NAME LIKE 'DIM_%' ORDER BY TABLE_NAME")
dim_names = [r[0] for r in cur_d.fetchall()]
for d in dim_names:
    cur_d.execute(f"SELECT COUNT(*) FROM {d}")
    nd = cur_d.fetchone()[0]
    print(f"  {d:<32} | Registros: {nd:>10,}")

print("-" * 70)
cur_d.execute("SELECT TABLE_NAME FROM USER_TABLES WHERE TABLE_NAME LIKE 'FACT_%' ORDER BY TABLE_NAME")
fact_names = [r[0] for r in cur_d.fetchall()]
for f in fact_names:
    cur_d.execute(f"SELECT COUNT(*) FROM {f}")
    nf = cur_d.fetchone()[0]
    print(f"  {f:<32} | Registros: {nf:>10,}")

print("\n" + "=" * 70)
print("3. AUDITORIA DE INTEGRIDAD REFERENCIAL (SURROGATE KEYS NULAS)")
print("=" * 70)
cur_d.execute("""
    SELECT 
        COUNT(CASE WHEN SK_TIEMPO IS NULL THEN 1 END) AS N_TIEMPO,
        COUNT(CASE WHEN SK_PACIENTE IS NULL THEN 1 END) AS N_PAC,
        COUNT(CASE WHEN SK_CLINICA IS NULL THEN 1 END) AS N_CLI,
        COUNT(CASE WHEN SK_MEDICO IS NULL THEN 1 END) AS N_MED,
        COUNT(CASE WHEN SK_ESPECIALIDAD IS NULL THEN 1 END) AS N_ESP,
        COUNT(CASE WHEN SK_TIPO_CONSULTA IS NULL THEN 1 END) AS N_TC,
        COUNT(CASE WHEN SK_UBICACION_PACIENTE IS NULL THEN 1 END) AS N_UBI
    FROM FACT_CONSULTAS
""")
row_fc = cur_d.fetchone()
print(f"  FACT_CONSULTAS FKs nulas -> {row_fc} (Esperado: [0, 0, 0, 0, 0, 0, 0])")

cur_d.execute("""
    SELECT 
        COUNT(CASE WHEN SK_TIEMPO IS NULL THEN 1 END) AS N_TIEMPO,
        COUNT(CASE WHEN SK_PACIENTE IS NULL THEN 1 END) AS N_PAC,
        COUNT(CASE WHEN SK_CLINICA IS NULL THEN 1 END) AS N_CLI,
        COUNT(CASE WHEN SK_MEDICO IS NULL THEN 1 END) AS N_MED,
        COUNT(CASE WHEN SK_ESPECIALIDAD IS NULL THEN 1 END) AS N_ESP,
        COUNT(CASE WHEN SK_ENFERMEDAD IS NULL THEN 1 END) AS N_ENF,
        COUNT(CASE WHEN SK_UBICACION_PACIENTE IS NULL THEN 1 END) AS N_UBI
    FROM FACT_CONSULTA_DIAGNOSTICOS
""")
row_fcd = cur_d.fetchone()
print(f"  FACT_CONSULTA_DIAGNOSTICOS FKs nulas -> {row_fcd} (Esperado: [0, 0, 0, 0, 0, 0, 0])")

cur_d.execute("""
    SELECT 
        COUNT(CASE WHEN SK_TIEMPO IS NULL THEN 1 END) AS N_TIEMPO,
        COUNT(CASE WHEN SK_PACIENTE IS NULL THEN 1 END) AS N_PAC,
        COUNT(CASE WHEN SK_CLINICA IS NULL THEN 1 END) AS N_CLI,
        COUNT(CASE WHEN SK_PAGADOR IS NULL THEN 1 END) AS N_PAG,
        COUNT(CASE WHEN SK_FORMA_PAGO_PREDOMINANTE IS NULL THEN 1 END) AS N_FP
    FROM FACT_COBROS_DISTRIBUCION
""")
row_fcd2 = cur_d.fetchone()
print(f"  FACT_COBROS_DISTRIBUCION FKs nulas -> {row_fcd2} (Esperado: [0, 0, 0, 0, 0])")

print("\n" + "=" * 70)
print("4. AUDITORIA FINANCIERA (METRICAS CUANTITATIVAS)")
print("=" * 70)
cur_d.execute("""
    SELECT 
        COUNT(*),
        SUM(PRECIO_HONORARIOS),
        SUM(TOTAL_PROCEDIMIENTOS),
        SUM(MONTO_TOTAL_FACTURADO),
        SUM(MONTO_TOTAL_PAGADO),
        SUM(SALDO_PENDIENTE)
    FROM FACT_CONSULTAS
""")
kpis = cur_d.fetchone()
print(f"  Total Consultas Atendidas:  {kpis[0]:,}")
print(f"  Total Honorarios Medicos:   ${kpis[1]:,.2f}")
print(f"  Total Procedimientos:       ${kpis[2]:,.2f}")
print(f"  Total Facturado:            ${kpis[3]:,.2f}")
print(f"  Total Pagado:               ${kpis[4]:,.2f}")
print(f"  Saldo Pendiente Global:     ${kpis[5]:,.2f}")

cur_d.execute("""
    SELECT 
        COUNT(*),
        SUM(MONTO_ASIGNADO),
        SUM(MONTO_PAGADO),
        SUM(SALDO_PENDIENTE)
    FROM FACT_COBROS_DISTRIBUCION
""")
kpis_dist = cur_d.fetchone()
print(f"\n  Desglose de Distribución de Cobro:")
print(f"  Total Registros Desglose:   {kpis_dist[0]:,}")
print(f"  Total Monto Asignado:       ${kpis_dist[1]:,.2f}")
print(f"  Total Monto Pagado:         ${kpis_dist[2]:,.2f}")
print(f"  Total Saldo Pendiente:      ${kpis_dist[3]:,.2f}")

c_oltp.close()
c_stg.close()
c_dwh.close()
