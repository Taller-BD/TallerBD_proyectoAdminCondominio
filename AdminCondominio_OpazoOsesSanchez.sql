-- Secuencia para errores
CREATE SEQUENCE seq_errores_detectados START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Tabla para registrar errores y mensajes informativos
CREATE TABLE errores_detectados (
    error_id    NUMBER PRIMARY KEY,
    mensaje     VARCHAR2(4000),    -- descripción del error o mensaje
    contexto    VARCHAR2(4000)     -- contexto adicional
);

-- Package para manejo de errores
CREATE OR REPLACE PACKAGE pkg_registro_errores AS
    PROCEDURE sp_registrar_error(
        p_mensaje   VARCHAR2,
        p_contexto  VARCHAR2 := NULL
    );
END pkg_registro_errores;

-- Package body para manejo de errores
CREATE OR REPLACE PACKAGE BODY pkg_registro_errores IS
    PROCEDURE sp_registrar_error(
        p_mensaje   VARCHAR2,
        p_contexto  VARCHAR2
    )
    IS
    BEGIN
        INSERT INTO errores_detectados (
            error_id,
            mensaje,
            contexto
        ) VALUES (
            seq_errores_detectados.NEXTVAL,
            SUBSTR(NVL(p_mensaje,''),1,4000),
            SUBSTR(NVL(p_contexto,''),1,4000)
        );
    EXCEPTION
        WHEN OTHERS THEN
            -- Manejo de error en el procedimiento de registro (no romper la tx principal)
            NULL; -- evitar bucle infinito de errores
    END sp_registrar_error;
END pkg_registro_errores;



--
DECLARE 
    
    -- 0. Defino variables constantes para no repetir el año mes y el id del edificio
    v_id_edif       GASTO_COMUN.id_edif%TYPE := 50; 
    v_anno_mes      GASTO_COMUN.anno_mes_pcgc%TYPE := 202503; -- marzo de 2025
    -------------------------

    -- 0,5. Defino variable para filtrar por dptos. Null muestra todos por defecto
    v_nro_depto     GASTO_COMUN.NRO_DEPTO%TYPE := NULL;

    -- 1. se define un RECORD que es como una fila temporal para almacenar un registro de la tabla GASTO_COMUN
    TYPE gasto_rec IS RECORD (
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


TYPE varray_prorrateo IS VARRAY(100) OF NUMBER(12,2);
v_prorrateo varray_prorrateo := varray_prorrateo();

    -- 3. Cursor simple selecciona todos los departamentos y su monto total del edificio con id 50 en marzo 2025
    CURSOR c_gastos IS
        SELECT id_edif, nro_depto, monto_total_gc
        FROM GASTO_COMUN
        WHERE anno_mes_pcgc = v_anno_mes
          AND id_edif = v_id_edif;

    
        -- 4. Cursor explícito con parámetro (permite filtrar por nro_depto); p_nro_depto puede ser NULL para seleccionar todos los departamentos
        CURSOR c_gastos_expl(p_nro_depto NUMBER) IS
                SELECT id_edif, nro_depto, monto_total_gc
                FROM GASTO_COMUN
                WHERE anno_mes_pcgc = v_anno_mes
                    AND id_edif = v_id_edif
                    AND (p_nro_depto IS NULL OR nro_depto = p_nro_depto);
                    

    -- 5. Variables escalares
    v_total        NUMBER := 0;  -- suma montos de todos los departamentos (para el edificio)
    v_index        NUMBER := 0;  -- lleva la posición dentro del varray
    v_suma_pror    NUMBER := 0;  -- suma de los prorrateos
    v_porcentaje   NUMBER := 0;  -- porcentaje de prorrateo
    v_prorrateo    NUMBER := 0;  -- monto prorrateado para cada departamento


BEGIN
    
    -- a) Usamos cursor simple con FOR (loop implícito)

    FOR reg IN c_gastos LOOP -- recorre cada fila del cursor c_gastos
        
    -- Registrar en tabla de errores/log (mensaje informativo)
    pkg_registro_errores.sp_registrar_error('Depto: ' || reg.nro_depto || ' - Monto: ' || reg.monto_total_gc, 'id_edif='||v_id_edif);
        
        -- Guardamos en VARRAY
        v_index := v_index + 1; -- se aumenta el índice para guardar el monto en el varray

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

    END LOOP; 

    
    -- b) Usamos cursor explícito (ahora parametrizado)

    -- Devuelve las filas de todos los departamentos
    OPEN c_gastos_expl(v_nro_depto);
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

    -- Registrar total
    pkg_registro_errores.sp_registrar_error('Total edificios = ' || v_total, 'id_edif='||v_id_edif); -- registrado en errores_detectados

    -- c) Calcular prorrateo, según % de depto
    pkg_registro_errores.sp_registrar_error('--- Prorrateo según porcentaje DEPARTAMENTO ---', 'id_edif='||v_id_edif);
    IF v_index = 0 THEN
        pkg_registro_errores.sp_registrar_error('No hay departamentos para prorratear.', 'id_edif='||v_id_edif);
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
                    pkg_registro_errores.sp_registrar_error('Depto no encontrado', 'id_edif='||v_id_edif||',nro_depto='||v_deptos(registro));
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

            -- Registrar comparación entre depto, porcentaje, prorrateo y original
            pkg_registro_errores.sp_registrar_error('Departamento: ' || v_deptos(registro) ||
                                ' Porcentaje: ' || NVL(v_porcentaje,0) ||
                                ' Prorrateo: ' || v_prorrateo(registro) ||
                                ' Original: ' || v_montos(registro), 'id_edif='||v_id_edif||',nro_depto='||v_deptos(registro));
        END LOOP;

    END IF;

EXCEPTION
    WHEN OTHERS THEN
        pkg_registro_errores.sp_registrar_error('Error: ' || SQLERRM, 'bloque principal'); -- registrar y relanzar
        RAISE;
END;
/