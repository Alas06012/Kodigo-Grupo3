# 📊 Módulo de Forecasting y Toma de Decisiones

Este módulo implementa el cálculo de **Regresión Lineal Simple por Mínimos Cuadrados Ordinarios ($y = mx + b$)** y proyección estadística de ventas directamente en SQL para **Oracle Database**.

---

##  Estructura del Módulo

| Archivo | Tipo | Descripción |
| :--- | :--- | :--- |
| **`00_MASTER_EJECUTAR_TODO_FORECASTING.sql`** | SQL Master | Ejecuta todo el flujo ordenadamente de principio a fin. |
| **`01_DDL_HISTORICO_VENTAS.sql`** | DDL | Creación y estructura de la tabla `historico_ventas`. |
| **`02_DML_POBLAR_12_MESES.sql`** | DML | Inserción de los 12 meses históricos de ventas. |
| **`03_CALCULO_VARIABLES_ESTADISTICAS.sql`** | Query | Obtención de $n, \sum X, \sum Y, \sum XY, \sum X^2$ y $(\sum X)^2$. |
| **`04_MODELO_REGRESION_Y_PRONOSTICO.sql`** | Query | Determinación de $m$, $b$ y proyección para el Mes 13. |
| **`05_VALIDACION_NATIVA_ORACLE.sql`** | Query | Validación cruzada con funciones analíticas nativas (`REGR_SLOPE`, `REGR_INTERCEPT`). |

---

##  Resumen de Resultados

* **$n$ (Meses):** 12
* **$\sum X$:** 78
* **$\sum Y$:** $21,672.45
* **$\sum XY$:** $156,532.45
* **$\sum X^2$:** 650
* **Pendiente ($m$):** `109.5212` (crecimiento promedio mensual: +$109.52)
* **Intersección ($b$):** `1094.1500` (base de partida: $1,094.15)
* **Ecuación del Modelo:** $Y = 109.5212 \cdot X + 1094.1500$
* **Pronóstico Mes 13:** **$2,517.93**
