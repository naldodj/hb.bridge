# Licenciamento — proposta e procedência

Status em 2026-10-04: análise para decisão, sem adoção de uma licença global.
Há avisos `Released to Public Domain` em vários fontes próprios e cabeçalhos
de terceiros com suas licenças. Ainda não existem `LICENSE` e inventário de
avisos na raiz. Esta proposta não substitui os avisos existentes.

## Modelo proposto

A recomendação para facilitar integração empresarial é **MIT para o código
efetivamente autoral do hbBridge**, independentemente de estar em Harbour,
C, Zig ou TLPP, após resolver a procedência descrita abaixo. MIT permite uso,
modificação e distribuição comercial, inclusive em produtos fechados,
mantendo os avisos exigidos. Também permite distribuir versões modificadas
sem exigir abertura dessas modificações. Texto padrão:
[MIT na OSI](https://opensource.org/license/mit).

As licenças das dependências permanecem próprias. A licença da linguagem ou
do compilador não determina automaticamente a licença do código escrito
para ele. Esse modelo usa textos padronizados e um inventário de componentes;
não cria um texto jurídico híbrido chamado "Harbour + Zig".

| Componente | Termos verificados / tratamento |
| --- | --- |
| Código autoral do hbBridge | Proposta MIT, condicionada à procedência; decisão pendente. |
| Bibliotecas Harbour | Em geral GPL v2 ou posterior com exceção de vinculação; conferir cada contrib utilizada. |
| Compilador Harbour e utilitários | Em geral GPL v2 ou posterior; a exceção das bibliotecas não se estende automaticamente a esses fontes. |
| Zig | O projeto publica MIT; componentes de terceiros do toolchain mantêm seus próprios avisos. |
| Cabeçalhos zlib incluídos | Licença zlib e copyright já preservados nos arquivos. |
| Ferramentas check/commit/3rdpatch em `.hbcommit` | Avisos GPL upstream preservados; procedência e termos separados. |
| hbhttpd/hbtcpio gerenciados e hbssl/OpenSSL opcional | Preserve avisos originais e registre versões vinculadas; patches do projeto não relicenciam fontes upstream. |

A exceção Harbour permite que a vinculação com suas bibliotecas, por si só,
não imponha GPL ao executável. Não autoriza relicenciar trechos copiados de
utilitários GPL nem apaga as obrigações relativas às bibliotecas distribuídas.
A licença das contribs deve ser verificada por arquivo.
[Termos Harbour](https://github.com/harbour/core/blob/master/LICENSE.txt).
A licença principal do Zig está no [repositório oficial](https://github.com/ziglang/zig/blob/master/LICENSE).

Se o objetivo for exigir entrega dos fontes das modificações do servidor
quando ele for distribuído, uma alternativa é **servidor sob GPL v2 ou
posterior e cliente TLPP autoral sob MIT**. Essa separação depende da
procedência de cada parte e não concede exceções a código de outros autores.
O fato de GPL permitir cobrança pelo software também não equivale a MIT:
as condições de distribuição são diferentes.
[Texto GPL v2 distribuído pelo Harbour](https://github.com/harbour/core/blob/master/LICENSE.txt).

## Pontos encontrados no código atual

O helper `FileSig` de [hbbridgeaddon.hb](../src/hb/addons/hbbridgeaddon.hb)
coincide com o helper homônimo do utilitário `hbnetio.prg` após normalizar
espaços. O fluxo de compilação/carregamento também apresenta semelhanças.
O utilitário upstream tem GPL v2 ou posterior sem exceção de vinculação em
seu cabeçalho; o aviso local de domínio público não esclarece essa procedência.
Essa é evidência para revisão, sem presumir titularidade nem concluir aqui
o alcance jurídico da coincidência. A adoção global de MIT depende de
esclarecer a origem e aplicar os termos ou permissões correspondentes.
[Fonte comparado, commit 8d94c31](https://github.com/harbour/core/blob/8d94c31367104a57eb9ae6fa248cca2abb8db309/contrib/hbnetio/utils/hbnetio/hbnetio.prg#L809-L829).

[hbbridgetime.tlpp](../src/tlpp/hbbridgetime.tlpp) registra adaptação de
`dna.tech.StopWatch.__GetCurrentTimeStamp()`. O checkout local
`naldodj-tlpp` contém `LICENSE.txt` com LGPL 2.1. Também é necessário
confirmar a titularidade e os termos aplicáveis à adaptação antes de
padronizar seu aviso. Não se presume autorização de relicenciamento a
partir do nome do repositório.

O [registro zlib](../src/c/third_party/zlib/README.pt-BR.md) identifica os dois
cabeçalhos copiados e o commit de origem. Seus avisos permanecem íntegros.
A análise de TRPC registra reaproveitamento de ideias; não identificou
incorporação das classes/protocolo/executor do arquivo upstream.

## Formalização depois da decisão

Criar `LICENSE` com o texto padrão escolhido e titulares confirmados,
`THIRD_PARTY_NOTICES.md` com origem/versão/termos dos componentes e os textos
necessários à distribuição. Padronizar identificadores SPDX nos fontes
autorizados, preservando avisos de terceiros e as permissões anteriormente
concedidas. O pacote binário também precisa considerar runtime Harbour,
contribs SQL/NETIO, SQLite, zlib e os componentes efetivamente incorporados
pelo toolchain; a análise dos fontes não certifica esse pacote completo.
O inventário também precisa identificar as bibliotecas HTTP modificadas e
o pacote OpenSSL efetivamente vinculado, quando habilitado.

O [TODO](../TODO.pt-BR.md) mantém a decisão e os pontos de procedência pendentes.
Nenhum fonte ou comportamento de execução foi alterado por esta análise.
