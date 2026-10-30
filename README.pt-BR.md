# hbBridge

[English](README.md) · [Documentação](docs/README.pt-BR.md) · [Wiki](https://github.com/naldodj/hb.bridge/wiki/Home.pt-BR) · [Trabalho atual](WIP.pt-BR.md)

[![Stars](https://img.shields.io/github/stars/naldodj/hb.bridge?style=social)](https://github.com/naldodj/hb.bridge)
![Clones](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/naldodj/hb.bridge/refs/heads/main/clone-badge.json)

**Amplie o TOTVS Protheus com Harbour, C e Zig.** O hbBridge oferece um host
de serviços compartilhado para clientes AdvPL/TLPP, Harbour nativo e HTTP,
com acesso SQL, addons Harbour e processamento nativo.

O hbBridge é um **executor genérico**. Protheus resolve suas regras de negócio,
tenant, empresa, filial, `xFilial` e nomes físicos de tabelas e envia consultas
e parâmetros explícitos. Perfis de banco são aliases escolhidos pelo chamador;
a biblioteca cliente não exige banco de demonstração.

## Por que Harbour, C e Zig?

- **Harbour traz a familiaridade do xBase.** A sintaxe e as convenções são
  semelhantes às de AdvPL/TLPP, facilitando a leitura e manutenção dos serviços
  e addons pelos desenvolvedores Protheus. Harbour também fornece RDDs nativos,
  NETIO, serialização e bibliotecas contrib. APIs específicas do Protheus ainda
  precisam de adaptação.
- **C fornece interoperabilidade nativa.** A API C do Harbour conecta código
  xBase a bibliotecas nativas; a ABI C também conecta extensões Harbour ao Zig.
  O caminho interno de integração é **Harbour ↔ C ↔ Zig**.
- **Zig moderniza o desenvolvimento nativo.** Interoperabilidade com C,
  tratamento explícito de erros, alocação/posse de recursos e avaliação em
  tempo de compilação sustentam extensões nativas. Zig também fornece o
  toolchain gerenciado Harbour/C e o codec numérico JSON compartilhado.

Veja a [arquitetura e os limites das extensões](docs/architecture.pt-BR.md).

## Disponível hoje

| Recurso | Implementação atual |
| --- | --- |
| Serviços compartilhados | Health, Echo, descoberta, funções controladas do core e execução de addons. |
| TCP Protheus | Cliente TLPP com contrato JSON/gzip `HBBRIDGE/1`. |
| Harbour nativo | NETIO incorporado para RPC registrado e acesso nativo a arquivos remotos. |
| HTTP/REST | Listener hbhttpd opcional, cliente HTTP TLPP, gzip e painel de status autenticado. |
| SQL | Perfis MSSQL/ODBC e SQLite, parâmetros/resultados tipados e paginação no SGBD. |
| Apresentação Protheus | Navegação de dataset, tabelas/browse nativos e metadados/exemplos SX3 resolvidos pelo chamador. |
| Addons e medições | Execução de fontes/HRB Harbour e exemplos reproduzíveis de benchmark CLI/visual. |

O projeto está em desenvolvimento ativo. Os [registros de homologação](docs/acceptance.pt-BR.md)
identificam versões, plataformas e limitações testadas. Instalação como
serviço, armazenamento protegido de credenciais, transporte
LOB geral e integração HBDAP permanecem futuros; veja [WIP](WIP.pt-BR.md) e
[roadmap](TODO.pt-BR.md).

## Primeira execução

Na raiz do repositório, com PowerShell 7 e Git instalados:

```powershell
pwsh ./scripts/bootstrap.ps1
pwsh ./scripts/build-hbbridge.ps1
pwsh ./scripts/run-hbbridge.ps1 -Config config/examples/hbbridge.ini
```

O bootstrap resolve as dependências fixadas de `hb_compile`, Harbour e Zig.
O executável é gerado em `out/`. Drivers SQL externos e o SDK licenciado da
TOTVS são pré-requisitos separados. Veja [dependências](docs/dependencies.pt-BR.md)
e [scripts de build/execução](scripts/README.pt-BR.md) para os requisitos Windows/Linux.

O [INI de exemplo](config/examples/hbbridge.ini) habilita TCP Protheus e NETIO
nativo; HTTP exige ativação explícita. Use uma configuração privada com os
endereços, credenciais e perfis SQL da instalação. Configure os clientes na
seção `[hbBridge]` do INI AppServer ativo, conforme o
[modelo do cliente](config/examples/protheus-appserver.ini) e o
[guia de configuração](docs/configuration.pt-BR.md).

Compile a árvore mantida `src/tlpp/` no seu ambiente TOTVS e execute:

```advpl
U_HBBridgeConnectionTest()
```

Esse primeiro teste exercita Health, Echo e o addon Harbour fornecido.
Os [exemplos Protheus](examples/protheus/README.pt-BR.md) orientam compilação,
HTTP, SQL, browses nativos e benchmark visual.

## Consumir um serviço em TLPP

Dentro de um método TLPP, após configurar o cliente:

```advpl
local jParams := JSONObject():New() as json
local jResponse as json
local oClient := HBBridge.Client.HBBridgeClient():New() as object

jParams["message"] := "Hello from Protheus"
jResponse := oClient:CallService("Echo", jParams)
ConOut(jResponse:ToJSON())

oClient:Close()
FreeObj(@oClient)
FreeObj(@jParams)
FreeObj(@jResponse)
```

Para HTTP, veja o [exemplo FWRest/TLPP](examples/http/README.pt-BR.md).
Para SQL, escolha um perfil configurado por chamada e utilize o
[dataset](docs/dataset.pt-BR.md), o [contrato SQL tipado](docs/typed-sql.pt-BR.md)
e os [exemplos de apresentação nativa](docs/native-presentation.pt-BR.md).

## Encontre os detalhes

O [índice da documentação](docs/README.pt-BR.md) agrupa guias por tarefa:

- [Configurar listeners, perfis e clientes](docs/configuration.pt-BR.md).
- [Entender HTTP, compressão e administração](docs/http.pt-BR.md).
- [Usar metadados SX3 e campos selecionados](docs/sx3-metadata.pt-BR.md).
- [Medir desempenho e interpretar benchmarks](docs/benchmarking.pt-BR.md).
- [Depurar Harbour e planejar integração HBDAP opcional](docs/debugging.pt-BR.md).
- [Reproduzir validações](docs/validation/README.pt-BR.md).

Os guias técnicos ficam em `docs/`, junto ao código. O portal Wiki é gerado a
partir do índice da documentação; os guias são mantidos em um único lugar.

## Contribuição e suporte

Siga os [padrões dos fontes e crivos de commit](docs/standards.pt-BR.md).
O [WIP](WIP.pt-BR.md) acompanha o pacote ativo; o [TODO](TODO.pt-BR.md) mantém
o roadmap completo. O licenciamento global do projeto ainda não foi
formalizado; consulte o [estado de licença/proveniência](docs/licensing.pt-BR.md)
e os avisos existentes nos fontes.

Estrelas e contribuições ajudam o projeto. Para suporte corporativo DNA Tech,
arquitetura Protheus, tuning de banco e integrações, veja os
[serviços e contatos](docs/support.pt-BR.md).
