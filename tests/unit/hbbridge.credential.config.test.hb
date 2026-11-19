/* Released to Public Domain. Synthetic SQL credential configuration tests. */

PROCEDURE HBBridgeCredentialConfigTests( nFailures, nChecks )

    LOCAL cError, cEnvelope, cINI, cKeyPath, cCommandKeyPath, cKeyBytes, cConfigPath, cJSONPath, cConnection, cInfo
    LOCAL cProfile := "MSSQL/pData", cId := "example", cKeyId := "primary"
    LOCAL cUser := "fixture}user", cPassword := " synthetic;} "

    LOCAL hConfig, hNormalized, hProfile, hJSON, hBound, hBad, hCredentials, hKeys, hRegistry, hResult

    LOCAL lCommandFixture := .F., lKeyCreated := .F., lINICreated := .F., lJSONCreated := .F.

    LOCAL oPool

    cKeyPath := HBBridgeAbsolutePath( "credential-config-fixture.key", hb_cwd() )
    cCommandKeyPath := HBBridgeAbsolutePath( "credential-command-fixture.key", hb_cwd() )
    cConfigPath := HBBridgeAbsolutePath( "credential-config-fixture.ini", hb_cwd() )
    cJSONPath := HBBridgeAbsolutePath( "credential-config-fixture.json", hb_cwd() )
    BEGIN SEQUENCE WITH __BreakBlock()
        IF hb_FileExists( cConfigPath ) .OR. hb_FileExists( cJSONPath ) .OR. ;
            hb_FileExists( cKeyPath ) .OR. hb_FileExists( cCommandKeyPath )
            M1Assert( .F., "SQL credential synthetic fixture paths are unused", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        lCommandFixture := .T.
        M1Assert( ! HBBridgeCredentialKeyCommand( { "--credential-create-key", "--key=" + cCommandKeyPath, ;
            "--password=synthetic-secret" } ) .AND. ! hb_FileExists( cCommandKeyPath ), ;
            "key command rejects extra secret arguments before file creation", @nFailures, @nChecks )
        M1Assert( HBBridgeCredentialKeyCommand( { "--credential-create-key", "--key=" + cCommandKeyPath } ), ;
            "key command creates a private key", @nFailures, @nChecks )
        cKeyBytes := hb_MemoRead( cCommandKeyPath )
        M1Assert( hb_BLen( cKeyBytes ) == 32 .AND. ;
            ! HBBridgeCredentialKeyCommand( { "--credential-create-key", "--key=" + cCommandKeyPath } ) .AND. ;
            hb_MemoRead( cCommandKeyPath ) == cKeyBytes, ;
            "key command never replaces an existing key", @nFailures, @nChecks )
        cKeyBytes := NIL
        lKeyCreated := HBBridgeCredentialCreateKey( cKeyPath, @cError )
        IF ! lKeyCreated
            M1Assert( .F., "SQL credential synthetic key is created", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        cEnvelope := HBBridgeCredentialEncrypt( cKeyPath, cProfile, cId, cKeyId, cUser, cPassword, @cError )
        IF ! HB_ISSTRING( cEnvelope )
            M1Assert( .F., "SQL credential synthetic envelope is created", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        cINI := "[SQL/" + cProfile + "]" + hb_eol() + "Driver=mssql" + hb_eol() + ;
            "Authentication=sql" + hb_eol() + "DSN=__HBBridgeMissingDSN__" + hb_eol() + ;
            "Credential=" + cId + hb_eol() + "[Credential/" + cId + "]" + hb_eol() + ;
            "User=" + cUser + hb_eol() + "KeyId=" + cKeyId + hb_eol() + "Password=" + cEnvelope + hb_eol() + ;
            "[Key/" + cKeyId + "]" + hb_eol() + "Provider=file" + hb_eol() + ;
            "Location=credential-config-fixture.key" + hb_eol()
        lINICreated := .T.
        IF ! hb_MemoWrit( cConfigPath, cINI )
            M1Assert( .F., "SQL credential synthetic INI is written", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        hConfig := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )
        M1Assert( HB_ISHASH( hConfig ), "SQL credential INI binds a protected profile", @nFailures, @nChecks )
        IF ! HB_ISHASH( hConfig )
            Break( NIL )
        ENDIF
        hProfile := hConfig[ "sqlProfiles" ][ cProfile ]
        M1Assert( ! HBBridgeCredentialTestCommand( { "--credential-test", "--config=", "--config=x", ;
            "--profile=x" } ) .AND. ! HBBridgeCredentialTestCommand( { "--credential-test", ;
            "--config=x", "--profile=x", "--password=synthetic-secret" } ), ;
            "local credential test rejects duplicate options and password arguments", @nFailures, @nChecks )
        M1Assert( ! HBBridgeCredentialTestProfile( hConfig, "missing" ) .AND. ;
            ! HBBridgeCredentialTestProfile( NIL, cProfile ), ;
            "local credential test rejects missing profile and invalid configuration", @nFailures, @nChecks )
        M1Assert( ! HBBridgeCredentialTestProfile( { "sqlProfiles" => { cProfile => ;
            { "driver" => "mssql", "username" => "fixture", "password" => "fixture" } } }, cProfile ) .AND. ;
            ! HBBridgeCredentialTestProfile( { "sqlProfiles" => { cProfile => ;
            { "driver" => "sqlite", "database" => ":memory:" } } }, cProfile ), ;
            "local credential test rejects plaintext and non-MSSQL profiles", @nFailures, @nChecks )
        M1Assert( ! HBBridgeCredentialTestProfile( hConfig, cProfile ), ;
            "local credential test fails closed when the MSSQL DSN is unavailable", @nFailures, @nChecks )
        M1Assert( HB_ISHASH( hProfile[ "credential" ] ) .AND. ! hb_HHasKey( hProfile, "connectionString" ) .AND. ;
            hProfile[ "credential" ][ "keyPath" ] == cKeyPath, ;
            "SQL profile keeps the encrypted reference and resolves the key path", @nFailures, @nChecks )
        hNormalized := HBBridgeSQLProfiles( { cProfile => hProfile }, hb_cwd(), @cError )
        M1Assert( HB_ISHASH( hNormalized ) .AND. ;
            hNormalized[ cProfile ][ "credential" ][ "envelope" ] == cEnvelope, ;
            "SQL credential survives repeated normalization", @nFailures, @nChecks )
        cInfo := hb_jsonEncode( HBBridgeConfigInfo( hConfig ) )
        M1Assert( ! ( cEnvelope $ cInfo ) .AND. ! ( cUser $ cInfo ) .AND. ! ( cKeyPath $ cInfo ), ;
            "config-info excludes the credential and key location", @nFailures, @nChecks )
        cConnection := HBBridgeSQLConnection( cProfile, hProfile, @cError )
        M1Assert( HB_ISSTRING( cConnection ) .AND. cError == "" .AND. ;
            "UID={fixture}}user};" $ cConnection .AND. "PWD={ synthetic;}} };" $ cConnection, ;
            "resolved SQL credential uses ODBC-safe escaping", @nFailures, @nChecks )
        cConnection := NIL
        hRegistry := HBBridgeBuiltinRegistry( { cProfile => hProfile } )
        hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", { "alias" => cProfile, "sql" => "SELECT 1" }, ;
            HBBridgeContext( "credential-test" ) )
        cInfo := hb_jsonEncode( hResult )
        M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "CONNECTION_FAILED" .AND. ;
            ! ( cPassword $ cInfo ) .AND. ! ( cUser $ cInfo ) .AND. ! ( cEnvelope $ cInfo ) .AND. ! ( cKeyPath $ cInfo ), ;
            "protected profile connection failure does not disclose credentials", @nFailures, @nChecks )
        M1Assert( HBBridgeSQLConnection( "other/profile", hProfile, @cError ) == NIL .AND. ;
            cError == "SQL credential is unavailable.", "changed profile fails closed", @nFailures, @nChecks )
        hBad := hb_HClone( hProfile )
        hBad[ "credential" ] := hb_HClone( hProfile[ "credential" ] )
        hBad[ "credential" ][ "keyPath" ] := cKeyPath + ".missing"
        M1Assert( HBBridgeSQLConnection( cProfile, hBad, @cError ) == NIL .AND. ;
            cError == "SQL credential is unavailable.", "missing key fails closed", @nFailures, @nChecks )
        M1Assert( hb_MemoWrit( cConfigPath, StrTran( cINI, "Location=credential-config-fixture.key", ;
            "Location=credential-config-fixture.key.missing" ) ), ;
            "missing-key configuration fixture is written", @nFailures, @nChecks )
        hConfig := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )
        M1Assert( HB_ISHASH( hConfig ) .AND. ;
            HBBridgeSQLConnection( cProfile, hConfig[ "sqlProfiles" ][ cProfile ], @cError ) == NIL .AND. ;
            cError == "SQL credential is unavailable.", ;
            "configuration is accepted without opening the key and fails at connection", @nFailures, @nChecks )
        oPool := HBBridgeSQLPool():New( hb_mutexCreate() )
        M1Assert( oPool:RegisterProfile( cProfile, hBad ) .AND. oPool:Acquire( cProfile ) == NIL, ;
            "SQL pool does not connect when credential resolution fails", @nFailures, @nChecks )
        oPool:Destroy()
        hBad := hb_HClone( hProfile )
        hBad[ "credential" ] := hb_HClone( hProfile[ "credential" ] )
        hBad[ "credential" ][ "envelope" ] := cEnvelope + "x"
        M1Assert( HBBridgeSQLConnection( cProfile, hBad, @cError ) == NIL .AND. ;
            cError == "SQL credential is unavailable.", "altered envelope fails closed", @nFailures, @nChecks )
        hBad[ "credential" ][ "envelope" ] := cEnvelope
        hBad[ "credential" ][ "user" ] := "other-user"
        M1Assert( HBBridgeSQLConnection( cProfile, hBad, @cError ) == NIL .AND. ;
            cError == "SQL credential is unavailable.", "altered SQL username fails closed", @nFailures, @nChecks )
        hBad := hb_HClone( hProfile )
        hBad[ "username" ] := cUser
        M1Assert( HBBridgeSQLProfiles( { cProfile => hBad }, hb_cwd(), @cError ) == NIL, ;
            "credential reference rejects a concurrent plaintext username", @nFailures, @nChecks )
        hBad := hb_HClone( hProfile )
        hBad[ "password" ] := cPassword
        M1Assert( HBBridgeSQLProfiles( { cProfile => hBad }, hb_cwd(), @cError ) == NIL, ;
            "credential reference rejects a concurrent plaintext password", @nFailures, @nChecks )
        hBad := hb_HClone( hProfile )
        hBad[ "authentication" ] := "integrated"
        M1Assert( HBBridgeSQLProfiles( { cProfile => hBad }, hb_cwd(), @cError ) == NIL, ;
            "integrated authentication rejects a credential reference", @nFailures, @nChecks )
        hBad := hb_HClone( hProfile )
        hBad[ "connectionString" ] := "DSN=fixture;"
        M1Assert( HBBridgeSQLProfiles( { cProfile => hBad }, hb_cwd(), @cError ) == NIL, ;
            "raw connection string rejects a credential reference", @nFailures, @nChecks )
        hBad := { "driver" => "mssql", "dsn" => "fixture", "authentication" => "sql", ;
            "username" => "fixture", "password" => "enc:v1:invalid" }
        M1Assert( HBBridgeSQLProfiles( { cProfile => hBad }, hb_cwd(), @cError ) == NIL, ;
            "encrypted envelope is never used as a plaintext structured password", @nFailures, @nChecks )
        hBad[ "password" ] := "enc:legacy-plaintext"
        M1Assert( HB_ISHASH( HBBridgeSQLProfiles( { cProfile => hBad }, hb_cwd(), @cError ) ), ;
            "plaintext password without the reserved version prefix remains compatible", @nFailures, @nChecks )
        hCredentials := { cId => { "user" => cUser, "keyId" => cKeyId, "password" => cEnvelope } }
        hKeys := { cKeyId => { "provider" => "file", "location" => "credential-config-fixture.key" } }
        hJSON := { "sqlProfiles" => { cProfile => { "driver" => "mssql", "dsn" => "fixture", ;
            "authentication" => "sql", "credential" => cId } }, "credentials" => hCredentials, "credentialKeys" => hKeys }
        lJSONCreated := .T.
        M1Assert( hb_MemoWrit( cJSONPath, hb_jsonEncode( hJSON ) ), "synthetic credential JSON is written", @nFailures, @nChecks )
        hConfig := HBBridgeConfig( { "-config=" + cJSONPath }, @cError )
        M1Assert( HB_ISHASH( hConfig ) .AND. ;
            HB_ISSTRING( HBBridgeSQLConnection( cProfile, hConfig[ "sqlProfiles" ][ cProfile ], @cError ) ), ;
            "JSON credential resolves equivalently to INI", @nFailures, @nChecks )
        hBound := HBBridgeCredentialBindProfiles( hJSON[ "sqlProfiles" ], {=>}, hKeys, hb_cwd(), @cError )
        M1Assert( hBound == NIL .AND. cError == "Invalid credential configuration.", ;
            "missing credential is rejected without exposing values", @nFailures, @nChecks )
        hBound := HBBridgeCredentialBindProfiles( hJSON[ "sqlProfiles" ], hCredentials, {=>}, hb_cwd(), @cError )
        M1Assert( hBound == NIL .AND. cError == "Invalid credential configuration.", ;
            "missing key definition is rejected without exposing values", @nFailures, @nChecks )
        hKeys[ cKeyId ][ "provider" ] := "other"
        hBound := HBBridgeCredentialBindProfiles( hJSON[ "sqlProfiles" ], hCredentials, hKeys, hb_cwd(), @cError )
        M1Assert( hBound == NIL .AND. cError == "Invalid credential configuration.", ;
            "unsupported key provider fails closed", @nFailures, @nChecks )
    ALWAYS
        IF lCommandFixture .AND. hb_FileExists( cCommandKeyPath )
            FErase( cCommandKeyPath )
        ENDIF
        IF lKeyCreated
            FErase( cKeyPath )
        ENDIF
        IF lINICreated .AND. hb_FileExists( cConfigPath )
            FErase( cConfigPath )
        ENDIF
        IF lJSONCreated .AND. hb_FileExists( cJSONPath )
            FErase( cJSONPath )
        ENDIF
    END SEQUENCE
RETURN
