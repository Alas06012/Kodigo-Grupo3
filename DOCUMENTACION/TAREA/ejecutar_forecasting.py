#Aca pueden escribir todo de una, ya iria involucrado todo paara gestionar los datos
"""
Script interactivo para ejecutar la actividad de Forecasting y Toma de Decisiones.
Calcula la regresión lineal (m, b) y la proyección del Mes 13.
"""

import sqlite3
import sys

# Asegurar codificación utf-8 en consola Windows
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def main():
    print("=" * 70)
    print(" ACTIVIDAD: FORECASTING Y TOMA DE DECISIONES - REGRESIÓN LINEAL EN SQL")
    print("=" * 70)

    conn = sqlite3.connect(':memory:')
    cur = conn.cursor()

    # 1. Crear tabla
    cur.execute("""
    CREATE TABLE historico_ventas (
      mes_id INT PRIMARY KEY,
      mes_nombre VARCHAR(20),
      total_ventas NUMERIC(10, 2)
    );
    """)

    # 2. Insertar datos
    datos = [
        (1, 'Enero', 1200.50), (2, 'Febrero', 1350.00), (3, 'Marzo', 1420.75),
        (4, 'Abril', 1580.00), (5, 'Mayo', 1700.20), (6, 'Junio', 1650.00),
        (7, 'Julio', 1820.40), (8, 'Agosto', 1950.00), (9, 'Septiembre', 2100.10),
        (10, 'Octubre', 2050.50), (11, 'Noviembre', 2300.00), (12, 'Diciembre', 2550.00)
    ]
    cur.executemany("INSERT INTO historico_ventas VALUES (?, ?, ?);", datos)
    conn.commit()

    # 3. Consulta de cálculo estadístico
    sql_query = """
    WITH variables_estadisticas AS (
        SELECT
            COUNT(*) AS n,
            SUM(mes_id) AS sum_x,
            SUM(total_ventas) AS sum_y,
            SUM(mes_id * total_ventas) AS sum_xy,
            SUM(mes_id * mes_id) AS sum_x2
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
        n,
        sum_x,
        ROUND(sum_y, 2) AS sum_y,
        ROUND(sum_xy, 2) AS sum_xy,
        sum_x2,
        ROUND(m, 4) AS pendiente_m,
        ROUND(b, 4) AS interseccion_b,
        13 AS mes_proyectado,
        ROUND((m * 13) + b, 2) AS venta_proyectada_mes_13
    FROM parametros_regresion;
    """

    cur.execute(sql_query)
    row = cur.fetchone()

    n, sum_x, sum_y, sum_xy, sum_x2, m, b, mes_13, y_pred = row

    print("\n--- PASO 1 & 2.1: VARIABLES ESTADÍSTICAS OBTENIDAS ---")
    print(f"• n (Número de períodos)   : {n}")
    print(f"• ΣX (Suma de meses)       : {sum_x}")
    print(f"• ΣY (Suma de ventas)      : ${sum_y:,.2f}")
    print(f"• ΣXY (Suma producto X*Y)  : ${sum_xy:,.2f}")
    print(f"• ΣX² (Suma de X al cuad.) : {sum_x2}")
    print(f"• (ΣX)²                    : {sum_x**2}")
    print(f"• Denominador común        : {n * sum_x2 - sum_x**2}")

    print("\n--- PASO 2.2: PENDIENTE (m) E INTERSECCIÓN (b) ---")
    print(f"• Pendiente (m)            : {m:.4f}  (Crecimiento promedio por mes: +${m:.2f})")
    print(f"• Intersección (b)         : {b:.4f}  (Punto de partida o mes cero: ${b:.2f})")
    print(f"• Ecuación de la recta     : Y = {m:.4f} * X + {b:.4f}")

    print("\n--- PASO 2.3: GENERACIÓN DEL PRONÓSTICO (MES 13) ---")
    print(f"• Venta Proyectada Mes 13  : ${y_pred:,.2f}")
    print(f"  Fórmula: ({m:.4f} * 13) + {b:.4f} = ${y_pred:,.2f}")

    print("\n" + "=" * 70)
    print(" CONCLUSIÓN PARA LA TOMA DE DECISIONES:")
    print("=" * 70)
    print("El análisis de regresión lineal muestra una clara tendencia alcista sostenida en las ventas,")
    print(f"con una tasa de crecimiento constante de ${m:.2f} mensuales (pendiente m = {m:.4f}).")
    print(f"La proyección de ${y_pred:,.2f} para el mes 13 evidencia un rendimiento superior al promedio histórico.")
    print("Estratégicamente, esto exige planificar con anticipación la capacidad operativa, inventarios y personal,")
    print("aprovechando la inercia positiva del mercado sin comprometer la liquidez ni el nivel de servicio.")
    print("=" * 70)

if __name__ == "__main__":
    main()
