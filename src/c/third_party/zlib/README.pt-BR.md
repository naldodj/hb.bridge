# Cabeçalhos zlib

[English](README.md)

`zlib.h` e `zconf.h` são os cabeçalhos públicos zlib 1.3.1, copiados sem
alterações de `src/3rd/zlib/` do Harbour no commit
[`8d94c31367104a57eb9ae6fa248cca2abb8db309`](https://github.com/harbour/core/tree/8d94c31367104a57eb9ae6fa248cca2abb8db309/src/3rd/zlib).
O aviso de licença zlib está preservado em `zlib.h`.

O decoder C usa esses cabeçalhos para chamar a zlib já vinculada pelo Harbour.
Não há outra implementação zlib nem uma nova DLL neste diretório. Os headers
ficam no repositório porque o pacote Harbour usado no build não os instala
junto à API C. `inflateInit2` verifica a compatibilidade da versão e da
estrutura com a biblioteca vinculada durante a inicialização.

Preservar a formatação original desses arquivos de terceiros.
