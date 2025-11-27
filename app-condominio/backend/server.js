import express from "express";
import cors from "cors";
import oracledb from "oracledb";
import dotenv from "dotenv";

dotenv.config();

// Aquí usar wallet de oracle
oracledb.initOracleClient({
  libDir: process.env.ORACLE_CLIENT_LIB_DIR,
  configDir: process.env.ORACLE_TNS_ADMIN
});

const app = express();
app.use(cors());
app.use(express.json());

//const PORT = process.env.PORT || 4000;

let pool;
async function initPool() {
  if (pool) return pool;
  pool = await oracledb.createPool({
    user: process.env.ORACLE_USER,
    password: process.env.ORACLE_PASSWORD,
    connectionString: process.env.ORACLE_CONNECT_STRING,
    poolMin: 1,
    poolMax: 5,
    poolIncrement: 1,
    queueTimeout: 0
  });
  return pool;
}

// Registrar pagos
app.post("/api/pago", async (req, res) => {
  console.log("📩 /api/pago body:", req.body);
  const { id_edif, nro_depto, anno_mes, monto, id_fpago } = req.body;

  let conn;
  try {
    await initPool();
    conn = await pool.getConnection();

    // 1) Ejecuta el package
    await conn.execute(
      `BEGIN 
          pkg_admin_condominio.sp_registrar_pago(
              :id_edif, :nro_depto, :monto, :anno_mes, :id_fpago
          ); 
       END;`,
      { id_edif, nro_depto, monto, anno_mes, id_fpago },
      { autoCommit: true }
    );

    // 2) Consulta REGISTRO_PAGOS
    const result = await conn.execute(
      `
      SELECT 
        id_log                AS ID_LOG,
        anno_mes_pcgc         AS ANNO_MES_PCGC,
        id_edif               AS ID_EDIF,
        nro_depto             AS NRO_DEPTO,
        TO_CHAR(fecha_cancelacion_pgc,'YYYY-MM-DD HH24:MI:SS') AS FECHA_CANCELACION_PGC,
        monto_cancelado_pgc   AS MONTO_CANCELADO_PGC,
        id_fpago              AS ID_FPAGO
      FROM registro_pagos
      WHERE id_edif = :id_edif
        AND nro_depto = :nro_depto
        AND anno_mes_pcgc = :anno_mes
      ORDER BY id_log DESC
      `,
      { id_edif, nro_depto, anno_mes },
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    res.json({
      mensaje: "Pago registrado correctamente.",
      registros: result.rows || []
    });
  } catch (err) {
    res.json({
      mensaje: "Error registrando pago: " + err.message,
      registros: []
    });
  } finally {
    if (conn) try { await conn.close(); } catch {}
  }
});

//prorratear gastos
app.post("/api/prorratea", async (req, res) => {
  console.log("📩 /api/prorratea body:", req.body);
  const { id_edif, nro_depto, anno_mes } = req.body;

  let conn;
  try {
    await initPool();
    conn = await pool.getConnection();

    // 1) Ejecuta el package de prorrateo
    await conn.execute(
      `BEGIN 
          pkg_admin_condominio.sp_prorratea_gastos(
              :id_edif, :anno_mes, :nro_depto
          ); 
       END;`,
      { id_edif, anno_mes, nro_depto },
      { autoCommit: true }
    );

    // 2) Consulta el GASTO_COMUN para ese depto/mes
    const result = await conn.execute(
      `
      SELECT
        anno_mes_pcgc           AS ANNO_MES_PCGC,
        id_edif                 AS ID_EDIF,
        nro_depto               AS NRO_DEPTO,
        prorrateado_gc          AS PRORRATEADO_GC,
        fondo_reserva_gc        AS FONDO_RESERVA_GC,
        agua_individual_gc      AS AGUA_INDIVIDUAL_GC,
        combustible_individual_gc AS COMBUSTIBLE_INDIVIDUAL_GC,
        lavanderia_gc           AS LAVANDERIA_GC,
        evento_gc               AS EVENTO_GC,
        servicio_gc             AS SERVICIO_GC,
        monto_atrasado_gc       AS MONTO_ATRASADO_GC,
        multa_gc                AS MULTA_GC,
        monto_total_gc          AS MONTO_TOTAL_GC,
        TO_CHAR(fecha_pago_gc,'YYYY-MM-DD') AS FECHA_PAGO_GC
      FROM gasto_comun
      WHERE id_edif = :id_edif
        AND nro_depto = :nro_depto
        AND anno_mes_pcgc = :anno_mes
      ORDER BY anno_mes_pcgc DESC
      `,
      { id_edif, nro_depto, anno_mes },
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    res.json({
      mensaje: "Prorrateo ejecutado correctamente.",
      gastos: result.rows || []
    });
  } catch (err) {
    res.json({
      mensaje: "Error prorrateando: " + err.message,
      gastos: []
    });
  } finally {
    if (conn) try { await conn.close(); } catch {}
  }
});

//ver errores registrados
app.get("/api/errores", async (req, res) => {
  let conn;
  try {
    await initPool();
    conn = await pool.getConnection();

    const r = await conn.execute(
      `SELECT 
         error_id   AS "error_id",
         mensaje    AS "mensaje",
         TO_CHAR(fecha_reg,'YYYY-MM-DD HH24:MI:SS') AS "fecha"
       FROM errores_detectados
       ORDER BY error_id DESC`,
      [],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    res.json(r.rows);
  } catch (err) {
    res.json([]);
  } finally {
    if (conn) try { await conn.close(); } catch {}
  }
});

//servidor
const PORT = process.env.PORT || 4000;

app.listen(PORT, async () => {
  try {
    await initPool();
    console.log("Backend iniciado en puerto " + PORT);
  } catch (e) {
    console.error("Error creando pool:", e);
  }
});