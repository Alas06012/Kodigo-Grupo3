# 📊 Entrega de Actividad: Forecasting y Toma de Decisiones

**Materia / Módulo:** Data Warehouse & Analytics / Kodigo Data Science  
**Equipo:** Grupo 3  
**Fecha:** Octubre 2026  

---

## 1. Código SQL Completo con los Cálculos

```sql
-- ============================================================================
-- PASO 1: CREACIÓN DE LA TABLA E HISTÓRICO DE VENTAS (12 MESES)
-- ============================================================================
CREATE TABLE historico_ventas (
  mes_id INT PRIMARY KEY,
  mes_nombre VARCHAR2(20),
  total_ventas NUMBER(10, 2)
);

INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (1, 'Enero', 1200.50);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (2, 'Febrero', 1350.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (3, 'Marzo', 1420.75);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (4, 'Abril', 1580.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (5, 'Mayo', 1700.20);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (6, 'Junio', 1650.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (7, 'Julio', 1820.40);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (8, 'Agosto', 1950.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (9, 'Septiembre', 2100.10);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (10, 'Octubre', 2050.50);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (11, 'Noviembre', 2300.00);
INSERT INTO historico_ventas (mes_id, mes_nombre, total_ventas) VALUES (12, 'Diciembre', 2550.00);
COMMIT;

-- ============================================================================
-- PASO 2: CÁLCULO ESTADÍSTICO, REGRESIÓN LINEAL (m, b) Y PRONÓSTICO (MES 13)
-- Modelo Matemático: Y = mX + b (Mínimos Cuadrados Ordinarios)
-- m = [n*Σ(xy) - Σx*Σy] / [n*Σ(x^2) - (Σx)^2]
-- b = [Σy - m*Σx] / n
-- ============================================================================
WITH variables_estadisticas AS (
    SELECT
        COUNT(*)                   AS n,
        SUM(mes_id)                AS sum_x,
        SUM(total_ventas)          AS sum_y,
        SUM(mes_id * total_ventas) AS sum_xy,
        SUM(mes_id * mes_id)       AS sum_x2
    FROM historico_ventas
),
parametros_regresion AS (
    SELECT
        n,
        sum_x,
        sum_y,
        sum_xy,
        sum_x2,
        ( (n * sum_xy) - (sum_x * sum_y) ) * 1.0 / ( (n * sum_x2) - (sum_x * sum_x) ) AS m,
        ( sum_y - ( ( (n * sum_xy) - (sum_x * sum_y) ) * 1.0 / ( (n * sum_x2) - (sum_x * sum_x) ) ) * sum_x ) * 1.0 / n AS b
    FROM variables_estadisticas
)
SELECT
    n                                   AS "n (Meses)",
    sum_x                               AS "ΣX",
    ROUND(sum_y, 2)                     AS "ΣY",
    ROUND(sum_xy, 2)                    AS "ΣXY",
    sum_x2                              AS "ΣX²",
    ROUND(m, 4)                         AS "Pendiente (m)",
    ROUND(b, 4)                         AS "Intersección (b)",
    13                                  AS "Mes Proyectado",
    ROUND((m * 13) + b, 2)              AS "Venta Proyectada (Mes 13)"
FROM parametros_regresion;
```

---

## 2. Tabla de Resultados

| Parámetro / Componente | Fórmula / Concepto | Resultado Obtenido |
| :--- | :--- | :--- |
| **$n$ (Observaciones)** | Número de meses analizados | **12** |
| **$\sum X$** | Suma de los identificadores de mes ($1+2+\dots+12$) | **78** |
| **$\sum Y$** | Suma acumulada de ventas de los 12 meses | **$21,672.45** |
| **$\sum XY$** | Suma de cada mes multiplicado por sus ventas | **$156,532.45** |
| **$\sum X^2$** | Suma de los cuadrados de cada mes ($1^2+2^2+\dots+12^2$) | **650** |
| **$(\sum X)^2$** | Cuadrado de la sumatoria de $X$ ($78^2$) | **6,084** |
| **Denominador Común** | $n \sum X^2 - (\sum X)^2 = (12 \cdot 650) - 6,084$ | **1,716** |
| **Pendiente ($m$)** | $\frac{n \sum XY - \sum X \sum Y}{n \sum X^2 - (\sum X)^2} = \frac{187,938.30}{1,716}$ | **109.5212** |
| **Intersección ($b$)** | $\frac{\sum Y - m \sum X}{n} = \frac{21,672.45 - (109.5212 \cdot 78)}{12}$ | **1094.1500** |
| **Ecuación del Modelo** | $Y = 109.5212 \cdot X + 1094.1500$ | — |
| **Pronóstico Mes 13 ($Y_{13}$)** | $(109.5212 \times 13) + 1094.1500$ | **$2,517.93** |

---

## 3. Breve Conclusión del Análisis (Toma de Decisiones)

> El análisis de regresión lineal confirma una **tendencia de crecimiento sostenido y saludable** en las ventas a lo largo del año, registrando un incremento promedio de **$109.52 mensuales** (pendiente $m = 109.5212$) y una base estimada de **$1,094.15** (intersección $b = 1094.1500$).  
> La proyección estadística para el **Mes 13 estima ventas por $2,517.93**, superando consistentemente el promedio del histórico. Para la dirección empresarial, esta proyección valida la decisión de **expandir la capacidad de atención, planificar con antelación el abastecimiento de insumos y asegurar el flujo de caja operativo** para sostener la demanda proyectada sin arriesgar la calidad del servicio.
