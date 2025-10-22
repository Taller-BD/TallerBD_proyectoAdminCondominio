-- 0) Deshabilitar/borrar trigger 
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER tgr_registra_pago';
EXCEPTION WHEN OTHERS THEN NULL;
END;

-- 1) Borrar package
BEGIN
  EXECUTE IMMEDIATE 'DROP PACKAGE BODY pkg_admin_condominio';
EXCEPTION WHEN OTHERS THEN NULL;
END;

BEGIN
  EXECUTE IMMEDIATE 'DROP PACKAGE pkg_admin_condominio';
EXCEPTION WHEN OTHERS THEN NULL;
END;

-- 2) Borrar package de errores 
BEGIN
  EXECUTE IMMEDIATE 'DROP PACKAGE BODY pkg_registro_errores';
EXCEPTION WHEN OTHERS THEN NULL;
END;

BEGIN
  EXECUTE IMMEDIATE 'DROP PACKAGE pkg_registro_errores';
EXCEPTION WHEN OTHERS THEN NULL;
END;

-- 3) Borrar tablas creadas
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE registro_pagos';
EXCEPTION WHEN OTHERS THEN NULL;
END;

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ERRORES_DETECTADOS';
EXCEPTION WHEN OTHERS THEN NULL;
END;

-- 4) Borrar secuencia
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_errores_detectados';
EXCEPTION WHEN OTHERS THEN NULL;
END;

--
/* Bloque de pba */
DECLARE
    v_id_edif  NUMBER := 50;
    v_mes      NUMBER := 202503; -- Marzo 2025
BEGIN
    -- Nota: sp_truncar_errores eliminado (se manteniene solo sp_registrar_error)

    -- prorrateo global
    pkg_admin_condominio.sp_prorratea_gastos(v_id_edif, v_mes, NULL);

    -- prorrateo para un depto específico (ejemplo: 101)
    pkg_admin_condominio.sp_prorratea_gastos(v_id_edif, v_mes, 101);

    -- registrar un pago para ver el trigger funcionando
    pkg_admin_condominio.sp_registrar_pago(v_id_edif, 101, 125000, 'ARRENDATARIO');
END;