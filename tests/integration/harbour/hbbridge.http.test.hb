/* Released to Public Domain. */
#include "hbsocket.ch"
REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE HTTPTestMain()
    LOCAL nFailures := 0, nChecks := 0
    hb_DirBuild( "config-test" )
    HTTPTests( @nFailures, @nChecks )
    ? "HTTP checks:", nChecks, "failures:", nFailures
    ErrorLevel( iif( nFailures == 0, 0, 1 ) )
RETURN

PROCEDURE HTTPTests( nFailures, nChecks )

    LOCAL hConfig := HBBridgeConfig( {} ), cError, hHost := NIL, hResponse, hResult
    LOCAL cDataAuth := "Bearer http-service-test-only"
    LOCAL cAdminAuth := "Basic " + hb_base64Encode( "admin:http-admin-test-only" )
    LOCAL hThreads := {=>}, hThread, nIndex, hNative, pNative := NIL, hIdle := NIL
    LOCAL hBusy := NIL, nBusyPort, hFailed, hInfo, hConfigINI, cLarge := Replicate( "HTTP xBase ", 20000 )
    LOCAL hError, nStarted, hDribble, hDribbleThread
    LOCAL cPreviousCodepage := hb_cdpSelect(), cUnicode := hb_HexToStr( "C3A9E4B8ADE69687F09F9880" )
    LOCAL cUnicodeJSON := '{"text":"' + cUnicode + '"}', cInvalidBytes

    HTTPAssert( ! hConfig[ "httpEnabled" ] .AND. hConfig[ "httpHost" ] == "127.0.0.1" .AND. ;
        hConfig[ "httpPort" ] == 8080 .AND. Empty( hConfig[ "httpPassword" ] ), ;
        "HTTP is disabled with loopback defaults and no default secret", @nFailures, @nChecks )
    hConfig[ "httpEnabled" ] := .T.
    HTTPAssert( ! HBBridgeConfigValid( hConfig, @cError ), ;
        "HTTP refuses activation without a service secret", @nFailures, @nChecks )
    hConfig[ "httpPassword" ] := "http-service-test-only"
    hConfig[ "adminPassword" ] := hConfig[ "httpPassword" ]
    HTTPAssert( ! HBBridgeConfigValid( hConfig, @cError ), ;
        "HTTP data and administration secrets must differ", @nFailures, @nChecks )
    hConfig[ "adminPassword" ] := "http-admin-test-only"
    hConfig[ "httpPort" ] := hConfig[ "netioPort" ]
    HTTPAssert( ! HBBridgeConfigValid( hConfig, @cError ), ;
        "HTTP configuration detects endpoint port collisions", @nFailures, @nChecks )
    hConfig[ "httpPort" ] := HTTPFreePort()
    hConfig[ "httpHost" ] := "0.0.0.0"
    HTTPAssert( HBBridgeConfigValid( hConfig, @cError ), ;
        "HTTP permits an explicit wildcard bind for deployment", @nFailures, @nChecks )
    IF ! hb_IsFunction( "__HBEXTERN__HBSSL__" )
        hConfig[ "httpTLS" ] := .T.
        HTTPAssert( ! HBBridgeConfigValid( hConfig, @cError ) .AND. "hbssl" $ cError, ;
            "TLS activation identifies the missing hbssl build capability", @nFailures, @nChecks )
        hConfig[ "httpTLS" ] := .F.
    ENDIF
    hb_MemoWrit( "config-test/http.ini", ;
        "[HTTP]" + hb_eol() + "Enabled=true" + hb_eol() + "Host=127.0.0.1" + hb_eol() + ;
        "Port=8088" + hb_eol() + "Password=http-ini-test-only" + hb_eol() + "TLS=false" + hb_eol() )
    hConfigINI := HBBridgeConfig( { "-config=config-test/http.ini", "-httpport=8089" }, @cError )
    HTTPAssert( hConfigINI != NIL .AND. hConfigINI[ "httpEnabled" ] .AND. ;
        hConfigINI[ "httpPort" ] == 8089 .AND. ! hConfigINI[ "httpTLS" ], ;
        "INI parses logical HTTP flags and CLI overrides its port", @nFailures, @nChecks )
    hb_MemoWrit( "config-test/http-bad.ini", "[HTTP]" + hb_eol() + "Enabled=1" )
    HTTPAssert( HBBridgeConfig( { "-config=config-test/http-bad.ini" }, @cError ) == NIL, ;
        "HTTP logical INI fields reject ambiguous numeric text", @nFailures, @nChecks )
    hInfo := HBBridgeConfigInfo( hConfig )
    HTTPAssert( hInfo[ "httpEnabled" ] .AND. ! ( "test-only" $ hb_jsonEncode( hInfo ) ), ;
        "config metadata includes HTTP capability without secrets", @nFailures, @nChecks )

    hConfig[ "httpHost" ] := "127.0.0.1"
    hConfig[ "protheusHost" ] := "127.0.0.1"
    hConfig[ "protheusPort" ] := 0
    hConfig[ "netioHost" ] := "127.0.0.1"
    hConfig[ "netioPort" ] := HTTPFreePort()
    hConfig[ "adminPort" ] := HTTPFreePort()
    hConfig[ "netioRoot" ] := HBBridgeAbsolutePath( "http-netio-data", hb_cwd() )
    hConfig[ "netioPassword" ] := "http-native-test-only"
    hConfig[ "sqlProfiles" ] := { "memory/HTTP" => { "driver" => "sqlite", "database" => ":memory:" } }
    /* Exercise native HTTP framing with character-indexed UTF8EX workers. */
    hb_cdpSelect( "UTF8EX" )
    hHost := HBBridgeHostStart( hConfig, @cError )
    HTTPAssert( hHost != NIL, "shared host starts HTTP alongside TCP and NETIO: " + cError, @nFailures, @nChecks )
    IF hHost == NIL
        hb_cdpSelect( cPreviousCodepage )
        RETURN
    ENDIF

    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/api/v1/health", "", "" )
        HTTPAssert( hResponse[ "status" ] == 401 .AND. "Bearer" $ hResponse[ "headers" ], ;
            "HTTP service routes require bearer authentication", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/api/v1/health", "", cAdminAuth )
        HTTPAssert( hResponse[ "status" ] == 401, ;
            "admin authentication cannot call data services", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/api/v1/health", "", cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. hResponse[ "json" ][ "success" ], ;
            "native hbhttpd GET reaches the shared Zig Health service", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/api/v1/health", "", Lower( Left( cDataAuth, 6 ) ) + SubStr( cDataAuth, 7 ) )
        HTTPAssert( hResponse[ "status" ] == 200, ;
            "HTTP bearer authentication scheme is case insensitive", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", ;
            '{"service":"Echo","params":{"tenantID":"caller-defined","branch":"caller-defined"}}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. ;
            hResponse[ "json" ][ "params" ][ "tenantID" ] == "caller-defined", ;
            "HTTP JSON RPC preserves caller ERP parameters without interpretation", @nFailures, @nChecks )
        pNative := netio_GetConnection( "127.0.0.1", hConfig[ "netioPort" ], 3000, hConfig[ "netioPassword" ] )
        hNative := netio_FuncExec( pNative, "HBBridge.Call", "Echo", hResponse[ "json" ][ "params" ] )
        HTTPAssert( hb_jsonEncode( hNative ) == hb_jsonEncode( hResponse[ "json" ] ), ;
            "HTTP and NETIO return the same service result", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", ;
            hb_jsonEncode( { "text" => cLarge } ), cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. hResponse[ "json" ][ "params" ][ "text" ] == cLarge, ;
            "REST service route returns a large JSON body identically", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", cUnicodeJSON, cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. hResponse[ "json" ][ "params" ][ "text" ] == cUnicode, ;
            "REST preserves raw UTF-8 accents, CJK and supplementary characters", @nFailures, @nChecks )
        HTTPAssert( HTTPContentLength( hResponse ) == hb_BLen( hResponse[ "body" ] ) .AND. ;
            hb_BLen( hResponse[ "body" ] ) > Len( hResponse[ "body" ] ), ;
            "HTTP Content-Length counts bytes with UTF8EX workers", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", ;
            '{"service":"Echo","params":' + cUnicodeJSON + '}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. hResponse[ "json" ][ "params" ][ "text" ] == cUnicode, ;
            "JSON RPC preserves UTF-8 through the shared dispatcher", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", ;
            '{"text":"\u00e9\u4e2d\u6587"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. ;
            hResponse[ "json" ][ "params" ][ "text" ] == hb_HexToStr( "C3A9E4B8ADE69687" ) .AND. ;
            HTTPContentLength( hResponse ) == hb_BLen( hResponse[ "body" ] ), ;
            "JSON Unicode escapes decode to UTF-8 with exact response framing", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", ;
            '{"text":"\u00e9\u4e2d\u6587\ud83d\ude00"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. hResponse[ "json" ][ "params" ][ "text" ] == cUnicode .AND. ;
            HTTPContentLength( hResponse ) == hb_BLen( hResponse[ "body" ] ), ;
            "REST surrogate pairs match raw supplementary UTF-8 bytes", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", ;
            '{"service":"Echo","params":{"text":"\u00e9\u4e2d\u6587\uD83D\uDE00"}}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. hResponse[ "json" ][ "params" ][ "text" ] == cUnicode, ;
            "JSON RPC normalizes mixed-case surrogate pairs before shared dispatch", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", ;
            '{"\ud83d\ude00":"emoji-key"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. ;
            hResponse[ "json" ][ "params" ][ hb_HexToStr( "F09F9880" ) ] == "emoji-key", ;
            "surrogate normalization applies to JSON hash keys", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", ;
            '{"text":"\\ud83d\\ude00"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. hResponse[ "json" ][ "params" ][ "text" ] == "\ud83d\ude00", ;
            "JSON escaped backslashes preserve literal Unicode escape text", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", ;
            '{"text":"\\\ud83d\ude00\"after"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. ;
            hResponse[ "json" ][ "params" ][ "text" ] == "\" + hb_HexToStr( "F09F9880" ) + '"after', ;
            "surrogate normalization preserves escaped backslash and quote boundaries", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", ;
            '{"service":"Health","params":"\ud800"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400 .AND. hResponse[ "json" ][ "code" ] == "INVALID_JSON", ;
            "orphan high surrogate is rejected before a parameter-ignoring service", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Health", ;
            '"\udc00"', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400 .AND. hResponse[ "json" ][ "code" ] == "INVALID_JSON", ;
            "orphan low surrogate is rejected before REST dispatch", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Health", ;
            '"\ude00\ud83d"', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400 .AND. hResponse[ "json" ][ "code" ] == "INVALID_JSON", ;
            "inverted surrogate pair is rejected before REST dispatch", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", ;
            cUnicodeJSON + " x", cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400 .AND. hResponse[ "json" ][ "code" ] == "INVALID_JSON", ;
            "REST rejects trailing bytes after multibyte JSON", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", ;
            '{"service":"Echo","params":' + cUnicodeJSON + '} x', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400 .AND. hResponse[ "json" ][ "code" ] == "INVALID_JSON", ;
            "shared JSON RPC rejects trailing bytes after multibyte JSON", @nFailures, @nChecks )
        cInvalidBytes := hb_HexToStr( "C0AF" )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", ;
            '{"text":"' + cInvalidBytes + '"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400 .AND. hResponse[ "json" ][ "code" ] == "INVALID_UTF8", ;
            "HTTP rejects overlong UTF-8 without changing payload bytes", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", ;
            '{"service":"Echo","params":{"text":"' + hb_HexToStr( "EDA080" ) + '"}}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400 .AND. hResponse[ "json" ][ "code" ] == "INVALID_UTF8", ;
            "HTTP rejects raw UTF-8 surrogate codepoints", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", ;
            cUnicodeJSON + Chr( 0 ), cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400 .AND. hResponse[ "json" ][ "code" ] == "INVALID_JSON", ;
            "HTTP does not hide a NUL byte following a JSON value", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/RPCRDD.Query", ;
            '{"alias":"memory/HTTP","sql":"SELECT 41 AS caller_value"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. ;
            hResponse[ "json" ][ "rows" ][ "1" ][ "CALLER_VALUE" ] == 41, ;
            "HTTP executes generic SQL using the explicit opaque profile alias", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/RPCRDD.Query", ;
            hb_jsonEncode( { "alias" => "memory/HTTP", "sql" => "SELECT '" + cUnicode + "' AS caller_text" }, .F., "UTF8" ), cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. ;
            hResponse[ "json" ][ "rows" ][ "1" ][ "CALLER_TEXT" ] == cUnicode, ;
            "HTTP SQLite query preserves UTF-8 text provided by the caller", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/ADDON.Execute", ;
            '{"module":"examples/hbbridgesampleaddon.hb","params":{}}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. hResponse[ "json" ][ "success" ], ;
            "HTTP uses the existing HRB addon executor", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/api/v1/services", "", cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. hResponse[ "json" ][ "success" ], ;
            "HTTP advertises permitted shared services", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", ;
            '{"service":"Admin.Status"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 403 .AND. hResponse[ "json" ][ "code" ] == "FORBIDDEN", ;
            "data RPC cannot bypass administration permissions", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/admin/status", "", cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 401 .AND. "Basic" $ hResponse[ "headers" ], ;
            "HTTP data token cannot administer the host", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/admin/status", "", cAdminAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. Len( hResponse[ "json" ][ "endpoints" ] ) == 4 .AND. ;
            hResponse[ "json" ][ "endpoints" ][ "http" ][ "rejected" ] >= 3 .AND. ;
            ! ( "test-only" $ hResponse[ "body" ] ), ;
            "web administration reports all endpoints and auth counters without secrets", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/admin/", "", cAdminAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. "hbBridge administration" $ hResponse[ "body" ] .AND. ;
            "Content-Security-Policy" $ hResponse[ "headers" ], ;
            "authenticated administration panel renders native endpoint status", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", "{", cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400 .AND. hResponse[ "json" ][ "code" ] == "INVALID_JSON", ;
            "invalid JSON returns a structured HTTP error", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Echo", "{} extra", cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 400, "REST rejects trailing JSON content", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", "{}", cDataAuth, "text/plain" )
        HTTPAssert( hResponse[ "status" ] == 415, "HTTP rejects unsupported request media", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", "", cDataAuth, ;
            "application/json", "Transfer-Encoding: chunked" )
        HTTPAssert( hResponse[ "status" ] == 400, ;
            "native HTTP rejects unsupported transfer coding before dispatch", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", "", cDataAuth, ;
            "application/json", "Content-Length: 1" )
        HTTPAssert( hResponse[ "status" ] == 400, ;
            "native HTTP rejects duplicate Content-Length headers", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", "", cDataAuth, ;
            "application/json", "", "1junk" )
        HTTPAssert( hResponse[ "status" ] == 400, ;
            "native HTTP rejects nondecimal Content-Length without waiting for a body", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/api/v1/rpc", "", cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 405, "RPC route advertises the required POST method", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/rpc", ;
            '{"service":"NoSuchService"}', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 404, "unknown service maps to HTTP 404", @nFailures, @nChecks )
        FOR nIndex := 1 TO 8
            hThreads[ hb_ntos( nIndex ) ] := hb_threadStart( 0, @HTTPParallelEcho(), hConfig[ "httpPort" ], nIndex, cDataAuth )
        NEXT
        FOR EACH hThread IN hThreads
            hResult := NIL
            hb_threadJoin( hThread, @hResult )
            HTTPAssert( HB_ISHASH( hResult ) .AND. hResult[ "params" ][ "index" ] == Val( hThread:__enumKey() ), ;
                "concurrent HTTP calls preserve request context " + hThread:__enumKey(), @nFailures, @nChecks )
        NEXT
        hIdle := hb_socketOpen()
        hb_socketConnect( hIdle, { HB_SOCKET_AF_INET, "127.0.0.1", hConfig[ "httpPort" ] }, 3000 )
        hb_socketSend( hIdle, "GET /api/v1/health HTTP/1.1" + Chr( 13 ) + Chr( 10 ) + "X-Pending:",,, 1000 )
        hDribble := { "mutex" => hb_mutexCreate(), "stopping" => .F. }
        hDribbleThread := hb_threadStart( 0, @HTTPDribble(), hIdle, hDribble )
        hb_idleSleep( 0.05 )
        nStarted := HBBridgeMonotonicMs()
        HTTPAssert( HBBridgeHostStop( hHost ) .AND. HBBridgeMonotonicMs() - nStarted < 5000 .AND. ;
            ! HBBridgeHostRunning( hHost ), ;
            "coordinated stop joins hbhttpd during a continuously incomplete HTTP header", @nFailures, @nChecks )
    RECOVER USING hError
        HTTPAssert( .F., "HTTP test exception: " + iif( HB_ISOBJECT( hError ), ;
            hError:Description + " (" + hError:Operation + ")", hb_ValToExp( hError ) ), @nFailures, @nChecks )
    ALWAYS
        IF hDribble != NIL
            hb_mutexEval( hDribble[ "mutex" ], {|| hDribble[ "stopping" ] := .T. } )
            IF ! Empty( hDribbleThread )
                hb_threadJoin( hDribbleThread )
            ENDIF
        ENDIF
        pNative := NIL
        IF ! Empty( hIdle )
            hb_socketClose( hIdle )
        ENDIF
        HBBridgeHostStop( hHost )
    END SEQUENCE

    /* Restart under a different worker codepage: only the HTTP request's
     * execution scope selects UTF8EX, leaving configuration bytes intact.
     */
    hb_cdpSelect( "EN" )
    hConfig[ "adminPassword" ] := ""
    hConfig[ "httpPassword" ] += hb_HexToStr( "C3A9" )
    cDataAuth := "Bearer " + hConfig[ "httpPassword" ]
    hHost := HBBridgeHostStart( hConfig, @cError )
    HTTPAssert( hHost != NIL, "HTTP and native endpoints restart after stop", @nFailures, @nChecks )
    IF hHost != NIL
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/api/v1/health", "", ;
            "Bearer http-service-test-only" + hb_HexToStr( "C3AA" ) )
        HTTPAssert( hResponse[ "status" ] == 401, ;
            "authentication compares every credential byte under UTF8EX", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "POST", "/api/v1/services/Core.Upper", ;
            '"' + hb_HexToStr( "C3A9" ) + '"', cDataAuth )
        HTTPAssert( hResponse[ "status" ] == 200 .AND. ;
            hResponse[ "json" ][ "result" ] == hb_HexToStr( "C389" ), ;
            "HTTP selects UTF8EX for native executor semantics with valid credential bytes", @nFailures, @nChecks )
        hResponse := HTTPRequest( hConfig[ "httpPort" ], "GET", "/admin/status", "", cAdminAuth )
        HTTPAssert( hResponse[ "status" ] == 403 .AND. HB_ISHASH( hResponse[ "json" ] ) .AND. ;
            hResponse[ "json" ][ "code" ] == "ADMIN_DISABLED", ;
            "web administration remains disabled without the separate admin secret", @nFailures, @nChecks )
        HBBridgeHostStop( hHost )
    ENDIF
    hBusy := hb_socketOpen()
    hb_socketBind( hBusy, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
    hb_socketListen( hBusy )
    nBusyPort := hb_socketGetSockName( hBusy )[ HB_SOCKET_ADINFO_PORT ]
    hConfig[ "httpPort" ] := nBusyPort
    hFailed := HBBridgeHostStart( hConfig, @cError )
    HTTPAssert( hFailed == NIL .AND. ! Empty( cError ), ;
        "occupied HTTP port fails startup and rolls back other listeners", @nFailures, @nChecks )
    IF hFailed != NIL
        HBBridgeHostStop( hFailed )
    ENDIF
    hb_socketClose( hBusy )
    hConfig[ "httpEnabled" ] := .F.
    hHost := HBBridgeHostStart( hConfig, @cError )
    HTTPAssert( hHost != NIL, "HTTP startup rollback releases NETIO and TCP ports", @nFailures, @nChecks )
    IF hHost != NIL
        HBBridgeHostStop( hHost )
    ENDIF
    hb_cdpSelect( cPreviousCodepage )
RETURN

STATIC FUNCTION HTTPParallelEcho( nPort, nIndex, cAuthorization )
RETURN HTTPRequest( nPort, "POST", "/api/v1/services/Echo", ;
    hb_jsonEncode( { "index" => nIndex } ), cAuthorization )[ "json" ]

STATIC PROCEDURE HTTPDribble( hSocket, hState )
    DO WHILE ! hb_mutexEval( hState[ "mutex" ], {|| hState[ "stopping" ] } )
        IF hb_socketSend( hSocket, "x",,, 1000 ) <= 0
            EXIT
        ENDIF
        hb_idleSleep( 0.005 )
    ENDDO
RETURN

STATIC PROCEDURE HTTPAssert( lCondition, cMessage, nFailures, nChecks )
    nChecks++
    IF lCondition
        ? "PASS", cMessage
    ELSE
        nFailures++
        ? "FAIL", cMessage
    ENDIF
RETURN

STATIC FUNCTION HTTPFreePort()
    LOCAL hSocket := hb_socketOpen(), nPort
    hb_socketBind( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
    nPort := hb_socketGetSockName( hSocket )[ HB_SOCKET_ADINFO_PORT ]
    hb_socketClose( hSocket )
RETURN nPort

STATIC FUNCTION HTTPContentLength( hResponse )
    LOCAL nStart := hb_BAt( "Content-Length: ", hResponse[ "headers" ] )
    IF nStart == 0
        RETURN -1
    ENDIF
RETURN Val( hb_BSubStr( hResponse[ "headers" ], nStart + 16 ) )

STATIC FUNCTION HTTPRequest( nPort, cMethod, cPath, cBody, cAuthorization, cContentType, cExtraHeaders, cLengthText )

    LOCAL hSocket := hb_socketOpen(), cRequest, cResponse := "", cBuffer := Space( 65536 )
    LOCAL nSent := 0, nCount, nSeparator, hResponse := { "status" => 0, "body" => "", "headers" => "", "json" => NIL }
    LOCAL cCRLF := Chr( 13 ) + Chr( 10 ), hJSON

    hb_default( @cContentType, "application/json" )
    hb_default( @cExtraHeaders, "" )
    hb_default( @cLengthText, hb_ntos( hb_BLen( cBody ) ) )
    IF ! hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", nPort }, 3000 )
        hb_socketClose( hSocket )
        RETURN hResponse
    ENDIF
    cRequest := cMethod + " " + cPath + " HTTP/1.1" + cCRLF + ;
        "Host: localhost" + cCRLF + "Connection: close" + cCRLF + ;
        "Content-Type: " + cContentType + cCRLF + "Content-Length: " + cLengthText + cCRLF
    IF ! Empty( cAuthorization )
        cRequest += "Authorization: " + cAuthorization + cCRLF
    ENDIF
    IF ! Empty( cExtraHeaders )
        cRequest += cExtraHeaders + cCRLF
    ENDIF
    cRequest += cCRLF + cBody
    DO WHILE nSent < hb_BLen( cRequest )
        nCount := hb_socketSend( hSocket, hb_BSubStr( cRequest, nSent + 1 ),,, 3000 )
        IF nCount <= 0
            EXIT
        ENDIF
        nSent += nCount
    ENDDO
    DO WHILE .T.
        nCount := hb_socketRecv( hSocket, @cBuffer,,, 3000 )
        IF nCount <= 0
            EXIT
        ENDIF
        cResponse += hb_BLeft( cBuffer, nCount )
    ENDDO
    hb_socketClose( hSocket )
    nSeparator := hb_BAt( cCRLF + cCRLF, cResponse )
    IF nSeparator > 0
        hResponse[ "headers" ] := hb_BLeft( cResponse, nSeparator - 1 )
        hResponse[ "body" ] := hb_BSubStr( cResponse, nSeparator + 4 )
        hResponse[ "status" ] := Val( SubStr( cResponse, 10, 3 ) )
        hb_jsonDecode( hResponse[ "body" ], @hJSON )
        hResponse[ "json" ] := hJSON
    ENDIF
RETURN hResponse
