# Capa de Staging (`stg_clinica_user`)

Estructura modularizada de la zona intermedia de ingesta y cálculo de hashes en Oracle Database (`XEPDB1`, Tablespace `stg_clinicas_db`).

---

## 1. Estructura de Carpetas

```plaintext
/STAGING
├── Tables/                                       <- 18 tablas individuales de Staging
│   ├── STG_UBICACIONES.sql
│   ├── STG_CLINICAS.sql
│   ├── STG_EMPRESAS.sql
│   ├── STG_ASEGURADORAS.sql
│   ├── STG_PACIENTES.sql
│   ├── STG_ESPECIALIDADES.sql
│   ├── STG_MEDICOS.sql
│   ├── STG_MEDICOS_ESPECIALIDADES.sql
│   ├── STG_ENFERMEDADES.sql
│   ├── STG_TIPOS_CONSULTA.sql
│   ├── STG_PROCEDIMIENTOS.sql
│   ├── STG_CONSULTAS.sql
│   ├── STG_DIAGNOSTICOS.sql
│   ├── STG_CONSULTAS_PROCEDIMIENTOS.sql
│   ├── STG_FORMAS_PAGO.sql
│   ├── STG_COBROS_CONSULTA.sql
│   ├── STG_DISTRIBUCION_COBRO.sql
│   └── STG_TRANSACCIONES_PAGO.sql
│
├── StoredProcedures/                             <- SPs individuales por cada tabla de Staging
│   ├── SP_EXTRACT_STG_UBICACIONES.sql            <- Extracción STG_UBICACIONES
│   ├── SP_EXTRACT_STG_CLINICAS.sql               <- Extracción STG_CLINICAS
│   ├── SP_EXTRACT_STG_EMPRESAS.sql               <- Extracción STG_EMPRESAS
│   ├── SP_EXTRACT_STG_ASEGURADORAS.sql           <- Extracción STG_ASEGURADORAS
│   ├── SP_EXTRACT_STG_PACIENTES.sql              <- Extracción STG_PACIENTES
│   ├── SP_EXTRACT_STG_ESPECIALIDADES.sql         <- Extracción STG_ESPECIALIDADES
│   ├── SP_EXTRACT_STG_MEDICOS.sql                <- Extracción STG_MEDICOS
│   ├── SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES.sql <- Extracción STG_MEDICOS_ESPECIALIDADES
│   ├── SP_EXTRACT_STG_ENFERMEDADES.sql           <- Extracción STG_ENFERMEDADES
│   ├── SP_EXTRACT_STG_TIPOS_CONSULTA.sql         <- Extracción STG_TIPOS_CONSULTA
│   ├── SP_EXTRACT_STG_PROCEDIMIENTOS.sql         <- Extracción STG_PROCEDIMIENTOS
│   ├── SP_EXTRACT_STG_FORMAS_PAGO.sql            <- Extracción STG_FORMAS_PAGO
│   ├── SP_EXTRACT_STG_CONSULTAS.sql              <- Extracción STG_CONSULTAS (Lookback)
│   ├── SP_EXTRACT_STG_DIAGNOSTICOS.sql           <- Extracción STG_DIAGNOSTICOS (Lookback)
│   ├── SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS.sql <- Extracción STG_CONSULTAS_PROCEDIMIENTOS
│   ├── SP_EXTRACT_STG_TRANSACCIONES_PAGO.sql     <- Extracción STG_TRANSACCIONES_PAGO (Lookback)
│   ├── SP_EXTRACT_STG_COBROS_CONSULTA.sql        <- Extracción STG_COBROS_CONSULTA (Lookback)
│   ├── SP_EXTRACT_STG_DISTRIBUCION_COBRO.sql     <- Extracción STG_DISTRIBUCION_COBRO (Lookback)
│   └── SP_EXTRACT_OLTP_TO_STG.sql                <- Maestro orquestador que invoca cada SP individual
│
├── 01_STG_DDL_TABLAS.sql                         <- Script consolidado de despliegue
└── 02_STG_SP_EXTRACT_OLTP_TO_STG.sql             <- Script consolidado de extracción
```

---

## 2. Ejecución Rápida
```sql
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = stg_clinica_user;

-- Extracción de los últimos 3 días (Modo producción)
EXEC SP_EXTRACT_OLTP_TO_STG('INCREMENTAL', 3);

-- Extracción completa
EXEC SP_EXTRACT_OLTP_TO_STG('FULL');

-- O extracción individual por tabla:
EXEC SP_EXTRACT_STG_PACIENTES('FULL');
EXEC SP_EXTRACT_STG_CONSULTAS('INCREMENTAL', 3);
```