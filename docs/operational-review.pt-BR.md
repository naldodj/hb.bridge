# Revisão operacional: segurança, capacidade e resiliência

[English](operational-review.md) · [Roadmap](../TODO.pt-BR.md) · [Pacote atual](../WIP.pt-BR.md)

Esta revisão registra ideias aproveitáveis de uma avaliação externa do projeto.
Ela não representa implementação ou aceite de produção. As atividades ficam
no roadmap; esta análise não altera o pacote ativo nem define novos padrões.

## Limites existentes

- O TCP Protheus atual não possui autenticação de cliente ou camada TLS e o
  bind padrão do servidor é `0.0.0.0`. HTTP é opcional e separa credenciais
  de serviço e administração; seu TLS não protege TCP ou NETIO. Restringir o
  acesso aos listeners até implementar e homologar a proteção correspondente.
  TLS HTTP direto e Linux exigem aceitação própria. Ver
  [credenciais](credentials.pt-BR.md), [HTTP](http.pt-BR.md) e
  [configuração](configuration.pt-BR.md).
- O Protheus resolve e fornece o contexto ERP quando o serviço precisa dele;
  o dispatcher não autentica automaticamente um tenant nem deduz empresa ou
  filial. Um addon confiável de aplicação pode implementar regras de negócio.
- `MaxWorkers` limita workers ativos, não todas as filas ou recursos. O TCP
  fecha conexões ao atingir a capacidade; o adaptador HTTP pode retornar
  `BUSY`/503, mas o hbhttpd lê o corpo antes da autenticação do adaptador e
  sua fila de sockets aceitos não tem teto explícito. Ver [limites HTTP](http.pt-BR.md).
- Syslog está vinculado, mas não conectado ao ciclo do host/RPC. O hbBridge
  acompanha empréstimos lógicos SQL; o reuso físico opcional pertence ao
  gerenciador ODBC. A quantidade de empréstimos não mede a ocupação física
  do pool. Ver [arquitetura](architecture.pt-BR.md) e [conexões SQL](sql-connections.pt-BR.md).
- `RPCRDD.Execute` pode ter resultado desconhecido após o envio ou a perda da
  resposta. Os timeouts atuais são separados por camada e não estabelecem um
  prazo universal de ponta a ponta. Não repetir automaticamente uma operação
  que possa ter produzido efeitos apenas porque a resposta se perdeu. Ver
  [execução SQL](sql-execution.pt-BR.md) e [enquadramento TCP](milestone2-framing.pt-BR.md).

## Oportunidades para pacotes futuros

1. **Admissão e sobrecarga:** medir filas, workers e esperas por transporte;
   desenhar admissão e prazos limitados e configuráveis na camada que consome
   recursos. Definir rejeição, considerando 503 para capacidade indisponível e
   429 quando existir política explícita de taxa por cliente. Testar clientes
   lentos, sobrecarga concorrente, recuperação e carga normal. São políticas
   operacionais, sem criar limites fixos de payload.
2. **Telemetria operacional:** definir contadores e histogramas limitados de
   latência por serviço, transporte e resultado, permitindo calcular percentis.
   Distinguir trabalho admitido/ativo/rejeitado, espera pelo SQL ou conexão e
   empréstimos lógicos. Informar métricas de pool físico somente quando houver
   fonte comprovada. Limitar a cardinalidade, excluir SQL/credenciais/dados
   pessoais, testar falha do coletor e medir overhead. Avaliar exportador
   Prometheus opcional e protegido depois de definir o contrato interno.
3. **Resiliência do cliente:** avaliar circuit breaker opcional por endpoint,
   com limiares, espera, sondas de recuperação e estado visível ao chamador.
   Separar reconexão de reenvio; respeitar o prazo total e permitir nova tentativa
   somente quando o contrato da operação comprovar que ela é segura.
4. **Contratos e fronteiras nativas:** avaliar envelope comum de sucesso/erro
   versionado, sem quebrar silenciosamente clientes nem expor descrições
   nativas sensíveis. Manter testes de contrato por transporte e testar entradas
   malformadas, posse, limpeza e ABI C/Zig/Harbour em falhas e concorrência.
5. **Dependências e comparações:** o manifesto já fixa Zig 0.16.0 com
   checksums e revisões exatas de Harbour/hb_compile; os propósitos dos patches
   estão em [dependências](dependencies.pt-BR.md). Continuar testando aplicação
   e revisando upstream antes de atualizar. Comparar desempenho com cargas
   equivalentes e metodologia documentada; um addon que devolve somente métricas
   não equivale à transferência de todo o dataset.

As atividades relacionadas já constam no [TODO](../TODO.pt-BR.md); escopo e
aceite concretos pertencem a um WIP futuro. Esta revisão não altera a decisão
sobre rotação de senha SQL nem a fronteira entre o hbBridge genérico e addons
de aplicação.
