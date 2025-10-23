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

--------------------------------------
--------------------------------------

-- 0) Deshabilitar/borrar trigger 
DROP TRIGGER tgr_registra_pago;

-- 1) Borrar package
DROP PACKAGE BODY pkg_admin_condominio;
DROP PACKAGE pkg_admin_condominio;

-- 2) Borrar package de errores 
DROP PACKAGE BODY pkg_registro_errores;
DROP PACKAGE pkg_registro_errores;

-- 3) Borrar tablas creadas
DROP TABLE registro_pagos;
DROP TABLE errores_detectados;

-- 4) Borrar secuencia
DROP SEQUENCE seq_errores_detectados;