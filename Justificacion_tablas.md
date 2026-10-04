# Arquitectura de Base de Datos - Red Clínicas
## Justificación y Catálogo de Entidades

Este documento resume la justificación operativa y relacional de cada una de las 18 tablas que integran el modelo de base de datos optimizado en Oracle Database, acompañado de un ejemplo concreto de aplicación para facilitar la inducción del equipo de desarrollo y administración de datos.

---

## Módulo 1: Catálogos Territoriales y Afiliaciones

### 1. UBICACIONES

**¿Por qué existe?**  
Estandariza la jerarquía geográfica (País, Departamento, Municipio, Distrito y Código Postal). Evita redundancias de texto y variaciones tipográficas en las direcciones físicas, permitiendo segmentaciones demográficas precisas y reportes epidemiológicos por zona territorial.

**Ejemplo de aplicación:**
```plaintext
ID_UBICACION: 1
PAIS: 'El Salvador'
DEPARTAMENTO: 'San Salvador'
MUNICIPIO: 'San Salvador Centro'
DISTRITO: 'San Salvador'
CODIGO_POSTAL: '01101'
```

---

### 2. CLINICAS

**¿Por qué existe?**  
Representa cada sede física o sucursal asistencial que integra la red. Se vincula formalmente a UBICACIONES para registrar su localización y gestiona los canales de contacto y el estado operativo (Activa/Inactiva).

**Ejemplo de aplicación:**
```plaintext
ID_CLINICA: 1
NOMBRE_CLINICA: 'Clínica Escalón Central'
ID_UBICACION: 1
DIRECCION: 'Paseo General Escalón y 79 Av. Norte #450'
TELEFONO: '2250-1001'
ESTADO: 'ACTIVA'
```

---

### 3. EMPRESAS

**¿Por qué existe?**  
Almacena a los empleadores que mantienen convenios de salud ocupacional o subsidios corporativos con la red de clínicas para la atención médica de sus colaboradores.

**Ejemplo de aplicación:**
```plaintext
ID_EMPRESA: 1
NOMBRE_EMPRESA: 'TelcoCorp El Salvador S.A.'
NIT: '0614-010190-101-1'
SECTOR: 'Telecomunicaciones'
TELEFONO: '2255-9000'
```

---

### 4. ASEGURADORAS

**¿Por qué existe?**  
Catálogo maestro de compañías de seguros privados. Permite identificar las entidades responsables de cubrir reclamos directos, copagos o pólizas de gastos médicos mayores y menores.

**Ejemplo de aplicación:**
```plaintext
ID_ASEGURADORA: 1
NOMBRE_ASEGURADORA: 'Aseguradora Suiza Salvadoreña'
NIT: '0614-120595-102-2'
TIPO_COBERTURA: 'Gastos Médicos Mayores y Menores'
TELEFONO: '2200-8888'
```

---

### 5. PACIENTES

**¿Por qué existe?**  
Es el expediente maestro de la persona atendida. Guarda su identidad biográfica, dirección residencial exacta (DIRECCION), clínica base preferente y sus convenios activos por defecto (ID_EMPRESA, ID_ASEGURADORA, NUMERO_POLIZA) para agilizar su admisión en recepción.

**Ejemplo de aplicación:**
```plaintext
ID_PACIENTE: 1
NOMBRES: 'Juan Carlos'
APELLIDOS: 'Pérez Meza'
FECHA_NACIMIENTO: 1995-04-12
SEXO: 'M'
ID_UBICACION: 1
DIRECCION: 'Col. Escalón, Pasaje Los Rosales #14'
ID_CLINICA_HABITUAL: 1
ID_EMPRESA: 1
ID_ASEGURADORA: NULL
```

---

## Módulo 2: Cuerpo Médico y Catálogos Asistenciales

### 6. ESPECIALIDADES

**¿Por qué existe?**  
Catálogo maestro de disciplinas médicas ofertadas en la red de clínicas. Estandariza la oferta de servicios profesionales sin duplicidades.

**Ejemplo de aplicación:**
```plaintext
ID_ESPECIALIDAD: 2
NOMBRE_ESPECIALIDAD: 'Otorrinolaringología'
DESCRIPCION: 'Diagnóstico y tratamiento de patologías de oído, nariz y garganta'
```

---

### 7. MEDICOS

**¿Por qué existe?**  
Contiene la ficha profesional de cada doctor adscrito a la red, su clínica de contratación base (ID_CLINICA_BASE) y su número de junta de vigilancia profesional (NUM_COLEGIADO). No tiene especialidad fija en esta tabla para permitir que un médico ejerza múltiples áreas.

**Ejemplo de aplicación:**
```plaintext
ID_MEDICO: 1
NOMBRES: 'Roberto Antonio'
APELLIDOS: 'Silva Flores'
ID_CLINICA_BASE: 1
NUM_COLEGIADO: 'JVPM-8841'
ESTADO: 'ACTIVO'
```

---

### 8. MEDICOS_ESPECIALIDADES

**¿Por qué existe?**  
Resuelve la relación muchos a muchos (N:M) entre médicos y especialidades. Un profesional puede ser médico general pero tener también una subespecialidad quirúrgica o pediátrica registrada con un número de registro oficial.

**Ejemplo de aplicación:**
```plaintext
ID_MEDICO_ESPECIALIDAD: 2
ID_MEDICO: 1 (Dr. Roberto Silva)
ID_ESPECIALIDAD: 2 (Otorrinolaringología)
NUM_REGISTRO_ESPECIAL: 'REG-ORL-2015'
ES_PRINCIPAL: 'N'
```

---

### 9. ENFERMEDADES

**¿Por qué existe?**  
Catálogo universal de diagnósticos médicos basado en la nomenclatura internacional CIE-10. Se eliminó la columna informativa de categoría para centralizar el catálogo en el código y el nombre patológico estandarizado.

**Ejemplo de aplicación:**
```plaintext
ID_ENFERMEDAD: 3
CODIGO_CIE10: 'S62.6'
NOMBRE_ENFERMEDAD: 'Fractura de otro dedo de la mano'
```

---

### 10. TIPOS_CONSULTA

**¿Por qué existe?**  
Clasifica la modalidad asistencial del acto médico (Consulta General, Especializada, Urgencia, Control de Seguimiento). Define la tarifa base sugerida (PRECIO_BASE) y desacopla la lógica de negocio del motor de base de datos sin requerir restricciones CHECK rígidas.

**Ejemplo de aplicación:**
```plaintext
ID_TIPO_CONSULTA: 3
NOMBRE_TIPO: 'Consulta de Urgencia'
DESCRIPCION: 'Atención prioritaria ambulatoria inmediata sin cita previa'
PRECIO_BASE: 45.00
ESTADO: 'ACTIVO'
```

---

### 11. PROCEDIMIENTOS

**¿Por qué existe?**  
Catálogo de intervenciones, terapias, curaciones o maniobras no farmacológicas que tienen un código clínico tarifado dentro de la red.

**Ejemplo de aplicación:**
```plaintext
ID_PROCEDIMIENTO: 1
CODIGO_PROCEDIMIENTO: 'PROC-ORT-01'
NOMBRE_PROCEDIMIENTO: 'Inmovilización con férula de dedo/mano'
COSTO_BASE: 70.00
ESTADO: 'ACTIVO'
```

---

## Módulo 3: Acto Médico y Expediente Clínico

### 12. CONSULTAS

**¿Por qué existe?**  
Es el registro del encuentro clínico entre el paciente y el médico. Guarda los honorarios pactados (PRECIO_CONSULTA), la clínica donde ocurrió el evento, la receta de medicamentos textual para compra externa (PRESCRIPCION) y garantiza por llave foránea compuesta declarativa (ID_MEDICO, ID_ESPECIALIDAD) que el médico atienda exclusivamente bajo una especialidad debidamente acreditada.

**Ejemplo de aplicación:**
```plaintext
ID_CONSULTA: 1
ID_PACIENTE: 1 (Juan Pérez)
ID_CLINICA: 1 (Clínica Escalón)
ID_MEDICO: 1 (Dr. Silva)
ID_ESPECIALIDAD: 1 (Medicina General)
ID_TIPO_CONSULTA: 1 (Consulta General)
PRECIO_CONSULTA: 30.00
MOTIVO_CONSULTA: 'Fiebre alta y dedo quebrado tras caída'
PRESCRIPCION: 'Acetaminofén 500mg c/8h por 3 días. Ibuprofeno 400mg c/8h por 4 días.'
```

---

### 13. DIAGNOSTICOS

**¿Por qué existe?**  
Resuelve la cardinalidad muchos a muchos (N:M) entre la consulta y las enfermedades. En un solo acto médico el paciente puede presentar múltiples cuadros patológicos simultáneos (ej. gripe, fiebre y traumatismo).

**Ejemplo de aplicación:**
```plaintext
ID_DIAGNOSTICO: 3
ID_CONSULTA: 1
ID_ENFERMEDAD: 3 (Fractura de dedo)
OBSERVACIONES: 'Fractura no desplazada en falange distal de 4to dedo de mano derecha'
```

---

### 14. CONSULTAS_PROCEDIMIENTOS

**¿Por qué existe?**  
Detalla los procedimientos clínicos aplicados al paciente durante la atención médica. Calcula automáticamente el campo SUBTOTAL como columna virtual (CANTIDAD * PRECIO_UNITARIO), garantizando consistencia matemática.

**Ejemplo de aplicación:**
```plaintext
ID_CONSULTA_PROCEDIMIENTO: 1
ID_CONSULTA: 1
ID_PROCEDIMIENTO: 1 (Férula)
CANTIDAD: 1
PRECIO_UNITARIO: 70.00
SUBTOTAL (Virtual): 70.00
OBSERVACIONES: 'Reducción cerrada e inmovilización con férula de aluminio'
```

---

## Módulo 4: Facturación, Coberturas y Tesorería

### 15. FORMAS_PAGO

**¿Por qué existe?**  
Catálogo de medios de pago autorizados en las cajas de recepción. Clasifica los ingresos según su naturaleza contable (CONTADO para efectivo/tarjetas vs. CREDITO para convenios corporativos o liquidaciones directas de aseguradoras).

**Ejemplo de aplicación:**
```plaintext
ID_FORMA_PAGO: 2
NOMBRE_FORMA_PAGO: 'Tarjeta de Débito'
CATEGORIA: 'CONTADO'
ESTADO: 'ACTIVO'
```

---

### 16. COBROS_CONSULTA

**¿Por qué existe?**  
Representa la cuenta médica global o factura consolidada de la consulta. Suma el precio de los honorarios médicos ($30) y los procedimientos ($70), totalizando los consumos del paciente. Mantiene un cálculo de SALDO_PENDIENTE en tiempo real mediante una columna virtual.

**Ejemplo de aplicación:**
```plaintext
ID_COBRO: 1
ID_CONSULTA: 1
MONTO_TOTAL_FACTURADO: 100.00
MONTO_TOTAL_PAGADO: 100.00 (Actualizado vía Trigger)
SALDO_PENDIENTE (Virtual): 0.00
ESTADO_COBRO: 'PAGADO'
```

---

### 17. DISTRIBUCION_COBRO

**¿Por qué existe?**  
Modela la responsabilidad financiera compartida. Permite que la cuenta sea asumida en porcentajes o montos específicos por el Paciente, su Empresa y/o su Aseguradora, monitoreando el saldo individual de cada actor involucrado sin cruces de deuda.

**Ejemplo de aplicación (Caso Juan Pérez):**

**Fila A (Empresa):**
```plaintext
ID_DISTRIBUCION: 1
ID_COBRO: 1
TIPO_PAGADOR: 'EMPRESA'
ID_EMPRESA: 1 (TelcoCorp)
PORCENTAJE: 25.00%
MONTO_ASIGNADO: 25.00
MONTO_PAGADO: 25.00
SALDO_PENDIENTE: 0.00
ESTADO: 'PAGADO'
```

**Fila B (Paciente):**
```plaintext
ID_DISTRIBUCION: 2
ID_COBRO: 1
TIPO_PAGADOR: 'PACIENTE'
ID_PACIENTE: 1 (Juan Pérez)
PORCENTAJE: 75.00%
MONTO_ASIGNADO: 75.00
MONTO_PAGADO: 75.00 (Abonado en dos partes: $65 inicial + $10 diferido)
SALDO_PENDIENTE: 0.00
ESTADO: 'PAGADO'
```

---

### 18. TRANSACCIONES_PAGO

**¿Por qué existe?**  
Es el libro diario inmutable de tesorería y caja. Cada abono realizado (ya sea total, parcial, en distintas fechas o con diferentes medios de pago) se guarda de forma histórica con su comprobante de pago. Nunca sobreescribe filas anteriores y dispara el trigger contable que recalcula los saldos de forma delta.

**Ejemplo de aplicación (Línea de tiempo de Juan Pérez):**

**Transacción 1 (Día de atención):**
```plaintext
ID_TRANSACCION: 1
ID_DISTRIBUCION: 1 (Empresa)
ID_FORMA_PAGO: 5 (Crédito Corporativo)
MONTO_TRANSACCION: 25.00
NUMERO_REFERENCIA: 'TELCO-ORD-9912'
```

**Transacción 2 (Día de atención):**
```plaintext
ID_TRANSACCION: 2
ID_DISTRIBUCION: 2 (Paciente)
ID_FORMA_PAGO: 2 (Tarjeta de Débito)
MONTO_TRANSACCION: 65.00
NUMERO_REFERENCIA: 'POS-VOUCH-5510'
OBSERVACIONES: 'Abono parcial en caja (queda debiendo $10)'
```

**Transacción 3 (Lunes siguiente):**
```plaintext
ID_TRANSACCION: 3
ID_DISTRIBUCION: 2 (Paciente)
ID_FORMA_PAGO: 1 (Efectivo)
MONTO_TRANSACCION: 10.00
NUMERO_REFERENCIA: 'REC-CAJA-3011'
OBSERVACIONES: 'Finiquito de saldo pendiente'
```

---

## Matriz Resumen de Entidades

| # | Tabla | Módulo | Función Primaria | Clave de Diseño |
|---|-------|--------|------------------|-----------------|
| 1 | UBICACIONES | Territorio | Normalización territorial (País a Distrito) | Evita cadenas libres de texto |
| 2 | CLINICAS | Territorio | Sedes asistenciales de la red médica | Vinculada a UBICACIONES |
| 3 | EMPRESAS | Convenios | Convenios corporativos de salud laboral | Conexión opcional en paciente y distribución |
| 4 | ASEGURADORAS | Convenios | Pólizas y entidades de seguro médico | Conexión opcional en paciente y distribución |
| 5 | PACIENTES | Pacientes | Expediente maestro del usuario | Contiene dirección de calle y pólizas base |
| 6 | ESPECIALIDADES | Catálogos | Ramas de la medicina ofertadas | Catálogo normalizado |
| 7 | MEDICOS | Personal | Cuerpo médico y clínica de contratación | Sin especialidad rígida en sus columnas |
| 8 | MEDICOS_ESPECIALIDADES | Personal | Tabla puente N:M médico-especialidades | Permite acreditaciones múltiples por doctor |
| 9 | ENFERMEDADES | Catálogos | Nomenclatura oficial CIE-10 | Sin categoría redundante |
| 10 | TIPOS_CONSULTA | Catálogos | Modalidades de consulta y tarifa base | Permite alta de nuevos tipos sin DDL |
| 11 | PROCEDIMIENTOS | Catálogos | Tarifario de actos médicos no farmacológicos | Costo base referencial |
| 12 | CONSULTAS | Asistencial | Registro de cita médica y prescripción | FK compuesta (MEDICO, ESPECIALIDAD) |
| 13 | DIAGNOSTICOS | Asistencial | Relación N:M consulta-enfermedades | Diagnósticos múltiples por cita |
| 14 | CONSULTAS_PROCEDIMIENTOS | Asistencial | Procedimientos realizados en consulta | Subtotal virtual automático |
| 15 | FORMAS_PAGO | Tesorería | Medios de pago autorizados | Tipificación CONTADO vs. CREDITO |
| 16 | COBROS_CONSULTA | Facturación | Cuenta global facturada por atención | Saldo virtual (FACTURADO - PAGADO) |
| 17 | DISTRIBUCION_COBRO | Facturación | Responsabilidad de pago desglosada | Monitoreo de saldo y estado por pagador |
| 18 | TRANSACCIONES_PAGO | Tesorería | Libro diario inmutable de abonos reales | Vinculado a distribución y auditado por trigger |