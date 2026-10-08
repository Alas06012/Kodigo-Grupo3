# Pipeline de Ingesta Masiva desde Parquet (`OLTP`)

Esta carpeta contiene la infraestructura de carga masiva de datos sintéticos/prueba desde archivos `.parquet` hacia el esquema transaccional `red_clinica_user` en **Oracle Database** (`XEPDB1`).

---

## 1. Métricas del Dataset de Prueba Detectado (8.34 Millones de Filas)

| Nivel | Tabla | Registros Parquet | Dependencias Clave Foránea (FK) |
| :---: | :--- | :---: | :--- |
| **0** | `UBICACIONES` | 262 | Ninguna (Catálogo base) |
| **0** | `EMPRESAS` | 68 | Ninguna |
| **0** | `ASEGURADORAS` | 10 | Ninguna |
| **0** | `ESPECIALIDADES` | 30 | Ninguna |
| **0** | `ENFERMEDADES` | 66 | Ninguna (Catálogo CIE-10) |
| **0** | `TIPOS_CONSULTA` | 9 | Ninguna |
| **0** | `PROCEDIMIENTOS` | 36 | Ninguna |
| **0** | `FORMAS_PAGO` | 9 | Ninguna |
| **1** | `CLINICAS` | 270 | `UBICACIONES` |
| **2** | `MEDICOS` | 916 | `CLINICAS` |
| **2** | `PACIENTES` | 100,032 | `UBICACIONES`, `CLINICAS`, `EMPRESAS`, `ASEGURADORAS` |
| **3** | `MEDICOS_ESPECIALIDADES`| 1,370 | `MEDICOS`, `ESPECIALIDADES` |
| **3** | `CONSULTAS` | 1,300,040 | `PACIENTES`, `CLINICAS`, `MEDICOS`, `ESPECIALIDADES`, `TIPOS_CONSULTA` |
| **4** | `DIAGNOSTICOS` | 1,651,801 | `CONSULTAS`, `ENFERMEDADES` |
| **4** | `CONSULTAS_PROCEDIMIENTOS`| 456,040 | `CONSULTAS`, `PROCEDIMIENTOS` *(Omite virtual: SUBTOTAL)* |
| **4** | `COBROS_CONSULTA` | 1,300,040 | `CONSULTAS` *(Omite virtual: SALDO_PENDIENTE)* |
| **5** | `DISTRIBUCION_COBRO` | 1,860,384 | `COBROS_CONSULTA`, `PACIENTES`, `ASEGURADORAS`, `EMPRESAS` *(Omite virtual: SALDO_PENDIENTE)* |
| **6** | `TRANSACCIONES_PAGO` | 1,665,109 | `COBROS_CONSULTA`, `DISTRIBUCION_COBRO`, `FORMAS_PAGO` |
| **TOTAL** | **18 Tablas** | **8,336,492** | **Carga íntegra sin violación de integridad referencial** |

---

## 2. Componentes y Scripts en esta Carpeta

```plaintext
/OLTP/Data/IngestaParquet/
├── 00_LIMPIAR_TABLAS_OLTP.sql                   <- Deshabilita FKs, trunca las 18 tablas y rehabilita FKs
├── 01_PRE_INGESTA_IDENTITY_BY_DEFAULT.sql       <- Habilita 'BY DEFAULT ON NULL' en las 18 columnas Identity
├── 02_POST_INGESTA_IDENTITY_ALWAYS_RESTART.sql  <- Calcula MAX(ID)+1, reinicia secuencias y bloquea a ALWAYS
├── ingestar_parquets_oltp.py                    <- Runner masivo de alta velocidad (python-oracledb)
└── README.md                                    <- Este documento
```

---

## 3. Instrucciones de Ejecución

### Opción A (Recomendada): Ingesta Directa de Alta Velocidad (3 a 5 minutos)
Utiliza el driver nativo `python-oracledb` con inserciones por lotes de array binds (`executemany`):

```powershell
# Desde la carpeta raíz del proyecto o desde /OLTP/Data/IngestaParquet:
python "OLTP/Data/IngestaParquet/ingestar_parquets_oltp.py" `
  --host localhost `
  --port 1521 `
  --service_name XEPDB1 `
  --user red_clinica_user `
  --password TU_PASSWORD_AQUI `
  --batch_size 25000
```

> **¿Qué hace este comando automáticamente?**
> 1. Se conecta a Oracle `XEPDB1`.
> 2. Ejecuta la Fase 1 (`01_PRE_INGESTA_IDENTITY_BY_DEFAULT.sql`).
> 3. Lee cada `.parquet` e inserta los 8.3 millones de filas en bloques de 25,000 en el orden estricto de claves foráneas.
> 4. Omite las columnas virtuales calculadas (`SALDO_PENDIENTE`, `SUBTOTAL`).
> 5. Ejecuta la Fase 3 (`02_POST_INGESTA_IDENTITY_ALWAYS_RESTART.sql`), calculando el `MAX(ID) + 1` de cada tabla y devolviendo la propiedad `ALWAYS AS IDENTITY`.

---

### Opción B: Ejecución Manual de Pre y Post Ingesta en SQL Developer / DBeaver

Si deseas controlar manualmente el ciclo de vida de las columnas Identity desde tu cliente SQL:

1. **Antes de la carga:**
   Ejecuta el script [01_PRE_INGESTA_IDENTITY_BY_DEFAULT.sql](file:///d:/Diego/Cursos/KODIGO%20SQL%20IA/ProyectoFinal/OLTP/Data/IngestaParquet/01_PRE_INGESTA_IDENTITY_BY_DEFAULT.sql).
2. **Realiza la inserción de los datos.**
3. **Después de la carga:**
   Ejecuta el script [02_POST_INGESTA_IDENTITY_ALWAYS_RESTART.sql](file:///d:/Diego/Cursos/KODIGO%20SQL%20IA/ProyectoFinal/OLTP/Data/IngestaParquet/02_POST_INGESTA_IDENTITY_ALWAYS_RESTART.sql).
   Esto asegura que los nuevos registros que el sistema transaccional inserte en el futuro comiencen exactamente en el correlativo siguiente al último ID cargado.
