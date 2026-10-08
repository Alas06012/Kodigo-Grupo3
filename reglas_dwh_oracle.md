# Reglas y Estándares para DWH en Oracle

## 1. Reglas para la Capa Staging (`STG_*`)

En Staging los datos son transitorios y se preparan para alimentar el
almacén.

-   **El Hash se calcula durante la extracción:** `ROWHASHVALUE` no debe
    venir vacío desde Staging. Debe generarse al momento de hacer el
    `INSERT INTO STG_... SELECT ...` desde el OLTP para que el `MERGE`
    posterior hacia el DWH sea rápido.
-   **Valores de inicio en Staging:**
    -   `CURRENTFLAG` entra siempre con valor `1`.
    -   `TIPOTRANSACCION` entra con valor inicial `'I'` (se
        reclasificará a `'U'` durante la comparación).
    -   `FECHAINICIO` se llena con la fecha y hora de la extracción
        (`SYSDATE`).
    -   `FECHAFIN` se fija con la fecha tope del sistema
        (`DATE '2999-12-31'`).
    -   `TIPOCARGA` se define como `'FULL'` o `'INCREMENTAL'` según el
        pipeline en ejecución.
-   **Staging no almacena Surrogate Keys (`SK`):** Solo conserva las
    claves naturales del negocio (`BK` o IDs originales) y las 6
    columnas técnicas.

## 2. Reglas para las Dimensiones (`DIM_*` - El motor de SCD Tipo 2)

Las dimensiones que sufren cambios en el tiempo (como `DIM_PACIENTE`,
`DIM_MEDICO` o `DIM_CLINICA`) son las que explotan al 100% este patrón.

### A. Regla del `ROWHASHVALUE` (Qué incluir y qué excluir)

-   **Qué SÍ entra en el Hash:** Únicamente los atributos descriptivos
    que, si cambian, justifican registrar una nueva versión histórica
    (ejemplo: nombres, dirección, clínica habitual, empresa, teléfono).
-   **Qué NUNCA debe entrar en el Hash:**
    -   La Surrogate Key (`SK_*`).
    -   Las fechas de auditoría (`FECHAINICIO`, `FECHAFIN`).
    -   Banderas operativas (`CURRENTFLAG`, `TIPOTRANSACCION`,
        `TIPOCARGA`).
-   **Delimitador y manejo de nulos obligatorio:** Al concatenar cadenas
    para calcular el hash, siempre usa un delimitador seguro (como `|`)
    y envuelve cada campo en `NVL`. De lo contrario, un campo `'A'` y
    `'BC'` generará el mismo hash que `'AB'` y `'C'`:

``` sql
STANDARD_HASH(
    NVL(NOMBRES, '~') || '|' ||
    NVL(APELLIDOS, '~') || '|' ||
    NVL(DIRECCION, '~') || '|' ||
    NVL(TO_CHAR(ID_EMPRESA), '~'),
    'SHA256'
)
```

### B. Regla de Vigencia y Fechas (`CURRENTFLAG`, `FECHAINICIO`, `FECHAFIN`)

-   **Unicidad de vigencia:** Por cada clave natural de negocio
    (`BK_ID_PACIENTE`), **solo puede existir exactamente una fila con
    `CURRENTFLAG = 1`**.
-   **Registros históricos:** Toda fila con `CURRENTFLAG = 0` debe tener
    obligatoriamente un `FECHAFIN` en el pasado o presente (el instante
    en que fue reemplazada).
-   **Registros vigentes:** La fila con `CURRENTFLAG = 1` debe tener
    siempre `FECHAFIN = DATE '2999-12-31'`. Esto evita comparaciones con
    `NULL` en los reportes de BI.

### C. Regla de Transición ante Cambios (Flujo SCD Tipo 2)

Cuando un registro del Staging coincide en clave natural (`BK`) con la
dimensión pero su `ROWHASHVALUE` es distinto:

1.  **Paso 1 (Caducar la versión anterior):**

``` sql
UPDATE DIM_PACIENTE
SET CURRENTFLAG = 0,
    FECHAFIN    = SYSDATE,
    TIPOTRANSACCION = 'U'
WHERE BK_ID_PACIENTE = :id_origen 
  AND CURRENTFLAG = 1;
```

2.  **Paso 2 (Insertar la nueva versión activa):**

``` sql
INSERT INTO DIM_PACIENTE (..., CURRENTFLAG, FECHAINICIO, FECHAFIN, TIPOTRANSACCION, ROWHASHVALUE)
VALUES (..., 1, SYSDATE, DATE '2999-12-31', 'I', :nuevo_hash);
```

## 3. Reglas para las Tablas de Hechos (`FACT_*`)

Las tablas de hechos representan **eventos transaccionales inmutables**
(una consulta médica ocurrió una sola vez en un instante específico; no
"envejece" como una dirección).

Si mantienes la plantilla corporativa con las 6 columnas en las tablas
de hechos:

-   `CURRENTFLAG` se inserta **siempre en `1`** (las transacciones no
    tienen versiones caducadas).
-   `FECHAFIN` se inserta **siempre en `DATE '2999-12-31'`**.
-   `TIPOTRANSACCION` suele ser casi exclusivamente `'I'` (Insert). Solo
    pasa a `'U'` si en el proceso de recarga se recalculó una métrica o
    un estado de cobro.
-   `ROWHASHVALUE` en una tabla de hechos sirve para **idempotencia y
    detección de duplicados**: se calcula con las claves foráneas y las
    métricas numéricas. Si vuelves a correr el proceso y el hash ya
    existe en la fecha dada, el pipeline ignora la fila y evita duplicar
    ventas o consultas.

## 4. Estándar de Tipos de Datos en Oracle

Adapta los tipos de datos de SQL Server a los equivalentes formales en
Oracle:

  ------------------------------------------------------------------------------------------------
  **Columna**             **Tipo de Dato en       **Restricción Recomendada**
                          Oracle**                
  ----------------------- ----------------------- ------------------------------------------------
  `CURRENTFLAG`           `NUMBER(1)`             `CHECK (CURRENTFLAG IN (0, 1))`

  `TIPOCARGA`             `VARCHAR2(20)`          `CHECK (TIPOCARGA IN ('FULL', 'INCREMENTAL'))`

  `FECHAINICIO`           `DATE`                  `DEFAULT SYSDATE NOT NULL`

  `FECHAFIN`              `DATE`                  `DEFAULT DATE '2999-12-31' NOT NULL`

  `TIPOTRANSACCION`       `CHAR(1)`               `CHECK (TIPOTRANSACCION IN ('I', 'U', 'D'))`

  `ROWHASHVALUE`          `VARCHAR2(64)`          Cadena hexadecimal SHA-256 (`NOT NULL`)
  ------------------------------------------------------------------------------------------------

## 5. Regla de Índices para Consultas de BI

El 95% de los dashboards de Power BI, Tableau o Looker consultan
únicamente los datos vigentes. Por ello, debes crear un índice B-Tree
compuesto sobre la clave natural y la bandera de vigencia en todas tus
dimensiones:

``` sql
-- Acelera el cruce en el ETL y filtra el registro activo en milisegundos
CREATE INDEX IX_DIM_PAC_BK_VIGENTE ON DIM_PACIENTE (BK_ID_PACIENTE, CURRENTFLAG);
CREATE INDEX IX_DIM_PAC_HASH       ON DIM_PACIENTE (ROWHASHVALUE);
```
