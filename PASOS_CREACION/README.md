# 🚀 Guía Rápida de Despliegue: Carpeta PASOS_CREACION

Esta carpeta recopila y ordena **paso a paso (del 00 al 06)** todo el ciclo de vida para desplegar el Data Warehouse y su pipeline analítico completo en Oracle Database (`XEPDB1`).

---

## 📋 Tabla Resumen de Ejecución Secuencial

| Paso | Archivo SQL | Usuario de Conexión | Contraseña | ¿Acción Externa Requerida? | Descripción |
| :-: | :--- | :--- | :--- | :-: | :--- |
| **00** | [`00_INFRAESTRUCTURA_Y_USUARIOS.sql`](./00_INFRAESTRUCTURA_Y_USUARIOS.sql) | `SYS AS SYSDBA` o `SYSTEM` | *(Tu clave SYS)* | No | Crea los 3 tablespaces físicos (`red_clinicas_db`, `stg_clinicas_db`, `dwh_clinicas_db`) y los 3 esquemas. |
| **01** | [`01_CREAR_TABLAS_OLTP.sql`](./01_CREAR_TABLAS_OLTP.sql) | `red_clinica_user` | `Password2026` | **Sí (Terminal)** | Crea las 18 tablas relacionales del sistema clínico. **Al terminar, corre la ingesta Parquet en terminal.** |
| **02** | [`02_CREAR_TABLAS_STAGING.sql`](./02_CREAR_TABLAS_STAGING.sql) | `stg_clinica_user` | `StagingPass2026` | No | Crea las 18 tablas de aterrizaje con 6 columnas técnicas de auditoría y otorga SELECT a DWH. |
| **03** | [`03_CREAR_TABLAS_Y_PROCEDIMIENTOS_DWH.sql`](./03_CREAR_TABLAS_Y_PROCEDIMIENTOS_DWH.sql) | `dwh_clinica_user` | `DwhPass2026` | No | Crea el modelo en estrella (10 dims + 3 hechos + tabla de control) y los SPs de auditoría/analíticos con `GRANT EXECUTE` a Staging. |
| **04** | [`04_CREAR_PROCEDIMIENTOS_STAGING.sql`](./04_CREAR_PROCEDIMIENTOS_STAGING.sql) | `stg_clinica_user` | `StagingPass2026` | No | Compila los 19 SPs de extracción (ahora sin errores de auditoría ni identificadores) y da permisos a DWH. |
| **05** | [`05_EJECUTAR_ETL_DWH.sql`](./05_EJECUTAR_ETL_DWH.sql) | `dwh_clinica_user` | `DwhPass2026` | No | Dispara la carga masiva (`SP_LOAD_DWH_MASTER('FULL')`) y muestra el resumen de lotes en `CTL_ETL_AUDIT`. |
| **06** | [`06_VALIDAR_KPIS_Y_AUDITORIA.sql`](./06_VALIDAR_KPIS_Y_AUDITORIA.sql) | `dwh_clinica_user` | `DwhPass2026` | Opcional | Ejecuta las consultas de verificación de filas y las 12 métricas oficiales de negocio. |

---

## 💻 Acciones Externas en Terminal (Detalle)

### 1. Ingesta Masiva de Datos Parquet (Durante el Paso 01)
Una vez ejecutado en tu cliente SQL el script `01_CREAR_TABLAS_OLTP.sql`, abre una terminal en la raíz del proyecto y corre:

```powershell
pip install -r "OLTP/Data/IngestaParquet/requirements.txt"
python "OLTP/Data/IngestaParquet/ingestar_parquets_oltp.py"
```
*(Tiempo estimado: 3 a 5 minutos para 8.34 millones de registros)*.

---

### 2. Auditoría Técnica y Conciliación Contable (Después del Paso 06)
Para verificar la conciliación centavo a centavo y cuadre entre capas:

```powershell
python audit_pipeline.py
```
*(Verifica 100% de coincidencias de conteos, cero llaves huérfanas y cuadre exacto de \$86,688,740.28)*.
