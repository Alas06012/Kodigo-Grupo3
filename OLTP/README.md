# Capa OLTP (`red_clinica_user`)

Estructura modularizada de la base de datos relacional productiva de la Red de Clínicas en Oracle Database (`XEPDB1`, Tablespace `red_clinicas_db`).

---

## 1. Estructura de Carpetas

```plaintext
/OLTP
├── Tables/                     <- 18 tablas maestras y transaccionales individuales
│   ├── UBICACIONES.sql
│   ├── CLINICAS.sql
│   ├── EMPRESAS.sql
│   ├── ASEGURADORAS.sql
│   ├── PACIENTES.sql
│   ├── ESPECIALIDADES.sql
│   ├── MEDICOS.sql
│   ├── MEDICOS_ESPECIALIDADES.sql
│   ├── ENFERMEDADES.sql
│   ├── TIPOS_CONSULTA.sql
│   ├── PROCEDIMIENTOS.sql
│   ├── CONSULTAS.sql
│   ├── DIAGNOSTICOS.sql
│   ├── CONSULTAS_PROCEDIMIENTOS.sql
│   ├── FORMAS_PAGO.sql
│   ├── COBROS_CONSULTA.sql
│   ├── DISTRIBUCION_COBRO.sql
│   └── TRANSACCIONES_PAGO.sql
│
├── Triggers/                   <- Triggers de validación clínica
│   ├── TRG_PACIENTES_VAL_FECHA_NAC.sql
│   └── TRG_CONSULTAS_VAL_ESP_MED.sql
│
├── Indexes/                    <- Índices B-Tree en Foreign Keys
│   └── INDEXES_OLTP.sql
│
├── Data/                       <- Script de poblamiento de prueba (2024-2026)
│   └── script_llenado_red_clinicas_db.sql
│
├── red_clinicas_db__2026-10-04.sql <- Script consolidado completo DDL
└── script_llenado_red_clinicas_db.sql
```