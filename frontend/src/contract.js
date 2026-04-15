export const CONTRACT_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";

export const CONTRACT_ABI = [
  {
    inputs: [{ internalType: "string", name: "nome", type: "string" }],
    name: "registrarUsuario",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "carteira", type: "address" }],
    name: "consultarUsuario",
    outputs: [
      { internalType: "string", name: "nome", type: "string" },
      { internalType: "bool", name: "registrado", type: "bool" },
      { internalType: "uint256", name: "dataRegistro", type: "uint256" },
      { internalType: "uint256", name: "saldo", type: "uint256" },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "carteira", type: "address" }],
    name: "recompensarUsuario",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "VALOR_RECOMPENSA_PADRAO",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
];
