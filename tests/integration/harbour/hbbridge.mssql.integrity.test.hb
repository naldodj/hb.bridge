/* Released to Public Domain. */
#include "hbsocket.ch"
REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE D03MSSQLMain( cConfig, cProfile, cMode )

    LOCAL cNulText := "A" + Chr( 0 ) + "B"
    LOCAL cAnsiText := hb_HexToStr( "61C3A7C3A36F" )
    LOCAL cBoundary := Replicate( "x", 2046 ) + hb_HexToStr( "F09F9880" ) + Replicate( "x", 2049 )
    LOCAL cError, cUnicode, cSQL, cRoute, cRequest

    LOCAL hPrivate, hConfig, hRegistry, hTCP, hHTTP, hSummary, hNative, hResult

    LOCAL nFailures, nChecks, nStart

    hConfig := HBBridgeConfig( {} )
    hTCP := NIL
    hHTTP := NIL
    nFailures := 0
    nChecks := 0
    cUnicode := hb_HexToStr( "61C3A7C3A36FE6BCA2F09F9880" )

    IF Empty( cConfig ) .OR. Empty( cProfile )
        ? "D03 prerequisite failed: CONFIG_AND_PROFILE_REQUIRED"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    hPrivate := HBBridgeConfig( { "-config=" + cConfig }, @cError )
    IF hPrivate == NIL .OR. ! hb_HHasKey( hPrivate[ "sqlProfiles" ], cProfile )
        ? "D03 prerequisite failed: CONFIG_OR_PROFILE_INVALID"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    IF hPrivate[ "sqlProfiles" ][ cProfile ][ "driver" ] != "mssql"
        ? "D03 prerequisite failed: MSSQL_PROFILE_REQUIRED"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    hb_cdpSelect( "UTF8EX" )
    hRegistry := HBBridgeBuiltinRegistry( { cProfile => hPrivate[ "sqlProfiles" ][ cProfile ] } )
    hConfig[ "httpHost" ] := "127.0.0.1"
    hConfig[ "httpPort" ] := D03FreePort()
    hConfig[ "httpPassword" ] := "d03-http-test-only"
    hTCP := HBBridgeServerStart( 0, 8, "127.0.0.1", hRegistry )
    hHTTP := HBBridgeHTTPStart( hConfig, hRegistry, {=>}, @cError )
    IF hTCP == NIL .OR. hHTTP == NIL
        IF hTCP != NIL
            HBBridgeServerStop( hTCP )
        ENDIF
        ? "D03 prerequisite failed: LISTENER_START_FAILED"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    BEGIN SEQUENCE WITH __BreakBlock()
        cSQL := "SELECT CAST(123.4567 AS float) AS FLOAT_VALUE, " + ;
            "CAST(-123.4567 AS float) AS FLOAT_NEGATIVE, CAST(1e-20 AS float) AS FLOAT_SMALL, " + ;
            "CAST(1e20 AS float) AS FLOAT_LARGE, CAST(123.4567 AS decimal(15,4)) AS DECIMAL_FOUR, " + ;
            "CAST(123.4567 AS decimal(15,2)) AS DECIMAL_TWO, " + ;
            "CONVERT(varchar(32),N'a'+NCHAR(231)+NCHAR(227)+N'o' COLLATE Latin1_General_100_CI_AS) AS ANSI_TEXT, " + ;
            "CONVERT(varchar(64),CONVERT(varbinary(32),CONVERT(varchar(32)," + ;
            "N'a'+NCHAR(231)+NCHAR(227)+N'o' COLLATE Latin1_General_100_CI_AS)),2) AS ANSI_STORAGE_HEX, " + ;
            "N'" + cUnicode + "' AS UNICODE_LITERAL, " + ;
            "REPLICATE(CAST(N'x' AS nvarchar(max)),2046)+CONVERT(nvarchar(max),0x3DD800DE)+" + ;
            "REPLICATE(CAST(N'x' AS nvarchar(max)),2049) AS UNICODE_BOUNDARY, " + ;
            "CAST(N'A'+NCHAR(0)+N'B' AS nvarchar(max)) AS NUL_TEXT, " + ;
            "CAST(N'' AS nvarchar(max)) AS EMPTY_TEXT, CAST(NULL AS nvarchar(max)) AS NULL_TEXT, " + ;
            "CONVERT(varchar(64),CAST(12345678901234567890.1234567890 AS decimal(30,10))) AS EXACT_TEXT"
        FOR EACH cRoute IN { "native", "json", "tcp", "http", "rest" }
            hResult := D03Query( cRoute, hRegistry, hTCP, hConfig, cProfile, cSQL )
            D03Assert( D03Success( hResult ), cRoute + ".query", @nFailures, @nChecks )
            IF ! D03Success( hResult )
                LOOP
            ENDIF
            IF cRoute == "native"
                hNative := hResult
            ENDIF
            D03Assert( hResult[ "rowCount" ] == 1, cRoute + ".rowCount", @nFailures, @nChecks )
            D03Assert( Abs( hResult[ "rows" ][ "1" ][ "FLOAT_VALUE" ] - 123.4567 ) < 0.000000001, ;
                cRoute + ".floatFraction", @nFailures, @nChecks )
            D03Assert( Abs( hResult[ "rows" ][ "1" ][ "FLOAT_NEGATIVE" ] + 123.4567 ) < 0.000000001, ;
                cRoute + ".floatNegative", @nFailures, @nChecks )
            D03Assert( Abs( hResult[ "rows" ][ "1" ][ "FLOAT_SMALL" ] * ( 10 ** 20 ) - 1 ) < 0.000000000001, ;
                cRoute + ".floatSmall", @nFailures, @nChecks )
            D03Assert( Abs( hResult[ "rows" ][ "1" ][ "FLOAT_LARGE" ] / ( 10 ** 20 ) - 1 ) < 0.000000000001, ;
                cRoute + ".floatLarge", @nFailures, @nChecks )
            D03Assert( hResult[ "rows" ][ "1" ][ "ANSI_TEXT" ] == cAnsiText .AND. ;
                hResult[ "rows" ][ "1" ][ "ANSI_STORAGE_HEX" ] == "61E7E36F", ;
                cRoute + ".varcharCP1252ToUTF8", @nFailures, @nChecks )
            D03Assert( hResult[ "rows" ][ "1" ][ "UNICODE_LITERAL" ] == cUnicode, ;
                cRoute + ".unicodeSQLInputAndResult", @nFailures, @nChecks )
            D03Assert( hResult[ "rows" ][ "1" ][ "UNICODE_BOUNDARY" ] == cBoundary, ;
                cRoute + ".surrogateChunk", @nFailures, @nChecks )
            D03Assert( hResult[ "rows" ][ "1" ][ "NUL_TEXT" ] == cNulText .AND. ;
                hResult[ "rows" ][ "1" ][ "EMPTY_TEXT" ] == "" .AND. ;
                hResult[ "rows" ][ "1" ][ "NULL_TEXT" ] == NIL, cRoute + ".nulEmptyNull", @nFailures, @nChecks )
            D03Assert( hResult[ "rows" ][ "1" ][ "DECIMAL_FOUR" ] == 123.4567 .AND. ;
                hResult[ "rows" ][ "1" ][ "DECIMAL_TWO" ] == 123.46 .AND. ;
                hResult[ "rows" ][ "1" ][ "EXACT_TEXT" ] == "12345678901234567890.1234567890", ;
                cRoute + ".decimalAndExactText", @nFailures, @nChecks )
            D03Assert( hResult[ "rows" ][ "1" ][ "FLOAT_VALUE" ] == hNative[ "rows" ][ "1" ][ "FLOAT_VALUE" ], ;
                cRoute + ".nativeFloatEquality", @nFailures, @nChecks )
        NEXT
        FOR EACH cRoute IN { "native", "json", "tcp", "http", "rest" }
            hResult := D03Query( cRoute, hRegistry, hTCP, hConfig, cProfile, ;
                "SELECT CAST(0x0080FFC3A900 AS varbinary(max)) AS RAW_BYTES" )
            IF cRoute == "native"
                D03Assert( D03Success( hResult ) .AND. hResult[ "rows" ][ "1" ][ "RAW_BYTES" ] == ;
                    hb_HexToStr( "0080FFC3A900" ), cRoute + ".nativeBinary", @nFailures, @nChecks )
            ELSE
                D03Assert( ! D03Success( hResult ) .AND. ;
                    hb_HGetDef( hResult, "code", "" ) == "BINARY_JSON_UNSUPPORTED", ;
                    cRoute + ".binaryRequiresExplicitEncoding", @nFailures, @nChecks )
            ENDIF
            hResult := D03Query( cRoute, hRegistry, hTCP, hConfig, cProfile, "SELECT 7 AS ID" )
            D03Assert( D03Success( hResult ) .AND. hResult[ "rows" ][ "1" ][ "ID" ] == 7, ;
                cRoute + ".recovery", @nFailures, @nChecks )
        NEXT
        cRequest := '{"service":"Echo","params":{"text":"\u00e7\u6f22\ud83d\ude00"}}'
        hResult := D03TCP( hTCP[ "port" ], cRequest )
        D03Assert( D03Success( hResult ) .AND. hResult[ "params" ][ "text" ] == ;
            hb_HexToStr( "C3A7E6BCA2F09F9880" ), "tcp.escapedUnicode", @nFailures, @nChecks )
        hResult := D03TCP( hTCP[ "port" ], '{"service":"Echo","params":"' + Chr( 255 ) + '"}' )
        D03Assert( ! D03Success( hResult ) .AND. hResult[ "code" ] == "INVALID_UTF8", ;
            "tcp.invalidUTF8", @nFailures, @nChecks )
        hResult := D03TCP( hTCP[ "port" ], '{"service":"Health","params":"\ud800"}' )
        D03Assert( ! D03Success( hResult ) .AND. hResult[ "code" ] == "INVALID_JSON", ;
            "tcp.invalidSurrogate", @nFailures, @nChecks )
        hSummary := { "fixture" => "d03.mssql.constants.v1", "checks" => nChecks, ;
            "failures" => nFailures, "success" => nFailures == 0, "profile" => cProfile, ;
            "tcpPort" => hTCP[ "port" ], "httpPort" => hConfig[ "httpPort" ], ;
            "httpToken" => hConfig[ "httpPassword" ] }
        hb_MemoWrit( "endpoints.json", HBBridgeJSONEncode( hSummary ) )
        IF cMode == "serve" .AND. nFailures == 0
            ? "D03 isolated listeners ready; endpoint file=endpoints.json; stop file=d03.stop"
            nStart := HBBridgeMonotonicMs()
            DO WHILE ! hb_FileExists( "d03.stop" ) .AND. HBBridgeMonotonicMs() - nStart < 600000
                hb_idleSleep( 0.1 )
            ENDDO
        ENDIF
    RECOVER
        D03Assert( .F., "controlledUnexpectedFailure", @nFailures, @nChecks )
    ALWAYS
        HBBridgeHTTPStop( hHTTP )
        HBBridgeServerStop( hTCP )
    END SEQUENCE
    ? "D03 MSSQL checks:", nChecks, "failures:", nFailures
    ErrorLevel( iif( nFailures == 0, 0, 1 ) )

RETURN

STATIC FUNCTION D03Query( cRoute, hRegistry, hTCP, hConfig, cProfile, cSQL )

    LOCAL cJSON

    LOCAL hParams := { "alias" => cProfile, "sql" => cSQL }, hResult, hResponse

    IF cRoute == "native"
        RETURN HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, HBBridgeContext( "d03" ) )
    ENDIF
    cJSON := HBBridgeJSONEncode( { "service" => "RPCRDD.Query", "params" => hParams } )
    DO CASE
    CASE cRoute == "json"
        cJSON := DispatcherRequest( cJSON, hRegistry )
    CASE cRoute == "tcp"
        RETURN D03TCP( hTCP[ "port" ], cJSON )
    OTHERWISE
        hResponse := HBBridgeHTTPTestRequest( hConfig[ "httpPort" ], "POST", ;
            iif( cRoute == "rest", "/api/v1/services/RPCRDD.Query", "/api/v1/rpc" ), ;
            iif( cRoute == "rest", HBBridgeJSONEncode( hParams ), cJSON ), "Bearer " + hConfig[ "httpPassword" ] )
        cJSON := hResponse[ "body" ]
    ENDCASE
    HBBridgeJSONDecode( cJSON, @hResult )

RETURN hResult

STATIC FUNCTION D03TCP( nPort, cJSON )

    LOCAL cResult

    LOCAL hSocket := hb_socketOpen(), hResult

    BEGIN SEQUENCE WITH __BreakBlock()
        IF hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", nPort }, 5000 ) .AND. ;
            SendResponse( hSocket, cJSON ) .AND. ReceiveRequest( hSocket, @cResult )
            HBBridgeJSONDecode( cResult, @hResult )
        ENDIF
    ALWAYS
        hb_socketClose( hSocket )
    END SEQUENCE

RETURN hResult

STATIC FUNCTION D03FreePort()
    LOCAL aAddress

    LOCAL hSocket := hb_socketOpen()
    hb_socketBind( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
    aAddress := hb_socketGetSockName( hSocket )
    hb_socketClose( hSocket )
RETURN aAddress[ HB_SOCKET_ADINFO_PORT ]

STATIC FUNCTION D03Success( hResult )
RETURN HB_ISHASH( hResult ) .AND. hb_HGetDef( hResult, "success", .F. )

STATIC PROCEDURE D03Assert( lPassed, cLabel, nFailures, nChecks )
    nChecks++
    IF ! lPassed
        nFailures++
    ENDIF
    ? iif( lPassed, "PASS D03 ", "FAIL D03 " ) + cLabel
RETURN
