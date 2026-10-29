# Convenções do hbBridge

[English](AGENTS.md) · [Padrões detalhados](docs/standards.pt-BR.md)

- No trabalho de pacote, leia [WIP.pt-BR.md](WIP.pt-BR.md) e retome a próxima
  tarefa pendente. Atualize progresso/evidências nas duas versões. Reabra
  decisões somente por novas evidências, falhas reproduzíveis, mudanças de
  requisito/dependência ou instruções do usuário. Renove WIP com os critérios
  atendidos; commits/publicações intermediários não o reiniciam. TODO mantém o roadmap.
- Use quatro espaços por nível de indentação nos fontes próprios. Preserve a
  formatação, os avisos de copyright e as licenças dos arquivos de terceiros.
- Trate `tmp/` como área inteiramente descartável. Comandos não podem exigir
  rodadas anteriores em tmp. Versione helpers/fixtures em `scripts/`/`tests/`
  e resumos sanitizados em `docs/validation/`. Caminhos históricos de logs tmp
  são proveniência, nunca exigência de retenção. `out/` é gerado; dependências
  de compilação gerenciadas pertencem a `.deps/`.
- Compile TLPP a partir do caminho do fonte mantido sempre que possível. Se
  testes ou validações precisarem copiar/gerar arquivos `.tlpp` em `tmp/`,
  remova-os imediatamente após o uso, inclusive nas falhas, com `try`/`finally`
  ou limpeza equivalente. Duplicatas retidas confundem a resolução de fontes
  da extensão TOTVS. Preserve logs, listas de fontes e hashes como evidência,
  em vez das cópias; nunca exclua os originais mantidos nessa limpeza.
- Use `#include "totvs.ch"` como include TLPP padrão. Acrescente `tlpp-core.th`,
  `tlpp-rest.th` ou outros headers somente por declarações/macros efetivamente
  utilizados, não apenas por o fonte ter extensão `.tlpp`.
- Prefira `tlpp.ToStr(nValue)` na conversão numérica comum para texto em TLPP.
  Use formatação explícita quando largura/escala fizer parte do contrato.
  Mantenha a negação dentro da expressão do alias: `(cAlias)->(!Eof())`.
- JSON numérico usa o codec compartilhado que preserva a precisão, independente
  de `SET DECIMALS`/`SET FIXED`. Não altere SETs globais para corrigir serialização
  nem inferir arredondamento de negócio. Restaure SETs temporários do addon em toda saída.
- Agrupe declarações de variáveis por tipo de dado e ordene os grupos
  alfabeticamente pelo prefixo do tipo, por exemplo `a`, `c`, `d`, `j`, `l`,
  `n`, `o`, `x`. Os nomes completos dentro do grupo não precisam de ordem
  alfabética. Preserve dependências de inicialização; atribua valores após
  as declarações quando necessário.
- Resolva constantes e expressões invariantes antes dos loops, incluindo
  conversões de caracteres e tamanho de strings/contêineres que não mudam.
  Valores variáveis, relógios, E/S e verificações de estado mutável ficam no loop.
- Use identificadores em inglês. Arquivos em minúsculas. Funções, procedures,
  métodos, namespaces e classes usam PascalCase. Os fontes usam palavras
  minúsculas separadas por pontos: `HBBridgeClient` fica em `hbbridge.client.tlpp`. Remover os pontos
  deve produzir o nome da classe em minúsculas; pontos não representam namespaces.
- Escreva comentários de fontes, mensagens de erro, logs e rótulos de interface
  próprios em inglês. Traduza comentários em português encontrados ao editar
  ou revisar fontes, preservando seu sentido técnico e nomes de APIs externas.
  Preserve textos externos e dados intencionais de testes de idioma/codificação.
  A documentação portuguesa continua nos arquivos pareados `.pt-BR`.
- Redija documentação de forma impessoal, com foco em decisões, resultados
  e evidências. Prefira "Validação confirmada" ou "Validação registrada".
  Distinga execução manual no AppServer de verificações automatizadas locais
  pelo método e pelos artefatos, preservando datas, escopo e situação.
- Use a mesma convenção de módulos em Harbour, TLPP, C e Zig; a extensão
  identifica a linguagem. Os módulos do produto começam com `hbbridge`.
- Use `.hb` nos fontes Harbour próprios, testes e addons. Preserve arquivos
  `.prg` upstream e o suporte a entradas `.prg` externas/do runtime.
  Entradas `.hbp`/`.hbm` compilam `.hb` como fonte; um caminho `.hb` como
  primeiro argumento do `hbmk2` seleciona execução de script. Na compilação
  direta, ponha `-hbexe` (executável) ou `-gh` (HRB) antes do caminho do fonte.
- Preserve nomes convencionais Git (`README`, `LICENSE`, `AGENTS`, `TODO`,
  `ChangeLog`), os nomes solicitados `WIP.md`/`WIP.pt-BR.md` do projeto e o
  sufixo `.pt-BR`. Toda documentação tem versão inglesa e
  portuguesa. Os demais documentos usam nomes em inglês e minúsculas.
- Preserve a grafia de APIs externas, campos de protocolo/JSON sensíveis a
  maiúsculas e macros/símbolos exigidos pelo compilador, incluindo `HB_FUNC`.
- Prefira hashes Harbour para registros, configurações, metadados e consultas
  por chave. No TLPP, prefira `JSONObject` para JSON e `THashMap` para mapas
  internos adequados. Arrays exigem necessidade concreta de API ou contrato;
  documente os custos de alocação, cópia e busca.
- Exponha APIs públicas Protheus por classes com namespace. Use métodos
  estáticos para utilitários sem estado; helpers locais podem ser funções
  estáticas. Testes `U_` mantêm os nomes publicados, como
  `U_HBBridgeConnectionTest`.
- Use `THREAD STATIC` Harbour para estado mutável pertencente à thread worker.
  Inicialize estado de requisição explicitamente ou use locais/parâmetros;
  reuso do worker e recarga HRB não garantem reset. Recursos do processo,
  como o mutex SQL, continuam em `STATIC` comum com sincronização.
- Mantenha hbBridge genérico. Protheus resolve regras, tenant, empresa, filial,
  `xFilial` e nomes físicos; serviços/addons recebem entradas explícitas.
  Aliases SQL são chaves opacas, sem dedução de contexto ERP. A biblioteca TLPP
  não pode impor perfil de banco demonstrativo.
- Obtenha a configuração ativa de conexão DBAccess por `FWGetTopInfo()` em vez
  de reconstruir servidor/porta/banco/alias por chaves INI. Preserve conexões
  existentes e feche somente a conexão aberta pelo próprio chamador.
- Nos blocos TLPP `catch xError`, utilize o valor capturado e, após tratá-lo,
  libere objetos com `if (ValType(xError)=="O"); FreeObj(@xError); endif`.
  Declare a variável como variant; o compilador precisa reconhecer seu uso.
- Reutilize o `hbhttpd` nativo para HTTP/REST e administração web pelo núcleo
  comum de serviços. Explicite dependências e capacidades habilitadas;
  `-hblib` é modo de compilação, não uma contrib Harbour separada.
- O pré-processador transforma `User Function Name` em `U_Name`. Não é
  necessário converter declarações existentes `procedure U_Name`.
- Resolva dependências por `scripts/bootstrap.ps1` e `config/dependencies.json`.
  Não fixe caminhos do desenvolvedor nem use o antigo `bin/harbour`.
- Antes de cada commit, execute `scripts/commit-check.ps1`: devem passar
  `.hbcommit/check.hb`, `.hbcommit/commit.hb` e a validação somente leitura de
  `.hbcommit/3rdpatch.hb`. Não ignore falhas nem altere o índice silenciosamente.
  O padrão verifica alterados/novos; `-Staged` valida conteúdos alterados do
  índice e `-All` solicita revisão completa. Alterações em políticas,
  ferramentas/configuração exigem validação completa; terceiros mantêm seu
  escopo global em todas as execuções.
