# Pacote de addons de exemplo

[English](addon-bundle.md) · [Exemplo de turnover](turnover-addon.pt-BR.md)

Compile um único módulo Harbour portátil para os exemplos do projeto:

```powershell
./scripts/build-hbbridge-addons.ps1
```

O artefato padrão é `addons/examples/hbbridgeaddons.hrb`; use `-Output` para
instalá-lo sob o `AddonRoot` configurado no servidor. O pacote compila quatro
fontes `.hb` mantidos no projeto. Ele possui um ponto de entrada `Main` e uma
seleção explícita, sensível a maiúsculas e minúsculas:

```json
{"service":"ADDON.Execute","params":{"module":"examples/hbbridgeaddons.hrb","params":{"action":"sample","params":{}}}}
```

As ações disponíveis são `sample`, `benchmark`, `temporaryInsert` e `turnover`.
Cada ação recebe seu objeto de parâmetros existente e retorna sua resposta
original. Um hash local à chamada, sensível a maiúsculas e minúsculas, associa
ações autorizadas aos símbolos das funções locais do HRB. `hb_ExecFromArray()`
chama o símbolo com o JSON de parâmetros e o contexto; o array ordenado de
argumentos é exigido por essa API nativa. Para ampliar o pacote, registre a
ação e inclua seu fonte; nomes de funções informados pelo cliente não são
resolvidos. O pacote rejeita ações desconhecidas e envelopes inválidos. Serviços
aninhados recebem o contexto da chamada e respeitam suas permissões. Credenciais
do banco permanecem na configuração do servidor. O cliente deve construir SQL
confiável e fornecer o contexto da aplicação quando o exemplo selecionado exigir.

O pacote único é o padrão dos exemplos de browse temporário, benchmark e
turnover. O executor genérico continua aceitando módulos `.hb`, `.prg` e `.hrb`
independentes, com seu contrato de entrada original; scripts dedicados anteriores
permanecem disponíveis por compatibilidade e para fixtures de regressão nativa.
Um HRB pode conter várias funções Harbour, mas addons independentes não precisam
compartilhar um único HRB ou ciclo de publicação. O compilador inclui os quatro
fontes em uma unidade e atribui nomes distintos às suas funções `Main`. Ao ampliar
o pacote, evitar também nomes repetidos de auxiliares static.

O cliente de benchmark inclui o envelope de ação quando o módulo configurado
termina com `hbbridgeaddons.hrb`; um módulo independente anterior configurado
explicitamente mantém o contrato direto. Valores existentes no INI continuam
selecionando o módulo configurado; atualize a configuração ao migrar para o pacote.
