# zlib public headers

[Português](README.pt-BR.md)

zlib.h and zconf.h are unchanged public zlib 1.3.1 headers copied from Harbour
src/3rd/zlib at
[8d94c31367104a57eb9ae6fa248cca2abb8db309](https://github.com/harbour/core/tree/8d94c31367104a57eb9ae6fa248cca2abb8db309/src/3rd/zlib).
The license notice remains in zlib.h. Preserve upstream formatting.

The C codecs call the zlib already linked by Harbour; this directory adds
neither another implementation nor a DLL. Headers are included because the
previous Harbour package did not install them beside the C API. inflateInit2
checks library/structure compatibility at initialization. Managed dependency
updates must preserve compatibility and pass codec regressions.

zlib.hbp records provenance and LF-normalized SHA256 values for read-only
.hbcommit/3rdpatch.hb validation in the commit gate; validation does not
download, patch or regenerate headers.
