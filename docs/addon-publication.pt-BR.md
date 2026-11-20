# Publicação de addons e execução nativa: análise

[English](addon-publication.md) · [Pacote atual de exemplos](addon-bundle.pt-BR.md) · [Roadmap](../TODO.pt-BR.md)

Este documento registra uma proposta e a análise de uma ideia de addon nativo.
Ele não implementa registro de addons, descoberta, loader nativo ou nova política
de autorização. Esses recursos exigem implementação e aceite posteriores. Regras
de negócio podem residir em addons Harbour confiáveis; o host permanece genérico
e o chamador fornece o contexto da aplicação explicitamente.

## Comportamento atual

`ADDON.Execute` recebe `module` relativo e `params`. O servidor resolve o módulo
sob `addonRoot`; hoje o caminho não é um registro individual de publicação. O
[executor](../src/hb/addons/hbbridge.addon.hb) compila `.hb`/`.prg` quando
necessário ou carrega um HRB com `HB_HRB_BIND_FORCELOCAL`, executa-o com JSON e
contexto nativo e descarrega seu handle a cada chamada. O addon instalado é
código confiável, com os privilégios do processo hbBridge.

O pacote de exemplos possui um mapa de ações fixo no próprio HRB e sensível a
maiúsculas. O mapa pertence ao exemplo; addons independentes não precisam usar
as mesmas ações. `Service.List` divulga serviços, mas não é um catálogo de
publicação de addons individuais. A permissão atual de canal `addon.execute`
não representa autorização por usuário ou por addon.

## Proposta de publicação e descoberta

Um catálogo administrado no servidor pode associar nome lógico e versão a um
módulo instalado e a um contrato explícito de entrada. Por exemplo, a estrutura
abaixo é uma possibilidade futura e **ainda não é uma configuração suportada**:

```ini
[Addon/turnover]
Enabled=1
Module=examples/hbbridgeaddons.hrb
Contract=bundle-action-v1
Action=turnoverReport
```

Uma requisição futura informaria `turnover` e seus parâmetros. O servidor, e
não o chamador, escolheria o módulo confiável e a ação configurada do pacote.
HRBs independentes podem manter um contrato direto. Mapear uma ação não registra
automaticamente funções arbitrárias no HRB: o contrato de entrada e suas ações
suportadas ainda precisam ser definidos e validados. O pacote de exemplos atual
continuaria precisando reconhecer as próprias ações.

O catálogo proposto deve validar identificadores, entradas duplicadas, versões,
ativação e caminhos permitidos, incluindo travessia e links do sistema de arquivos.
As entradas devem apontar para artefatos instalados por administrador sob uma
raiz permitida; o cliente não deve informar caminho ou símbolo para contornar a
política de registro. Preservar os clientes atuais com `module` por um modo de
compatibilidade explícito e definir migração e padrão antes de implementar; um
registro acompanhado de caminhos irrestritos não impõe publicação. Inicialização,
atualização e recarga ainda precisam de contrato.

Um futuro endpoint de catálogo pode expor nome lógico, versão e ativação ao
chamador autorizado, sem divulgar caminhos locais ou credenciais. Diferenciar
**configurado/ativado**, **artefato presente** e **validado ou carregado**: uma
entrada ou arquivo existente não comprova que a carga ou execução será bem-sucedida.
Não executar regras de negócio como teste de descoberta. Restrições de canal e,
quando implementadas, identidade autenticada e autorização por addon devem filtrar
descoberta e execução de modo consistente. Menus do Protheus podem consumir o
catálogo; permissões de usuários permanecem sob responsabilidade da aplicação e
do modelo futuro de autorização do servidor.

## Análise da ideia de addon nativo

Compilar funções Harbour via `-gc3` para C pode valer uma medição em trabalho
intensivo de CPU. A execução ainda usa operações da VM/runtime Harbour; não há
garantia de que toda expressão se torne aritmética nativa independente. No
[gerador C do Harbour fixado](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/compiler/gencc.c),
codeblocks ainda podem conter pcode. Um HRB compilado com `-gh` continua sendo
HRB; o `-gc3` do host não transforma as funções do HRB em nativas. Custos de SQL,
codificação, carregamento e transporte precisam ser medidos separadamente.

A ideia de DLL é plausível como prova de conceito, mas as premissas apresentadas
não demonstram uma implementação portátil:

- A [ponte `hbmaindllp` fixada](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/vm/maindllp/dllpcode.c)
  é específica do Windows. Linux e macOS exigem estratégia própria e testada para
  vínculo da VM e exportação de símbolos; o exemplo não comprova esses ambientes.
- O projeto e o exemplo proposto têm contratos diferentes: o HRB atual recebe
  JSON e contexto nativo, enquanto o exemplo proposto recebe um hash. Um adaptador
  precisa preservar erros, posse de recursos e permissões.
- Um ponteiro `STATIC` no HRB não é um singleton confiável do processo no ciclo
  atual de carga e descarga. Primeiras cargas concorrentes, colisão global de
  símbolos, compatibilidade de ABI, classes retidas e chamadas ativas exigem
  tratamento explícito antes de manter biblioteca em cache ou descarregá-la.
- Os exemplos de `-ldflags=` da proposta não correspondem à opção de linha de
  comando/projeto do `hbmk2` fixado: a opção é `-ldflag=`. O significado e a
  disponibilidade das flags ainda exigem validação por linker e SO. `-static`,
  isoladamente, também não comprova um executável totalmente estático no sistema.
- Bibliotecas nativas executam dentro do processo do servidor como código
  confiável; exportar símbolos da VM não cria isolamento. A escolha entre
  `hb_DynCall`, símbolos Harbour diretos ou uma ABI C versionada depende da
  interface concreta; não se presume uma proibição geral ou garantia de segurança.

Antes de mudar o loader, medir resultados e contratos JSON equivalentes para o
HRB atual, um candidato que mantém em cache os **bytes** do HRB mas carrega um
handle separado por chamada, e um protótipo nativo. Medir separadamente carga
fria/aquecida, execução, SQL, serialização, memória e concorrência. Verificar
substituição de versão, recuperação de falhas, encerramento, posse de recursos e
compatibilidade entre plataformas. A [evolução do benchmark](benchmark-evolution.pt-BR.md)
já prevê comparações C/Zig. Adotar addon nativo somente se as medições e seu
ciclo de vida justificarem a complexidade adicional.
