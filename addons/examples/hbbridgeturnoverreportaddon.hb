/* Released to Public Domain. Example adapter for a caller-supplied monthly report. */
FUNCTION Main( cJSON, hContext )

    LOCAL hBranch, hParams, hPeriodBranches, hReport

    IF ! HB_ISSTRING( cJSON ) .OR. ! HBBridgeJSONComplete( cJSON, HBBridgeJSONDecode( cJSON, @hParams ) ) .OR. ;
        ! HB_ISHASH( hParams ) .OR. ! HB_ISHASH( hContext )
        RETURN HBBridgeJSONEncode( TurnoverReportError( "INVALID_PARAMS" ) )
    ENDIF
    IF ( Len( hParams ) != 3 .AND. Len( hParams ) != 5 ) .OR. ;
        ! hb_HHasKey( hParams, "profile" ) .OR. ! hb_HHasKey( hParams, "sql" ) .OR. ;
        ! hb_HHasKey( hParams, "bindings" ) .OR. ;
        ! HB_ISSTRING( hParams[ "profile" ] ) .OR. Empty( AllTrim( hParams[ "profile" ] ) ) .OR. ;
        ! HB_ISSTRING( hParams[ "sql" ] ) .OR. Empty( AllTrim( hParams[ "sql" ] ) ) .OR. ;
        ! HB_ISHASH( hParams[ "bindings" ] ) .OR. ! hb_HHasKey( hContext, "registry" )
        RETURN HBBridgeJSONEncode( TurnoverReportError( "INVALID_PARAMS" ) )
    ENDIF
    IF Len( hParams ) == 5 .AND. ( ! hb_HHasKey( hParams, "branchSql" ) .OR. ;
        ! hb_HHasKey( hParams, "branchBindings" ) .OR. ! HB_ISSTRING( hParams[ "branchSql" ] ) .OR. ;
        Empty( AllTrim( hParams[ "branchSql" ] ) ) .OR. ! HB_ISHASH( hParams[ "branchBindings" ] ) )
        RETURN HBBridgeJSONEncode( TurnoverReportError( "INVALID_PARAMS" ) )
    ENDIF
    hReport := TurnoverReportRead( hParams[ "profile" ], hParams[ "sql" ], hParams[ "bindings" ], hContext, .F. )
    IF ! hb_HGetDef( hReport, "success", .F. )
        RETURN HBBridgeJSONEncode( hReport )
    ENDIF
    IF Len( hParams ) == 5
        hBranch := TurnoverReportRead( hParams[ "profile" ], hParams[ "branchSql" ], ;
            hParams[ "branchBindings" ], hContext, .T. )
        IF ! hb_HGetDef( hBranch, "success", .F. )
            RETURN HBBridgeJSONEncode( hBranch )
        ENDIF
        FOR EACH hPeriodBranches IN hBranch[ "periods" ]
            IF ! hb_HHasKey( hReport[ "periods" ], hPeriodBranches:__enumKey() )
                RETURN HBBridgeJSONEncode( TurnoverReportError( "UNMATCHED_PERIOD" ) )
            ENDIF
        NEXT
        hReport[ "branches" ] := hBranch[ "periods" ]
        hReport[ "branchRowCount" ] := hBranch[ "rowCount" ]
    ENDIF
RETURN HBBridgeJSONEncode( hReport )

STATIC FUNCTION TurnoverReportRead( cProfile, cSQL, hBindings, hContext, lBranch )

    LOCAL aFields := { "PERIODO", "TTRFSAI", "TTRFENT", "TFUNIMES", "TFUNADMMES", ;
        "TFUNMES", "TFUNDEMMES", "TFUNFMES", "TURNOVER", "TURNMOVF" }

    LOCAL cBranch, cField, cPeriod

    LOCAL hEntry, hPeriods := {=>}, hQuery, hResult, hRow

    LOCAL nRow

    hQuery := { "requestVersion" => 1, "alias" => cProfile, "sql" => cSQL, "bindings" => hBindings }
    hResult := HBBridgeDispatch( hContext[ "registry" ], "RPCRDD.QueryTyped", hQuery, hContext )
    IF ! HB_ISHASH( hResult )
        RETURN TurnoverReportError( "QUERY_FAILED" )
    ENDIF
    IF ! hb_HGetDef( hResult, "success", .F. )
        RETURN hResult
    ENDIF
    FOR EACH cField IN aFields
        IF ! hb_HHasKey( hResult[ "header" ], cField )
            RETURN TurnoverReportError( "INVALID_SOURCE" )
        ENDIF
    NEXT
    IF lBranch .AND. ! hb_HHasKey( hResult[ "header" ], "RA_FILIAL" )
        RETURN TurnoverReportError( "INVALID_SOURCE" )
    ENDIF
    FOR nRow := 1 TO hResult[ "rowCount" ]
        hRow := hResult[ "rows" ][ hb_ntos( nRow ) ]
        IF ! HB_ISSTRING( hRow[ "PERIODO" ] )
            RETURN TurnoverReportError( "INVALID_SOURCE" )
        ENDIF
        cPeriod := AllTrim( hRow[ "PERIODO" ] )
        IF Len( cPeriod ) != 6 .OR. StrZero( Val( cPeriod ), 6 ) != cPeriod .OR. ;
            Val( Left( cPeriod, 4 ) ) < 1 .OR. Val( Right( cPeriod, 2 ) ) < 1 .OR. ;
            Val( Right( cPeriod, 2 ) ) > 12
            RETURN TurnoverReportError( "INVALID_SOURCE" )
        ENDIF
        FOR EACH cField IN aFields
            IF cField != "PERIODO" .AND. ! TurnoverReportNumber( hRow[ cField ] )
                RETURN TurnoverReportError( "INVALID_SOURCE" )
            ENDIF
        NEXT
        /* Typed numeric and exact decimal strings retain their wire representation. */
        hEntry := { "period" => cPeriod, "transferOut" => hRow[ "TTRFSAI" ], ;
            "transferIn" => hRow[ "TTRFENT" ], "initial" => hRow[ "TFUNIMES" ], ;
            "admissions" => hRow[ "TFUNADMMES" ], "active" => hRow[ "TFUNMES" ], ;
            "dismissals" => hRow[ "TFUNDEMMES" ], "final" => hRow[ "TFUNFMES" ], ;
            "turnoverPercent" => hRow[ "TURNOVER" ], "dismissalPercent" => hRow[ "TURNMOVF" ] }
        IF lBranch
            IF ! HB_ISSTRING( hRow[ "RA_FILIAL" ] )
                RETURN TurnoverReportError( "INVALID_SOURCE" )
            ENDIF
            cBranch := AllTrim( hRow[ "RA_FILIAL" ] )
            IF ! hb_HHasKey( hPeriods, cPeriod )
                hPeriods[ cPeriod ] := {=>}
            ENDIF
            IF hb_HHasKey( hPeriods[ cPeriod ], cBranch )
                RETURN TurnoverReportError( "DUPLICATE_BRANCH" )
            ENDIF
            hPeriods[ cPeriod ][ cBranch ] := hEntry
        ELSE
            IF hb_HHasKey( hPeriods, cPeriod )
                RETURN TurnoverReportError( "DUPLICATE_PERIOD" )
            ENDIF
            hPeriods[ cPeriod ] := hEntry
        ENDIF
    NEXT
RETURN { "success" => .T., "schemaVersion" => 1, "definition" => "source-monthly-turnover-v1", ;
    "rowCount" => hResult[ "rowCount" ], "periods" => hPeriods }

STATIC FUNCTION TurnoverReportNumber( xValue )

    LOCAL cChar

    LOCAL lDigit := .F., lDot := .F.

    LOCAL nAt, nLength

    IF HB_ISNUMERIC( xValue )
        RETURN .T.
    ENDIF
    IF ! HB_ISSTRING( xValue ) .OR. Empty( xValue )
        RETURN .F.
    ENDIF
    nLength := Len( xValue )
    FOR nAt := 1 TO nLength
        cChar := SubStr( xValue, nAt, 1 )
        DO CASE
        CASE cChar >= "0" .AND. cChar <= "9"
            lDigit := .T.
        CASE cChar == "-" .AND. nAt == 1
        CASE cChar == "." .AND. ! lDot .AND. lDigit .AND. nAt < nLength
            lDot := .T.
        OTHERWISE
            RETURN .F.
        ENDCASE
    NEXT
RETURN lDigit

STATIC FUNCTION TurnoverReportError( cCode )
RETURN HBBridgeError( cCode, "The monthly turnover report could not process the supplied source." )
