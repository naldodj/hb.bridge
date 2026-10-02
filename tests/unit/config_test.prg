PROCEDURE M1ConfigTests( nFailures, nChecks )

   LOCAL hConfig, cError, cArg

   hConfig := HBBridgeConfig( {}, @cError )
   M1Assert( hConfig[ "netioHost" ] == "0.0.0.0" .AND. hConfig[ "netioPort" ] == 2941 .AND. ;
      hConfig[ "adminHost" ] == "127.0.0.1" .AND. hConfig[ "adminPort" ] == 2940 .AND. ;
      Empty( hConfig[ "adminPassword" ] ), "upstream endpoint defaults and disabled admin", @nFailures, @nChecks )
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
   FOR EACH cArg IN { "-port=65536", "-port=-1", "-port=1.5", "-port=1512x", "-maxworkers=0", ;
      "-netioport=0", "-netiotimeout=0", "-host=300.0.0.1", "-host=", "-unknown=x", "-port=2941" }
      hConfig := HBBridgeConfig( { cArg }, @cError )
      M1Assert( hConfig == NIL .AND. ! Empty( cError ), "invalid configuration rejected " + cArg, @nFailures, @nChecks )
   NEXT
   FOR EACH cArg IN { '{"unknown":1}', '{"maxWorkers":"2"}', '{"netioRoot":""}', ;
      '{"adminPassword":"test-only","adminPort":2941}', '{} trailing', '{' }
      hb_MemoWrit( "config-test/bad.json", cArg )
      hConfig := HBBridgeConfig( { "-config=config-test/bad.json" }, @cError )
      M1Assert( hConfig == NIL .AND. ! Empty( cError ), "invalid JSON configuration rejected", @nFailures, @nChecks )
   NEXT
RETURN
