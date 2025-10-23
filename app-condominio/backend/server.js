import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import oracledb from "oracledb";

console.log("🚀 Iniciando backend...");

process.on("unhandledRejection", err => {
  console.error("🔥 Unhandled rejection:", err);
});
process.on("uncaughtException", err => {
  console.error("💀 Uncaught exception:", err);
});

dotenv.config();

oracledb.initOracleClient({
  libDir: process.env.ORACLE_CLIENT_LIB_DIR,
  configDir: process.env.ORACLE_TNS_ADMIN
});

const app = express();
app.use(cors());
app.use(express.json());
const PORT = process.env.PORT || 4000;

let pool;
async function initPool() {
  console.log("🧠 Entrando a initPool...");
  if (pool) {
    console.log("🧠 Pool ya existente, devolviendo...");
    return pool;
  }
  try {
    console.log("🔧 Creando nuevo pool...");
    pool = await oracledb.createPool({
      user: process.env.ORACLE_USER,
      password: process.env.ORACLE_PASSWORD,
      connectionString: process.env.ORACLE_CONNECT_STRING,
      poolMin: 1,
      poolMax: 5,
      poolIncrement: 1
    });
    console.log("✅ Pool creado correctamente");
  } catch (err) {
    console.error("❌ Error creando pool:", err);
  }
  return pool;
}

// ---- ENDPOINTS ----

// Prorratea gastos
app.post("/api/prorratea", async (req, res) => {
  const { id_edif, anno_mes, nro_depto } = req.body;
  let conn;
  try {
    await initPool();
    conn = await pool.getConnection();
    await conn.execute(
      `BEGIN pkg_admin_condominio.sp_prorratea_gastos(:id_edif, :anno_mes, :nro_depto); END;`,
      { id_edif, anno_mes, nro_depto }
    );
    res.json({ ok: true, mensaje: "✅ Prorrateo ejecutado correctamente." });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  } finally {
    if (conn) await conn.close();
  }
});

// Registrar pago
app.post("/api/pago", async (req, res) => {
  const { id_edif, nro_depto, monto, anno_mes, id_fpago } = req.body;
  let conn;
  try {
    await initPool();
    conn = await pool.getConnection();
    await conn.execute(
      `BEGIN pkg_admin_condominio.sp_registrar_pago(:id_edif, :nro_depto, :monto, :anno_mes, :id_fpago); END;`,
      { id_edif, nro_depto, monto, anno_mes, id_fpago }
    );
    res.json({ ok: true, mensaje: "💰 Pago registrado correctamente." });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  } finally {
    if (conn) await conn.close();
  }
});

// Consultar errores
app.get("/api/errores", async (req, res) => {
  let conn;
  try {
    await initPool();
    conn = await pool.getConnection();
    const result = await conn.execute(
      `SELECT error_id, mensaje, TO_CHAR(fecha_reg, 'YYYY-MM-DD HH24:MI:SS') fecha
       FROM errores_detectados
       ORDER BY error_id DESC`
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    if (conn) await conn.close();
  }
});

app.listen(PORT, async () => {
  await initPool();
  console.log(`✅ Servidor backend en http://localhost:${PORT}`);
});