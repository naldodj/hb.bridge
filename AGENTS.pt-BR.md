# Convenções do hbBridge

[English](AGENTS.md) · [Padrões detalhados](docs/standards.pt-BR.md)

- No trabalho de pacote, leia [WIP.pt-BR.md](WIP.pt-BR.md) e retome a próxima
  tarefa pendente. Atualize progresso/evidências nas duas versões. Reabra
  decisões somente por novas evidências, falhas reproduzíveis, mudanças de
  requisito/dependência ou instruções do usuário. Renove WIP com os critérios
  atendidos; commits/publicações intermediários não o reiniciam. TODO mantém o roadmap.
- Use quatro espaços por nível de indentação nos fontes próprios. Preserve a
  formatação, os avisos de copyright e as licenças dos arquivos de terceiros.
- Use identificadores em inglês. Arquivos em minúsculas. Funções, procedures,
  métodos, namespaces e classes usam PascalCase, conforme esclarecimento
  explícito do responsável. O arquivo usa o nome da classe em minúsculas:
  `HBBridgeClient` fica em `hbbridgeclient.tlpp`.
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
