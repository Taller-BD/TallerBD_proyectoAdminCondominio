
SET SERVEROUTPUT ON; --habilita la salida de mensajes en consola, aunque me lee igual sin esto

DECLARE -- inicio del bloque para declarar variables, tipos, cursores y estructuras
    
    -- 0. Defino variables constantes para no repetir el año mes y el id del edificio
    v_id_edif       GASTO_COMUN.id_edif%TYPE := 50; 
    v_anno_mes      GASTO_COMUN.anno_mes_pcgc%TYPE := 202503; -- marzo de 2025
    -------------------------

    -- 1. se define un RECORD que es como una fila temporal para almacenar un registro de la tabla GASTO_COMUN
    TYPE gasto_rec IS RECORD (
        -- es la variable que usaremos para guardar datos de una fila a la vez cuando usamos el cursor explícito
        -- %TYPE hace que cada campo tome el tipo de dato de la tabla
        id_edif       GASTO_COMUN.id_edif%TYPE,
        nro_depto     GASTO_COMUN.nro_depto%TYPE,
        monto_total   GASTO_COMUN.monto_total_gc%TYPE
    );
    v_gasto gasto_rec; 

    
    -- 2. VARRAY para guardar hasta 100 montos de gastos comunes de cada departamento
    TYPE varray_montos IS VARRAY(100) OF NUMBER(10);
    v_montos varray_montos := varray_montos(); -- inicializa el arreglo vacío.

    TYPE varray_deptos IS VARRAY(100) OF GASTO_COMUN.nro_depto%TYPE; -- arreglo para guardar los números de departamento
    v_deptos varray_deptos := varray_deptos(); 

    TYPE varray_prorrateo IS VARRAY(100) OF NUMBER(12,2); -- arreglo para guardar los montos prorrateados
    -- en el tipo de dato number(12,2), el 12 es la cantidad de números que puede almacenar y el 2 los decimales
    v_prorrateo varray_prorrateo := varray_prorrateo();


    -- 3. Cursor simple selecciona todos los departamentos y su monto total del edificio
    -- con id 50 en marzo 2025
    CURSOR c_gastos IS
        SELECT id_edif, nro_depto, monto_total_gc
        FROM GASTO_COMUN
        WHERE anno_mes_pcgc = v_anno_mes
          AND id_edif = v_id_edif;

    
    -- 4. Cursor explícito (otra forma de recorrer): OPEN, FETCH y CLOSE
    CURSOR c_gastos_expl IS
        SELECT id_edif, nro_depto, monto_total_gc
        FROM GASTO_COMUN
        WHERE anno_mes_pcgc = v_anno_mes
          AND id_edif = v_id_edif;


    -- 5. Variables escalares
    v_total        NUMBER := 0;  -- suma montos de todos los departamentos (para el edificio)
    v_index        NUMBER := 0;  -- lleva la posición dentro del varray
    v_suma_pror    NUMBER := 0;  -- suma de los prorrateos
    v_porcentaje   NUMBER := 0;  -- porcentaje de prorrateo


BEGIN
    
    -- a) Usamos cursor simple con FOR (loop implícito)
    DBMS_OUTPUT.PUT_LINE('--- Cursor simple ---');
    FOR reg IN c_gastos LOOP -- recorre cada fila del cursor c_gastos
        
        -- Imprime en consola el departamento y su monto.
        DBMS_OUTPUT.PUT_LINE('Depto: ' || reg.nro_depto || ' - Monto: ' || reg.monto_total_gc);
        -- no se necesita hacer OPEN ni FETCH; el FOR lo hace automáticamente
        
        -- Guardamos en VARRAY
        v_index := v_index + 1; -- se aumenta el índice para guardar el monto en el varray

        -- antes de EXTEND, reviso que el varray no haya llegado a su tamaño máximo
        IF v_deptos.COUNT = v_deptos.LIMIT THEN
            RAISE_APPLICATION_ERROR(-20003, 'Se alcanzó el límite de 100 departamentos en el varray.');
        END IF;

        v_deptos.EXTEND; 
        v_deptos(v_index) := reg.nro_depto; -- asigna el número de departamento actual a la posición v_index

        IF v_montos.COUNT = v_montos.LIMIT THEN
            RAISE_APPLICATION_ERROR(-20004, 'Se alcanzó el límite de 100 montos en el varray.');
        END IF;
        
        v_montos.EXTEND; -- agrega un espacio vacío al final del varray
        v_montos(v_index) := reg.monto_total_gc; -- guarda el monto en la misma posición

    END LOOP; -- cierra loop

    
    -- b) Usamos cursor explícito
    DBMS_OUTPUT.PUT_LINE('--- Cursor explícito ---'); -- print
    OPEN c_gastos_expl; -- abrimos el cursor con OPEN
    LOOP
        FETCH c_gastos_expl INTO v_gasto;
        EXIT WHEN c_gastos_expl%NOTFOUND; -- sale del loop si no hay más filas

        -- Manejo de excepción: monto nulo (validación con RAISE_APPLICATION_ERROR)
        IF v_gasto.monto_total IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Monto nulo en depto ' || v_gasto.nro_depto);
        END IF;

        -- Acumular total
        v_total := v_total + v_gasto.monto_total; -- suma el monto de cada departamento al v_total

    END LOOP;
    CLOSE c_gastos_expl; -- cierra cursor explícito

    -- Mostrar total
    DBMS_OUTPUT.PUT_LINE('Total edificios = ' || v_total); -- print

    -- c) Calcular prorrateo, según % de depto
    DBMS_OUTPUT.PUT_LINE('--- Prorrateo según porcentaje DEPARTAMENTO ---');
    IF v_index = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No hay departamentos para prorratear.');
    ELSE
        FOR registro IN 1..v_index LOOP

            -- Bloque BEGIN...EXCEPTION solo para el SELECT INTO (capturar NO_DATA_FOUND / TOO_MANY_ROWS)
            BEGIN
                -- Ahora obtendremos el porcentaje de prorrateo del depto(registro) desde DEPARTAMENTO
                SELECT PORC_PRORRATEO_DEPTO
                INTO v_porcentaje
                FROM DEPARTAMENTO
                WHERE id_edif = v_id_edif
                  AND nro_depto = v_deptos(registro);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN 
                    v_porcentaje := 0; -- si no encuentra el depto, pone el porcentaje en cero
                    DBMS_OUTPUT.PUT_LINE('ADVERTENCIA: Dpto '|| v_deptos(registro) ||
                                         ' no tiene porcentaje de prorrateo en DEPARTAMENTO. Se usará 0%.' ); -- imprime advertencia
                WHEN TOO_MANY_ROWS THEN -- si hay más de un registro con el mismo depto, lanza error
                    RAISE_APPLICATION_ERROR(-20002, 'Duplicado de porcentaje de prorrateo para depto '
                                                || v_deptos(registro) || ' en DEPARTAMENTO. Revise los datos.');
            END;

            -- Verifica límite del varray de prorrateos
            IF v_prorrateo.COUNT = v_prorrateo.LIMIT THEN
                RAISE_APPLICATION_ERROR(-20005, 'Se alcanzó el límite de 100 prorrateos en el varray.');
            END IF;

            -- Calcular: total * (porcentaje / 100)
            v_prorrateo.EXTEND; 
            v_prorrateo(registro) := ROUND(v_total * (NVL(v_porcentaje,0)/100),2); -- redondeado a 2 decimales

            -- Acumular suma prorrateo
            v_suma_pror := v_suma_pror + v_prorrateo(registro);

            -- Mostrar comparación entre depto, porcentaje, prorrateo y original en pantalla
            DBMS_OUTPUT.PUT_LINE('Departamento: ' || v_deptos(registro) ||
                                ' Porcentaje: ' || NVL(v_porcentaje,0) ||
                                ' Prorrateo: ' || v_prorrateo(registro) ||
                                ' Original: ' || v_montos(registro)
                                );
        END LOOP;

    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM); -- si ocurre cualquier excepción no controlada, imprime el mensaje
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




