/* Released to Public Domain. Synthetic serialization and binary file probe. */

PROCEDURE Main( cFile )

    LOCAL cData, cRemainder

    LOCAL hFixture := { "version" => 1, "profile" => "sql/example", ;
        "bytes" => Chr( 0 ) + "synthetic" + Chr( 26 ) }, hRead

    IF ! HB_ISSTRING( cFile ) .OR. Empty( cFile )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    cData := hb_Serialize( hFixture )
    IF ! hb_MemoWrit( cFile, cData )
        OutErr( "Unable to write the synthetic probe." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    cRemainder := hb_MemoRead( cFile )
    IF ! ( cRemainder == cData )
        OutErr( "Binary file bytes changed." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    hRead := hb_Deserialize( @cRemainder )
    IF ! HB_ISHASH( hRead ) .OR. Len( cRemainder ) != 0
        OutErr( "Unable to decode the complete synthetic payload." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    IF ! hb_HHasKey( hRead, "version" ) .OR. ! hb_HHasKey( hRead, "profile" ) .OR. ;
        ! hb_HHasKey( hRead, "bytes" )
        OutErr( "Synthetic payload fields are missing." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    IF hRead[ "version" ] != 1 .OR. ! ( hRead[ "profile" ] == hFixture[ "profile" ] ) .OR. ;
        ! ( hRead[ "bytes" ] == hFixture[ "bytes" ] )
        OutErr( "Synthetic payload values changed." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    IF ! hb_MemoWrit( cFile, cData + Chr( 26 ) )
        OutErr( "Unable to write the trailing-byte probe." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    cRemainder := hb_MemoRead( cFile )
    IF ! ( cRemainder == cData + Chr( 26 ) )
        OutErr( "The trailing EOF byte changed." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    hRead := hb_Deserialize( @cRemainder )
    IF ! HB_ISHASH( hRead ) .OR. ! ( cRemainder == Chr( 26 ) )
        OutErr( "The trailing data was not preserved." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    OutStd( "Harbour serialization and binary file probe passed." + hb_eol() )
RETURN
