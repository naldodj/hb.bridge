/* Released to Public Domain. */
/* The host supplies the native context only to trusted, installed addon code.
 * Rows stay in this process; the response contains measurements/checks only.
 */
FUNCTION Main( cJSON, hContext )

    LOCAL cKey, cProfile, cSQL

    LOCAL hParams, hReport, hSample, hSeries

    LOCAL lWarmup

    LOCAL nIteration, nRows, nSize, nIterations, nWarmup, nStarted, nTotal := 0, nMin := 0, nMax := 0
    LOCAL nCompleted := 0

    IF ! HB_ISSTRING( cJSON ) .OR. hb_jsonDecode( cJSON, @hParams ) == 0 .OR. ;
        ! HB_ISHASH( hParams ) .OR. ! HB_ISHASH( hContext )
        RETURN hb_jsonEncode( AddonFailure( "INVALID_PARAMS" ) )
    ENDIF
    IF ! hb_HHasKey( hContext, "registry" )
        RETURN hb_jsonEncode( AddonFailure( "INVALID_CONTEXT" ) )
    ENDIF
    IF Len( hParams ) != 5
        RETURN hb_jsonEncode( AddonFailure( "INVALID_PARAMS" ) )
    ENDIF
    FOR EACH cKey IN { "profile", "rows", "pageSize", "iterations", "warmup" }
        IF ! hb_HHasKey( hParams, cKey )
            RETURN hb_jsonEncode( AddonFailure( "INVALID_PARAMS" ) )
        ENDIF
    NEXT
    cProfile := hParams[ "profile" ]
    nRows := hParams[ "rows" ]
    nSize := hParams[ "pageSize" ]
    nIterations := hParams[ "iterations" ]
    nWarmup := hParams[ "warmup" ]
    IF ! HB_ISSTRING( cProfile )
        RETURN hb_jsonEncode( AddonFailure( "INVALID_PARAMS" ) )
    ENDIF
    IF Empty( AllTrim( cProfile ) ) .OR. Chr( 0 ) $ cProfile .OR. ;
        ! AddonInteger( nRows, 1, 100000 ) .OR. ! AddonInteger( nSize, 1, 100000 ) .OR. ;
        ! AddonInteger( nIterations, 1, 1000000 ) .OR. ! AddonInteger( nWarmup, 0, 1000000 )
        RETURN hb_jsonEncode( AddonFailure( "INVALID_PARAMS" ) )
    ENDIF
    cSQL := AddonSQL( nRows )
    hSeries := { "success" => .F., "completedIterations" => 0, "warmupCompleted" => 0, ;
        "totalMs" => NIL, "minMs" => NIL, "maxMs" => NIL, "avgMs" => NIL, ;
        "measuredCalls" => 0, "measuredRows" => 0, "samples" => {=>}, "warmupSamples" => {=>}, ;
        "failureCategory" => "", "failurePhase" => "", "failureIteration" => 0, ;
        "statisticsScope" => "successful server-side measured traversals only; warmups excluded", ;
        "timingScope" => "Harbour addon: local paged dispatcher, SQL, hash traversal and value validation; excludes transport and HRB loading", ;
        "clock" => "HBBridgeMonotonicMs", "clockResolution" => "native whole milliseconds; Windows system tick resolution applies" }
    nStarted := HBBridgeMonotonicMs()
    BEGIN SEQUENCE WITH __BreakBlock()
        FOR nIteration := 1 TO nWarmup + nIterations
            lWarmup := nIteration <= nWarmup
            hSample := AddonIteration( hContext, cProfile, cSQL, nRows, nSize )
            cKey := hb_ntos( iif( lWarmup, nIteration, nIteration - nWarmup ) )
            hSeries[ iif( lWarmup, "warmupSamples", "samples" ) ][ cKey ] := hSample
            IF ! hSample[ "success" ]
                hSeries[ "failureCategory" ] := iif( lWarmup, "WARMUP_FAILED", "MEASURED_ITERATION_FAILED" )
                hSeries[ "failurePhase" ] := iif( lWarmup, "warmup", "measured" )
                hSeries[ "failureIteration" ] := Val( cKey )
                EXIT
            ENDIF
            IF lWarmup
                hSeries[ "warmupCompleted" ]++
            ELSE
                nCompleted++
                nTotal += hSample[ "elapsedMs" ]
                nMin := iif( nCompleted == 1, hSample[ "elapsedMs" ], Min( nMin, hSample[ "elapsedMs" ] ) )
                nMax := Max( nMax, hSample[ "elapsedMs" ] )
                hSeries[ "measuredCalls" ] += hSample[ "rpcCalls" ]
                hSeries[ "measuredRows" ] += hSample[ "rowsRead" ]
            ENDIF
        NEXT
        hSeries[ "success" ] := nCompleted == nIterations .AND. hSeries[ "warmupCompleted" ] == nWarmup
    RECOVER
        hSeries[ "failureCategory" ] := "RUNTIME_EXCEPTION"
    END SEQUENCE
    hSeries[ "completedIterations" ] := nCompleted
    IF nCompleted > 0
        hSeries[ "totalMs" ] := nTotal
        hSeries[ "minMs" ] := nMin
        hSeries[ "maxMs" ] := nMax
        hSeries[ "avgMs" ] := nTotal / nCompleted
    ENDIF
    hSeries[ "serverRunElapsedMs" ] := HBBridgeMonotonicMs() - nStarted
    hReport := { "schemaVersion" => 1, "success" => hSeries[ "success" ], ;
        "fixture" => "m08.constant.v1", "profile" => cProfile, "rowsPerIteration" => nRows, ;
        "pageSize" => nSize, "iterations" => nIterations, "warmupIterations" => nWarmup, ;
        "series" => hSeries }

RETURN hb_jsonEncode( hReport )

STATIC FUNCTION AddonIteration( hContext, cProfile, cSQL, nRows, nSize )

    LOCAL cFailure

    LOCAL hSample, hResult, hRow

    LOCAL nStarted, nPages, nPage, nRow, nExpected, nID

    nStarted := HBBridgeMonotonicMs()
    nPages := Int( ( nRows - 1 ) / nSize ) + 1
    hSample := { "success" => .F., "failureCategory" => "", "serviceCode" => "", ;
        "httpStatus" => NIL, "failedPage" => NIL, "rowsRead" => 0, "pagesRead" => 0, "rpcCalls" => 0 }
    cFailure := ""

    BEGIN SEQUENCE WITH __BreakBlock()
        FOR nPage := 1 TO nPages
            hSample[ "rpcCalls" ]++
            hResult := HBBridgeDispatch( hContext[ "registry" ], "RPCRDD.Query", ;
                { "alias" => cProfile, "sql" => cSQL, ;
                    "page" => { "number" => nPage, "size" => nSize, "orderBy" => "ID ASC" } }, hContext )
            IF ! HB_ISHASH( hResult ) .OR. ! hb_HGetDef( hResult, "success", .F. )
                cFailure := "QUERY_FAILED"
                IF HB_ISHASH( hResult )
                    hSample[ "serviceCode" ] := AddonCode( hb_HGetDef( hResult, "code", "" ) )
                ENDIF
                EXIT
            ENDIF
            nExpected := Min( nSize, nRows - ( nPage - 1 ) * nSize )
            IF Len( hResult[ "header" ] ) != 3 .OR. ;
                hResult[ "header" ][ "ID" ][ "position" ] != 1 .OR. ;
                hResult[ "header" ][ "NAME" ][ "position" ] != 2 .OR. ;
                hResult[ "header" ][ "AMOUNT" ][ "position" ] != 3
                cFailure := "METADATA_MISMATCH"
                EXIT
            ENDIF
            IF hResult[ "rowCount" ] != nExpected .OR. hResult[ "totalRows" ] != nRows .OR. ;
                hResult[ "totalPages" ] != nPages .OR. hResult[ "page" ][ "number" ] != nPage .OR. ;
                hResult[ "page" ][ "size" ] != nSize .OR. ;
                hResult[ "page" ][ "hasNext" ] != ( nPage < nPages )
                cFailure := "PAGE_MISMATCH"
                EXIT
            ENDIF
            FOR nRow := 1 TO nExpected
                nID := ( nPage - 1 ) * nSize + nRow
                hRow := hResult[ "rows" ][ hb_ntos( nRow ) ]
                IF ! HB_ISNUMERIC( hRow[ "ID" ] ) .OR. ! HB_ISSTRING( hRow[ "NAME" ] ) .OR. ;
                    ! HB_ISNUMERIC( hRow[ "AMOUNT" ] )
                    cFailure := "VALUE_TYPE_MISMATCH"
                    EXIT
                ENDIF
                IF hRow[ "ID" ] != nID .OR. AllTrim( hRow[ "NAME" ] ) != "hbbridge-" + hb_ntos( nID ) .OR. ;
                    hRow[ "AMOUNT" ] != nID / 4
                    cFailure := "VALUE_MISMATCH"
                    EXIT
                ENDIF
                hSample[ "rowsRead" ]++
            NEXT
            IF ! Empty( cFailure )
                EXIT
            ENDIF
            hSample[ "pagesRead" ]++
            hResult := NIL
        NEXT
    RECOVER
        cFailure := "RUNTIME_EXCEPTION"
    END SEQUENCE
    hSample[ "success" ] := Empty( cFailure )
    hSample[ "failureCategory" ] := cFailure
    IF ! Empty( cFailure ) .AND. HB_ISNUMERIC( nPage ) .AND. nPage <= nPages
        hSample[ "failedPage" ] := nPage
    ENDIF
    hSample[ "elapsedMs" ] := HBBridgeMonotonicMs() - nStarted

RETURN hSample

STATIC FUNCTION AddonInteger( xValue, nMin, nMax )
    IF ! HB_ISNUMERIC( xValue )
        RETURN .F.
    ENDIF
RETURN xValue >= nMin .AND. xValue <= nMax .AND. xValue == Int( xValue )

STATIC FUNCTION AddonFailure( cCode )
RETURN { "success" => .F., "code" => cCode, "error" => "Benchmark addon could not complete the fixture." }

STATIC FUNCTION AddonCode( xCode )
    LOCAL nIndex, nLength
    IF ! HB_ISSTRING( xCode ) .OR. Empty( xCode ) .OR. Len( xCode ) > 80
        RETURN "UNCLASSIFIED_CLIENT_ERROR"
    ENDIF
    nLength := Len( xCode )
    FOR nIndex := 1 TO nLength
        IF !( SubStr( xCode, nIndex, 1 ) $ "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_" )
            RETURN "UNCLASSIFIED_CLIENT_ERROR"
        ENDIF
    NEXT
RETURN xCode

STATIC FUNCTION AddonSQL( nRows )
    LOCAL cDigits := "(VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9))"
RETURN "SELECT ID, CAST('hbbridge-' + CAST(ID AS VARCHAR(10)) AS VARCHAR(32)) AS NAME, " + ;
    "CAST(ID * 0.25 AS DECIMAL(15,2)) AS AMOUNT FROM (SELECT 1 + A.N + 10 * B.N + " + ;
    "100 * C.N + 1000 * D.N + 10000 * E.N AS ID FROM " + cDigits + " A(N) CROSS JOIN " + ;
    cDigits + " B(N) CROSS JOIN " + cDigits + " C(N) CROSS JOIN " + cDigits + ;
    " D(N) CROSS JOIN " + cDigits + " E(N)) F WHERE ID <= " + hb_ntos( nRows )
