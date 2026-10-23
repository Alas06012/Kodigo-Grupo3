# Capa Data Warehouse (`dwh_clinica_user`)

Estructura modularizada del Data Warehouse en Oracle Database (`XEPDB1`, Tablespace `dwh_clinicas_db`).

## 1. Estructura de Carpetas

```plaintext
/DWH
├── CTL_ETL_AUDIT.sql                            <- DDL y procedimientos autónomos de control y auditoría
├── 01_CREAR_TODAS_LAS_TABLAS_DWH.sql            <- DDL maestro consolidado (10 dimensiones + 3 hechos + 1 control)
├── 02_CREAR_TODOS_LOS_STORED_PROCEDURES_DWH.sql <- PL/SQL maestro de los 18 procedimientos (3 auditoría + 15 analíticos)
├── 03_VALIDACION_KPIS_NEGOCIO.sql               <- Script analítico oficial para responder los 12 KPIs
├── README.md                                    <- Este documento
│
├── DimTables/                                   <- 10 tablas dimensionales individuales
│   ├── DIM_UBICACION.sql                        <- SCD 1 (Territorio geográfico)
│   ├── DIM_ESPECIALIDAD.sql                     <- SCD 1 (Especialidad médica)
│   ├── DIM_ENFERMEDAD.sql                       <- SCD 1 (Patología CIE-10)
│   ├── DIM_TIPO_CONSULTA.sql                    <- SCD 1 (Modalidad de consulta)
│   ├── DIM_FORMA_PAGO.sql                       <- SCD 1 (Canal/Forma de pago)
│   ├── DIM_PAGADOR.sql                          <- SCD 1 (Particular, Empresa, Aseguradora)
│   ├── DIM_CLINICA.sql                          <- SCD 2 (Sedes clínicas con versionado histórico)
│   ├── DIM_MEDICO.sql                           <- SCD 2 (Médicos con versionado histórico)
│   ├── DIM_PACIENTE.sql                         <- SCD 2 (Pacientes, residencia y convenios)
│   └── DIM_TIEMPO.sql                           <- Dimensión Conformada (2024 al 2030 + 19000101)
│
├── FactTables/                                  <- 3 tablas de hechos individuales
│   ├── FACT_CONSULTAS.sql                       <- Grano: 1 fila por atención médica
│   ├── FACT_CONSULTA_DIAGNOSTICOS.sql           <- Grano: Diagnósticos prorrateados por consulta
│   └── FACT_COBROS_DISTRIBUCION.sql             <- Grano: Desglose por pagador y forma de pago
│
└── StoredProcedures/                            <- 18 SPs individuales de carga y control (AUTHID DEFINER)
    ├── SP_AUDIT_START.sql                       <- Registro autónomo de inicio de SP en CTL_ETL_AUDIT
    ├── SP_AUDIT_END.sql                         <- Registro autónomo de finalización y cálculo de duración
    ├── SP_AUDIT_ERROR.sql                       <- Registro autónomo de fallos (preservado ante ROLLBACK)
    ├── SP_POBLAR_DIM_TIEMPO.sql                 <- Generador de calendario analítico (2024-2030)
    ├── SP_LOAD_DIM_TIEMPO.sql                   <- Wrapper estandarizado de DIM_TIEMPO
    ├── SP_LOAD_DIM_UBICACION.sql                <- Carga DIM_UBICACION (MERGE con SHA-256)
    ├── SP_LOAD_DIM_ESPECIALIDAD.sql             <- Carga DIM_ESPECIALIDAD (MERGE con SHA-256)
    ├── SP_LOAD_DIM_ENFERMEDAD.sql               <- Carga DIM_ENFERMEDAD (MERGE con SHA-256)
    ├── SP_LOAD_DIM_TIPO_CONSULTA.sql            <- Carga DIM_TIPO_CONSULTA (MERGE con SHA-256)
    ├── SP_LOAD_DIM_FORMA_PAGO.sql               <- Carga DIM_FORMA_PAGO (MERGE con SHA-256)
    ├── SP_LOAD_DIM_PAGADOR.sql                  <- Carga DIM_PAGADOR (Particulares + Empresas + Aseguradoras)
    ├── SP_LOAD_DIM_CLINICA.sql                  <- Carga DIM_CLINICA (Caduca versión previa e inserta nueva)
    ├── SP_LOAD_DIM_MEDICO.sql                   <- Carga DIM_MEDICO (SCD2 histórico)
    ├── SP_LOAD_DIM_PACIENTE.sql                 <- Carga DIM_PACIENTE (SCD2 con cálculo de edad y grupo etario)
    ├── SP_LOAD_FACT_CONSULTAS.sql               <- Carga FACT_CONSULTAS (Lookups + MERGE con hash de hecho)
    ├── SP_LOAD_FACT_CONSULTA_DIAGNOSTICOS.sql   <- Carga FACT_CONSULTA_DIAGNOSTICOS (Prorrateo de costos)
    ├── SP_LOAD_FACT_COBROS_DISTRIBUCION.sql     <- Carga FACT_COBROS_DISTRIBUCION (Forma de pago predominante)
    └── SP_LOAD_DWH_MASTER.sql                   <- Orquestador maestro end-to-end con propagación de Batch ID
```

---

## 2. Instrucciones de Despliegue y Ejecución

Conectado como **`dwh_clinica_user`**:

```sql
-- 1. Crear las 14 tablas (13 dimensionales/hechos + CTL_ETL_AUDIT)
@DWH/01_CREAR_TODAS_LAS_TABLAS_DWH.sql

-- 2. Compilar los 18 procedimientos almacenados (3 auditoría + 15 analíticos)
@DWH/02_CREAR_TODOS_LOS_STORED_PROCEDURES_DWH.sql

-- 3. Ejecutar la carga completa end-to-end (OLTP -> STAGING -> DWH)
-- Carga inicial Full:
EXEC SP_LOAD_DWH_MASTER('FULL');

-- Carga incremental recurrente (ejemplo: ventana de 3 días de lookback):
EXEC SP_LOAD_DWH_MASTER('INCREMENTAL', 3);

-- 4. Monitorear la auditoría del último lote ejecutado
SELECT 
    ID_AUDIT, BATCH_ID, CAPA, OBJETO_DESTINO, PROCEDIMIENTO, 
    DURACION_SEGUNDOS, FILAS_INSERTADAS, FILAS_ACTUALIZADAS, ESTADO
FROM CTL_ETL_AUDIT
WHERE BATCH_ID = (SELECT MAX(BATCH_ID) FROM CTL_ETL_AUDIT)
ORDER BY ID_AUDIT ASC;

-- 5. Validar las 12 consultas analíticas oficiales de KPIs
@DWH/03_VALIDACION_KPIS_NEGOCIO.sql
```
