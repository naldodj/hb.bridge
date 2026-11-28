/* Released to Public Domain. */

PROCEDURE HBBridgeCredentialTransportTests( nFailures, nChecks )

    LOCAL aCases := { "missing", "altered" }

    LOCAL cCase, cError, cKey, cPath, cToken

    LOCAL hConfig, hFile, hHTTP, hRegistry, hTCP

    LOCAL lKeyCreated := .F., lPrepared := .T.

    LOCAL nHandle := hb_FTempCreateEx( @cPath, hb_cwd(), "HBWirePrivate", ".json" )

    LOCAL xFailure

    M1Assert( nHandle >= 0, "credential transport owns its synthetic configuration", @nFailures, @nChecks )
    IF nHandle < 0
        RETURN
    ENDIF
    FClose( nHandle )
    cKey := cPath + ".HBWirePrivate.key"
    cToken := "HBWirePrivate" + Left( hb_MD5( cPath ), 16 )
    BEGIN SEQUENCE WITH {|oError| Break( oError ) }
        lKeyCreated := HBBridgeCredentialCreateKey( cKey, @cError )
        M1Assert( lKeyCreated .AND. ! hb_FileExists( cKey + ".absent" ), ;
            "credential transport owns a fresh key and a missing-key reference", @nFailures, @nChecks )
        IF ! lKeyCreated .OR. hb_FileExists( cKey + ".absent" )
            BREAK
        ENDIF
        hFile := { "sqlProfiles" => {=>}, "credentials" => {=>}, "credentialKeys" => {=>} }
        FOR EACH cCase IN aCases
            lPrepared := WireProfile( hFile, cCase, cKey, cToken ) .AND. lPrepared
        NEXT
        M1Assert( lPrepared, "original credentials authenticate before injecting both faults", @nFailures, @nChecks )
        IF ! lPrepared .OR. ! hb_MemoWrit( cPath, hb_jsonEncode( hFile ) )
            M1Assert( .F., "credential transport writes the fixture", @nFailures, @nChecks )
            BREAK
        ENDIF
        hConfig := HBBridgeConfig( { "-config=" + cPath }, @cError )
        M1Assert( HB_ISHASH( hConfig ), "protected transport configuration loads", @nFailures, @nChecks )
        IF ! HB_ISHASH( hConfig )
            BREAK
        ENDIF
        hConfig[ "httpHost" ] := "127.0.0.1"
        hConfig[ "httpPassword" ] := cToken
        hRegistry := HBBridgeBuiltinRegistry( hConfig[ "sqlProfiles" ] )
        hTCP := HBBridgeServerStart( 0, 4, "127.0.0.1", hRegistry, NIL, hConfig )
        hConfig[ "httpPort" ] := HBBridgeHTTPTestFreePort()
        hHTTP := HBBridgeHTTPStart( hConfig, hRegistry, NIL, @cError )
        M1Assert( HB_ISHASH( hTCP ) .AND. HB_ISHASH( hHTTP ), ;
            "credential TCP and HTTP listeners start on loopback", @nFailures, @nChecks )
        IF HB_ISHASH( hTCP ) .AND. HB_ISHASH( hHTTP )
            FOR EACH cCase IN aCases
                WireCase( cCase, hTCP[ "port" ], hConfig, @nFailures, @nChecks )
            NEXT
            M1Assert( ! HBBridgeODBCPoolingInfo()[ "frozen" ], ;
                "credential failures leave the ODBC connection path untouched", @nFailures, @nChecks )
        ENDIF
    RECOVER USING xFailure
        IF xFailure != NIL
            M1Assert( .F., "unexpected credential transport fixture error", @nFailures, @nChecks )
        ENDIF
    ALWAYS
        IF HB_ISHASH( hHTTP )
            M1Assert( HBBridgeHTTPStop( hHTTP ), "credential HTTP listener stops", @nFailures, @nChecks )
        ENDIF
        IF HB_ISHASH( hTCP )
            M1Assert( HBBridgeServerStop( hTCP ), "credential TCP listener stops", @nFailures, @nChecks )
        ENDIF
        IF lKeyCreated
            M1Assert( FErase( cKey ) == 0, "credential transport removes owned key", @nFailures, @nChecks )
        ENDIF
        M1Assert( FErase( cPath ) == 0, "credential transport removes owned configuration", @nFailures, @nChecks )
    END SEQUENCE
RETURN

STATIC FUNCTION WireProfile( hFile, cCase, cKey, cToken )

    LOCAL cAlias := "wire/" + cCase, cBytes, cEnvelope, cError, cId := cToken + "ref" + cCase
    LOCAL cKeyId := cToken + "key" + cCase, cPassword := cToken + "pass" + cCase, cUser := cToken + "user" + cCase

    cEnvelope := HBBridgeCredentialEncrypt( cKey, cAlias, cId, cKeyId, cUser, cPassword, @cError )
    IF ! HB_ISSTRING( cEnvelope ) .OR. ;
        ! ( HBBridgeCredentialDecrypt( cKey, cAlias, cId, cKeyId, cUser, cEnvelope, @cError ) == cPassword )
        RETURN .F.
    ENDIF
    IF cCase == "altered"
        cBytes := hb_base64Decode( hb_BSubStr( cEnvelope, 8 ) )
        hb_BPoke( @cBytes, hb_BLen( cBytes ), hb_bitXor( hb_BCode( hb_BRight( cBytes, 1 ) ), 1 ) )
        cEnvelope := "enc:v1:" + hb_base64Encode( cBytes )
    ENDIF
    hFile[ "sqlProfiles" ][ cAlias ] := { "driver" => "mssql", "dsn" => Left( cToken, 24 ), ;
        "authentication" => "sql", "credential" => cId }
    hFile[ "credentials" ][ cId ] := { "user" => cUser, "password" => cEnvelope, "keyId" => cKeyId }
    hFile[ "credentialKeys" ][ cKeyId ] := { "provider" => "file", ;
        "location" => iif( cCase == "missing", cKey + ".absent", cKey ) }
RETURN .T.

STATIC PROCEDURE WireCase( cCase, nPort, hConfig, nFailures, nChecks )

    LOCAL cAlias := "wire/" + cCase, cAuth := "Bearer " + hConfig[ "httpPassword" ]
    LOCAL cEcho := '{"service":"Echo","params":{"id":42}}', cError, cPlain, cRequest

    LOCAL hContract := { "code" => "CONNECTION_FAILED", "error" => "Database connection is unavailable." }
    LOCAL hCredential := hConfig[ "sqlProfiles" ][ cAlias ][ "credential" ], hHTTP, hTCP

    M1Assert( HBBridgeCredentialDecrypt( hCredential[ "keyPath" ], cAlias, hCredential[ "id" ], hCredential[ "keyId" ], ;
        hCredential[ "user" ], hCredential[ "envelope" ], @cError ) == NIL .AND. ;
        cError == iif( cCase == "missing", "KEY_UNAVAILABLE", "AUTHENTICATION_FAILED" ), ;
        "provider distinguishes the injected credential fault: " + cCase, @nFailures, @nChecks )
    M1Assert( HBBridgeSQLConnection( cAlias, hConfig[ "sqlProfiles" ][ cAlias ], @cError ) == NIL .AND. ;
        cError == "SQL credential is unavailable.", "resolver rejects credential: " + cCase, @nFailures, @nChecks )
    cRequest := hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => { "alias" => cAlias, "sql" => "SELECT 1" } } )
    hTCP := MTRequest( nPort, cRequest,, @cPlain )
    M1Assert( HBBridgeTestSQLSafeFailure( hTCP, hContract ) .AND. WireClean( cPlain ), ;
        "TCP returns the sanitized credential failure: " + cCase, @nFailures, @nChecks )
    hTCP := MTRequest( nPort, cEcho,, @cPlain )
    M1Assert( WireEcho( hTCP ) .AND. WireClean( cPlain ), "TCP Echo after " + cCase, @nFailures, @nChecks )
    hHTTP := HBBridgeHTTPTestRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", cRequest, cAuth )
    M1Assert( hHTTP[ "status" ] == 500 .AND. HBBridgeTestSQLSafeFailure( hHTTP[ "json" ], hContract ) .AND. ;
        WireClean( hHTTP[ "headers" ] + hHTTP[ "decodedBody" ] ), ;
        "HTTP returns the sanitized credential failure: " + cCase, @nFailures, @nChecks )
    hHTTP := HBBridgeHTTPTestRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", cEcho, cAuth )
    M1Assert( hHTTP[ "status" ] == 200 .AND. WireEcho( hHTTP[ "json" ] ) .AND. ;
        WireClean( hHTTP[ "headers" ] + hHTTP[ "decodedBody" ] ), "HTTP Echo after " + cCase, @nFailures, @nChecks )
RETURN

STATIC FUNCTION WireClean( cPlain )
RETURN HB_ISSTRING( cPlain ) .AND. ! Empty( cPlain ) .AND. ! ( "HBWirePrivate" $ cPlain ) .AND. ! ( "enc:v1:" $ cPlain )

STATIC FUNCTION WireEcho( hResponse )
RETURN HB_ISHASH( hResponse ) .AND. hb_HGetDef( hResponse, "success", .F. ) == .T. .AND. ;
    HB_ISHASH( hb_HGetDef( hResponse, "params", NIL ) ) .AND. hb_HGetDef( hResponse[ "params" ], "id", NIL ) == 42
