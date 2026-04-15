import { useMemo, useState } from "react";
import {
  useAccount,
  useConnect,
  useDisconnect,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { CONTRACT_ABI, CONTRACT_ADDRESS } from "./contract";
import "./App.css";

function App() {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { data: hash, error, isPending, writeContract } = useWriteContract();

  const [nome, setNome] = useState("");
  const [carteiraConsulta, setCarteiraConsulta] = useState("");
  const [carteiraRecompensa, setCarteiraRecompensa] = useState("");
  const [consultaRealizada, setConsultaRealizada] = useState(false);

  const { isLoading: confirmando } = useWaitForTransactionReceipt({ hash });

  const consulta = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: CONTRACT_ABI,
    functionName: "consultarUsuario",
    args: carteiraConsulta ? [carteiraConsulta] : undefined,
    query: {
      enabled: false,
    },
  });

  const resultadoConsulta = useMemo(() => {
    if (!consulta.data) return null;

    const [nomeConsulta, registrado, dataRegistro, saldo] = consulta.data;
    return {
      nome: nomeConsulta,
      registrado,
      dataRegistro: Number(dataRegistro),
      saldo: Number(saldo),
    };
  }, [consulta.data]);

  return (
    <main className="container">
      <h1>RegistroDeUsuariosComRecompensa</h1>
      <p className="subtitle">React + wagmi + Hardhat</p>

      <section className="card">
        <h2>1) Conectar carteira</h2>
        {isConnected ? (
          <>
            <p>Conectado: {address}</p>
            <button onClick={() => disconnect()}>Desconectar</button>
          </>
        ) : (
          connectors.map((connector) => (
            <button key={connector.uid} onClick={() => connect({ connector })}>
              Conectar com {connector.name}
            </button>
          ))
        )}
      </section>

      <section className="card">
        <h2>2) Registrar usuario</h2>
        <input
          placeholder="Nome do usuario"
          value={nome}
          onChange={(e) => setNome(e.target.value)}
        />
        <button
          disabled={!nome || !isConnected || isPending || confirmando}
          onClick={() =>
            writeContract({
              address: CONTRACT_ADDRESS,
              abi: CONTRACT_ABI,
              functionName: "registrarUsuario",
              args: [nome],
            })
          }
        >
          Registrar
        </button>
      </section>

      <section className="card">
        <h2>3) Consultar usuario</h2>
        <input
          placeholder="Endereco da carteira"
          value={carteiraConsulta}
          onChange={(e) => {
            setCarteiraConsulta(e.target.value);
            setConsultaRealizada(false);
          }}
        />
        <button
          disabled={carteiraConsulta.length !== 42 || consulta.isFetching}
          onClick={() => {
            setConsultaRealizada(true);
            consulta.refetch();
          }}
        >
          {consulta.isFetching ? "Consultando..." : "Consultar"}
        </button>
        {consultaRealizada && resultadoConsulta && (
          <p className="status">
            {resultadoConsulta.registrado ? "Usuario existe." : "Usuario nao existe."}
          </p>
        )}
        {resultadoConsulta && (
          <div className="result">
            <p>Nome: {resultadoConsulta.nome || "-"}</p>
            <p>Registrado: {resultadoConsulta.registrado ? "Sim" : "Nao"}</p>
            <p>Data do registro (timestamp): {resultadoConsulta.dataRegistro}</p>
            <p>Saldo token simulado: {resultadoConsulta.saldo}</p>
          </div>
        )}
      </section>

      <section className="card">
        <h2>4) Recompensar usuario</h2>
        <input
          placeholder="Endereco da carteira"
          value={carteiraRecompensa}
          onChange={(e) => setCarteiraRecompensa(e.target.value)}
        />
        <button
          disabled={!isConnected || carteiraRecompensa.length !== 42 || isPending || confirmando}
          onClick={() =>
            writeContract({
              address: CONTRACT_ADDRESS,
              abi: CONTRACT_ABI,
              functionName: "recompensarUsuario",
              args: [carteiraRecompensa],
            })
          }
        >
          Enviar recompensa
        </button>
      </section>

      {hash && (
        <p className="status">
          Tx hash: {hash}
          {confirmando ? " (confirmando...)" : " (confirmada)"}
        </p>
      )}

      {error && <p className="error">Erro: {error.shortMessage || error.message}</p>}
    </main>
  );
}

export default App;
