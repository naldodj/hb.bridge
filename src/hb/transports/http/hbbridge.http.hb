/* Released to Public Domain. */
#include "hbthread.ch"
REQUEST HB_TCPIO
REQUEST HB_CODEPAGE_UTF8EX
#ifdef HBBRIDGE_HTTP_TLS
REQUEST __HBEXTERN__HBSSL__
#endif

/* hbhttpd owns HTTP parsing, sockets and its worker pool. This adapter owns
 * authorization and invokes the same registry used by NETIO and TCP clients.
 */
MEMVAR server

FUNCTION HBBridgeHTTPStart( hConfig, hRegistry, hHost, cError )

    LOCAL hHTTP, lReady := .F.

    cError := ""
    hHTTP := { "mutex" => hb_mutexCreate(), "stopMutex" => hb_mutexCreate(), ;
        "readyMutex" => hb_mutexCreate(), "ready" => .F., "stopping" => .F., ;
        "active" => 0, "requests" => 0, "rejected" => 0, ;
        "host" => hConfig[ "httpHost" ], "port" => hConfig[ "httpPort" ], ;
        "maxWorkers" => hConfig[ "maxWorkers" ], "listener" => NIL, ;
        "server" => UHttpdNew(), "config" => hConfig, "registry" => hRegistry, ;
        "context" => HBBridgeContext( "http", hConfig[ "addonRoot" ], hHost ), ;
        "adminContext" => HBBridgeContext( "http.admin", hConfig[ "addonRoot" ], hHost, .T. ) }
    hHTTP[ "listener" ] := hb_threadStart( 0, @HBBridgeHTTPRun(), hHTTP )
    IF Empty( hHTTP[ "listener" ] )
        cError := "Unable to create the HTTP listener thread"
        RETURN NIL
    ENDIF
    IF ! hb_mutexSubscribe( hHTTP[ "readyMutex" ], 5, @lReady ) .OR. ! lReady
        cError := "Unable to start hbhttpd: " + hHTTP[ "server" ]:cError
        HBBridgeHTTPStop( hHTTP )
        RETURN NIL
    ENDIF

RETURN hHTTP

STATIC PROCEDURE HBBridgeHTTPRun( hHTTP )

    LOCAL hConfig := hHTTP[ "config" ], hNative, lReady

    hNative := { "BindAddress" => hConfig[ "httpHost" ], "Port" => hConfig[ "httpPort" ], ;
        "FirewallFilter" => "", ;
        "MaxWorkers" => hConfig[ "maxWorkers" ], ;
        "SSL" => hConfig[ "httpTLS" ], "PrivateKeyFilename" => hConfig[ "httpPrivateKey" ], ;
        "CertificateFilename" => hConfig[ "httpCertificate" ], ;
        "Ready" => {| oServer | HBBridgeHTTPReady( hHTTP, oServer ) }, ;
        "Idle" => {| oServer | HBBridgeHTTPReady( hHTTP, oServer ) }, ;
        "Mount" => { "/*" => {| cPath | HBBridgeHTTPHandle( hHTTP, cPath ) } } }
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hHTTP[ "server" ]:Run( hNative )
    RECOVER
        /* Native diagnostics can contain request data. Do not publish them. */
        hHTTP[ "server" ]:cError := "HTTP listener failure"
    ALWAYS
        lReady := hb_mutexEval( hHTTP[ "mutex" ], {|| hHTTP[ "ready" ] } )
        hb_mutexEval( hHTTP[ "mutex" ], {|| hHTTP[ "stopping" ] := .T. } )
        IF ! lReady
            hb_mutexNotify( hHTTP[ "readyMutex" ], .F. )
        ENDIF
    END SEQUENCE
RETURN

STATIC PROCEDURE HBBridgeHTTPReady( hHTTP, oServer )
    IF hb_mutexEval( hHTTP[ "mutex" ], {|| HBBridgeHTTPMarkReady( hHTTP ) } )
        hb_mutexNotify( hHTTP[ "readyMutex" ], .T. )
    ENDIF
    IF hb_mutexEval( hHTTP[ "mutex" ], {|| hHTTP[ "stopping" ] } )
        oServer:Stop()
    ENDIF
RETURN

STATIC FUNCTION HBBridgeHTTPMarkReady( hHTTP )
    IF hHTTP[ "ready" ]
        RETURN .F.
    ENDIF
    hHTTP[ "ready" ] := .T.
RETURN .T.

FUNCTION HBBridgeHTTPStop( hHTTP )
RETURN hb_mutexEval( hHTTP[ "stopMutex" ], {|| HBBridgeHTTPStopAndJoin( hHTTP ) } )

STATIC FUNCTION HBBridgeHTTPStopAndJoin( hHTTP )
    LOCAL lStopped := .T.
    hb_mutexEval( hHTTP[ "mutex" ], {|| hHTTP[ "stopping" ] := .T. } )
    hHTTP[ "server" ]:Stop()
    IF ! Empty( hHTTP[ "listener" ] )
        lStopped := hb_threadJoin( hHTTP[ "listener" ] )
        hHTTP[ "listener" ] := NIL
    ENDIF
RETURN lStopped

STATIC FUNCTION HBBridgeHTTPHandle( hHTTP, cPath )

    LOCAL cPreviousCodepage := hb_cdpSelect(), cResult

    /* Codepages are local to the worker. JSON and the executor share UTF-8
     * for this request; restore the native worker's codepage on every exit.
     * Configuration and credentials keep their original byte representation.
     */
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hb_cdpSelect( "UTF8EX" )
        cResult := HBBridgeHTTPRequest( hHTTP, cPath )
    RECOVER
        cResult := HBBridgeHTTPJSON( HBBridgeError( "SERVICE_ERROR", "HTTP request failed" ), 500 )
    ALWAYS
        hb_cdpSelect( cPreviousCodepage )
    END SEQUENCE

RETURN cResult

STATIC FUNCTION HBBridgeHTTPRequest( hHTTP, cPath )

    LOCAL lAdmin := cPath == "admin" .OR. Left( cPath, 6 ) == "admin/"
    LOCAL hResult, cBody, nConsumed, xParams, cMethod := server[ "REQUEST_METHOD" ]
    LOCAL cContentType, nSemicolon, cService, lAdmitted, cResult

    UAddHeader( "Cache-Control", "no-store" )
    UAddHeader( "X-Content-Type-Options", "nosniff" )
    IF ! HBBridgeHTTPAuthorized( hHTTP, lAdmin )
        hb_mutexEval( hHTTP[ "mutex" ], {|| hHTTP[ "rejected" ]++ } )
        IF lAdmin .AND. Empty( hHTTP[ "config" ][ "adminPassword" ] )
            RETURN HBBridgeHTTPJSON( HBBridgeError( "ADMIN_DISABLED", "Web administration is disabled" ), 403 )
        ENDIF
        UAddHeader( "WWW-Authenticate", iif( lAdmin, ;
            'Basic realm="hbBridge admin", charset="UTF-8"', 'Bearer realm="hbBridge"' ) )
        RETURN HBBridgeHTTPJSON( HBBridgeError( "UNAUTHORIZED", "Authentication required" ), 401 )
    ENDIF
    lAdmitted := hb_mutexEval( hHTTP[ "mutex" ], {|| HBBridgeHTTPAdmit( hHTTP ) } )
    IF ! lAdmitted
        RETURN HBBridgeHTTPJSON( HBBridgeError( "BUSY", "HTTP executor capacity is unavailable" ), 503 )
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        DO CASE
        CASE lAdmin
            cResult := HBBridgeHTTPAdmin( hHTTP, cPath, cMethod )
        CASE cPath == "api/v1/health" .AND. cMethod == "GET"
            hResult := HBBridgeDispatch( hHTTP[ "registry" ], "Health", NIL, hHTTP[ "context" ] )
            cResult := HBBridgeHTTPJSON( hResult )
        CASE cPath == "api/v1/services" .AND. cMethod == "GET"
            hResult := HBBridgeDispatch( hHTTP[ "registry" ], "Service.List", NIL, hHTTP[ "context" ] )
            cResult := HBBridgeHTTPJSON( hResult )
        CASE cPath == "api/v1/rpc" .OR. Left( cPath, 16 ) == "api/v1/services/"
            IF ! ( cMethod == "POST" )
                UAddHeader( "Allow", "POST" )
                cResult := HBBridgeHTTPJSON( HBBridgeError( "METHOD_NOT_ALLOWED", "Use POST for service calls" ), 405 )
            ELSE
                cContentType := Lower( hb_HGetDef( server, "CONTENT_TYPE", "" ) )
                nSemicolon := At( ";", cContentType )
                IF nSemicolon > 0
                    cContentType := AllTrim( Left( cContentType, nSemicolon - 1 ) )
                ENDIF
                IF ! ( cContentType == "application/json" ) .OR. ;
                    ! ( Lower( hb_HGetDef( server, "HTTP_CONTENT_ENCODING", "identity" ) ) == "identity" )
                    cResult := HBBridgeHTTPJSON( HBBridgeError( "UNSUPPORTED_MEDIA_TYPE", ;
                        "Use uncompressed application/json" ), 415 )
                ELSE
                    /* REQUEST_BODY is exposed by the documented managed hbhttpd patch. */
                    cBody := hb_HGetDef( server, "REQUEST_BODY", "" )
                    IF ! HBBridgeUTF8Valid( cBody )
                        cResult := HBBridgeHTTPJSON( HBBridgeError( "INVALID_UTF8", "JSON must use valid UTF-8" ), 400 )
                    ELSEIF ( cBody := HBBridgeHTTPJSONNormalize( cBody ) ) == NIL
                        cResult := HBBridgeHTTPJSON( HBBridgeError( "INVALID_JSON", "Invalid Unicode escape in JSON" ), 400 )
                    ELSEIF cPath == "api/v1/rpc"
                        cResult := DispatcherRequest( cBody, hHTTP[ "registry" ], hHTTP[ "context" ] )
                        hb_jsonDecode( cResult, @hResult, "UTF8" )
                        cResult := HBBridgeHTTPJSON( hResult )
                    ELSE
                        nConsumed := hb_jsonDecode( cBody, @xParams, "UTF8" )
                        IF nConsumed == 0 .OR. ! Empty( AllTrim( hb_BSubStr( cBody, nConsumed + 1 ) ) )
                            cResult := HBBridgeHTTPJSON( HBBridgeError( "INVALID_JSON", "Invalid JSON request" ), 400 )
                        ELSE
                            cService := UUrlDecode( SubStr( cPath, 17 ) )
                            hResult := HBBridgeDispatch( hHTTP[ "registry" ], cService, xParams, hHTTP[ "context" ] )
                            cResult := HBBridgeHTTPJSON( hResult )
                        ENDIF
                    ENDIF
                ENDIF
            ENDIF
        OTHERWISE
            cResult := HBBridgeHTTPJSON( HBBridgeError( "NOT_FOUND", "HTTP route not found" ), 404 )
        ENDCASE
    RECOVER
        cResult := HBBridgeHTTPJSON( HBBridgeError( "SERVICE_ERROR", "HTTP request failed" ), 500 )
    ALWAYS
        hb_mutexEval( hHTTP[ "mutex" ], {|| hHTTP[ "active" ]-- } )
    END SEQUENCE

RETURN cResult

STATIC FUNCTION HBBridgeHTTPAdmit( hHTTP )
    IF hHTTP[ "stopping" ] .OR. hHTTP[ "active" ] >= hHTTP[ "maxWorkers" ]
        RETURN .F.
    ENDIF
    hHTTP[ "active" ]++
    hHTTP[ "requests" ]++
RETURN .T.

STATIC FUNCTION HBBridgeHTTPAuthorized( hHTTP, lAdmin )
    LOCAL cAuthorization := hb_HGetDef( server, "HTTP_AUTHORIZATION", "" ), cExpected, cScheme
    LOCAL nSeparator := At( " ", cAuthorization )
    IF nSeparator == 0
        RETURN .F.
    ENDIF
    cScheme := Lower( Left( cAuthorization, nSeparator - 1 ) )
    cAuthorization := LTrim( SubStr( cAuthorization, nSeparator + 1 ) )
    IF lAdmin
        IF ! ( cScheme == "basic" ) .OR. Empty( hHTTP[ "config" ][ "adminPassword" ] )
            RETURN .F.
        ENDIF
        cExpected := hb_base64Encode( "admin:" + hHTTP[ "config" ][ "adminPassword" ] )
    ELSE
        IF ! ( cScheme == "bearer" )
            RETURN .F.
        ENDIF
        cExpected := hHTTP[ "config" ][ "httpPassword" ]
    ENDIF
RETURN HBBridgeHTTPSecretEqual( cAuthorization, cExpected )

STATIC FUNCTION HBBridgeHTTPSecretEqual( cActual, cExpected )
    LOCAL nDifference := hb_bitXor( hb_BLen( cActual ), hb_BLen( cExpected ) ), nIndex
    IF hb_BLen( cActual ) != hb_BLen( cExpected )
        RETURN .F.
    ENDIF
    FOR nIndex := 1 TO hb_BLen( cExpected )
        nDifference := hb_bitOr( nDifference, ;
            hb_bitXor( hb_BCode( hb_BSubStr( cActual, nIndex, 1 ) ), hb_BCode( hb_BSubStr( cExpected, nIndex, 1 ) ) ) )
    NEXT
RETURN nDifference == 0

STATIC FUNCTION HBBridgeHTTPAdmin( hHTTP, cPath, cMethod )
    LOCAL hResult
    IF ! ( cMethod == "GET" )
        UAddHeader( "Allow", "GET" )
        RETURN HBBridgeHTTPJSON( HBBridgeError( "METHOD_NOT_ALLOWED", "Administration uses GET" ), 405 )
    ENDIF
    IF ! ( cPath == "admin" .OR. cPath == "admin/" .OR. cPath == "admin/status" )
        RETURN HBBridgeHTTPJSON( HBBridgeError( "NOT_FOUND", "Administration route not found" ), 404 )
    ENDIF
    hResult := HBBridgeDispatch( hHTTP[ "registry" ], "Admin.Status", NIL, hHTTP[ "adminContext" ] )
    IF cPath == "admin/status"
        RETURN HBBridgeHTTPJSON( hResult )
    ENDIF
    UAddHeader( "Content-Type", "text/html; charset=utf-8" )
    UAddHeader( "Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'" )
RETURN '<!doctype html><html lang="en"><meta charset="utf-8"><title>hbBridge administration</title>' + ;
    '<style>body{font:16px system-ui;max-width:900px;margin:3rem auto;padding:1rem;background:#f5f7fb}' + ;
    'pre{background:white;padding:1.5rem;overflow:auto;border:1px solid #ddd}a{color:#1266b0}</style>' + ;
    '<h1>hbBridge administration</h1><p>Live status of hbBridge and the embedded NETIO endpoints.</p>' + ;
    '<form method="get"><button type="submit">Refresh status</button></form><pre>' + ;
    UHtmlEncode( hb_jsonEncode( hResult, .T., "UTF8" ) ) + '</pre><p><a href="/admin/status">JSON status</a></p></html>'

STATIC FUNCTION HBBridgeHTTPJSON( hResult, nStatus )
    LOCAL cCode, cJSON := hb_jsonEncode( hResult, .F., "UTF8" )
    IF ! HBBridgeUTF8Valid( cJSON )
        hResult := HBBridgeError( "INVALID_UTF8_RESULT", "Service result must use valid UTF-8 text" )
        cJSON := hb_jsonEncode( hResult, .F., "UTF8" )
        nStatus := 500
    ENDIF
    IF nStatus == NIL
        nStatus := 200
        IF HB_ISHASH( hResult ) .AND. hb_HGetDef( hResult, "success", .T. ) == .F.
            cCode := hb_HGetDef( hResult, "code", "SERVICE_ERROR" )
            DO CASE
            CASE cCode == "FORBIDDEN"
                nStatus := 403
            CASE cCode == "SERVICE_NOT_FOUND"
                nStatus := 404
            CASE Left( cCode, 7 ) == "INVALID"
                nStatus := 400
            OTHERWISE
                nStatus := 500
            ENDCASE
        ENDIF
    ENDIF
    USetStatusCode( nStatus )
    UAddHeader( "Content-Type", "application/json; charset=utf-8" )
RETURN cJSON
