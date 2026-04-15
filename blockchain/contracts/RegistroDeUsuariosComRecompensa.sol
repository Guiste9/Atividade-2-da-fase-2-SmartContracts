// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 *
 *  GAS
 *    Toda instrução executada pela EVM (Ethereum Virtual Machine) tem
 *    um custo em "gas". Quem envia a transação define um gasLimit e
 *    paga gasUsed * gasPrice em ETH. Isso impede loops infinitos e
 *    spam na rede — a blockchain cobra pelo processamento.
 *
 *  EVM
 *    A Ethereum Virtual Machine é o ambiente de execução sandboxed
 *    que roda em TODOS os nós da rede simultaneamente. Cada nó executa
 *    o mesmo bytecode e chega ao mesmo estado final — isso garante
 *    consenso sem precisar confiar num servidor central.
 *
 *  SMART CONTRACT vs CONTRATO TRADICIONAL
 *    | Contrato tradicional          | Smart contract                  |
 *    |-------------------------------|---------------------------------|
 *    | Depende de cartório / tribunal| Auto-executável, sem árbitro    |
 *    | Pode ser alterado por partes  | Imutável após o deploy          |
 *    | Opaco / privado               | Código público e auditável      |
 *    | Lento para executar           | Executa em segundos on-chain    |
 */

contract RegistroDeUsuariosComRecompensa {
    struct Usuario {
        string  nome;          // Nome declarado pelo usuário
        bool    registrado;    // Flag de existência — evita busca nula
        uint256 dataRegistro;  // block.timestamp no momento do registro
    }

    // mapping(chave => valor): estrutura de hash-table da EVM.
    // Cada slot é inicializado com o valor-zero do tipo (false / 0 / "").
    mapping(address => Usuario)  public usuarios;
    mapping(address => uint256)  public saldosToken; // token simulado

    /// Endereço que implantou o contrato — único a recompensar.
    address public dono;

    /// Quantidade de tokens simulados por recompensa.
    uint256 public constant VALOR_RECOMPENSA_PADRAO = 100;
    
    event UsuarioRegistrado(
        address indexed carteira,
        string          nome,
        uint256         timestamp 
    );

    /**
     *  Emitido quando o dono envia uma recompensa.
     *  carteira Destinatário da recompensa.
     *  valor Quantidade de tokens creditados.
     */
    event RecompensaEnviada(address indexed carteira, uint256 valor);
    
    constructor() {
        dono = msg.sender;
    }
    modifier apenasDono() {
        require(msg.sender == dono, "Apenas o dono pode recompensar usuarios.");
        _;
    }

    function registrarUsuario(string memory nome) external {
        // Valida entrada — bytes(nome).length evita nome com só espaços vazios codificados
        require(bytes(nome).length > 0, "Nome nao pode ser vazio.");

        // Evita registro duplicado — lê o slot de storage uma única vez
        require(!usuarios[msg.sender].registrado, "Usuario ja registrado.");

        // Escreve a struct no storage — operação mais cara do contrato (~60 000 gas)
        usuarios[msg.sender] = Usuario({
            nome:         nome,
            registrado:   true,
            dataRegistro: block.timestamp  // segundos desde o Unix epoch, fornecido pelo bloco
        });

        // Emite evento — barato (~375 gas base + dados); indexado facilita filtragem off-chain
        emit UsuarioRegistrado(msg.sender, nome, block.timestamp);
    }

    function consultarUsuario(address carteira)
        external
        view
        returns (
            string  memory nome,
            bool           registrado,
            uint256        dataRegistro,
            uint256        saldo
        )
    {
        require(carteira != address(0), "Carteira invalida.");

        // Copia para memory uma única vez — mais eficiente que 3 SLOADs separados
        Usuario memory usuario = usuarios[carteira];

        return (
            usuario.nome,
            usuario.registrado,
            usuario.dataRegistro,
            saldosToken[carteira]
        );
    }
    function recompensarUsuario(address carteira) external apenasDono {
        require(carteira != address(0), "Carteira invalida.");
        require(usuarios[carteira].registrado, "Usuario nao registrado.");

        saldosToken[carteira] += VALOR_RECOMPENSA_PADRAO;

        emit RecompensaEnviada(carteira, VALOR_RECOMPENSA_PADRAO);
    }

    //  CASO DE USO REAL
    /*
     *  PLATAFORMA DE CURSOS ONLINE COM CERTIFICAÇÃO ON-CHAIN
     *  -------------------------------------------------------
     *  Cenário:
     *    Uma edtech implanta este contrato na rede Polygon (taxas baixas).
     *    Ao concluir um módulo, o backend da plataforma — autenticado
     *    como `dono` — chama `recompensarUsuario(alunoAddress)`.
     *    O saldo acumulado pode ser trocado por descontos, certificados
     *    NFT ou benefícios dentro do ecossistema.
     *
     *  Vantagens sobre um sistema de pontos tradicional (banco de dados):
     *    • Transparência: qualquer pessoa audita saldos e transações.
     *    • Portabilidade: o aluno leva os tokens para qualquer carteira.
     *    • Imutabilidade: histórico de conquistas não pode ser apagado.
     *    • Interoperabilidade: outros contratos (ex.: NFT de certificado)
     *      podem ler `saldosToken` diretamente, sem API intermediária.
     *
     *  Evolução natural:
     *    Substituir `saldosToken` por uma chamada real a um contrato
     *    ERC-20 (`IERC20.transfer`) e `dono` por um contrato multisig
     *    (ex.: Gnosis Safe) para distribuir o poder administrativo.
     */
}
