/* Released to Public Domain. Read-only protected SQL credential acceptance. */

PROCEDURE HBBridgeMSSQLCredentialTest( cConfigPath, cProfile, cExecutable )

    LOCAL cCommand, cError, cKeyPath, cEnvelope, cUser, cPassword, cFixturePath, cOutput, cStderr

    LOCAL hDefaults, hInput, hRaw, hProtected, hFixture, hConfig, hProfiles, hRegistry, hResult

    LOCAL lSuccess := .F., lKeyCreated := .F., lConfigCreated := .F.

    LOCAL nExit

    cKeyPath := HBBridgeAbsolutePath( "protected-mssql-fixture.key", hb_cwd() )
    cFixturePath := HBBridgeAbsolutePath( "protected-mssql-fixture.json", hb_cwd() )
    BEGIN SEQUENCE WITH __BreakBlock()
        IF ! HB_ISSTRING( cConfigPath ) .OR. ! HB_ISSTRING( cProfile ) .OR. ! hb_FileExists( cConfigPath )
            OutErr( "MSSQL protected credential prerequisite: CONFIG_AND_PROFILE_REQUIRED" + hb_eol() )
            Break( NIL )
        ENDIF
        hDefaults := HBBridgeConfig( {}, @cError )
        hInput := HBBridgeConfigINI( hb_MemoRead( cConfigPath ), hDefaults, @cError )
        IF ! HB_ISHASH( hInput ) .OR. ! hb_HHasKey( hInput, "sqlProfiles" ) .OR. ;
            ! hb_HHasKey( hInput[ "sqlProfiles" ], cProfile )
            OutErr( "MSSQL protected credential prerequisite: PROFILE_UNAVAILABLE" + hb_eol() )
            Break( NIL )
        ENDIF
        hRaw := hInput[ "sqlProfiles" ][ cProfile ]
        IF ! HB_ISHASH( hRaw ) .OR. hb_HGetDef( hRaw, "driver", "" ) != "mssql" .OR. ;
            hb_HGetDef( hRaw, "authentication", "" ) != "sql" .OR. ;
            ! hb_HHasKey( hRaw, "username" ) .OR. ! hb_HHasKey( hRaw, "password" ) .OR. ;
            hb_HHasKey( hRaw, "connectionString" ) .OR. hb_HHasKey( hRaw, "credential" )
            OutErr( "MSSQL protected credential prerequisite: STRUCTURED_SQL_AUTH_REQUIRED" + hb_eol() )
            Break( NIL )
        ENDIF
        cUser := hRaw[ "username" ]
        cPassword := hRaw[ "password" ]
        lKeyCreated := HBBridgeCredentialCreateKey( cKeyPath, @cError )
        IF ! lKeyCreated
            OutErr( "MSSQL protected credential prerequisite: KEY_CREATION_FAILED" + hb_eol() )
            Break( NIL )
        ENDIF
        cEnvelope := HBBridgeCredentialEncrypt( cKeyPath, cProfile, "acceptance", "fixture", cUser, cPassword, @cError )
        IF ! HB_ISSTRING( cEnvelope )
            OutErr( "MSSQL protected credential prerequisite: ENCRYPTION_FAILED" + hb_eol() )
            Break( NIL )
        ENDIF
        hProtected := hb_HClone( hRaw )
        hb_HDel( hProtected, "username" )
        hb_HDel( hProtected, "password" )
        hProtected[ "credential" ] := "acceptance"
        hFixture := { "sqlProfiles" => { cProfile => hProtected }, ;
            "credentials" => { "acceptance" => { "user" => cUser, "keyId" => "fixture", "password" => cEnvelope } }, ;
            "credentialKeys" => { "fixture" => { "provider" => "file", "location" => cKeyPath } } }
        IF hb_FileExists( cFixturePath )
            OutErr( "MSSQL protected credential prerequisite: FIXTURE_WRITE_FAILED" + hb_eol() )
            Break( NIL )
        ENDIF
        lConfigCreated := .T.
        IF ! hb_MemoWrit( cFixturePath, hb_jsonEncode( hFixture ) )
            OutErr( "MSSQL protected credential prerequisite: FIXTURE_WRITE_FAILED" + hb_eol() )
            Break( NIL )
        ENDIF
        hConfig := HBBridgeConfig( { "-config=" + cFixturePath }, @cError )
        IF ! HB_ISHASH( hConfig )
            OutErr( "MSSQL protected credential prerequisite: PROFILE_INVALID" + hb_eol() )
            Break( NIL )
        ENDIF
        hProfiles := hConfig[ "sqlProfiles" ]
        IF ! HB_ISHASH( hProfiles )
            OutErr( "MSSQL protected credential prerequisite: PROFILE_INVALID" + hb_eol() )
            Break( NIL )
        ENDIF
        IF ! HBBridgeCredentialTestCommand( { "--credential-test", "--config=" + cFixturePath, ;
            "--profile=" + cProfile } )
            OutErr( "MSSQL protected credential prerequisite: CONNECTION_TEST_FAILED" + hb_eol() )
            Break( NIL )
        ENDIF
        IF HB_ISSTRING( cExecutable ) .AND. ! Empty( cExecutable )
            IF ! hb_FileExists( cExecutable ) .OR. '"' $ cExecutable .OR. '"' $ cFixturePath .OR. '"' $ cProfile
                OutErr( "MSSQL protected credential prerequisite: CLI_PATH_INVALID" + hb_eol() )
                Break( NIL )
            ENDIF
            cCommand := '"' + cExecutable + '" --credential-test "--config=' + cFixturePath + ;
                '" "--profile=' + cProfile + '"'
            nExit := hb_processRun( cCommand, NIL, @cOutput, @cStderr )
            IF nExit != 0 .OR. ! ( "Credential connection test: PASS" $ cOutput ) .OR. ;
                cPassword $ cOutput .OR. cPassword $ cStderr .OR. cEnvelope $ cOutput .OR. cEnvelope $ cStderr
                OutErr( "MSSQL protected credential prerequisite: CLI_TEST_FAILED" + hb_eol() )
                Break( NIL )
            ENDIF
        ENDIF
        hRegistry := HBBridgeBuiltinRegistry( hProfiles )
        hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
            { "alias" => cProfile, "sql" => "SELECT 1 AS ID" }, HBBridgeContext( "credential-test" ) )
        lSuccess := HB_ISHASH( hResult ) .AND. hb_HGetDef( hResult, "success", .F. ) .AND. ;
            hResult[ "rows" ][ "1" ][ "ID" ] == 1
    RECOVER
        lSuccess := .F.
        OutErr( "MSSQL protected credential test did not complete." + hb_eol() )
    ALWAYS
        cPassword := NIL
        cEnvelope := NIL
        hRaw := NIL
        hInput := NIL
        IF lKeyCreated
            IF FErase( cKeyPath ) != 0
                lSuccess := .F.
            ENDIF
        ENDIF
        IF lConfigCreated .AND. hb_FileExists( cFixturePath )
            IF FErase( cFixturePath ) != 0
                lSuccess := .F.
            ENDIF
        ENDIF
    END SEQUENCE
    OutStd( iif( lSuccess, "PASS", "FAIL" ) + ": protected MSSQL credential and read-only SELECT; key cleanup" + hb_eol() )
    ErrorLevel( iif( lSuccess, 0, 1 ) )
RETURN
