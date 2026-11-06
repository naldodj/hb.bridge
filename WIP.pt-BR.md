# Pacote de trabalho ativo do hbBridge

[English](WIP.md) · [Roadmap](TODO.pt-BR.md) · [Homologação](docs/acceptance.pt-BR.md)

## Pacote 004: proteção portátil de credenciais no servidor

A primeira entrega protege uma credencial SQL configurada no hbBridge em repouso
no Windows e no Linux. O Protheus continua enviando somente o perfil SQL opaco e
o contexto de aplicação. O desenho comum deve permitir os consumidores NETIO,
administração e HTTP posteriormente; a proteção do cliente TLPP exige provedor
próprio comprovado. Armazenamento de segredos e segurança em trânsito exigem
aceites separados. Veja a [análise de credenciais](docs/credentials.pt-BR.md).

- [ ] C01: inventariar configuração, consumidores, vazamentos, toolchain e testes;
  confirmar envelope autenticado versionado, provedor com chave externa,
  compatibilidade, recuperação e limites de segurança. Verificar entropia,
  criptografia e ABI do Zig 0.16 e identidade de serviço em cada plataforma.
- [ ] C02: implementar e testar o provedor local portátil e ciclo da chave;
  cifragem autenticada, nonce único, vínculo ao contexto, erros explícitos,
  sem chave mestra embutida e com vida útil reduzida do segredo. Impedir fallback
  silencioso e uso do texto cifrado como senha quando a resolução falhar.
- [ ] C03: integrar o provedor a um perfil MSSQL com autenticação SQL e escape
  ODBC correto. Preservar autenticação integrada e configurações existentes;
  rejeitar combinações ambíguas e não expor segredos em diagnósticos, erros,
  config-info, descoberta ou logs.
- [ ] C04: oferecer utilitário local com entrada sem eco, segredos fora de
  argumentos, gravação atômica e orientações para permissões de chave, backup,
  atualização manual e migração. Sem rotação automática de senha do banco.
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
A validação visual do relatório mensal isolado, os movimentos reais da SRE e a
reconciliação histórica foram adiados, sem serem dados como aprovados. Veja o
[histórico do pacote 003](docs/validation/package-003.pt-BR.md).
