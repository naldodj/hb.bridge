# Turnover: reconciliação das regras históricas

[English](turnover-reconciliation.md) · [Exemplo](turnover-addon.pt-BR.md) · [Pacote de trabalho](../WIP.pt-BR.md)

O objetivo é criar um novo exemplo no hbBridge que use as consultas de turnover
fornecidas como fontes de dados e adapte seus resultados a um novo dashboard e
drill-down. A implementação histórica é uma referência, sem exigir comportamento
idêntico. Definir o significado das novas medidas e validá-las contra a origem
escolhida; afirmar equivalência histórica apenas se ela for comprovada à parte.

O addon experimental atual recebe uma linha por funcionário-mês e monta toda a
hierarquia em memória. As consultas fornecidas retornam medidas já calculadas em
níveis distintos e, nos relatórios gerais, usam um lote SQL que materializa uma
tabela de resultado. Não podem ser passadas sem adaptação à ação `turnover`
existente como um SELECT tipado. Um novo contrato do addon de aplicação deve
consumir o formato escolhido sem somar a mesma agregação em vários níveis e
obter o nível selecionado e seus detalhes quando necessário. O Protheus fornece
identificadores de tabelas resolvidos e contexto autorizado; o addon pode conter
modelos SQL confiáveis e regras de cálculo. Vincular valores de filtros e validar
identificadores; não avaliar macros armazenadas do Protheus no processo Harbour.
Adaptar a saída dos lotes ao contrato de execução e de propriedade das tabelas;
comparar o retorno JSON com uma tabela temporária do chamador quando couber.
Nenhuma vantagem de desempenho é presumida antes de medições.

Esta comparação de código considera os cinco backups SQL históricos fornecidos
para os relatórios por empresa, filial, centro de custo, função e funcionário.
Eles são insumos para a reconciliação e não comprovam que correspondam à
customização atualmente instalada. Cada backup é idêntico, byte a byte, ao SQL
correspondente no projeto GEP fornecido. A aplicação resolve nomes físicos das tabelas,
empresa, filial, permissões e filtros. O núcleo genérico do hbBridge não os
infere; um addon confiável pode implementar as regras da própria aplicação.

## Regras observadas e cobertura atual

| Assunto | Backups SQL históricos | Exemplo atual do addon |
| --- | --- | --- |
| Elegibilidade no mês | A admissão deve ocorrer até o período; o desligamento deve estar vazio ou ocorrer no período ou depois. Um desligamento preenchido não pode preceder a admissão. | O chamador fornece `ACTIVE=1`; o addon não reconstrói a elegibilidade. Um teste SQLite sintético exercita esses limites mensais. |
| Admissão e desligamento | Contam-se as respectivas datas da SRA no mês. Uma admissão e um desligamento no mesmo mês podem contribuir para ambos. | Cada linha fornece indicadores 0/1. Um teste controlado cobre os dois eventos no mesmo mês e um desligamento anterior ao mês seguinte. |
| Medidas | `inicial = ativos - admissões`; `final = ativos - desligamentos`; turnover é `(admissões + desligamentos) / 2 / inicial * 100`, arredondado para duas casas; movimento de desligamento é `desligamentos / 2 / inicial * 100`. Com inicial zero, ambas as taxas são zero. | Inicial e ambas as taxas usam a mesma aritmética sobre as linhas recebidas. O exemplo não expõe a quantidade final histórica. Fórmulas iguais não comprovam populações iguais. |
| Transferências | Os backups contam registros SRE por mês e identidade, com critérios distintos para origem e destino. Algumas dimensões exibidas são resolvidas pelo primeiro ou último movimento correspondente no próprio mês. | O chamador fornece eventos datados com direção explícita `in`/`out`; evidência ausente permanece desconhecida. O addon soma eventos por linha recebida. Ele não infere direção, atribuição ou lotação histórica da SRE. |
| Função | Os backups usam a última data correspondente da SR7 no mês e recorrem à SRA se não houver registro. | A origem fornece a função em cada linha. |
| Dimensões e identidade | Subconsultas históricas usam critérios de empresa, filial, matrícula e código único; os agrupamentos variam por relatório. CTT e SRJ usam `INNER JOIN` com condições de compartilhamento de filial. | A hierarquia é período/empresa/filial/centro de custo/função/funcionário. O chamador fornece chave e dimensões sem ambiguidade. Uma chave repetida no mesmo caminho completo é rejeitada. |

O teste controlado usa datas inventadas, uma tabela SQLite isolada e uma origem
mensal deliberadamente simplificada. Compara resultados calculados manualmente,
sem executar o SQL original ou comprovar comportamento no SQL Server,
reconstrução de transferências ou equivalência à aplicação instalada. Totais
acima do nível de período somam funcionários-mês; não são contagens distintas
nem taxas de turnover entre períodos automaticamente significativas.

## Casos a definir e validar

- Comparar com o relatório efetivamente instalado e sua resolução de parâmetros
  e tabelas; nomes físicos nos backups não constituem contrato portátil.
  Preservar a autorização e não copiar dados reais de funcionários para
  fixtures, logs ou repositório.
- Validar a geração dos meses e os limites inclusivos. Nesses backups a sequência
  usa `TOP (DATEDIFF(MONTH, minimum, GETDATE()))`; o limite final, incluindo o
  mês atual, precisa ser comparado com a aplicação.
- Resolver a semântica de origem e destino da SRE com movimentos controlados de
  ida, retorno e múltiplos, empates na mesma data e casos entre empresas e
  filiais. Não mapear `TTRFSAI` e `TTRFENT` para `out`/`in` apenas pelo nome.
  Definir a atribuição do evento em cada nível e evitar contagem dupla quando
  aparecer em mais de uma lotação recebida.
- Verificar mudanças na SR7, ausência ou duplicidade de correspondências em
  CTT/SRJ, compartilhamentos, exclusões e readmissões. Nos backups examinados,
  as subconsultas de admissão e desligamento não filtram explicitamente a
  exclusão lógica; a de desligamento agrupa por filial sem uma igualdade de
  filial explícita. Definir o comportamento esperado antes de reproduzi-lo ou
  alterá-lo.
- Definir identidade única de funcionário e lotação nas transferências. O
  contrato de indicadores 0/1 não representa contagens arbitrárias maiores que
  um, e o caminho atual não distingue chaves de funcionário iguais na mesma
  lotação.
- Validar cada nível, indicadores, movimentos e totais arredondados com entradas
  controladas e em ambiente Protheus autorizado. Comparar com a implementação
  histórica usando a mesma entrada pode explicar diferenças, mas só é obrigatório
  para uma afirmação explícita de equivalência. Registrar resultados sanitizados
  e transportes.

O exemplo ainda não é um relatório de RH ou folha homologado.

## Uso na aplicação GEP

Os arquivos `Turnover*.prg` referenciados são consumidores de modelos e telas
em Harbour/Nefele. O relatório de empresa encaminha filtros de período a
`GetDataModel`; os links de drill-down prosseguem por filial, centro de custo,
função e funcionário. Os dashboards de empresa e filial usam os dados dos
respectivos relatórios para montar séries mensais de transferências, admissões,
desligamentos, efetivos inicial e final e as duas taxas de turnover.
`GetDataModel` pode usar JSON em cache ou solicitar um modelo; a leitura desses
fontes não demonstra qual caminho está ativo em uma instalação.

O mapeamento de parâmetros SQL correspondente fornece expressões `RetSQLName`
para diversas tabelas físicas, parâmetros da aplicação e nomes de tabelas
temporárias. Isso evidencia o mecanismo daquela aplicação, sem exigir que o
addon do hbBridge adote o mesmo modelo JSON ou fixe nomes de tabelas.

Os seis arquivos de configuração do GEP descrevem ainda a ordem das colunas,
títulos, propriedades de dados, formatação, pesquisa, ordenação e colunas fixas,
além das configurações de acesso aos modelos. São referências de apresentação;
o novo exemplo não precisa lê-los. Algumas entradas nas configurações de empresa
e funcionários repetem campos ou associam uma coluna a outra propriedade de
dados. Validar o mapeamento pretendido contra a consulta e o modelo antes de
reaproveitá-lo. Configurações de acesso desses arquivos não devem ser copiadas
para a documentação do projeto.

### Modelos cadastrados e geração do JSON

Uma consulta somente de leitura ao MSSQL local de desenvolvimento em
2026-11-05 encontrou seis modelos ativos de turnover, relacionados entre `ZZ_`
e `ZX_` pelo código da query. Os cinco modelos gerais usam o modo de execução
SQL; o modelo de previsto versus realizado usa o outro modo de consulta. Os
mapeamentos de campos são configurações, não dados de funcionários.

O endpoint de modelos do Protheus resolve o modelo e lê a consulta e seu
mapeamento de parâmetros na `ZX_`. `QueryToTmpTable` avalia as expressões de
parâmetros no ambiente Protheus. No modo de execução, executa o SQL, inspeciona
a tabela resultante, cria uma `FWTemporaryTable`, preenche-a por `INSERT INTO
... SELECT` e remove a tabela intermediária. O endpoint pagina o alias
resultante; `AFXUtils:getJSON` usa os registros ordenados da `ZZ_` para mapear
campos ou expressões em propriedades JSON. Cada item é colocado em
`table.items[].detail.items`. O consumidor GEP pode posteriormente obter a
resposta do modelo ou um JSON em cache. O fluxo foi identificado pelos fontes
e pela configuração examinados; nenhum relatório foi executado nesta análise.

Por exemplo, o modelo de empresa cadastrado mapeia `PERIODO` para `codPeriodo`,
`TTRFSAI` para `totalTransferenciasSaida`, `TTRFENT` para
`totalTransferenciasEntrada`, `TFUNIMES` para `totalFuncionariosInicioMes` e
`TURNOVER` para `turnOverGeral`. No modelo de funcionários, expressões
configuradas posicionam a SRA por `SRARECNO` para obter nome e data de admissão;
a data de desligamento é retornada condicionalmente à contagem de desligamentos
no mês. Esses mapeamentos identificam os nomes históricos, mas não comprovam,
isoladamente, a atribuição de cada movimento aos grupos corretos.

Os cinco textos SQL armazenados nos registros `ZX_` do desenvolvimento diferem
dos backups correspondentes. Em quatro, a diferença está na expressão
normalizada do mês e em um marcador da SRA; a query de funcionários apresenta
diferenças adicionais nas expressões mensais. O SQL cadastrado usa o marcador
da SRA presente no seu mapeamento de parâmetros. Essas observações não
comprovam equivalência semântica. A reconciliação deve considerar a query e a
configuração aplicáveis, além dos fontes da aplicação, sem executar expressões
armazenadas fora de seu contexto Protheus confiável.

Os dashboards calculam também uma taxa para o período selecionado, separada das
taxas mensais do SQL. Para dados não vazios e denominador diferente de zero, a
expressão examinada é `((soma(admissões) + soma(desligamentos)) / 2 /
soma(inicial) / quantidadeDeLinhas) * 100`; a taxa de desligamentos substitui
o numerador por `soma(desligamentos)`. O efetivo inicial do período vem da
primeira linha retornada e o final, da última. A raiz do addon atual aplica a
fórmula do nó às somas dos indicadores funcionário-mês, sem essa divisão
adicional pela quantidade de linhas. São cálculos distintos; os fontes, por si
só, não definem qual deve ser adotado em um novo relatório nem seu comportamento
sem dados. Confirmar ordenação, cobertura de períodos e fórmula pretendida
antes de implementar ou comparar os totais do dashboard. As séries mensais
continuam comparáveis separadamente.
