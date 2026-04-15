// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * ============================================================
 *  RegistroDeUsuariosComRecompensa
 *  Autor : você :)
 *  Rede  : EVM-compatível (Hardhat local / Sepolia / Polygon)
 * ============================================================
 *
 *  CONCEITOS-CHAVE
 *  ---------------
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

    // ----------------------------------------------------------------
    //  ESTRUTURA DE DADOS
    // ----------------------------------------------------------------

    /**
     * @notice Representa um usuário da plataforma.
     * @dev    Armazenada em storage (caro em gas); lida com `memory`
     *         dentro das funções para economizar custo de leitura.
     */
    struct Usuario {
        string  nome;          // Nome declarado pelo usuário
        bool    registrado;    // Flag de existência — evita busca nula
        uint256 dataRegistro;  // block.timestamp no momento do registro
    }

    // mapping(chave => valor): estrutura de hash-table da EVM.
    // Cada slot é inicializado com o valor-zero do tipo (false / 0 / "").
    // Custo de escrita: ~20 000 gas (SSTORE em slot frio).
    mapping(address => Usuario)  public usuarios;
    mapping(address => uint256)  public saldosToken; // token simulado (off-chain)

    // ----------------------------------------------------------------
    //  ESTADO ADMINISTRATIVO
    // ----------------------------------------------------------------

    /// @notice Endereço que implantou o contrato — único a recompensar.
    address public dono;

    /// @notice Quantidade de tokens simulados por recompensa.
    uint256 public constant VALOR_RECOMPENSA_PADRAO = 100;

    // ----------------------------------------------------------------
    //  EVENTOS
    // ----------------------------------------------------------------

    /**
     * @notice Emitido sempre que um novo usuário é registrado.
     * @param  carteira  Endereço que fez o registro.
     * @param  nome      Nome informado.
     * @param  timestamp Momento do registro (block.timestamp).
     */
    event UsuarioRegistrado(
        address indexed carteira,
        string          nome,
        uint256         timestamp   // ← adicionado: útil para o frontend filtrar eventos
    );

    /**
     * @notice Emitido quando o dono envia uma recompensa.
     * @param  carteira Destinatário da recompensa.
     * @param  valor    Quantidade de tokens creditados.
     */
    event RecompensaEnviada(address indexed carteira, uint256 valor);

    // ----------------------------------------------------------------
    //  CONSTRUTOR
    // ----------------------------------------------------------------

    /**
     * @dev `msg.sender` no construtor é quem fez o deploy.
     *      Esse endereço fica gravado em storage — custo único de SSTORE.
     */
    constructor() {
        dono = msg.sender;
    }

    // ----------------------------------------------------------------
    //  MODIFIER
    // ----------------------------------------------------------------

    /**
     * @dev Modifier reutilizável: reverte a transação se o chamador
     *      não for o dono. O `_;` marca onde o corpo da função entra.
     *      Gas da checagem: ~200 (SLOAD) + ~3 (comparação).
     */
    modifier apenasDono() {
        require(msg.sender == dono, "Apenas o dono pode recompensar usuarios.");
        _;
    }

    // ----------------------------------------------------------------
    //  FUNÇÕES PRINCIPAIS
    // ----------------------------------------------------------------

    /**
     * @notice Registra o chamador como usuário da plataforma.
     * @param  nome Nome público do usuário (não pode ser vazio).
     *
     * @dev `external` é mais barato que `public` para chamadas externas
     *      porque os argumentos não são copiados para memória interna.
     *      `require` consome todo o gas restante se falhar em versões
     *      antigas; a partir do Solidity 0.8 reverte sem consumir tudo.
     */
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

    /**
     * @notice Retorna os dados completos de um usuário.
     * @param  carteira Endereço a consultar.
     * @return nome         Nome registrado (string vazia se não existe).
     * @return registrado   true se o endereço está cadastrado.
     * @return dataRegistro Timestamp do registro (0 se não existe).
     * @return saldo        Saldo de tokens simulados.
     *
     * @dev `view` garante que a função NÃO altera estado — leitura gratuita
     *      quando chamada off-chain (ex.: wagmi useReadContract).
     *      `memory` na struct: copia do storage para memória temporária,
     *      evitando múltiplos SLOADs.
     */
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

    /**
     * @notice Credita VALOR_RECOMPENSA_PADRAO tokens ao usuário indicado.
     * @param  carteira Endereço do usuário a recompensar.
     *
     * @dev Protegido por `apenasDono`. O token é simulado (off-chain):
     *      não há transferência de ETH nem ERC-20 real — apenas um
     *      saldo interno no mapping, o que seria substituído por um
     *      contrato ERC-20 em produção.
     */
    function recompensarUsuario(address carteira) external apenasDono {
        require(carteira != address(0), "Carteira invalida.");
        require(usuarios[carteira].registrado, "Usuario nao registrado.");

        // += em uint256: sem risco de overflow no Solidity ^0.8 (reverte automaticamente)
        saldosToken[carteira] += VALOR_RECOMPENSA_PADRAO;

        emit RecompensaEnviada(carteira, VALOR_RECOMPENSA_PADRAO);
    }

    // ================================================================
    //  CASO DE USO REAL
    // ================================================================
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
