# 📊 Diccionario de Datos y Guía de Modelado Power BI (Star Schema)

Esta carpeta contiene los archivos `.csv` del modelo dimensional extraídos directamente del Data Warehouse (`dwh_clinica_user`), codificados en **UTF-8 con BOM** para compatibilidad automática e inmediata con **Power BI Desktop** y **Microsoft Excel**.

---

## 🏗️ 1. Arquitectura del Modelo Dimensional (Esquema en Estrella)

El modelo está compuesto por **10 Tablas Dimensionales** y **3 Tablas de Hechos**, conectadas mediante **Claves Subrogadas (`SK_*`)** de tipo numérico entero para máxima velocidad y compresión en el motor en memoria **VertiPaq** de Power BI.

```
       [DIM_PACIENTE]         [DIM_MEDICO]         [DIM_CLINICA]
             │ (1)                 │ (1)                │ (1)
             ▼ (*)                 ▼ (*)                ▼ (*)
      ┌─────────────────────────────────────────────────────────┐
      │                     FACT_CONSULTAS                      │
      │ ─────────────────────────────────────────────────────── │
      │  * SK_CONSULTA (PK)                                     │
      │  * SK_TIEMPO (FK)          * MONTO_TOTAL_FACTURADO      │
      │  * SK_PACIENTE (FK)        * MONTO_TOTAL_PAGADO         │
      │  * SK_CLINICA (FK)         * SALDO_PENDIENTE            │
      │  * SK_MEDICO (FK)          * ESTADO_COBRO               │
      │  * SK_ESPECIALIDAD (FK)    * TOTAL_PROCEDIMIENTOS       │
      │  * SK_TIPO_CONSULTA (FK)   * CANTIDAD_CONSULTAS         │
      └─────────────────────────────────────────────────────────┘
             ▲ (*)                 ▲ (*)                ▲ (*)
             │ (1)                 │ (1)                │ (1)
       [DIM_TIEMPO]        [DIM_ESPECIALIDAD]   [DIM_TIPO_CONSULTA]

      ┌─────────────────────────────────────────────────────────┐
      │               FACT_CONSULTA_DIAGNOSTICOS                │
      │ ─────────────────────────────────────────────────────── │
      │  * SK_ENFERMEDAD (FK)  ---> [DIM_ENFERMEDAD]            │
      │  * MONTO_PRORRATEADO (Facturación equitativa por CIE10) │
      └─────────────────────────────────────────────────────────┘

      ┌─────────────────────────────────────────────────────────┐
      │                FACT_COBROS_DISTRIBUCION                 │
      │ ─────────────────────────────────────────────────────── │
      │  * SK_PAGADOR (FK)     ---> [DIM_PAGADOR] (Aseg/Emp/Pac)│
      │  * SK_FORMA_PAGO (FK)  ---> [DIM_FORMA_PAGO]            │
      │  * PORCENTAJE_COBERTURA, MONTO_ASIGNADO, MONTO_PAGADO   │
      └─────────────────────────────────────────────────────────┘
```

---

## 🔗 2. Relaciones a Configurar en Power BI (`1:*` Uno a Varios)

| Tabla Origen (Dimensión - 1) | Columna Origen (PK) | Tabla Destino (Hechos - *) | Columna Destino (FK) | Dirección de Filtro |
| :--- | :--- | :--- | :--- | :--- |
| `DIM_TIEMPO` | `SK_TIEMPO` | `FACT_CONSULTAS` | `SK_TIEMPO` | Única (1 -> *) |
| `DIM_PACIENTE` | `SK_PACIENTE` | `FACT_CONSULTAS` | `SK_PACIENTE` | Única (1 -> *) |
| `DIM_MEDICO` | `SK_MEDICO` | `FACT_CONSULTAS` | `SK_MEDICO` | Única (1 -> *) |
| `DIM_CLINICA` | `SK_CLINICA` | `FACT_CONSULTAS` | `SK_CLINICA` | Única (1 -> *) |
| `DIM_ESPECIALIDAD` | `SK_ESPECIALIDAD` | `FACT_CONSULTAS` | `SK_ESPECIALIDAD` | Única (1 -> *) |
| `DIM_TIPO_CONSULTA` | `SK_TIPO_CONSULTA` | `FACT_CONSULTAS` | `SK_TIPO_CONSULTA` | Única (1 -> *) |
| `DIM_UBICACION` | `SK_UBICACION` | `FACT_CONSULTAS` | `SK_UBICACION_PACIENTE` | Única (1 -> *) |
| `DIM_ENFERMEDAD` | `SK_ENFERMEDAD` | `FACT_CONSULTA_DIAGNOSTICOS`| `SK_ENFERMEDAD` | Única (1 -> *) |
| `DIM_PAGADOR` | `SK_PAGADOR` | `FACT_COBROS_DISTRIBUCION` | `SK_PAGADOR` | Única (1 -> *) |
| `DIM_FORMA_PAGO` | `SK_FORMA_PAGO` | `FACT_COBROS_DISTRIBUCION` | `SK_FORMA_PAGO_PREDOMINANTE` | Única (1 -> *) |

> [!TIP]
> **Filtro de Versiones SCD Tipo 2:** En las dimensiones que manejan versionado histórico (`DIM_PACIENTE`, `DIM_MEDICO`, `DIM_CLINICA`), para análisis de estado demográfico actual se puede filtrar por `CURRENTFLAG = 1`.

---

## 📐 3. Medidas DAX Recomendadas

Crea una tabla dedicada para medidas (`_Medidas`) e introduce las siguientes fórmulas básicas:

```dax
// 1. Facturación Total
Total Facturado = SUM(FACT_CONSULTAS[MONTO_TOTAL_FACTURADO])

// 2. Monto Efectivamente Pagado
Total Recaudado = SUM(FACT_CONSULTAS[MONTO_TOTAL_PAGADO])

// 3. Cartera Pendiente de Cobro
Saldo Pendiente = SUM(FACT_CONSULTAS[SALDO_PENDIENTE])

// 4. Tasa de Eficacia de Cobro (%)
Tasa de Recaudacion = 
DIVIDE([Total Recaudado], [Total Facturado], 0)

// 5. Volumen de Atenciones Médicas
Total Consultas = COUNTROWS(FACT_CONSULTAS)

// 6. Ticket Promedio por Atención
Ticket Promedio = 
DIVIDE([Total Facturado], [Total Consultas], 0)

// 7. Facturación de Procedimientos Médicos
Total Procedimientos = SUM(FACT_CONSULTAS[TOTAL_PROCEDIMIENTOS])

// 8. Pacientes Únicos Atendidos
Pacientes Atendidos = DISTINCTCOUNT(FACT_CONSULTAS[SK_PACIENTE])
```

---

## 🔄 4. Cómo Actualizar los CSVs en Cualquier Momento

Desde la raíz del repositorio, ejecuta:
```bash
python exportar_csv_powerbi.py
```
*Si deseas incluir la tabla de auditoría del pipeline ETL (`CTL_ETL_AUDIT`), agrega la bandera `--incluir-auditoria`.*
