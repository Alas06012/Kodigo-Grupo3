# 🚀 Guía de Despliegue: Carpeta PASOS_CREACION

Esta carpeta proporciona dos modalidades para desplegar el Data Warehouse y su pipeline analítico en Oracle Database (`XEPDB1`):

1. **Modalidad Automática (Todo en uno):** Un solo script SQL que orquesta la ejecución continua.
2. **Modalidad Modular (Paso a Paso):** Scripts individuales del `00` al `07` para control y auditoría paso a paso.

---

## ⚡ Modalidad 1: Ejecutar Todo de una Sola Vez (100% SQL)

Si utilizas **Oracle SQL Developer**, **SQL*Plus** o **SQLcl**, puedes ejecutar el script maestro:

📁 [`EJECUTAR_TODO_MASTER.sql`](./EJECUTAR_TODO_MASTER.sql)

### ¿Cómo correrlo?

- **Desde SQL Developer:** Abre [`EJECUTAR_TODO_MASTER.sql`](./EJECUTAR_TODO_MASTER.sql) conectado como `SYS AS SYSDBA` o `SYSTEM` y presiona **[F5] (Ejecutar Script)**.
- **Desde Consola (SQL*Plus / SQLcl):**
  ```powershell
  sqlplus / as sysdba @PASOS_CREACION/EJECUTAR_TODO_MASTER.sql
  ```

> [!NOTE]
> Este script maestro es **100% SQL puro**: limpia el entorno previo, crea tablespaces y esquemas, conecta secuencialmente con cada usuario (`red_clinica_user`, `stg_clinica_user`, `dwh_clinica_user`), compila todos los objetos, lanza la orquestación ETL y valida los KPIs analíticos.

---

## 📋 Modalidad 2: Ejecución Secuencial Paso a Paso

Ideal para clientes como **DBeaver**, **VS Code** o cuando desees verificar los resultados intermedios en cada etapa:


|  Paso  | Archivo SQL                                                                              | Usuario de Conexión       | Contraseña       | ¿Acción Externa? | Descripción                                                                                                                         |
| :----: | :--------------------------------------------------------------------------------------- | :------------------------- | :---------------- | :----------------: | :----------------------------------------------------------------------------------------------------------------------------------- |
| **00** | [`00_LIMPIEZA_TOTAL.sql`](./00_LIMPIEZA_TOTAL.sql)                                       | `SYS AS SYSDBA` o `SYSTEM` | *(Tu clave SYS)*  |         No         | **Limpieza Total:** Cierra sesiones activas, elimina los 3 esquemas en cascada y borra tablespaces físicos de forma idempotente.    |
| **01** | [`01_INFRAESTRUCTURA_Y_USUARIOS.sql`](./01_INFRAESTRUCTURA_Y_USUARIOS.sql)               | `SYS AS SYSDBA` o `SYSTEM` | *(Tu clave SYS)*  |         No         | Crea los 3 tablespaces físicos (`red_clinicas_db`, `stg_clinicas_db`, `dwh_clinicas_db`) y los 3 esquemas.                          |
| **02** | [`02_CREAR_TABLAS_OLTP.sql`](./02_CREAR_TABLAS_OLTP.sql)                                 | `red_clinica_user`         | `Password2026`    | **Sí (Terminal)** | Crea las 18 tablas relacionales del sistema clínico.**Al terminar, corre la ingesta Parquet en terminal.**                          |
| **03** | [`03_CREAR_TABLAS_STAGING.sql`](./03_CREAR_TABLAS_STAGING.sql)                           | `stg_clinica_user`         | `StagingPass2026` |         No         | Crea las 18 tablas de aterrizaje con 6 columnas técnicas de auditoría y otorga SELECT a DWH.                                       |
| **04** | [`04_CREAR_TABLAS_Y_PROCEDIMIENTOS_DWH.sql`](./04_CREAR_TABLAS_Y_PROCEDIMIENTOS_DWH.sql) | `dwh_clinica_user`         | `DwhPass2026`     |         No         | Crea el modelo en estrella (10 dims + 3 hechos + tabla de control) y los SPs de auditoría/analíticos con`GRANT EXECUTE` a Staging. |
| **05** | [`05_CREAR_PROCEDIMIENTOS_STAGING.sql`](./05_CREAR_PROCEDIMIENTOS_STAGING.sql)           | `stg_clinica_user`         | `StagingPass2026` |         No         | Compila los 19 SPs de extracción (sin errores de auditoría ni identificadores) y da permisos a DWH.                                |
| **06** | [`06_EJECUTAR_ETL_DWH.sql`](./06_EJECUTAR_ETL_DWH.sql)                                   | `dwh_clinica_user`         | `DwhPass2026`     |         No         | Dispara la carga masiva (`SP_LOAD_DWH_MASTER('FULL')`) y muestra el resumen de lotes en `CTL_ETL_AUDIT`.                             |
| **07** | [`07_VALIDAR_KPIS_Y_AUDITORIA.sql`](./07_VALIDAR_KPIS_Y_AUDITORIA.sql)                   | `dwh_clinica_user`         | `DwhPass2026`     |      Opcional      | Ejecuta las consultas de verificación de filas y las 12 métricas oficiales de negocio.                                             |

---

## 💻 Acciones Externas en Terminal 

### 1. Ingesta Masiva de Datos Parquet (Durante el Paso 02)

Una vez ejecutado el script `02_CREAR_TABLAS_OLTP.sql`:

```powershell
pip install -r "OLTP/Data/IngestaParquet/requirements.txt"
python "OLTP/Data/IngestaParquet/ingestar_parquets_oltp.py"
```

*(Tiempo estimado: 3 a 5 minutos para 8.34 millones de registros)*.

---

### 2. Auditoría Técnica y Conciliación Contable (Después del Paso 07)

Para verificar la conciliación centavo a centavo y cuadre entre capas:

```powershell
python audit_pipeline.py
```

*(Verifica 100% de coincidencias de conteos, cero llaves huérfanas y cuadre exacto de \$86,688,740.28)*.
