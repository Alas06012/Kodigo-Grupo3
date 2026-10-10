# Capa Data Warehouse (`dwh_clinica_user`)

Estructura modularizada del Data Warehouse analítico bajo metodología **Kimball** en Oracle Database (`XEPDB1`, Tablespace `dwh_clinicas_db`).

---

## 1. Estructura de Carpetas

```plaintext
/DWH
├── DimTables/                            <- Tablas dimensionales individuales (SCD1, SCD2 y Tiempo)
│   ├── DIM_UBICACION.sql
│   ├── DIM_ESPECIALIDAD.sql
│   ├── DIM_ENFERMEDAD.sql
│   ├── DIM_TIPO_CONSULTA.sql
│   ├── DIM_FORMA_PAGO.sql
│   ├── DIM_PAGADOR.sql
│   ├── DIM_CLINICA.sql
│   ├── DIM_MEDICO.sql
│   ├── DIM_PACIENTE.sql
│   └── DIM_TIEMPO.sql
│
├── FactTables/                           <- Tablas de hechos individuales
│   ├── FACT_CONSULTAS.sql
│   ├── FACT_CONSULTA_DIAGNOSTICOS.sql
│   └── FACT_COBROS_DISTRIBUCION.sql
│
├── StoredProcedures/                     <- SPs individuales por cada tabla poblada
│   ├── SP_POBLAR_DIM_TIEMPO.sql          <- Generador calendario 2024-2030
│   ├── SP_LOAD_DIM_TIEMPO.sql            <- Wrapper estandarizado DIM_TIEMPO
│   ├── SP_LOAD_DIM_UBICACION.sql         <- Carga DIM_UBICACION (SCD1)
│   ├── SP_LOAD_DIM_ESPECIALIDAD.sql      <- Carga DIM_ESPECIALIDAD (SCD1)
│   ├── SP_LOAD_DIM_ENFERMEDAD.sql        <- Carga DIM_ENFERMEDAD (SCD1)
│   ├── SP_LOAD_DIM_TIPO_CONSULTA.sql     <- Carga DIM_TIPO_CONSULTA (SCD1)
│   ├── SP_LOAD_DIM_FORMA_PAGO.sql        <- Carga DIM_FORMA_PAGO (SCD1)
│   ├── SP_LOAD_DIM_PAGADOR.sql           <- Carga DIM_PAGADOR (SCD1)
│   ├── SP_LOAD_DIM_CLINICA.sql           <- Carga DIM_CLINICA (SCD2)
│   ├── SP_LOAD_DIM_MEDICO.sql            <- Carga DIM_MEDICO (SCD2)
│   ├── SP_LOAD_DIM_PACIENTE.sql          <- Carga DIM_PACIENTE (SCD2)
│   ├── SP_LOAD_FACT_CONSULTAS.sql        <- Carga FACT_CONSULTAS (Lookups + MERGE)
│   ├── SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS.sql <- Carga FACT_CONSULTA_DIAGNOSTICOS
│   ├── SP_LOAD_FACT_COBROS_DISTRIBUCION.sql   <- Carga FACT_COBROS_DISTRIBUCION
│   └── SP_LOAD_DWH_MASTER.sql            <- Orquestador maestro que invoca cada SP individual
│
├── 01_DWH_DDL_MODELO_DIMENSIONAL.sql    <- Script consolidado de despliegue DDL
├── 02_DWH_POBLAR_DIM_TIEMPO.sql         <- Script consolidado de calendario
├── 03_DWH_ETL_PIPELINE_MASTER.sql       <- Package PL/SQL consolidado
└── 04_DWH_VALIDACION_KPIS.sql           <- Script de validación analítica (12 KPIs)
```

---

## 2. Ejecución Rápida
```sql
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = dwh_clinica_user;

-- Ejecución en producción (Ventana incremental de 3 días)
EXEC SP_LOAD_DWH_MASTER('INCREMENTAL', 3);

-- Recalibración completa inicial (Backfill)
EXEC SP_LOAD_DWH_MASTER('FULL');

-- O ejecución individual por tabla:
EXEC SP_LOAD_DIM_PACIENTE('INCREMENTAL');
EXEC SP_LOAD_FACT_CONSULTAS('INCREMENTAL');
```