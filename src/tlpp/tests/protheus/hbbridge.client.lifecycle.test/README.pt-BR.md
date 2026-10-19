# Ciclo de vida do componente cliente TCP

[English](README.md) · [Benchmark](../hbbridge.benchmark.test/README.pt-BR.md) · [Pacote ativo](../../../../../WIP.pt-BR.md)

`HBBridge.Test.HBBridgeClientLifecycleTest` exercita requisições TCP repetidas
sem carga SQL. `HBBridgeClient` mantém um `TSocketClient` nativo criado sob
demanda e reconecta esse componente a cada requisição. O contrato continua
sendo uma requisição/resposta por conexão TCP. Isso evita criar um componente
do terminal para cada página de uma varredura extensa do dataset.

Compile este diretório com toda a árvore `src/tlpp`. Informe explicitamente
host/porta TCP de um hbBridge ativo e outra porta do mesmo host, verificada
como fechada. O teste não inicia listeners nem altera qualquer INI. Não exige
perfil SQL, token HTTP nem credencial do banco.

```tlpp
// 1513 é apenas exemplo: verificar que está fechada antes de utilizar.
nResult := U_HBBridgeClientLifecycleTest("127.0.0.1", 1512, 1513, 6000, 30000)
```

Argumentos: host, porta ativa, porta recusada, quantidade de chamadas Health
repetidas e timeout por requisição em milissegundos. Host e ambas as portas
são obrigatórios. A quantidade e o timeout omitidos usam 6000 e 30000 ms.
A quantidade é configurável; 6000 supera as 5020 requisições de páginas TCP
da rodada registrada com 500 iterações, dois aquecimentos e dez páginas por
iteração. Não repete a leitura de 50 milhões de linhas SQL.

Para um ambiente CLI licenciado do AppServer, com o INI privado junto ao executável:

```bat
appserver.exe -ini="private-lifecycle.ini" -run=U_HBBridgeClientLifecycleCLI -env=PROTHEUS --host=127.0.0.1 --port=1512 --refused-port=1513 --calls=6000 --timeout-ms=30000
```

As flags usam entradas únicas `--nome=valor` e inteiros decimais positivos
canônicos. O timeout se aplica a cada requisição; não é um prazo total da
rodada. O progresso é registrado a cada 1000 chamadas Health bem-sucedidas.

O relatório retornado/impresso contém 17 verificações com chaves: Health inicial
de dois clientes independentes, chamadas repetidas, serviço inexistente seguido
de recuperação no mesmo cliente, isolamento do segundo cliente, duas tentativas
recusadas, recuperação do cliente saudável, limpeza idempotente e rejeição
de chamadas após fechar. Fechar o primeiro cliente deve manter o segundo
utilizável. A recusa só é aceita com código `CONNECT_FAILED`; uma porta de
recusa que esteja ativa reprova o teste. Falhas preservam categorias seguras,
sem descrições nativas, endpoints ou payloads. `Run(...)` retorna `JSONObject`
de propriedade do chamador; as entradas públicas `U_` imprimem seu JSON e
retornam 0 no sucesso ou 1 na falha.

`Close()` fecha definitivamente aquele cliente e tenta a limpeza nativa com
`CloseConnection()`/`FreeObj`. Retorna falso se o cliente estiver ocupado ou
se a limpeza falhar. Chamadas posteriores retornam `CLIENT_CLOSED`. Cada
tentativa normal ou malsucedida também fecha sua conexão antes da próxima
chamada. Utilizar um cliente próprio por worker; este teste não deduz
compartilhamento entre threads a partir da mitigação estática anterior.

A reflexão opcional `ClassMethArray` informa os nomes de métodos de limpeza
nativos disponíveis no runtime testado. O teste não presume nem chama métodos
`End`/`Destroy` sem contrato documentado. Não mede registro do terminal, alocador
nativo nem memória do processo; requisições repetidas aprovadas não comprovam
ausência de vazamentos. A reflexão usa o array posicional fornecido pela API
nativa; verificações e relatórios permanecem em objetos JSON com chaves.

O aceite focado no AppServer CLI em 2026-10-18 passou em 6000 chamadas
Health e 17 checks, saída 0. Evidência:
`tmp/comparison-protheus-0d6eed2eb4554737acfe9a05f902d8da/validation.json`,
`results.lifecycle`. O fonte atual do cliente corresponde ao snapshot registrado.
[Evidência V01 consolidada](../../../../../docs/acceptance.pt-BR.md#v01-v02-benchmark-acceptance-on-2026-10-19).
O resultado homologa o ciclo/recuperação exercitado, sem comprovar ausência de
vazamentos no alocador/registro do terminal. M08 mantém seu escopo anterior;
a repetição manual TCP/HTTP ampliada continua reprovada.
