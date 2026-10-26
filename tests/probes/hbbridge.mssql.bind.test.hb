/* Released to Public Domain. */
REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE MSSQLBindTests( cConfig, cProfile )

    LOCAL cError, cPreviousCodepage

    LOCAL hConfig, hResult

    LOCAL nExit := 1

    cPreviousCodepage := hb_cdpSelect( "UTF8EX" )
    hResult := { "schemaVersion" => 1, "success" => .F., "error" => "PREREQUISITE_UNAVAILABLE" }
    BEGIN SEQUENCE WITH __BreakBlock()
        IF ! HB_ISSTRING( cConfig ) .OR. ! HB_ISSTRING( cProfile ) .OR. Empty( cProfile )
            Break( NIL )
        ENDIF
        hConfig := HBBridgeConfig( { "-config=" + cConfig }, @cError )
        IF hConfig == NIL .OR. ! hb_HHasKey( hConfig[ "sqlProfiles" ], cProfile ) .OR. ;
            hConfig[ "sqlProfiles" ][ cProfile ][ "driver" ] != "mssql"
            Break( NIL )
        ENDIF
        hResult := HBBridgeMSSQLBindProbe( hConfig[ "sqlProfiles" ][ cProfile ][ "connectionString" ] )
        hResult[ "scope" ] := "Windows native ODBC prepared-binding and declared session-table proof; no SQLMIX integration"
        nExit := iif( hResult[ "success" ], 0, 1 )
    RECOVER
        hResult := { "schemaVersion" => 1, "success" => .F., "error" => "UNEXPECTED_PROBE_FAILURE" }
    ALWAYS
        hb_cdpSelect( cPreviousCodepage )
        IF ! hb_MemoWrit( "result.json", HBBridgeJSONEncode( hResult, .T. ) )
            nExit := 1
        ENDIF
    END SEQUENCE
    ? "MSSQL native binding probe:", iif( nExit == 0, "OK", "FAILED" )
    IF hb_HHasKey( hResult, "checks" )
        ? "Checks:", hResult[ "checkCount" ], "Failures:", hResult[ "failureCount" ]
    ENDIF
    ErrorLevel( nExit )

RETURN
