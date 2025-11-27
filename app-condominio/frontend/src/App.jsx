import React, { useState } from "react";
import "./App.css";

export default function App() {
  const [accion, setAccion] = useState("pago");
  const [data, setData] = useState({});
  const [resultado, setResultado] = useState("");
  const [errores, setErrores] = useState([]);
  const [filas, setFilas] = useState([]);
  const api = import.meta.env.VITE_API_BASE || "http://localhost:4000";

  async function enviar(url, body) {
    const res = await fetch(`${api}${url}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    let data = {};
    try {
      data = await res.json();
    } catch {
      data = {};
    }

    if (!res.ok) {
      const msg = data.error || data.mensaje || `Error HTTP ${res.status}`;
      throw new Error(msg);
    }

    return data;
  }

  const ejecutar = async (e) => {
    e.preventDefault();
    setResultado("Procesando...");
    setFilas([]); // limpiar tabla anterior

    try {
      let r;
      if (accion === "pago") {
        r = await enviar("/api/pago", data);
        setResultado(r.mensaje || "Pago registrado correctamente.");
        setFilas(r.registros || []);
      } else {
        r = await enviar("/api/prorratea", data);
        setResultado(r.mensaje || "Prorrateo ejecutado correctamente.");
        setFilas(r.gastos || []);
      }
    } catch (err) {
      setResultado(`Error: ${err.message || "No se pudo ejecutar la acción."}`);
      setFilas([]);
    }
  };

  const verErrores = async () => {
    setResultado(""); // opcional, limpia el mensaje anterior
    try {
      const res = await fetch(`${api}/api/errores`);

      let data = [];
      try {
        data = await res.json();
      } catch {
        data = [];
      }

      if (!res.ok) {
        const msg = (data && data.error) || `Error HTTP ${res.status}`;
        throw new Error(msg);
      }

      setErrores(Array.isArray(data) ? data : []);
    } catch (err) {
      setResultado(`Error al consultar errores: ${err.message || ""}`);
    }
  };

  return (
    <div className="container">
      <h1>🏢 Administración de Condominio</h1>
      <form onSubmit={ejecutar}>
        <label>Acción:</label>
        <select value={accion} onChange={(e) => setAccion(e.target.value)}>
          <option value="pago">Registrar Pago</option>
          <option value="prorratea">Prorratear Gastos</option>
        </select>
        <br />
        <input placeholder="ID Edificio" onChange={e => setData({ ...data, id_edif: Number(e.target.value) })} />
        <input placeholder="N° Depto" onChange={e => setData({ ...data, nro_depto: Number(e.target.value) })} />
        <input placeholder="AñoMes (YYYYMM)" onChange={e => setData({ ...data, anno_mes: Number(e.target.value) })} />
        {accion === "pago" && (
          <>
            <input placeholder="Monto" onChange={e => setData({ ...data, monto: Number(e.target.value) })} />
            <input placeholder="ID Forma Pago" onChange={e => setData({ ...data, id_fpago: Number(e.target.value) })} />
          </>
        )}
        <br />
        <button type="submit">Ejecutar</button>
      </form>

      <p className="resultado">{resultado}</p>

      {filas.length > 0 && accion === "pago" && (
        <table style={{ margin: "1rem auto", borderCollapse: "collapse" }}>
          <thead>
            <tr>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>ID Log</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>AñoMes</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Edificio</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Depto</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Fecha Pago</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Monto</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>ID FPago</th>
            </tr>
          </thead>
          <tbody>
            {filas.map((f, i) => (
              <tr key={i}>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.ID_LOG}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.ANNO_MES_PCGC}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.ID_EDIF}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.NRO_DEPTO}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.FECHA_CANCELACION_PGC}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.MONTO_CANCELADO_PGC}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.ID_FPAGO}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {filas.length > 0 && accion === "prorratea" && (
        <table style={{ margin: "1rem auto", borderCollapse: "collapse" }}>
          <thead>
            <tr>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>AñoMes</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Edificio</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Depto</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Monto Total</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Fecha Pago</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Atrasado</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Multa</th>
            </tr>
          </thead>
          <tbody>
            {filas.map((f, i) => (
              <tr key={i}>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.ANNO_MES_PCGC}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.ID_EDIF}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.NRO_DEPTO}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.MONTO_TOTAL_GC}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.FECHA_PAGO_GC}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.MONTO_ATRASADO_GC}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{f.MULTA_GC}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <hr />

      <button onClick={verErrores}>Ver errores registrados</button>

      {errores.length === 0 ? (
        <p>No hay errores registrados.</p>
      ) : (
        <table style={{ margin: "1rem auto", borderCollapse: "collapse" }}>
          <thead>
            <tr>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>ID</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Mensaje</th>
              <th style={{ border: "1px solid #ccc", padding: "4px" }}>Fecha</th>
            </tr>
          </thead>
          <tbody>
            {errores.map((e) => (
              <tr key={e.error_id}>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{e.error_id}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{e.mensaje}</td>
                <td style={{ border: "1px solid #ccc", padding: "4px" }}>{e.fecha}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

    </div>
  );
}