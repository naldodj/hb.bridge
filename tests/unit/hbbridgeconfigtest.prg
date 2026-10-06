PROCEDURE M1ConfigTests( nFailures, nChecks )

    LOCAL hConfig, cError, cArg, hRuntimeLimits, cKey, xValue, cAbsolute

    cAbsolute := HBBridgeAbsolutePath( "config-test/good.json", hb_cwd() )
    M1Assert( HBBridgeAbsolutePath( cAbsolute, hb_cwd() ) == cAbsolute, ;
        "absolute path normalization is idempotent", @nFailures, @nChecks )
    IF ! Empty( hb_osDriveSeparator() )
        M1Assert( HBBridgeAbsolutePath( SubStr( cAbsolute, At( hb_osDriveSeparator(), cAbsolute ) + 1 ), ;
            hb_cwd() ) == cAbsolute, "root-relative Windows path keeps the base drive and separator", @nFailures, @nChecks )
    ENDIF

    hConfig := HBBridgeConfig( {}, @cError )
    M1Assert( hConfig[ "netioHost" ] == "0.0.0.0" .AND. hConfig[ "netioPort" ] == 2941 .AND. ;
        hConfig[ "adminHost" ] == "127.0.0.1" .AND. hConfig[ "adminPort" ] == 2940 .AND. ;
        Empty( hConfig[ "adminPassword" ] ) .AND. hConfig[ "netioTimeout" ] == 0, ;
        "upstream endpoint defaults, native NETIO wait, and disabled admin", @nFailures, @nChecks )
    M1Assert( hConfig[ "protheusMaxPayloadBytes" ] == 0 .AND. hConfig[ "protheusMaxWireBytes" ] == 0 .AND. ;
        hConfig[ "protheusReadChunkBytes" ] == 65536 .AND. hConfig[ "protheusTimeoutMs" ] == 30000, ;
        "transport defaults have no application payload or wire ceiling", @nFailures, @nChecks )
    hRuntimeLimits := HBBridgeRuntimeLimits()
    hConfig := HBBridgeConfig( { "-maxpayloadbytes=0", "-maxwirebytes=0", "-iotimeout=0", "-readchunkbytes=1" }, @cError )
    M1Assert( HB_ISHASH( hConfig ) .AND. Empty( cError ), ;
        "zero disables optional limits and deadline; one-byte read buffer is valid", @nFailures, @nChecks )
    hConfig := HBBridgeConfig( { "-maxpayloadbytes=33554432", "-maxwirebytes=50331648", ;
        "-readchunkbytes=32768", "-iotimeout=60000" }, @cError )
    M1Assert( hConfig[ "protheusMaxPayloadBytes" ] == 33554432 .AND. hConfig[ "protheusMaxWireBytes" ] == 50331648 .AND. ;
        hConfig[ "protheusReadChunkBytes" ] == 32768 .AND. hConfig[ "protheusTimeoutMs" ] == 60000, ;
        "CLI accepts independent optional caps above the former 16 MiB ceiling", @nFailures, @nChecks )
    FOR EACH cKey IN { "protheusMaxPayloadBytes", "protheusMaxWireBytes", "protheusTimeoutMs" }
        hConfig := HBBridgeConfig( {}, @cError )
        hConfig[ cKey ] := hRuntimeLimits[ "stringBytesMax" ]
        M1Assert( HBBridgeConfigValid( hConfig, @cError ), ;
            "runtime numeric maximum is accepted for " + cKey, @nFailures, @nChecks )
        FOR EACH xValue IN { -1, 0.5, "0", .F., hRuntimeLimits[ "stringBytesMax" ] * 2, ;
            hRuntimeLimits[ "stringBytesMax" ] + 1 }
            hConfig[ cKey ] := xValue
            M1Assert( ! HBBridgeConfigValid( hConfig, @cError ) .AND. ! Empty( cError ), ;
                "invalid policy value rejected for " + cKey + " (" + ValType( xValue ) + ")", @nFailures, @nChecks )
        NEXT
    NEXT
    hConfig := HBBridgeConfig( {}, @cError )
    hConfig[ "protheusReadChunkBytes" ] := Min( hRuntimeLimits[ "socketChunkBytesMax" ], hRuntimeLimits[ "zlibChunkBytesMax" ] )
    M1Assert( HBBridgeConfigValid( hConfig, @cError ), ;
        "read buffer accepts the actual socket and codec runtime maximum", @nFailures, @nChecks )
    FOR EACH xValue IN { 0, -1, 1.5, "65536", .T., ;
        Min( hRuntimeLimits[ "socketChunkBytesMax" ], hRuntimeLimits[ "zlibChunkBytesMax" ] ) + 1 }
        hConfig[ "protheusReadChunkBytes" ] := xValue
        M1Assert( ! HBBridgeConfigValid( hConfig, @cError ) .AND. ! Empty( cError ), ;
            "invalid read buffer rejected (" + ValType( xValue ) + ")", @nFailures, @nChecks )
    NEXT
    hConfig := HBBridgeConfig( { "-netiotimeout=0" }, @cError )
    M1Assert( HB_ISHASH( hConfig ) .AND. Empty( cError ), ;
        "NETIO zero selects its native unlimited wait", @nFailures, @nChecks )
    hConfig[ "netioTimeout" ] := hRuntimeLimits[ "netioTimeoutMsMax" ]
    M1Assert( HBBridgeConfigValid( hConfig, @cError ), ;
        "NETIO timeout accepts the actual C integer maximum", @nFailures, @nChecks )
    hConfig[ "netioTimeout" ] := hRuntimeLimits[ "netioTimeoutMsMax" ] + 1
    M1Assert( ! HBBridgeConfigValid( hConfig, @cError ) .AND. ! Empty( cError ), ;
        "NETIO timeout rejects overflow of its native C integer", @nFailures, @nChecks )
    hb_DirBuild( "config-test" )
    hb_MemoWrit( "config-test/host.json", ;
        '{"protheusPort":1700,"maxWorkers":3,"netioRoot":"files","addonRoot":"../addons"}' )
    hConfig := HBBridgeConfig( { "-port=1701", "-config=config-test/host.json" }, @cError )
    M1Assert( hConfig[ "protheusPort" ] == 1701 .AND. hConfig[ "maxWorkers" ] == 3, ;
        "CLI overrides file regardless of argument order", @nFailures, @nChecks )
    M1Assert( hConfig[ "netioRoot" ] == HBBridgeAbsolutePath( "config-test/files", hb_cwd() ) .AND. ;
        hConfig[ "addonRoot" ] == HBBridgeAbsolutePath( "addons", hb_cwd() ), ;
        "file paths resolve relative to config location", @nFailures, @nChecks )
    hConfig := HBBridgeConfig( { "-config=config-test/host.json", "-netioroot=cli-files" }, @cError )
    M1Assert( hConfig[ "netioRoot" ] == HBBridgeAbsolutePath( "cli-files", hb_cwd() ), ;
        "CLI paths resolve relative to working directory", @nFailures, @nChecks )
    hb_MemoWrit( "config-test/transport.json", ;
        '{"protheusMaxPayloadBytes":33554432,"protheusMaxWireBytes":50331648,' + ;
        '"protheusReadChunkBytes":8192,"protheusTimeoutMs":0}' )
    hConfig := HBBridgeConfig( { "-config=config-test/transport.json" }, @cError )
    M1Assert( hConfig[ "protheusMaxPayloadBytes" ] == 33554432 .AND. hConfig[ "protheusMaxWireBytes" ] == 50331648 .AND. ;
        hConfig[ "protheusReadChunkBytes" ] == 8192 .AND. hConfig[ "protheusTimeoutMs" ] == 0, ;
        "JSON configures caps above 16 MiB, read buffer, and unlimited deadline", @nFailures, @nChecks )
    hConfig := HBBridgeConfig( { "-maxpayloadbytes=0", "-maxwirebytes=0", "-readchunkbytes=1024", ;
        "-iotimeout=45000", "-config=config-test/transport.json" }, @cError )
    M1Assert( hConfig[ "protheusMaxPayloadBytes" ] == 0 .AND. hConfig[ "protheusMaxWireBytes" ] == 0 .AND. ;
        hConfig[ "protheusReadChunkBytes" ] == 1024 .AND. hConfig[ "protheusTimeoutMs" ] == 45000, ;
        "CLI overrides every JSON transport setting, including removal of caps", @nFailures, @nChecks )
    FOR EACH cArg IN { "-port=65536", "-port=-1", "-port=1.5", "-port=1512x", "-maxworkers=0", ;
        "-netioport=0", "-netiotimeout=-1", "-netiotimeout=0.5", "-host=300.0.0.1", "-host=127x.0.0.1", "-host=", ;
        "-unknown=x", "-port=2941", "-port=1512 ", "-port=1512" + Chr( 0 ) + "x", "-netioroot=F:relative", ;
        "-maxpayloadbytes=-1", "-maxpayloadbytes=1.5", "-maxpayloadbytes=16777216x", ;
        "-maxwirebytes=-1", "-maxwirebytes=2.5", "-maxwirebytes=", "-readchunkbytes=0", ;
        "-readchunkbytes=-1", "-readchunkbytes=1.5", "-iotimeout=-1", "-iotimeout=1.5", "-iotimeout=5000x" }
        hConfig := HBBridgeConfig( { cArg }, @cError )
        M1Assert( hConfig == NIL .AND. ! Empty( cError ), "invalid configuration rejected " + cArg, @nFailures, @nChecks )
    NEXT
    FOR EACH cArg IN { '{"unknown":1}', '{"maxWorkers":"2"}', '{"netioRoot":""}', ;
        '{"adminPassword":"test-only","adminPort":2941}', '{} trailing', '{', ;
        '{"netioPassword":"' + Replicate( "x", 65 ) + '"}', '{"netioRoot":"data\u0000"}', ;
        '{"protheusMaxPayloadBytes":"0"}', '{"protheusMaxWireBytes":-1}', ;
        '{"protheusReadChunkBytes":0}', '{"protheusTimeoutMs":null}' }
        hb_MemoWrit( "config-test/bad.json", cArg )
        hConfig := HBBridgeConfig( { "-config=config-test/bad.json" }, @cError )
        M1Assert( hConfig == NIL .AND. ! Empty( cError ), "invalid JSON configuration rejected " + cArg, @nFailures, @nChecks )
    NEXT
    M1Assert( ! HBBridgeConfigValid( {=>}, @cError ) .AND. ! Empty( cError ), ;
        "incomplete configuration fails without a runtime error", @nFailures, @nChecks )
RETURN
