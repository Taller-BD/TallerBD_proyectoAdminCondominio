import React, { useState } from "react";
import "./App.css";

export default function App() {
  const [accion, setAccion] = useState("pago");
  const [data, setData] = useState({});
  const [resultado, setResultado] = useState("");
  const [errores, setErrores] = useState([]);
  const api = import.meta.env.VITE_API_BASE;

  async function enviar(url, body) {
    const res = await fetch(`${api}${url}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    return res.json();
  }

  const ejecutar = async (e) => {
    e.preventDefault();
    try {
      let r;
      if (accion === "pago")
        r = await enviar("/api/pago", data);
      else
        r = await enviar("/api/prorratea", data);
      setResultado(r.mensaje || "Operación ejecutada.");
    } catch {
      setResultado("Error ejecutando la acción.");
    }
  };

  const verErrores = async () => {
    const r = await fetch(`${api}/api/errores`);
    const d = await r.json();
    setErrores(d);
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
        <input placeholder="ID Edificio" onChange={e => setData({...data, id_edif: Number(e.target.value)})}/>
        <input placeholder="N° Depto" onChange={e => setData({...data, nro_depto: Number(e.target.value)})}/>
        <input placeholder="AñoMes (YYYYMM)" onChange={e => setData({...data, anno_mes: Number(e.target.value)})}/>
        {accion === "pago" && (
          <>
            <input placeholder="Monto" onChange={e => setData({...data, monto: Number(e.target.value)})}/>
            <input placeholder="ID Forma Pago" onChange={e => setData({...data, id_fpago: Number(e.target.value)})}/>
          </>
        )}
        <br />
        <button type="submit">Ejecutar</button>
      </form>

      <p className="resultado">{resultado}</p>

      <hr />
      <button onClick={verErrores}>Ver errores registrados</button>
      <ul>
        {errores.map((e, i) => (
          <li key={i}>{e[0]} — {e[1]} ({e[2]})</li>
        ))}
      </ul>
    </div>
  );
}