# Pacote de trabalho ativo do hbBridge

[English](WIP.md) · [Roadmap](TODO.pt-BR.md) · [Homologação](docs/acceptance.pt-BR.md)

## Pacote 004: proteção portátil de credenciais no servidor

A primeira entrega protege uma credencial SQL configurada no hbBridge em repouso
no Windows e no Linux. O Protheus continua enviando somente o perfil SQL opaco e
o contexto de aplicação. O desenho comum deve permitir os consumidores NETIO,
administração e HTTP posteriormente; a proteção do cliente TLPP exige provedor
próprio comprovado. Armazenamento de segredos e segurança em trânsito exigem
aceites separados. Veja a [análise de credenciais](docs/credentials.pt-BR.md).

- [x] C01: inventariadas configuração atual, consumidores, exposição em
  diagnósticos e toolchain. Definidos envelope autenticado versionado para a
  senha SQL, provedor com chave em arquivo separado, compatibilidade e limites
  de recuperação. As provas Windows x64 e Linux x86_64 no WSL2 passaram em
  serialização binária, cifragem autenticada, entropia segura do SO e ABI
  sintética Harbour/C/Zig com Harbour e Zig 0.16.0 fixados. O Windows Authz e
  unidades transitórias no Linux verificaram o modelo de acesso com dados
  sintéticos. O C02 valida o provedor de produção e o C05 homologa as
  identidades da instalação.
  Veja o [desenho e as evidências C01](docs/credentials.pt-BR.md#c01-recursos-nativos-e-administração-local).
- [ ] C02: implementar e testar o provedor local portátil e ciclo da chave;
  cifragem autenticada, nonce único, vínculo ao contexto, erros explícitos,
  sem chave mestra embutida e com vida útil reduzida do segredo. Impedir fallback
  silencioso e uso do texto cifrado como senha quando a resolução falhar.
  Ponte Harbour/C/Zig e teste sintético inicial passaram 45 verificações no
  Windows, com DACL restrita ao usuário atual e LocalSystem. No WSL Ubuntu,
  passaram 45 verificações como root, com modo 600, tanto usando Harbour global
  r2610242111 quanto a toolchain isolada gerenciada, com Harbour r2609292008 e
  Zig 0.16. Preparação privada e publicação exclusiva passaram
  em cenários normais, concorrentes e de interrupção controlada nos dois sistemas.
  Uma interrupção pode deixar chave temporária restrita. No Windows e no WSL, a
  prova sintética remove o temporário após a saída do processo interrompido, cria uma
  chave completa e confirma que novas tentativas não a substituem. Durabilidade
  do filesystem e identidades de serviço permanecem abertas. Falhas de limpeza
  simuladas preservaram uma chave existente no Windows e no WSL e, após a
  publicação no WSL, preservaram a chave final e a cópia temporária. O leitor
  agora rejeita permissões inseguras de chaves existentes: testes sintéticos
  Windows cobriram acesso Everyone e DACL herdada; no WSL foram testados modo
  0644 e criação e uso de chave sintética pela identidade sem privilégios
  `nobody`. Envelope e chave sintéticos foram transferidos e decifrados nos dois
  sentidos entre Windows e WSL; alterações em cada campo de contexto vinculado
  foram rejeitadas. A prova valida o formato do provedor, não a migração do INI
  nem a autenticação SQL. Identidades reais de serviço e filesystems de
  instalação ainda exigem aceite. O provedor está integrado ao SQL estruturado;
  o utilitário local ainda não foi implementado.
- [ ] C03: integrar o provedor a um perfil MSSQL com autenticação SQL e escape
  ODBC correto. Preservar autenticação integrada e configurações existentes;
  rejeitar combinações ambíguas e não expor segredos em diagnósticos, erros,
  config-info, descoberta ou logs.
  O patch ODBC gerenciado deixou de solicitar a string de conexão de saída e de
  incluir a entrada em erros de alocação; falha de conexão informa SQLSTATE e
  mensagem fixa. A prova com DSN sintético ausente e a suíte MSSQL real somente
  de leitura passaram no Windows. Referências estruturadas em INI/JSON agora
  sobrevivem às normalizações e são resolvidas apenas na conexão; testes
  sintéticos cobrem escape, conflitos, chave ausente, envelope alterado e
  sanitização. A suíte focada passou 24 verificações no Windows e no Ubuntu WSL
  como root, com toolchain Harbour/Zig gerenciada e isolada; não houve teste
  de servidor MSSQL no Linux. Uma prova Windows/MSSQL somente de leitura cifra em memória a
  senha configurada, cria um perfil JSON protegido temporário e usa a consulta
  normal. Aceites ampliados de transporte, identidade de serviço e SQL no Linux
  seguem pendentes.
- [ ] C04: oferecer utilitário local com entrada sem eco, segredos fora de
  argumentos, gravação atômica e orientações para permissões de chave, backup,
  atualização manual e migração. Sem rotação automática de senha do banco.
  Disponibilizar teste explícito de conexão com perfil e credencial salvos,
  consulta inofensiva, diagnóstico sanitizado e liberação da conexão; não
  iniciar listeners, exibir segredos ou alterar dados no banco.
  Um primeiro modo local `--credential-test` testa um perfil MSSQL protegido
  existente com `SELECT 1` fixo e retorna apenas PASS/FAIL. A validação Windows
  usou perfil protegido temporário em MSSQL e executou o produto sem exibir a
  senha ou o envelope. Um comando local de criação de chave usa o provedor de
  arquivos existente, com criação exclusiva e permissões restritas. Um
  preparador interno altera apenas a senha cifrada existente em memória e
  preserva os demais bytes; ele não autentica o novo envelope nem grava arquivos.
  Testes sintéticos passaram em Windows e Ubuntu WSL com o parser Harbour
  independente. Um segundo preparador autentica o envelope anterior no contexto
  do perfil, cifra e verifica a substituição e rejeita credenciais referenciadas
  por múltiplos perfis. Testes sintéticos no Windows cobrem a preparação e os
  casos de falha; ele também não grava arquivos. Um protótipo isolado de leitura
  no terminal recusa entrada redirecionada e restaura o estado nos cancelamentos
  testados; verificações sintéticas passaram em Windows e WSL com PTY. Ele não
  está ligado ao produto nem ao fluxo de atualização. Integração Linux, comando
  interativo, detecção de conflito, publicação atômica, implantação e aceite
  completo permanecem pendentes.
- [ ] C05: testar adulteração, chave errada/ausente, provedor indisponível,
  Unicode, concorrência, limpeza e sanitização; homologar SQL real com segredos
  sintéticos quando possível no Windows, além de build, execução e identidade
  de serviço no Linux. Registrar ambientes e escopos ainda não cobertos.
- [ ] C06: atualizar documentação bilíngue de configuração, instalação,
  dependências e segurança, evidências e ChangeLogs. Documentar migração e
  retorno à configuração anterior; preservar o uso atual de arquivo protegido
  até a aceitação da alternativa.

**Conclusão:** a entrega SQL e o utilitário funcionam nos escopos Windows/Linux
registrados e nas falhas previstas, com checks reproduzíveis e sem segredos nas
saídas verificadas. Integração de segredos NETIO/admin/HTTP, armazenamento
no Protheus/TLPP, cofres de SO/OpenBao opcionais e TLS por canal são etapas
futuras separadas, salvo inclusão explícita com aceite próprio. `RPCRDD`
permanece genérico.

## Pacote anterior

O pacote 003 entregou os exemplos de turnover controlado e de consultas
cadastradas e o drill-down Protheus real por TCP/HTTP no escopo registrado.
A evidência visual posterior confirmou uma transferência da SRE por TCP e HTTP;
a reconciliação histórica e o relatório mensal isolado seguem pendentes. Veja o
[histórico do pacote 003](docs/validation/package-003.pt-BR.md).
