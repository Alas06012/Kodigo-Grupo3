/*
    SI YA TIENSES LA BASE DE DATOS CREADA Y AUN NO TIENES DATOS EN EL OLTP.
    PRIMERO EJECUTA EL SCRIPT PYTHON PARA CARGAR DATOS DE PRUEBA EN EL OLTP.

    1. COMANDO PARA INSTALAR LAS DEPENDENCIAS DE PYTHON (SI NO LO HAS HECHO AUN):
    pip install -r "OLTP/Data/IngestaParquet/requirements.txt"

    2. Desde la carpeta raíz del proyecto o desde /OLTP/Data/IngestaParquet:
        python "OLTP/Data/IngestaParquet/ingestar_parquets_oltp.py" `
        --host localhost `
        --port 1521 `
        --service_name XEPDB1 `
        --user red_clinica_user `
        --password TU_PASSWORD_AQUI `
        --batch_size 25000
*/


/* 
    UNA VEZ CARGADOS LOS DATOS EN EL OLTP, EJECUTA EL SIGUIENTE SP PARA CARGAR LOS DATOS EN EL DWH:
        Conectase como dwh_clinica_user (DwhPass2026) y ejecuta:
*/
    EXECUTE SP_LOAD_DWH_MASTER('FULL');

/*
    CON ESTO YA QUEDARIA POBLADO TODO EL DWH CON LOS DATOS DE PRUEBA DEL OLTP.
    SI QUIERES HACER UNA CARGA INCREMENTAL, COLOCA INCREMENTAL COMO PRIMER PARAMETRO Y LUEGO EL NUMERO DE DIAS QUE QUIERES QUE EL SP BUSQUE REGISTROS NUEVOS EN EL OLTP. 
    EJEMPLO:   
*/
    -- EXECUTE SP_LOAD_DWH_MASTER('INCREMENTAL', 7);