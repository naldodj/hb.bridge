/* Released to Public Domain. */
PROCEDURE M1INIConfigTests( nFailures, nChecks )

    LOCAL cError, hINI, hJSON, hInfo, cIni, cBad, cCase
    LOCAL cAutoFile := hb_FNameDir( hb_ProgName() ) + "hbbridge.ini"
    LOCAL cPrevious := NIL

    cIni := "[General]" + hb_eol() + "MaxWorkers=3" + hb_eol() + ;
        "AddonRoot=../addons" + hb_eol() + "[Protheus]" + hb_eol() + ;
        "Host=127.0.0.1" + hb_eol() + "Port=1700" + hb_eol() + ;
        "MaxPayloadBytes=0" + hb_eol() + "MaxWireBytes=0" + hb_eol() + ;
        "ReadChunkBytes=8192" + hb_eol() + "TimeoutMs=0" + hb_eol() + ;
        "[NETIO]" + hb_eol() + "Root=files" + hb_eol() + "Password=test;#=secret" + hb_eol() + ;
        "TimeoutMs=0" + hb_eol() + "[Admin]" + hb_eol() + "Password=" + hb_eol() + ;
        "[SQL/SqliteDemo]" + hb_eol() + "Driver=SQLite" + hb_eol() + "Database=sample.sqlite3" + hb_eol()
    hb_MemoWrit( "config-test/host.ini", cIni )
    hb_MemoWrit( "config-test/equivalent.json", ;
        '{"maxWorkers":3,"addonRoot":"../addons","protheusHost":"127.0.0.1",' + ;
        '"protheusPort":1700,"protheusMaxPayloadBytes":0,"protheusMaxWireBytes":0,' + ;
        '"protheusReadChunkBytes":8192,"protheusTimeoutMs":0,"netioRoot":"files",' + ;
        '"netioPassword":"test;#=secret","netioTimeout":0,"adminPassword":"",' + ;
        '"sqlProfiles":{"SqliteDemo":{"driver":"sqlite","database":"sample.sqlite3"}}}' )
    hINI := HBBridgeConfig( { "-config=config-test/host.ini" }, @cError )
    hJSON := HBBridgeConfig( { "-config=config-test/equivalent.json" } )
    M1Assert( hINI != NIL .AND. hJSON != NIL .AND. ;
        hb_jsonEncode( hINI ) == hb_jsonEncode( hJSON ), ;
        "INI and JSON normalize to the same typed configuration: " + cError, @nFailures, @nChecks )
    M1Assert( hINI[ "netioPassword" ] == "test;#=secret" .AND. Empty( hINI[ "adminPassword" ] ) .AND. ;
        hINI[ "sqlProfiles" ][ "SqliteDemo" ][ "database" ] == ;
        HBBridgeAbsolutePath( "config-test/sample.sqlite3", hb_cwd() ), ;
        "INI preserves password punctuation, empty admin and relative SQLite paths", @nFailures, @nChecks )
    hINI := HBBridgeConfig( { "-port=1701", "-maxworkers=4", "-config=config-test/host.ini" }, @cError )
    M1Assert( hINI != NIL .AND. hINI[ "protheusPort" ] == 1701 .AND. hINI[ "maxWorkers" ] == 4, ;
        "CLI overrides INI regardless of argument order", @nFailures, @nChecks )
    hINI := HBBridgeConfig( { "--config-info", "-config=config-test/host.ini", "-netioroot=cli-ini" } )
    M1Assert( hINI != NIL .AND. hINI[ "netioRoot" ] == HBBridgeAbsolutePath( "cli-ini", hb_cwd() ), ;
        "INI CLI paths remain relative to working directory", @nFailures, @nChecks )
    hb_MemoWrit( "config-test/mssql.INI", Chr( 239 ) + Chr( 187 ) + Chr( 191 ) + ;
        "; comment" + Chr( 13 ) + Chr( 10 ) + "# comment" + Chr( 13 ) + Chr( 10 ) + ;
        "[sql/MssqlDemo]" + Chr( 13 ) + Chr( 10 ) + Chr( 9 ) + "driver = MSSQL" + Chr( 9 ) + ;
        Chr( 13 ) + Chr( 10 ) + "ConnectionString = DSN=fixture;UID=include user;PWD=a#b;c=d;" )
    hINI := HBBridgeConfig( { "-config=config-test/mssql.INI" }, @cError )
    M1Assert( hINI != NIL .AND. hINI[ "sqlProfiles" ][ "MssqlDemo" ][ "driver" ] == "mssql" .AND. ;
        hINI[ "sqlProfiles" ][ "MssqlDemo" ][ "connectionString" ] == ;
        "DSN=fixture;UID=include user;PWD=a#b;c=d;", ;
        "INI handles BOM/CRLF/tabs/case while preserving complete ODBC values", @nFailures, @nChecks )
    hInfo := HBBridgeConfigInfo( hINI )
    M1Assert( hInfo[ "configVersion" ] == 1 .AND. hInfo[ "sqlProfiles" ][ "MssqlDemo" ][ "driver" ] == "mssql" .AND. ;
        ! ( "DSN=" $ hb_jsonEncode( hInfo ) ) .AND. ! ( "PWD=" $ hb_jsonEncode( hInfo ) ) .AND. ;
        Len( hInfo[ "sqlProfiles" ][ "MssqlDemo" ] ) == 1, ;
        "config-info metadata omits passwords, DSN and storage paths", @nFailures, @nChecks )

    hb_MemoWrit( "config-test/multiple.ini", ;
        "[SQL/sqlite_demo]" + hb_eol() + "Driver=sqlite" + hb_eol() + "Database=:memory:" + hb_eol() + ;
        "[SQL/mssql/pData]" + hb_eol() + "Driver=mssql" + hb_eol() + ;
        "ConnectionString=DSN=pData;Trusted_Connection=Yes;" + hb_eol() )
    hINI := HBBridgeConfig( { "-config=config-test/multiple.ini" }, @cError )
    M1Assert( hINI != NIL .AND. Len( hINI[ "sqlProfiles" ] ) == 2 .AND. ;
        hb_HHasKey( hINI[ "sqlProfiles" ], "mssql/pData" ) .AND. ;
        ! hb_HHasKey( hINI[ "sqlProfiles" ], "mssql/pdata" ), ;
        "multiple INI profiles preserve slash and case in opaque aliases", @nFailures, @nChecks )
    hInfo := HBBridgeConfigInfo( hINI )
    M1Assert( Len( hInfo[ "sqlProfiles" ] ) == 2 .AND. ;
        hInfo[ "sqlProfiles" ][ "mssql/pData" ][ "driver" ] == "mssql" .AND. ;
        ! ( "DSN=" $ hb_jsonEncode( hInfo ) ), ;
        "multiple profile metadata remains sanitized", @nFailures, @nChecks )
    FOR EACH cBad IN { ;
        "empty" => "", "noSection" => "Port=1512", "invalidLine" => "[General]" + hb_eol() + "broken", ;
        "unknownSection" => "[Service]" + hb_eol() + "Name=x", ;
        "unknownKey" => "[General]" + hb_eol() + "Workerz=1", ;
        "duplicateSection" => "[General]" + hb_eol() + "[general]", ;
        "duplicateKey" => "[Protheus]" + hb_eol() + "Port=1512" + hb_eol() + "port=1700", ;
        "openSection" => "[Protheus", "emptySection" => "[]", ;
        "emptyProfile" => "[SQL/]", "badNumber" => "[Protheus]" + hb_eol() + "Port=1512x", ;
        "outOfRange" => "[Protheus]" + hb_eol() + "Port=65536", ;
        "missingDriver" => "[SQL/demo]" + hb_eol() + "Database=:memory:", ;
        "extraProfileKey" => "[SQL/demo]" + hb_eol() + "Driver=sqlite" + hb_eol() + "User=x", ;
        "include" => "include config-test/host.ini", ;
        "nulValue" => "[NETIO]" + hb_eol() + "Password=x" + Chr( 0 ), ;
        "inlineComment" => "[Protheus]" + hb_eol() + "Port=1512 # comment" }
        cCase := cBad:__enumKey()
        hb_MemoWrit( "config-test/bad.ini", cBad )
        hINI := HBBridgeConfig( { "-config=config-test/bad.ini" }, @cError )
        M1Assert( hINI == NIL .AND. ! Empty( cError ), "INI rejects " + cCase, @nFailures, @nChecks )
    NEXT
    M1Assert( HBBridgeConfig( { "-config=F:relative.ini" }, @cError ) == NIL .AND. ! Empty( cError ), ;
        "invalid explicit config path cannot fall back to automatic INI", @nFailures, @nChecks )

    /* The runner's executable directory is isolated. Restore any prior file. */
    IF hb_FileExists( cAutoFile )
        cPrevious := hb_MemoRead( cAutoFile )
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hb_MemoWrit( cAutoFile, "[General]" + hb_eol() + "MaxWorkers=7" )
        hINI := HBBridgeConfig( {} )
        M1Assert( hINI != NIL .AND. hINI[ "maxWorkers" ] == 7, ;
            "default hbbridge.ini is loaded from the executable directory", @nFailures, @nChecks )
        hINI := HBBridgeConfig( { "-config=config-test/equivalent.json" } )
        M1Assert( hINI != NIL .AND. hINI[ "maxWorkers" ] == 3, ;
            "explicit JSON replaces automatic INI instead of merging two files", @nFailures, @nChecks )
    ALWAYS
        IF cPrevious == NIL
            FErase( cAutoFile )
        ELSE
            hb_MemoWrit( cAutoFile, cPrevious )
        ENDIF
    END SEQUENCE

    M1StructuredSQLConfigTests( @nFailures, @nChecks )

RETURN

STATIC PROCEDURE M1StructuredSQLConfigTests( nFailures, nChecks )

    LOCAL cPassword := "a#;=}}" + hb_UTF8Chr( 233 ) + ";UID=extra"
    LOCAL hBase := { "driver" => "mssql", "authentication" => "sql", "dsn" => "fixture", ;
        "username" => "reader", "password" => "synthetic-private-password" }
    LOCAL hProfiles := { ;
        "dsnSQL" => { "driver" => "mssql", "authentication" => "sql", "dsn" => "fixture", ;
            "database" => "db;}", "username" => "reader;PWD=override}", "password" => cPassword, ;
            "encrypt" => "mandatory", "trustServerCertificate" => .F. }, ;
        "dsnIntegrated" => { "driver" => "mssql", "authentication" => "integrated", ;
            "dsn" => "fixture", "database" => "override" }, ;
        "directSQL" => { "driver" => "mssql", "authentication" => "sql", ;
            "odbcDriver" => "ODBC Driver 18 for SQL Server", "server" => "tcp:localhost,1433", ;
            "database" => "sample", "username" => "reader", "password" => "fixture", ;
            "encrypt" => "optional", "trustServerCertificate" => .T. }, ;
        "directIntegrated" => { "driver" => "mssql", "authentication" => "integrated", ;
            "odbcDriver" => "ODBC Driver 18 for SQL Server", "server" => "localhost", ;
            "database" => "sample", "encrypt" => "strict", "trustServerCertificate" => .F. } }
    LOCAL hExpected := { ;
        "dsnSQL" => "DSN=fixture;DATABASE={db;}}};Trusted_Connection=No;" + ;
            "UID={reader;PWD=override}}};PWD={a#;=}}}}" + hb_UTF8Chr( 233 ) + ;
            ";UID=extra};Encrypt=Yes;TrustServerCertificate=No;", ;
        "dsnIntegrated" => "DSN=fixture;DATABASE={override};Trusted_Connection=Yes;", ;
        "directSQL" => "DRIVER={ODBC Driver 18 for SQL Server};SERVER={tcp:localhost,1433};" + ;
            "DATABASE={sample};Trusted_Connection=No;UID={reader};PWD={fixture};" + ;
            "Encrypt=No;TrustServerCertificate=Yes;", ;
        "directIntegrated" => "DRIVER={ODBC Driver 18 for SQL Server};SERVER={localhost};" + ;
            "DATABASE={sample};Trusted_Connection=Yes;Encrypt=Strict;TrustServerCertificate=No;" }
    LOCAL hBad := {=>}, hProfile, hINI, hJSON, hInfo, hNormalized, cCase, cError, cINI, cField, cControl

    FOR EACH hProfile IN hProfiles
        cCase := hProfile:__enumKey()
        cINI := StructuredSQLTestINI( hProfile )
        hb_MemoWrit( "config-test/structured.ini", cINI )
        hb_MemoWrit( "config-test/structured.json", ;
            hb_jsonEncode( { "sqlProfiles" => { "mssql/pData" => hProfile } } ) )
        hINI := HBBridgeConfig( { "-config=config-test/structured.ini" }, @cError )
        hJSON := HBBridgeConfig( { "-config=config-test/structured.json" }, @cError )
        M1Assert( hINI != NIL .AND. hJSON != NIL .AND. hb_jsonEncode( hINI ) == hb_jsonEncode( hJSON ), ;
            "structured MSSQL INI/JSON parity: " + cCase, @nFailures, @nChecks )
        IF hINI != NIL
            hNormalized := hINI[ "sqlProfiles" ][ "mssql/pData" ]
            M1Assert( Len( hNormalized ) == 2 .AND. hNormalized[ "driver" ] == "mssql" .AND. ;
                hNormalized[ "connectionString" ] == hExpected[ cCase ], ;
                "structured MSSQL attributes normalize exactly: " + cCase, @nFailures, @nChecks )
            hInfo := HBBridgeConfigInfo( hINI )
            M1Assert( Len( hInfo[ "sqlProfiles" ][ "mssql/pData" ] ) == 1 .AND. ;
                ! ( "PWD=" $ hb_jsonEncode( hInfo ) ) .AND. ! ( "DSN=" $ hb_jsonEncode( hInfo ) ) .AND. ;
                ! ( cPassword $ hb_jsonEncode( hInfo ) ), ;
                "structured MSSQL metadata contains only its driver: " + cCase, @nFailures, @nChecks )
        ELSE
            M1Assert( .F., "structured MSSQL accepted profile: " + cCase, @nFailures, @nChecks )
        ENDIF
    NEXT

    hProfile := hb_HClone( hBase )
    hProfile[ "password" ] := " " + Chr( 9 ) + "fixture " + Chr( 9 )
    hb_MemoWrit( "config-test/structured.ini", StructuredSQLTestINI( hProfile ) )
    hINI := HBBridgeConfig( { "-config=config-test/structured.ini" }, @cError )
    hNormalized := HBBridgeSQLProfiles( { "test" => hProfile }, hb_cwd(), @cError )
    M1Assert( hINI != NIL .AND. hINI[ "sqlProfiles" ][ "mssql/pData" ][ "connectionString" ] == ;
        "DSN=fixture;Trusted_Connection=No;UID={reader};PWD={fixture};" .AND. ;
        hNormalized != NIL .AND. hNormalized[ "test" ][ "connectionString" ] == ;
        "DSN=fixture;Trusted_Connection=No;UID={reader};PWD={ " + Chr( 9 ) + "fixture " + Chr( 9 ) + "};", ;
        "INI trims password edges while JSON/native configuration preserves them", @nFailures, @nChecks )
    hProfile[ "password" ] := "   "
    hb_MemoWrit( "config-test/structured.ini", StructuredSQLTestINI( hProfile ) )
    hINI := HBBridgeConfig( { "-config=config-test/structured.ini" }, @cError )
    hNormalized := HBBridgeSQLProfiles( { "test" => hProfile }, hb_cwd(), @cError )
    M1Assert( hINI == NIL .AND. hNormalized != NIL .AND. ;
        hNormalized[ "test" ][ "connectionString" ] == ;
        "DSN=fixture;Trusted_Connection=No;UID={reader};PWD={   };", ;
        "INI rejects a trimmed empty password; literal JSON spaces are not rewritten", @nFailures, @nChecks )
    hProfile[ "password" ] := '"fixture"'
    hb_MemoWrit( "config-test/structured.ini", StructuredSQLTestINI( hProfile ) )
    hINI := HBBridgeConfig( { "-config=config-test/structured.ini" }, @cError )
    M1Assert( hINI != NIL .AND. hINI[ "sqlProfiles" ][ "mssql/pData" ][ "connectionString" ] == ;
        'DSN=fixture;Trusted_Connection=No;UID={reader};PWD={"fixture"};', ;
        "INI password quotes are literal characters", @nFailures, @nChecks )

    hBad[ "missingAuthentication" ] := hb_HClone( hBase )
    hb_HDel( hBad[ "missingAuthentication" ], "authentication" )
    hBad[ "unsupportedAuthentication" ] := hb_HClone( hBase )
    hBad[ "unsupportedAuthentication" ][ "authentication" ] := "automatic"
    hBad[ "missingPassword" ] := hb_HClone( hBase )
    hb_HDel( hBad[ "missingPassword" ], "password" )
    hBad[ "emptyPassword" ] := hb_HClone( hBase )
    hBad[ "emptyPassword" ][ "password" ] := ""
    hBad[ "missingUsername" ] := hb_HClone( hBase )
    hb_HDel( hBad[ "missingUsername" ], "username" )
    hBad[ "blankUsername" ] := hb_HClone( hBase )
    hBad[ "blankUsername" ][ "username" ] := "   "
    hBad[ "integratedCredentials" ] := hb_HClone( hBase )
    hBad[ "integratedCredentials" ][ "authentication" ] := "integrated"
    hBad[ "integratedEmptyUsername" ] := hb_HClone( hProfiles[ "dsnIntegrated" ] )
    hBad[ "integratedEmptyUsername" ][ "username" ] := ""
    hBad[ "integratedEmptyPassword" ] := hb_HClone( hProfiles[ "dsnIntegrated" ] )
    hBad[ "integratedEmptyPassword" ][ "password" ] := ""
    hBad[ "mixedConnectionForms" ] := hb_HClone( hBase )
    hBad[ "mixedConnectionForms" ][ "connectionString" ] := "DSN=fixture;"
    hBad[ "dsnAndServer" ] := hb_HClone( hBase )
    hBad[ "dsnAndServer" ][ "server" ] := "localhost"
    hBad[ "dsnAndDriver" ] := hb_HClone( hBase )
    hBad[ "dsnAndDriver" ][ "odbcDriver" ] := "ODBC Driver 18 for SQL Server"
    hBad[ "missingODBCDriver" ] := hb_HClone( hProfiles[ "directSQL" ] )
    hb_HDel( hBad[ "missingODBCDriver" ], "odbcDriver" )
    hBad[ "missingServer" ] := hb_HClone( hProfiles[ "directSQL" ] )
    hb_HDel( hBad[ "missingServer" ], "server" )
    hBad[ "missingDatabase" ] := hb_HClone( hProfiles[ "directSQL" ] )
    hb_HDel( hBad[ "missingDatabase" ], "database" )
    hBad[ "unknownKey" ] := hb_HClone( hBase )
    hBad[ "unknownKey" ][ "synthetic-private-password" ] := "unknown"
    hBad[ "invalidEncrypt" ] := hb_HClone( hBase )
    hBad[ "invalidEncrypt" ][ "encrypt" ] := "yes"
    hBad[ "stringTrust" ] := hb_HClone( hBase )
    hBad[ "stringTrust" ][ "trustServerCertificate" ] := "false"
    FOR EACH cControl IN { "leftBracket" => "[", "rightBracket" => "]", ;
        "leftBrace" => "{", "rightBrace" => "}", "leftParenthesis" => "(", "rightParenthesis" => ")", ;
        "comma" => ",", "semicolon" => ";", "question" => "?", "asterisk" => "*", ;
        "equal" => "=", "exclamation" => "!", "at" => "@", "backslash" => Chr( 92 ), ;
        "tab" => Chr( 9 ), "control" => Chr( 1 ), "delete" => Chr( 127 ) }
        hBad[ "dsn" + cControl:__enumKey() ] := hb_HClone( hBase )
        hBad[ "dsn" + cControl:__enumKey() ][ "dsn" ] := "fixture" + cControl + "tail"
    NEXT
    hBad[ "dsnLeadingSpace" ] := hb_HClone( hBase )
    hBad[ "dsnLeadingSpace" ][ "dsn" ] := " fixture"
    hBad[ "dsnTrailingSpace" ] := hb_HClone( hBase )
    hBad[ "dsnTrailingSpace" ][ "dsn" ] := "fixture "
    hBad[ "dsnInjection" ] := hb_HClone( hBase )
    hBad[ "dsnInjection" ][ "dsn" ] := "fixture;Trusted_Connection=Yes;UID=other"
    FOR EACH cField IN { "authentication" => .T., "dsn" => .T., "username" => .T., "password" => .T. }
        cCase := cField:__enumKey()
        hBad[ "numeric" + cCase ] := hb_HClone( hBase )
        hBad[ "numeric" + cCase ][ cCase ] := 123
    NEXT
    FOR EACH cField IN { "odbcDriver" => .T., "server" => .T., "database" => .T., ;
        "username" => .T., "password" => .T. }
        cCase := cField:__enumKey()
        FOR EACH cControl IN { "nul" => Chr( 0 ), "cr" => Chr( 13 ), "lf" => Chr( 10 ) }
            hBad[ cCase + cControl:__enumKey() ] := hb_HClone( hProfiles[ "directSQL" ] )
            hBad[ cCase + cControl:__enumKey() ][ cCase ] := "synthetic-private-password" + cControl
        NEXT
    NEXT
    hBad[ "rawCR" ] := { "driver" => "mssql", "connectionString" => "DSN=fixture;" + Chr( 13 ) }
    hBad[ "rawLF" ] := { "driver" => "mssql", "connectionString" => "DSN=fixture;" + Chr( 10 ) }
    FOR EACH hProfile IN hBad
        cCase := hProfile:__enumKey()
        hb_MemoWrit( "config-test/structured-bad.json", ;
            hb_jsonEncode( { "sqlProfiles" => { "test" => hProfile } } ) )
        hJSON := HBBridgeConfig( { "-config=config-test/structured-bad.json" }, @cError )
        M1Assert( hJSON == NIL .AND. ! Empty( cError ) .AND. ;
            ! ( "synthetic-private-password" $ cError ), ;
            "structured MSSQL rejects safely: " + cCase, @nFailures, @nChecks )
    NEXT
    FOR EACH cINI IN { ;
        "invalidTrust" => "TrustServerCertificate=yes", ;
        "missingTrust" => "TrustServerCertificate=", ;
        "invalidEncrypt" => "Encrypt=yes", ;
        "duplicatePassword" => "Password=second", ;
        "unknownCredential" => "User=reader" }
        cCase := cINI:__enumKey()
        hb_MemoWrit( "config-test/structured-bad.ini", StructuredSQLTestINI( hBase ) + cINI + hb_eol() )
        hINI := HBBridgeConfig( { "-config=config-test/structured-bad.ini" }, @cError )
        M1Assert( hINI == NIL .AND. ! Empty( cError ) .AND. ;
            ! ( "synthetic-private-password" $ cError ), ;
            "structured MSSQL INI rejects safely: " + cCase, @nFailures, @nChecks )
    NEXT

RETURN

STATIC FUNCTION StructuredSQLTestINI( hProfile )
    LOCAL cINI := "[SQL/mssql/pData]" + hb_eol(), cKey, xValue
    FOR EACH xValue IN hProfile
        cKey := xValue:__enumKey()
        cINI += Upper( cKey ) + "="
        IF HB_ISLOGICAL( xValue )
            cINI += iif( xValue, "TRUE", "FALSE" )
        ELSEIF cKey == "driver" .OR. cKey == "authentication" .OR. cKey == "encrypt"
            cINI += Upper( xValue )
        ELSE
            cINI += xValue
        ENDIF
        cINI += hb_eol()
    NEXT
RETURN cINI
