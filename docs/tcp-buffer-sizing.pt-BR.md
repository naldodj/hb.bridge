# Proposta de teste do tamanho do buffer TCP

[English](tcp-buffer-sizing.md)

`ReadChunkBytes` define o tamanho das operações de I/O do socket. O padrão é
65.536 bytes. A configuração fica em `[hbBridge]` no INI do AppServer e em
`[Protheus]` no INI do hbBridge. O servidor também aceita
`protheusReadChunkBytes` em JSON e `-readchunkbytes=` na linha de comando.
Cada ponta pode usar um valor diferente. `MaxWireBytes` e `MaxPayloadBytes`
continuam regendo o tamanho das mensagens.
[Enquadramento e configuração TCP](milestone2-framing.pt-BR.md).

A ideia de considerar a memória, usada na leitura de arquivos, é pertinente
sob carga concorrente. O tamanho do arquivo é conhecido na abertura.
No TCP, o primeiro buffer precisa ser alocado antes de conhecer o tamanho
da mensagem. Com 64 chamadas simultâneas, um buffer de recepção por chamada
representa 4 MiB com 64 KiB e 64 MiB com 1 MiB. A conta considera somente
os buffers. Mensagens comprimidas e expandidas, cópias temporárias e
alocações dos sockets e do runtime também contribuem para o pico de memória.

## 1. Verificar o reaproveitamento do buffer de 64 KiB

- Comparar a alocação dentro do laço com um buffer local por requisição.
  Começar pelo Harbour. `hb_socketRecv()` recebe o tamanho explicitamente e
  a implementação usada no projeto preserva o comprimento da string passada
  por referência. No AppServer, medir `Len(cChunk)` antes e depois de uma
  leitura curta com `TSocketClient:Receive()`, seguida por uma mais longa na
  mesma conexão. O reaproveitamento depende de preservar ou restabelecer a
  capacidade configurada. Consumir somente os bytes retornados pela API.
  [Recepção em Harbour](../src/hb/transports/protheus/hbbridge.framing.hb), [cliente TLPP](../src/tlpp/hbbridge.client.tlpp).
- Usar as amostras existentes de gzip fragmentado e Echo. Fragmentar o
  cabeçalho e o trailer do gzip, forçar uma leitura curta seguida de uma
  mais longa e exercitar envios parciais. Verificar a igualdade byte a byte,
  conteúdo UTF-8 e bytes zero no gzip. O fim do gzip encerra o pedido no
  Harbour. O servidor de teste deve fechar a conexão após enviar a resposta
  completa ao Protheus. Verificar o prazo total de I/O com um par lento.
  [Executor de regressão Harbour](../scripts/test-hbbridge.ps1), [teste de conexão no AppServer](../src/tlpp/tests/protheus/hbbridge.connection.test/hbbridge.connection.test.tlpp).
- Verificar um byte abaixo, no valor exato e um byte acima dos limites de
  tamanho no fio e após descompressão. Incluir gzip corrompido, desconexão
  prematura, timeout e uma chamada válida após falha. Manter e registrar o
  `MAXSTRINGSIZE` efetivo no AppServer. O TLPP descomprime a resposta inteira
  com `GzStrDecomp()`. A checagem do tamanho declarado pelo gzip é
  preliminar. Reduzir o buffer de recepção preserva o custo dessa alocação.
  [TOTVS `MaxStringSize`](https://tdn-homolog.totvs.com/pages/viewpage.action?pageId=161349793).

## 2. Medir os tamanhos fixos

| Dimensão | Comparação proposta |
| --- | --- |
| Tamanho do buffer | 32, 64, 128 e 256 KiB. Fixar a outra ponta em 64 KiB. Combinar tamanhos após medir cada ponta isoladamente. |
| Tráfego TCP | Echo determinístico com gzip abaixo, próximo e acima de 64 KiB, incluindo cerca de 1 MiB. Usar amostras compressíveis e de baixa compressibilidade dentro dos limites configurados. Registrar bytes no fio e após descompressão. |
| Concorrência | Começar com 1 e 8 chamadas simultâneas. Confirmar os candidatos com 32 e próximo da capacidade configurada do listener quando o AppServer de teste permitir. Manter a concorrência efetiva entre variantes. |
| Ambiente | Testar o Harbour em Windows e Linux. Registrar as versões do AppServer e do Harbour, as configurações, a topologia e o uso de WSL. Executar os testes de correção do cliente no build do AppServer em avaliação. |
| Confirmação com SQL | Usar o benchmark TCP existente com a mesma consulta, quantidade de linhas, tamanho de página e perfil para 64 KiB e o melhor candidato. Registrar essas medições à parte do Echo. |

Aquecer cada variante e alternar a referência e o candidato em pelo menos
três rodadas pareadas. Para comparar p95, registrar ao menos 100 chamadas
válidas por variante em cada rodada, contabilizar as falhas à parte e
repetir quando a variação da referência encobrir o resultado.

Medir latências p50 e p95, vazão, tempo de CPU por chamada bem-sucedida e
pico de memória por processo, separadamente para o Harbour e o AppServer.
Registrar a métrica de memória e o intervalo de amostragem de cada processo.
Contar envios, recepções e bytes efetivos por operação, incluindo operações
parciais. O ajuste também afeta o envio, por isso é preciso medir os dois.
[Benchmark existente](benchmarking.pt-BR.md).

## 3. Decidir se um modo `auto` se justifica

Exigir aprovação em todos os testes de correção. A meta inicial é obter
melhora repetida de pelo menos 10% em uma métrica escolhida antes do ensaio
(p95, CPU por chamada ou pico de memória). O ganho deve superar a variação
da referência. Sinalizar regressões sustentadas acima de 5% em p95 ou vazão
em qualquer carga de referência. Manter 64 KiB como padrão se a evidência
for inconclusiva e usar valores fixos por ponta onde houver ganho.

Prototipar `auto` somente se os testes com tamanhos fixos sob carga normal e
com um limite controlado de memória indicarem a necessidade de escolhas
diferentes. Tornar a opção explícita e resolver o valor na carga da
configuração. Preservar o significado dos valores numéricos. Comparar o
protótipo com o melhor valor fixo em cada ambiente e incluir testes sem
informação de memória disponível.

Calcular a escolha automática a partir de um orçamento verificado da
instalação e da demanda medida de I/O concorrente. Reservar espaço para
outras alocações e selecionar entre tamanhos validados dentro dos limites
do runtime. Memória física disponível, disponibilidade de commit e espaço
de endereçamento no Windows, e consumo e limites de cgroups no Linux
descrevem restrições diferentes. No Linux, cgroups ancestrais podem impor
limites adicionais. A documentação de `GetSrvInfo()[4]` indica informação de
memória e não garante a folga disponível para o AppServer.
[Status de memória no Windows](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/ns-sysinfoapi-memorystatusex), [controle de memória em cgroups v2](https://docs.kernel.org/admin-guide/cgroup-v2.html#memory), [TOTVS `GetSrvInfo`](https://tdn-homolog.totvs.com/display/tec/GetSrvInfo).

Usar o padrão quando o dado de memória estiver indisponível. Se o orçamento
conhecido for insuficiente até para o menor tamanho validado, informar essa
condição. Registrar o tamanho escolhido e o motivo nos diagnósticos locais.
HTTP e NETIO têm políticas de I/O próprias. A mesma metodologia pode ser
aplicada a outros tamanhos fixos quando houver um custo de alocação ou I/O
identificado.
