# Depuração: hbdebug primeiro, HBDAP como evolução

[English](debugging.md) · [Documentação](README.pt-BR.md) · [Roadmap](../TODO.pt-BR.md#depuração--frente-transversal-do-produto)

O `hbdebug` nativo está disponível no Harbour. O perfil de depuração do
produto/addons e sua homologação continuam pendentes: ter o depurador no
toolchain não comprova uma sessão funcional de depuração do hbBridge.

## Depuração nativa Harbour

O perfil inicial de desenvolvimento em console utilizará o
[hbdebug](https://github.com/harbour/core/tree/master/src/debug) para
breakpoints, execução passo a passo e inspeção de pilha e variáveis, usando
a mesma implementação do produto utilizada na execução comum.

Compilar os fontes Harbour com `-b`, vincular o depurador e manter acessíveis
os fontes correspondentes. Isso inclui os `.prg`/`.hb` compilados em memória
pelo loader e os `.hrb` preparados fora do servidor. A composição atual de
[build](../hbbridge.hbm) e a chamada a `hb_compileBuf` no
[loader](../src/hb/addons/hbbridge.addon.hb) não habilitam `-b`.
No `hbmk2`, `-debug` controla informações para o depurador nativo C; a opção
Harbour `-b` tem outra função. Veja o
[hbmk2](https://github.com/harbour/core/blob/master/utils/hbmk2/hbmk2.prg).

A homologação inicial deverá exercitar uma chamada e um worker controlados:
pausar em um handler e em um addon, inspecionar o estado e retomar até a
resposta. Definir terminal/GT, efeitos nos timeouts RPC e limpeza de recursos.
Ativar explicitamente o perfil de desenvolvimento; a operação como serviço
não deverá depender de depuração interativa.

## Integração futura com HBDAP

**HBDAP** é um projeto privado experimental, referenciado localmente em
`F:\GitHub\hbdap`, que adapta a depuração Harbour ao Debug Adapter Protocol
(DAP). O caminho local é uma referência de desenvolvimento, não uma
dependência fixa da instalação. O hbdebug nativo permanece como caminho
inicial; o DAP poderá atender posteriormente clientes IDE e CLI.

A extensão opcional **Harbour DAP** do VS Code é desenvolvida separadamente em
`hbdap-vscode-extension`, localmente `F:\GitHub\hbdap-vscode-extension`. Ela
registra o tipo de depuração `harbour-dap` no `launch.json` e conecta o editor
ao runtime habilitado para DAP, diretamente ou por adaptador, conforme o modo
escolhido. O fluxo pretendido é **VS Code → extensão Harbour DAP → HBDAP →
hbdebug no hbBridge**. Outros clientes DAP também poderão utilizar HBDAP.

O VSIX contém a integração com o editor. O runtime Harbour, a biblioteca
HBDAP e os adaptadores exigidos por cada modo são preparados separadamente.
Fixar hooks/patches do runtime, revisões e toolchain compatíveis; configurar
executável e fontes; depois homologar launch/attach com handler e addon reais.
Essa integração do hbBridge permanece futura, mesmo com testes próprios nos
projetos HBDAP e da extensão.

A referência experimental HBDAP utiliza hooks/patches no runtime e
recompilação. Depuração multithread e ciclo de carga/descarga HRB exigem
homologação específica no hbBridge. Suporte DAP básico não comprova controle
dos workers.

## Canais e fronteiras entre runtimes

Manter o tráfego de depuração separado do RPC Protheus/NETIO e da
administração, com ativação explícita e acesso local/controlado. Logs e saída
do servidor não poderão corromper o framing DAP. Um adaptador externo de
desenvolvimento permanece opcional e preserva o executável único do produto.

Homologar breakpoints, stepping, pilha, variáveis e desconexão pelos
[critérios do roadmap](../TODO.pt-BR.md#depuração--frente-transversal-do-produto).
Este trabalho inspeciona a execução Harbour no hbBridge. AdvPL/TLPP utiliza
a depuração do AppServer; C/Zig exige símbolos nativos e depurador compatível
com o toolchain. A correlação de chamadas permite acompanhar essas fronteiras
sem pressupor uma sessão única de stepping entre runtimes.
