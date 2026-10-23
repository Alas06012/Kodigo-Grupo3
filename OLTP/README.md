# Capa OLTP (`red_clinica_user`)

Estructura modularizada de la base de datos relacional transaccional de la Red de Clínicas en Oracle Database (`XEPDB1`, Tablespace `red_clinicas_db`).

---

## 1. Estructura de Carpetas

```plaintext
/OLTP
├── 01_CREAR_TODAS_LAS_TABLAS_OLTP.sql   <- Script DDL maestro completo (18 tablas, índices y triggers)
├── README.md                            <- Este documento
│
├── Tables/                              <- 18 tablas maestras y transaccionales individuales
│   ├── UBICACIONES.sql                  <- Catálogo geográfico
│   ├── CLINICAS.sql                     <- Sedes asistenciales
│   ├── EMPRESAS.sql                     <- Empresas con convenio corporativo
│   ├── ASEGURADORAS.sql                 <- Compañías aseguradoras
│   ├── PACIENTES.sql                    <- Maestro de pacientes y pólizas
│   ├── ESPECIALIDADES.sql               <- Especialidades médicas
│   ├── MEDICOS.sql                      <- Cuerpo facultativo
│   ├── MEDICOS_ESPECIALIDADES.sql       <- Relación N:M médicos y especialidades
│   ├── ENFERMEDADES.sql                 <- Catálogo CIE-10
│   ├── TIPOS_CONSULTA.sql               <- Modalidades de consulta médica
│   ├── PROCEDIMIENTOS.sql               <- Catálogo de procedimientos médicos
│   ├── CONSULTAS.sql                    <- Registro de atenciones médicas
│   ├── DIAGNOSTICOS.sql                 <- Diagnósticos asignados por atención
│   ├── CONSULTAS_PROCEDIMIENTOS.sql     <- Procedimientos aplicados en consulta
│   ├── FORMAS_PAGO.sql                  <- Catálogo de medios de pago
│   ├── COBROS_CONSULTA.sql              <- Facturación y saldos de la consulta
│   ├── DISTRIBUCION_COBRO.sql           <- Desglose de cobro por pagador
│   └── TRANSACCIONES_PAGO.sql           <- Libro de pagos efectuados
│
├── Indexes/                             <- Índices B-Tree en Foreign Keys para optimización de Joins
│   └── INDEXES_OLTP.sql
│
├── Triggers/                            <- Triggers de integridad de negocio
│   ├── TRG_PACIENTES_VAL_FECHA_NAC.sql  <- Valida fecha de nacimiento lógica
│   └── TRG_CONSULTAS_VAL_ESP_MED.sql    <- Valida que el médico posea la especialidad
│
└── Data/
    ├── *.parquet                        <- 18 archivos Parquet con 8,336,492 registros
    └── IngestaParquet/                  <- Pipeline de ingesta masiva
        ├── requirements.txt             <- Librerías requeridas (pandas, pyarrow, oracledb)
        ├── ingestar_parquets_oltp.py    <- Runner de ingesta por lotes (array binds)
        ├── 00_LIMPIAR_TABLAS_OLTP.sql   <- Truncate y deshabilitación/rehabilitación de FKs
        ├── 01_PRE_INGESTA_IDENTITY_BY_DEFAULT.sql   <- Modifica Identity a 'BY DEFAULT ON NULL'
        ├── 02_POST_INGESTA_IDENTITY_ALWAYS_RESTART.sql <- Reinicia secuencias y fija 'ALWAYS'
        └── 03_AUDITORIA_INTEGRIDAD_INGESTA.sql      <- Auditoría de conteo y cuadre
```

---

## 2. Instrucciones de Despliegue e Ingesta

### Paso 1: Crear la estructura de tablas
Conéctate como `red_clinica_user`:
- Ejecuta [`01_CREAR_TODAS_LAS_TABLAS_OLTP.sql`](file:///d:/Diego/Cursos/KODIGO%20SQL%20IA/ProyectoFinal/OLTP/01_CREAR_TODAS_LAS_TABLAS_OLTP.sql) (crea las 18 tablas, llaves foráneas, índices B-Tree y triggers de auditoría clínica en orden topológico).
*(O alternativamente ejecuta uno a uno los archivos dentro de `Tables/`, `Indexes/` y `Triggers/`)*.

### Paso 2: Cargar los 8.34 Millones de Registros desde Parquet
Desde la terminal:
```powershell
# 1. Instalar dependencias
pip install -r "OLTP/Data/IngestaParquet/requirements.txt"

# 2. Ejecutar la ingesta
python "OLTP/Data/IngestaParquet/ingestar_parquets_oltp.py"
```

El script Python realiza de forma desatendida:
1. Ajuste de columnas Identity a `BY DEFAULT ON NULL`.
2. Inserción masiva en lotes de 50,000 registros mediante `executemany` (array binds).
3. Reactivación y cálculo de secuencias Identity con `START WITH MAX(ID)+1` y modo `ALWAYS`.
4. Auditoría de filas cargadas.
