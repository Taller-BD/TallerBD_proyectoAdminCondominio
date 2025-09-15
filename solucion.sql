DECLARE --inicio del bloque para declarar variables,tipos,cursores y estructurass
    -- 1. se define el un RECORD que es como una fila temporal para almacenar un registro de la tabla GASTO_COMUN
    TYPE gasto_rec IS RECORD (
    --es la variable que usaremos para guardar datosde una fila a la vez cuando usamos el cursor explicito
    -- %TYPE hace que cada campo tome el tipo de dato de la tabla
        id_edif       GASTO_COMUN.id_edif%TYPE,
        nro_depto     GASTO_COMUN.nro_depto%TYPE,
        monto_total   GASTO_COMUN.monto_total_gc%TYPE
    );
    v_gasto gasto_rec; 

    -- 2. VARRAY para guardar hasta 100 montos de gastos comunes de cada departamento
    TYPE varray_montos IS VARRAY(100) OF NUMBER(10);
    v_montos varray_montos := varray_montos();--inicializa el arreglo vacío.

    -- 3. Cursor simple selecciona todos los departamentos y su monto total del edificio
    -- con id 50 en marzo 2025
    CURSOR c_gastos IS
        SELECT id_edif, nro_depto, monto_total_gc
        FROM GASTO_COMUN
        WHERE anno_mes_pcgc = 202503
          AND id_edif = 50;

    -- 4. Cursor explícito (otra forma de recorrer):Cursor explícito: hace exactamente lo mismo, pero lo recorreremos con
    -- OPEN, FETCH y CLOSE, controlando manualmente el ciclo.
    CURSOR c_gastos_expl IS
        SELECT id_edif, nro_depto, monto_total_gc
        FROM GASTO_COMUN
        WHERE anno_mes_pcgc = 202503
          AND id_edif = 50;

    v_total NUMBER := 0;--suma montos de todos los edificios
    v_index NUMBER := 0;--lleva la posicion dentro del varray

BEGIN
    -- Usamos cursor simple con FOR
    DBMS_OUTPUT.PUT_LINE('--- Cursor simple ---');
    --reg variable temporal que contiene una gila completa del cursor (id_edif,nro_Depto,monto_total_gc)
    FOR reg IN c_gastos LOOP--for loop implicito:recorre cada fila del cursor c_gastos
       --DBMS_OUTPUT.PUT_LINE imprime en consola el departamento y su monto.
        DBMS_OUTPUT.PUT_LINE('Depto: ' || reg.nro_depto || ' - Monto: ' || reg.monto_total_gc);
        --no se necesita hacer OPEN ni FECTH EL LOOP lo hace automaticamente
        -- Guardamos en VARRAY
        v_index := v_index + 1;-- se aumenta el indice para guardar el monto en el varray
        v_montos.EXTEND; --agrega un espacio vacio al final del varray para poder guardar un nuevo elemento
        v_montos(v_index) := reg.monto_total_gc;--asigna el monto del departamento actual a la posicion v_index 
    END LOOP;--cierra loop

    -- Usamos cursor explícito
    DBMS_OUTPUT.PUT_LINE('--- Cursor explícito ---'); --un print
    OPEN c_gastos_expl;--abrimos el cursor con OPEN,traemos fila por fila con FETCH
    LOOP
        FETCH c_gastos_expl INTO v_gasto;
        EXIT WHEN c_gastos_expl%NOTFOUND;--sale del loop si no hay mas filas

        -- Manejo de excepción: monto nulo
        IF v_gasto.monto_total IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Monto nulo en depto ' || v_gasto.nro_depto);
        END IF;
        --verifica si el monto es nulo y lanza un error personalizado si es asi, mosntrando que departamento tiene el problema


        -- Acumular total
        v_total := v_total + v_gasto.monto_total;
        --suma el monto de cada departamento al v_total
    END LOOP;
    CLOSE c_gastos_expl;--cierra cursos explicito 

    -- Mostrar total
    DBMS_OUTPUT.PUT_LINE('Total edificios = ' || v_total);--print

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);

        --si ocurre cualquier excepcion no controlsda, imprime el mensade de error SQLERMM
END;
/
--Apuntes:
--1.-recorremos la tabla GASTO_COMUN de dos maneras:cursor simple y cursor explicito
--2.-usamos un varray para guardar los montos de cada departamento y calculamos el total 
--3.-manejamos excepcion para monto nulo en el cursor explicito
--4.-Mostramos resultados en consola

--Terminos y partes importantes:
--DECLARE-->seccion donde se declara variable,tipo,cursores y estructuras antes de ejecutar el codigo
--TYPE ...IS RECORD-->define un registro que agrupa varias columas de una tabla en una sola variables, ejemplo: gasto_Rec junta id_edif, nro_depto y mono_total
--v_gasto-->varianle del tipo gasto_rec que guarda temporalmente una fila del cursor explicito
--TYPE ...IS VARRAY(n)-->define un arreglo de tamaño fijo n, ejemplo: varray_montos guarda hasta 100 montos
--v_montos-->variable del tipo varray_montos que guarda los montos de cada departamento
--CURSOR c_gastos/c_gastos_expl--> cursores que definen una consulta a al tabla GASTO_COMUN para luego rrecorer sus resultados. c_gastos(cursor simple usado con for loop), c_gastots_expl(cursor explicito usando OPEN.FETCH Y CLOES)
--DBMS_OUTPUT.PUT_LINE(...) -->imprime texto en la consola de salida
--OPEN / FETCH / CLOSE → Manejo manual del cursor explícito: abrirlo, traer filas una por una y cerrarlo al final.
--EXCEPTION / WHEN OTHERS → Captura cualquier error que ocurra en el bloque y lo muestra con SQLERRM.


