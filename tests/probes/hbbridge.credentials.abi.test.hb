/* Released to Public Domain. Synthetic ABI probe; not a credential provider. */

PROCEDURE Main()

    LOCAL cData

    LOCAL hFixture := { "profile" => "sql/example", "bytes" => Chr( 0 ) + Chr( 26 ) }

    cData := hb_Serialize( hFixture )
    IF ! HBBridgeCredentialProbe( cData ) .OR. HBBridgeCredentialProbe( NIL )
        OutErr( "Credential ABI probe failed." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    OutStd( "Harbour/C/Zig credential ABI probe passed." + hb_eol() )
RETURN
