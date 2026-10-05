PROCEDURE m1configtests( nFailures, nChecks )

    LOCAL hConfig, cError, cArg, hRuntimeLimits, cKey, xValue, cAbsolute

    cAbsolute := hbbridgeabsolutepath( "config-test/good.json", hb_cwd() )
    m1assert( hbbridgeabsolutepath( cAbsolute, hb_cwd() ) == cAbsolute, ;
        "absolute path normalization is idempotent", @nFailures, @nChecks )
    IF ! Empty( hb_osDriveSeparator() )
        m1assert( hbbridgeabsolutepath( SubStr( cAbsolute, At( hb_osDriveSeparator(), cAbsolute ) + 1 ), ;
            hb_cwd() ) == cAbsolute, "root-relative Windows path keeps the base drive and separator", @nFailures, @nChecks )
    ENDIF

    hConfig := hbbridgeconfig( {}, @cError )
    m1assert( hConfig[ "netioHost" ] == "0.0.0.0" .AND. hConfig[ "netioPort" ] == 2941 .AND. ;
        hConfig[ "adminHost" ] == "127.0.0.1" .AND. hConfig[ "adminPort" ] == 2940 .AND. ;
        Empty( hConfig[ "adminPassword" ] ) .AND. hConfig[ "netioTimeout" ] == 0, ;
        "upstream endpoint defaults, native NETIO wait, and disabled admin", @nFailures, @nChecks )
    m1assert( hConfig[ "protheusMaxPayloadBytes" ] == 0 .AND. hConfig[ "protheusMaxWireBytes" ] == 0 .AND. ;
        hConfig[ "protheusReadChunkBytes" ] == 65536 .AND. hConfig[ "protheusTimeoutMs" ] == 30000, ;
        "transport defaults have no application payload or wire ceiling", @nFailures, @nChecks )
    hRuntimeLimits := hbbridgeruntimelimits()
    hConfig := hbbridgeconfig( { "-maxpayloadbytes=0", "-maxwirebytes=0", "-iotimeout=0", "-readchunkbytes=1" }, @cError )
    m1assert( HB_ISHASH( hConfig ) .AND. Empty( cError ), ;
        "zero disables optional limits and deadline; one-byte read buffer is valid", @nFailures, @nChecks )
    hConfig := hbbridgeconfig( { "-maxpayloadbytes=33554432", "-maxwirebytes=50331648", ;
        "-readchunkbytes=32768", "-iotimeout=60000" }, @cError )
    m1assert( hConfig[ "protheusMaxPayloadBytes" ] == 33554432 .AND. hConfig[ "protheusMaxWireBytes" ] == 50331648 .AND. ;
        hConfig[ "protheusReadChunkBytes" ] == 32768 .AND. hConfig[ "protheusTimeoutMs" ] == 60000, ;
        "CLI accepts independent optional caps above the former 16 MiB ceiling", @nFailures, @nChecks )
    FOR EACH cKey IN { "protheusMaxPayloadBytes", "protheusMaxWireBytes", "protheusTimeoutMs" }
        hConfig := hbbridgeconfig( {}, @cError )
        hConfig[ cKey ] := hRuntimeLimits[ "stringBytesMax" ]
        m1assert( hbbridgeconfigvalid( hConfig, @cError ), ;
            "runtime numeric maximum is accepted for " + cKey, @nFailures, @nChecks )
        FOR EACH xValue IN { -1, 0.5, "0", .F., hRuntimeLimits[ "stringBytesMax" ] * 2, ;
            hRuntimeLimits[ "stringBytesMax" ] + 1 }
            hConfig[ cKey ] := xValue
            m1assert( ! hbbridgeconfigvalid( hConfig, @cError ) .AND. ! Empty( cError ), ;
                "invalid policy value rejected for " + cKey + " (" + ValType( xValue ) + ")", @nFailures, @nChecks )
        NEXT
    NEXT
    hConfig := hbbridgeconfig( {}, @cError )
    hConfig[ "protheusReadChunkBytes" ] := Min( hRuntimeLimits[ "socketChunkBytesMax" ], hRuntimeLimits[ "zlibChunkBytesMax" ] )
    m1assert( hbbridgeconfigvalid( hConfig, @cError ), ;
        "read buffer accepts the actual socket and codec runtime maximum", @nFailures, @nChecks )
    FOR EACH xValue IN { 0, -1, 1.5, "65536", .T., ;
        Min( hRuntimeLimits[ "socketChunkBytesMax" ], hRuntimeLimits[ "zlibChunkBytesMax" ] ) + 1 }
        hConfig[ "protheusReadChunkBytes" ] := xValue
        m1assert( ! hbbridgeconfigvalid( hConfig, @cError ) .AND. ! Empty( cError ), ;
            "invalid read buffer rejected (" + ValType( xValue ) + ")", @nFailures, @nChecks )
    NEXT
    hConfig := hbbridgeconfig( { "-netiotimeout=0" }, @cError )
    m1assert( HB_ISHASH( hConfig ) .AND. Empty( cError ), ;
        "NETIO zero selects its native unlimited wait", @nFailures, @nChecks )
    hConfig[ "netioTimeout" ] := hRuntimeLimits[ "netioTimeoutMsMax" ]
    m1assert( hbbridgeconfigvalid( hConfig, @cError ), ;
        "NETIO timeout accepts the actual C integer maximum", @nFailures, @nChecks )
    hConfig[ "netioTimeout" ] := hRuntimeLimits[ "netioTimeoutMsMax" ] + 1
    m1assert( ! hbbridgeconfigvalid( hConfig, @cError ) .AND. ! Empty( cError ), ;
        "NETIO timeout rejects overflow of its native C integer", @nFailures, @nChecks )
    hb_DirBuild( "config-test" )
    hb_MemoWrit( "config-test/host.json", ;
        '{"protheusPort":1700,"maxWorkers":3,"netioRoot":"files","addonRoot":"../addons"}' )
    hConfig := hbbridgeconfig( { "-port=1701", "-config=config-test/host.json" }, @cError )
    m1assert( hConfig[ "protheusPort" ] == 1701 .AND. hConfig[ "maxWorkers" ] == 3, ;
        "CLI overrides file regardless of argument order", @nFailures, @nChecks )
    m1assert( hConfig[ "netioRoot" ] == hbbridgeabsolutepath( "config-test/files", hb_cwd() ) .AND. ;
        hConfig[ "addonRoot" ] == hbbridgeabsolutepath( "addons", hb_cwd() ), ;
        "file paths resolve relative to config location", @nFailures, @nChecks )
    hConfig := hbbridgeconfig( { "-config=config-test/host.json", "-netioroot=cli-files" }, @cError )
    m1assert( hConfig[ "netioRoot" ] == hbbridgeabsolutepath( "cli-files", hb_cwd() ), ;
        "CLI paths resolve relative to working directory", @nFailures, @nChecks )
    hb_MemoWrit( "config-test/transport.json", ;
        '{"protheusMaxPayloadBytes":33554432,"protheusMaxWireBytes":50331648,' + ;
        '"protheusReadChunkBytes":8192,"protheusTimeoutMs":0}' )
    hConfig := hbbridgeconfig( { "-config=config-test/transport.json" }, @cError )
    m1assert( hConfig[ "protheusMaxPayloadBytes" ] == 33554432 .AND. hConfig[ "protheusMaxWireBytes" ] == 50331648 .AND. ;
        hConfig[ "protheusReadChunkBytes" ] == 8192 .AND. hConfig[ "protheusTimeoutMs" ] == 0, ;
        "JSON configures caps above 16 MiB, read buffer, and unlimited deadline", @nFailures, @nChecks )
    hConfig := hbbridgeconfig( { "-maxpayloadbytes=0", "-maxwirebytes=0", "-readchunkbytes=1024", ;
        "-iotimeout=45000", "-config=config-test/transport.json" }, @cError )
    m1assert( hConfig[ "protheusMaxPayloadBytes" ] == 0 .AND. hConfig[ "protheusMaxWireBytes" ] == 0 .AND. ;
        hConfig[ "protheusReadChunkBytes" ] == 1024 .AND. hConfig[ "protheusTimeoutMs" ] == 45000, ;
        "CLI overrides every JSON transport setting, including removal of caps", @nFailures, @nChecks )
    FOR EACH cArg IN { "-port=65536", "-port=-1", "-port=1.5", "-port=1512x", "-maxworkers=0", ;
        "-netioport=0", "-netiotimeout=-1", "-netiotimeout=0.5", "-host=300.0.0.1", "-host=127x.0.0.1", "-host=", ;
        "-unknown=x", "-port=2941", "-port=1512 ", "-port=1512" + Chr( 0 ) + "x", "-netioroot=F:relative", ;
        "-maxpayloadbytes=-1", "-maxpayloadbytes=1.5", "-maxpayloadbytes=16777216x", ;
        "-maxwirebytes=-1", "-maxwirebytes=2.5", "-maxwirebytes=", "-readchunkbytes=0", ;
        "-readchunkbytes=-1", "-readchunkbytes=1.5", "-iotimeout=-1", "-iotimeout=1.5", "-iotimeout=5000x" }
        hConfig := hbbridgeconfig( { cArg }, @cError )
        m1assert( hConfig == NIL .AND. ! Empty( cError ), "invalid configuration rejected " + cArg, @nFailures, @nChecks )
    NEXT
    FOR EACH cArg IN { '{"unknown":1}', '{"maxWorkers":"2"}', '{"netioRoot":""}', ;
        '{"adminPassword":"test-only","adminPort":2941}', '{} trailing', '{', ;
        '{"netioPassword":"' + Replicate( "x", 65 ) + '"}', '{"netioRoot":"data\u0000"}', ;
        '{"protheusMaxPayloadBytes":"0"}', '{"protheusMaxWireBytes":-1}', ;
        '{"protheusReadChunkBytes":0}', '{"protheusTimeoutMs":null}' }
        hb_MemoWrit( "config-test/bad.json", cArg )
        hConfig := hbbridgeconfig( { "-config=config-test/bad.json" }, @cError )
        m1assert( hConfig == NIL .AND. ! Empty( cError ), "invalid JSON configuration rejected " + cArg, @nFailures, @nChecks )
    NEXT
    m1assert( ! hbbridgeconfigvalid( {=>}, @cError ) .AND. ! Empty( cError ), ;
        "incomplete configuration fails without a runtime error", @nFailures, @nChecks )
RETURN
