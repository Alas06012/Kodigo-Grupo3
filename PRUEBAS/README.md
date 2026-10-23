# 🧪 Manual de Pruebas Integrales y Simulación Incremental del Data Warehouse

Este directorio contiene la suite completa de pruebas end-to-end para validar el comportamiento del pipeline de extracción, transformación y carga (ETL) en **Apache Hop** y **Oracle Database** ante la operativa diaria de la red hospitalaria.

---

## 📁 Estructura de la Carpeta `PRUEBAS/`

| Archivo | Esquema / Motor | Descripción |
| :--- | :--- | :--- |
| [`01_SIMULACION_CARGA_OLTP.sql`](file:///d:/Diego/Cursos/KODIGO%20SQL%20IA/ProyectoFinal/PRUEBAS/01_SIMULACION_CARGA_OLTP.sql) | `red_clinica_user` (OLTP) | Script PL/SQL que inyecta todos los escenarios operativos reales (maestros, mutaciones, personas y cobros). Es **idempotente** (limpia automáticamente corridas previas). |
| [`02_VALIDACION_DWH_POST_CARGA.sql`](file:///d:/Diego/Cursos/KODIGO%20SQL%20IA/ProyectoFinal/PRUEBAS/02_VALIDACION_DWH_POST_CARGA.sql) | `dwh_clinica_user` (DWH) | Batería de consultas analíticas para auditar el lote en `CTL_ETL_AUDIT`, verificar SCD1, comprobar versionamiento SCD2 y auditar las Fact Tables. |
| [`03_LIMPIEZA_ROLLBACK_PRUEBAS.sql`](file:///d:/Diego/Cursos/KODIGO%20SQL%20IA/ProyectoFinal/PRUEBAS/03_LIMPIEZA_ROLLBACK_PRUEBAS.sql) | OLTP / DWH | Script de rollback total que elimina los datos etiquetados con `[PRUEBA]` y restaura las entidades mutadas a su estado original previo a las pruebas. |
| [`ejecutar_simulacion_completa.py`](file:///d:/Diego/Cursos/KODIGO%20SQL%20IA/ProyectoFinal/PRUEBAS/ejecutar_simulacion_completa.py) | Python 3.x (`oracledb`) | Orquestador automatizado que ejecuta la inyección OLTP, llama al script `.bat` de Apache Hop, evalúa el DWH y despliega el reporte en consola. |

---

## 🎯 Escenarios de Prueba Cubiertos

### 1. Nuevos Datos Maestros (Nuevos Catálogos)
Simula la expansión de la red médica y la creación de nuevos servicios:
* **Ubicación**: *Zona 16 - Paseo Cayalá* (Guatemala).
* **Clínica**: *Clínica Médica Cayalá Élite*.
* **Empresa Corporativa**: *Tech Solutions & Cloud Services S.A.* (NIT `99887766-5`).
* **Aseguradora**: *Aseguradora Internacional del Caribe* (NIT `88776655-4`).
* **Especialidad**: *Inmunología y Alergología Clínica Avanzada*.
* **Enfermedad (CIE-10)**: `U07.1` (*COVID-19 Infección Respiratoria Variante 2026*).
* **Tipo de Consulta**: *Teleconsulta Especializada Digital HD* ($350.00).
* **Procedimiento**: `PR-ANGIO-01` (*Angiotomografía Coronaria Multicorte*, $1,850.00).
* **Forma de Pago**: *Billetera Digital / QR Interbancario* (Categoría CONTADO).

### 2. Dimensión de Cambio Lento Tipo 1 (SCD Tipo 1 - Sobrescritura)
* **Entidad**: `ESPECIALIDADES` (ID 1 - *Medicina General*).
* **Acción**: Se actualiza la descripción agregando la certificación internacional 2026.
* **Comportamiento Esperado en DWH**: En `DIM_ESPECIALIDAD`, el registro `BK_ID_ESPECIALIDAD = 1` se actualiza in-place sin generar una nueva clave subrogada (`SK_ESPECIALIDAD`), preservando el histórico de hechos vinculado.

### 3. Dimensión de Cambio Lento Tipo 2 (SCD Tipo 2 - Historización con Vigencia)
Simula cambios sustanciales que requieren mantener la trazabilidad histórica:
* **Paciente (`BK_ID_PACIENTE = 10`)**: Modifica su dirección de residencia y se afilia a una nueva aseguradora con nueva póliza.
* **Médico (`BK_ID_MEDICO = 5`)**: Es trasladado de sede base hacia la nueva *Clínica Médica Cayalá Élite*.
* **Clínica (`BK_ID_CLINICA = 2`)**: Actualiza su dirección física y número telefónico de conmutador.
* **Comportamiento Esperado en DWH**:
  1. La versión anterior se cierra: `CURRENTFLAG = 0` y `VALIDTO = SYSDATE` (o fecha de carga).
  2. Se inserta un nuevo registro con nuevo `SK_*`: `CURRENTFLAG = 1` y `VALIDTO = 9999-12-31`.

### 4. Nuevas Personas (Pacientes y Personal Médico)
* **Paciente 1**: Particular (Sin seguro ni empresa convenio).
* **Paciente 2**: Corporativo (Empleado de *Tech Solutions & Cloud Services S.A.*).
* **Paciente 3**: Asegurado Internacional (*Aseguradora Internacional del Caribe*).
* **Nuevo Médico**: *Dra. Mariana Elizabeth Herrera Solares* (Colegiado `COL-99881`), especialista principal en *Inmunología y Alergología Avanzada*.

### 5. Facturación y Transacciones en Ventana Deslizante (Lookback)
* **Caso 5.1 (Copago Mixto 80/20 y Multidiagnóstico)**:
  * Consulta ($400) + Procedimiento Angiotomografía ($1,850) = Total **$2,250.00**.
  * 2 Diagnósticos asociados (Sospecha Isquémica + Hipertensión).
  * Distribución: Aseguradora paga 80% ($1,800 vía Transferencia), Paciente paga 20% ($450 con Tarjeta de Crédito).
  * *Validación*: En `FACT_CONSULTA_DIAGNOSTICOS`, el monto se prorratea equitativamente ($1,125.00 por diagnóstico) sin duplicar la facturación global.
* **Caso 5.2 (Billetera Digital QR / Pago Contado)**:
  * Consulta médica de $250.00 pagada 100% mediante la nueva forma de pago *Billetera Digital / QR Interbancario*.
  * Diagnóstico asignado: CIE-10 `U07.1`.
* **Caso 5.3 (Facturación a Crédito Corporativo / Cobro Pendiente)**:
  * Teleconsulta de $350.00 asignada al 100% a la empresa convenio.
  * No tiene transacción de pago registrada (`MONTO_PAGADO = 0`, `ESTADO_COBRO = 'PENDIENTE'`).
  * *Validación*: `SALDO_PENDIENTE = $350.00` en hechos para comprobar métricas de cuentas por cobrar.
* **Caso 5.4 (Pago Parcial / Abono)**:
  * Consulta ($250) + Procedimiento de curación ($350) = Facturado **$600.00**.
  * El paciente abona en efectivo $200.00 (`ESTADO_COBRO = 'PARCIAL'`).
  * *Validación*: Saldo pendiente de $400.00 registrado con precisión en el DWH.
* **Caso 5.5 (Transacción de Ayer - Lookback Incremental)**:
  * Consulta médica de control realizada con fecha `SYSDATE - 1`.
  * *Validación*: Demuestra que el parámetro de lookback deslizante (por defecto 3 días) captura transacciones ingresadas o consolidadas con desfase de 24-72 horas.

---

## 🚀 Guía de Ejecución

### Opción A: Ejecución Automatizada de 1 Clic (Python)

El script `ejecutar_simulacion_completa.py` coordina las tres capas sin intervención manual:

```bash
# Ejecutar ciclo completo: Inyección OLTP -> Apache Hop -> Validación DWH
python PRUEBAS/ejecutar_simulacion_completa.py --modo completo

# O ejecutar por fases independientes:
python PRUEBAS/ejecutar_simulacion_completa.py --modo cargar    # Solo inyecta en OLTP
python PRUEBAS/ejecutar_simulacion_completa.py --modo hop       # Solo corre Apache Hop
python PRUEBAS/ejecutar_simulacion_completa.py --modo validar   # Solo valida el DWH
python PRUEBAS/ejecutar_simulacion_completa.py --modo limpiar   # Realiza rollback total
```

---

### Opción B: Ejecución Manual Paso a Paso

#### Paso 1: Inyectar datos en OLTP
Conéctate a la base de datos con el usuario `red_clinica_user` (en SQL Developer, DBeaver, VS Code o SQL*Plus) y ejecuta el archivo:
```sql
@PRUEBAS/01_SIMULACION_CARGA_OLTP.sql
```
*Verifica la salida de consola de DBMS_OUTPUT para comprobar que no existan errores de llaves primarias ni disparadores.*

#### Paso 2: Ejecutar el Pipeline ETL en Apache Hop
Puedes ejecutarlo desde línea de comandos usando el ejecutable batch optimizado:
```cmd
cd /d "d:\Diego\Cursos\KODIGO SQL IA\ProyectoFinal\HOP"
ejecutar_pipeline_diario.bat INCREMENTAL 3
```
*O abrir Hop GUI (`hop-gui.bat`), abrir `wf_dwh_master.hwf` y pulsar el botón **Run**.*

#### Paso 3: Validar resultados en el Data Warehouse
Conéctate con el usuario `dwh_clinica_user` y ejecuta:
```sql
@PRUEBAS/02_VALIDACION_DWH_POST_CARGA.sql
```

#### Paso 4: (Opcional) Revertir y limpiar las pruebas
Para restaurar el estado original de la base de datos sin alterar los datos de producción:
```sql
-- Ejecutar conectado como red_clinica_user y luego como dwh_clinica_user:
@PRUEBAS/03_LIMPIEZA_ROLLBACK_PRUEBAS.sql
```

---

## 📊 Matriz de Verificación y Criterios de Éxito

| Área | Criterio de Éxito | Consulta / Tabla de Validación |
| :--- | :--- | :--- |
| **Auditoría** | Los 31 procedimientos completan con `ESTADO = 'SUCCESS'` compartiendo el mismo `BATCH_ID`. | `SELECT * FROM CTL_ETL_AUDIT WHERE BATCH_ID = (SELECT MAX(BATCH_ID) FROM CTL_ETL_AUDIT);` |
| **Catálogos** | 9 entidades nuevas mapeadas con sus claves naturales y atributos. | `SELECT COUNT(*) FROM DIM_UBICACION WHERE DISTRITO LIKE '%Cayalá%';` |
| **SCD Tipo 1** | Modificación in-place sin alterar el `SK_ESPECIALIDAD`. | `SELECT DESCRIPCION FROM DIM_ESPECIALIDAD WHERE BK_ID_ESPECIALIDAD = 1;` |
| **SCD Tipo 2** | Exactamente 2 versiones: una con `CURRENTFLAG = 0` y la vigente con `CURRENTFLAG = 1` y fecha fin `9999-12-31`. | `SELECT SK_PACIENTE, CURRENTFLAG, VALIDTO FROM DIM_PACIENTE WHERE BK_ID_PACIENTE = 10;` |
| **Fact Consultas** | Las 5 consultas de prueba están presentes con sus métricas (`MONTO_TOTAL_FACTURADO`, `MONTO_TOTAL_PAGADO`, `SALDO_PENDIENTE`). | `SELECT COUNT(*) FROM FACT_CONSULTAS WHERE MOTIVO_CONSULTA LIKE '%[PRUEBA]%';` (Esperado: 5) |
| **Prorrateo Diagnósticos** | El monto se distribuye equitativamente entre los diagnósticos sin duplicación financiera. | `SELECT BK_ID_CONSULTA, SUM(MONTO_CONSULTA_PRORRATEADO) FROM FACT_CONSULTA_DIAGNOSTICOS GROUP BY BK_ID_CONSULTA;` |
| **Fact Cobros Distribución** | Se reflejan los porcentajes y montos por cada tipo de pagador (Aseguradora, Paciente, Empresa). | `SELECT TIPO_PAGADOR, MONTO_ASIGNADO, ESTADO_DISTRIBUCION FROM FACT_COBROS_DISTRIBUCION WHERE SK_CONSULTA IN (...);` |

---

## 🛠️ Preguntas Frecuentes y Solución de Problemas

1. **¿Qué ocurre si el pipeline falla por memoria o bloqueo de sesión?**
   * Revisa la tabla `CTL_ETL_AUDIT` filtrando por `ESTADO = 'FAILED'`.
   * Verifica que ninguna sesión de SQL Developer mantenga transacciones abiertas sin `COMMIT` en `red_clinica_user` o `dwh_clinica_user`.
2. **¿Por qué la consulta del día de ayer es procesada si la ejecución es diaria?**
   * El parámetro `DIAS_LOOKBACK` (por defecto `3`) define una ventana de tolerancia móvil para capturar transacciones registradas con desfase o corregidas retrospectivamente en el sistema transaccional.
3. **¿Se puede cambiar el parámetro lookback en las pruebas?**
   * Sí, pasando el argumento `--lookback <dias>` al script de Python o como segundo parámetro en `ejecutar_pipeline_diario.bat INCREMENTAL 7`.
