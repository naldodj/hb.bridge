# Testes de regressão do dataset

[English](README.md) · [Contrato do dataset](../../../../../docs/dataset.pt-BR.md)

Compile este diretório com os fontes atuais de cliente/dataset em `src/tlpp`
em RPO dedicado de teste do AppServer e execute:

```advpl
U_HBBridgeDataSetTest()
U_HBBridgeTypedDataSetTest()
```

A suíte comum verifica metadados versão 1, totais, fronteiras de páginas, erros,
recuperação e cópias defensivas. A suíte tipada usa o mesmo mock de cliente e a
implementação real de `JSONObject`/dataset: versões estritas de requisição/
resultado, bindings canônicos, NULL versus ausente, UTF-8/NUL, strings exatas
inteiras/decimais, metadados de origem/transporte, entradas imutáveis entre
páginas e ausência de fallback sem bind. Ambas imprimem checks e totais.
A tipada devolve 0/1 numérico; a procedure antiga pode devolver -4 no CLI mesmo
com resumo explícito bem-sucedido.

São testes determinísticos do contrato cliente, sem conexão SQL ou navegador.
Os testes nativos de backend/transporte são reproduzidos por
`scripts/test-hbbridge-typed-sql.ps1`; homologação AppServer/backend e apresentação
permanecem separadas. O [manifesto da integração](../../../../../docs/validation/typed.sql.windows.json)
registra identidades dos fontes/RPO e escopo aceito.
