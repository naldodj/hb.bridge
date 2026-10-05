/* Released to Public Domain. */
PROCEDURE m1iniconfigtests( nFailures, nChecks )

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
    hINI := hbbridgeconfig( { "-config=config-test/host.ini" }, @cError )
    hJSON := hbbridgeconfig( { "-config=config-test/equivalent.json" } )
    m1assert( hINI != NIL .AND. hJSON != NIL .AND. ;
        hb_jsonEncode( hINI ) == hb_jsonEncode( hJSON ), ;
        "INI and JSON normalize to the same typed configuration: " + cError, @nFailures, @nChecks )
    m1assert( hINI[ "netioPassword" ] == "test;#=secret" .AND. Empty( hINI[ "adminPassword" ] ) .AND. ;
        hINI[ "sqlProfiles" ][ "SqliteDemo" ][ "database" ] == ;
        hbbridgeabsolutepath( "config-test/sample.sqlite3", hb_cwd() ), ;
        "INI preserves password punctuation, empty admin and relative SQLite paths", @nFailures, @nChecks )
    hINI := hbbridgeconfig( { "-port=1701", "-maxworkers=4", "-config=config-test/host.ini" }, @cError )
    m1assert( hINI != NIL .AND. hINI[ "protheusPort" ] == 1701 .AND. hINI[ "maxWorkers" ] == 4, ;
        "CLI overrides INI regardless of argument order", @nFailures, @nChecks )
    hINI := hbbridgeconfig( { "--config-info", "-config=config-test/host.ini", "-netioroot=cli-ini" } )
    m1assert( hINI != NIL .AND. hINI[ "netioRoot" ] == hbbridgeabsolutepath( "cli-ini", hb_cwd() ), ;
        "INI CLI paths remain relative to working directory", @nFailures, @nChecks )
    hb_MemoWrit( "config-test/mssql.INI", Chr( 239 ) + Chr( 187 ) + Chr( 191 ) + ;
        "; comment" + Chr( 13 ) + Chr( 10 ) + "# comment" + Chr( 13 ) + Chr( 10 ) + ;
        "[sql/MssqlDemo]" + Chr( 13 ) + Chr( 10 ) + Chr( 9 ) + "driver = MSSQL" + Chr( 9 ) + ;
        Chr( 13 ) + Chr( 10 ) + "ConnectionString = DSN=fixture;UID=include user;PWD=a#b;c=d;" )
    hINI := hbbridgeconfig( { "-config=config-test/mssql.INI" }, @cError )
    m1assert( hINI != NIL .AND. hINI[ "sqlProfiles" ][ "MssqlDemo" ][ "driver" ] == "mssql" .AND. ;
        hINI[ "sqlProfiles" ][ "MssqlDemo" ][ "connectionString" ] == ;
        "DSN=fixture;UID=include user;PWD=a#b;c=d;", ;
        "INI handles BOM/CRLF/tabs/case while preserving complete ODBC values", @nFailures, @nChecks )
    hInfo := hbbridgeconfiginfo( hINI )
    m1assert( hInfo[ "configVersion" ] == 1 .AND. hInfo[ "sqlProfiles" ][ "MssqlDemo" ][ "driver" ] == "mssql" .AND. ;
        ! ( "DSN=" $ hb_jsonEncode( hInfo ) ) .AND. ! ( "PWD=" $ hb_jsonEncode( hInfo ) ) .AND. ;
        Len( hInfo[ "sqlProfiles" ][ "MssqlDemo" ] ) == 1, ;
        "config-info metadata omits passwords, DSN and storage paths", @nFailures, @nChecks )

    hb_MemoWrit( "config-test/multiple.ini", ;
        "[SQL/sqlite_demo]" + hb_eol() + "Driver=sqlite" + hb_eol() + "Database=:memory:" + hb_eol() + ;
        "[SQL/mssql/pData]" + hb_eol() + "Driver=mssql" + hb_eol() + ;
        "ConnectionString=DSN=pData;Trusted_Connection=Yes;" + hb_eol() )
    hINI := hbbridgeconfig( { "-config=config-test/multiple.ini" }, @cError )
    m1assert( hINI != NIL .AND. Len( hINI[ "sqlProfiles" ] ) == 2 .AND. ;
        hb_HHasKey( hINI[ "sqlProfiles" ], "mssql/pData" ) .AND. ;
        ! hb_HHasKey( hINI[ "sqlProfiles" ], "mssql/pdata" ), ;
        "multiple INI profiles preserve slash and case in opaque aliases", @nFailures, @nChecks )
    hInfo := hbbridgeconfiginfo( hINI )
    m1assert( Len( hInfo[ "sqlProfiles" ] ) == 2 .AND. ;
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
        hINI := hbbridgeconfig( { "-config=config-test/bad.ini" }, @cError )
        m1assert( hINI == NIL .AND. ! Empty( cError ), "INI rejects " + cCase, @nFailures, @nChecks )
    NEXT
    m1assert( hbbridgeconfig( { "-config=F:relative.ini" }, @cError ) == NIL .AND. ! Empty( cError ), ;
        "invalid explicit config path cannot fall back to automatic INI", @nFailures, @nChecks )

    /* The runner's executable directory is isolated. Restore any prior file. */
    IF hb_FileExists( cAutoFile )
        cPrevious := hb_MemoRead( cAutoFile )
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hb_MemoWrit( cAutoFile, "[General]" + hb_eol() + "MaxWorkers=7" )
        hINI := hbbridgeconfig( {} )
        m1assert( hINI != NIL .AND. hINI[ "maxWorkers" ] == 7, ;
            "default hbbridge.ini is loaded from the executable directory", @nFailures, @nChecks )
        hINI := hbbridgeconfig( { "-config=config-test/equivalent.json" } )
        m1assert( hINI != NIL .AND. hINI[ "maxWorkers" ] == 3, ;
            "explicit JSON replaces automatic INI instead of merging two files", @nFailures, @nChecks )
    ALWAYS
        IF cPrevious == NIL
            FErase( cAutoFile )
        ELSE
            hb_MemoWrit( cAutoFile, cPrevious )
        ENDIF
    END SEQUENCE

RETURN
