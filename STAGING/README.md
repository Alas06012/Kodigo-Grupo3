# Capa de Staging (`stg_clinica_user`)

Estructura modularizada de la zona intermedia de ingesta, cálculo de hashes SHA-256 al vuelo, control de ventanas incrementales y auditoría nativa en Oracle Database (`XEPDB1`, Tablespace `stg_clinicas_db`).

---

## 1. Estructura de Carpetas

```plaintext
/STAGING
├── 01_CREAR_TODAS_LAS_TABLAS_STAGING.sql            <- DDL maestro consolidado (18 tablas de Staging)
├── 02_CREAR_TODOS_LOS_STORED_PROCEDURES_STAGING.sql <- PL/SQL maestro de los 19 procedimientos
├── README.md                                        <- Este documento
│
├── Tables/                                          <- 18 DDLs individuales de tablas Staging
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
└── StoredProcedures/                                <- 19 SPs individuales (AUTHID DEFINER) con auditoría nativa
    ├── SP_EXTRACT_STG_UBICACIONES.sql               <- Extracción STG_UBICACIONES
    ├── SP_EXTRACT_STG_CLINICAS.sql                  <- Extracción STG_CLINICAS
    ├── SP_EXTRACT_STG_EMPRESAS.sql                  <- Extracción STG_EMPRESAS
    ├── SP_EXTRACT_STG_ASEGURADORAS.sql              <- Extracción STG_ASEGURADORAS
    ├── SP_EXTRACT_STG_PACIENTES.sql                 <- Extracción STG_PACIENTES
    ├── SP_EXTRACT_STG_ESPECIALIDADES.sql            <- Extracción STG_ESPECIALIDADES
    ├── SP_EXTRACT_STG_MEDICOS.sql                   <- Extracción STG_MEDICOS (Mapea ID_CLINICA_BASE)
    ├── SP_EXTRACT_STG_MEDICOS_ESPECIALIDADES.sql    <- Extracción STG_MEDICOS_ESPECIALIDADES
    ├── SP_EXTRACT_STG_ENFERMEDADES.sql              <- Extracción STG_ENFERMEDADES
    ├── SP_EXTRACT_STG_TIPOS_CONSULTA.sql            <- Extracción STG_TIPOS_CONSULTA
    ├── SP_EXTRACT_STG_PROCEDIMIENTOS.sql            <- Extracción STG_PROCEDIMIENTOS
    ├── SP_EXTRACT_STG_FORMAS_PAGO.sql               <- Extracción STG_FORMAS_PAGO
    ├── SP_EXTRACT_STG_CONSULTAS.sql                 <- Extracción STG_CONSULTAS (Lookback)
    ├── SP_EXTRACT_STG_DIAGNOSTICOS.sql              <- Extracción STG_DIAGNOSTICOS (Lookback)
    ├── SP_EXTRACT_STG_CONSULTAS_PROCEDIMIENTOS.sql  <- Extracción STG_CONSULTAS_PROCEDIMIENTOS
    ├── SP_EXTRACT_STG_TRANSACCIONES_PAGO.sql        <- Extracción STG_TRANSACCIONES_PAGO (Lookback + ID_COBRO)
    ├── SP_EXTRACT_STG_COBROS_CONSULTA.sql           <- Extracción STG_COBROS_CONSULTA (Cascada de pagos)
    ├── SP_EXTRACT_STG_DISTRIBUCION_COBRO.sql        <- Extracción STG_DISTRIBUCION_COBRO (Lookback)
    └── SP_EXTRACT_OLTP_TO_STG.sql                   <- Maestro orquestador con propagación de Batch ID
```

---

## 2. Características Arquitectónicas de Staging

1. **6 Columnas Técnicas de Auditoría en cada tabla:**
   - `CURRENTFLAG`: `1` para registros activos recién cargados.
   - `TIPOCARGA`: `'FULL'` o `'INCREMENTAL'`.
   - `FECHAINICIO`: `SYSDATE` de la extracción.
   - `FECHAFIN`: `DATE '2999-12-31'`.
   - `TIPOTRANSACCION`: Inicializado con `'I'`.
   - `ROWHASHVALUE`: `RAWTOHEX(STANDARD_HASH(..., 'SHA256'))` con delimitador seguro `|` y protección `NVL`.
2. **Contexto de Seguridad (`AUTHID DEFINER`):**
   Todos los procedimientos están declarados con `AUTHID DEFINER` para permitir que usuarios externos (como `dwh_clinica_user` o herramientas de integración como Apache Hop) los ejecuten sin errores de resolución de objetos `ORA-00942`.
3. **Carga Direct-Path:** Uso sistemático del hint `/*+ APPEND */` y `TRUNCATE TABLE` para rendimiento masivo en disco.
4. **Auditoría Nativa en `CTL_ETL_AUDIT`:**
   Cada procedimiento almacena el inicio (`RUNNING`), la finalización (`SUCCESS` con filas y duración) y las fallas (`FAILED` con código y mensaje de error) mediante llamadas autónomas a `dwh_clinica_user.SP_AUDIT_*`.

---

> [!IMPORTANT]
> **Orden de Dependencias de Auditoría:**
> Las tablas de Staging (Paso 1) se crean inicialmente. Sin embargo, los **Stored Procedures de Staging (Paso 2)** utilizan los procedimientos autónomos de auditoría `dwh_clinica_user.SP_AUDIT_*`. Por tanto, deben compilarse **después** de haber creado y otorgado permisos a dichos procedimientos en el DWH (consultar `DWH/CTL_ETL_AUDIT.sql` o `PASOS_CREACION/03_CREAR_TABLAS_Y_PROCEDIMIENTOS_DWH.sql`) para evitar el error `PLS-00201`.

## 3. Instrucciones de Despliegue

Conectado como **`stg_clinica_user`**:

```sql
-- 1. Crear las 18 tablas (o individualmente desde STAGING/Tables/)
@STAGING/01_CREAR_TODAS_LAS_TABLAS_STAGING.sql

-- 2. Compilar los 19 procedimientos almacenados (o individualmente desde STAGING/StoredProcedures/)
--    (Ejecutar DESPUÉS de compilar la capa DWH de auditoría)
@STAGING/02_CREAR_TODOS_LOS_STORED_PROCEDURES_STAGING.sql
```
