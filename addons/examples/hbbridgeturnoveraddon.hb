/* Released to Public Domain. Example business addon; the caller owns the source. */
FUNCTION Main( cJSON, hContext )

    LOCAL aDimensions := { "PERIOD", "COMPANY", "BRANCH", "COST_CENTER", "JOB", "EMPLOYEE" }

    LOCAL cField, cKey, cPeriod

    LOCAL hParams, hQuery, hResult, hRoot, hRow, hNode, hLeaf, hDetails

    LOCAL nRow, nActive, nAdmissions, nDismissals, nTransfersIn, nTransfersOut

    IF ! HB_ISSTRING( cJSON ) .OR. ! HBBridgeJSONComplete( cJSON, HBBridgeJSONDecode( cJSON, @hParams ) ) .OR. ;
        ! HB_ISHASH( hParams ) .OR. ! HB_ISHASH( hContext )
        RETURN HBBridgeJSONEncode( TurnoverError( "INVALID_PARAMS" ) )
    ENDIF
    IF Len( hParams ) != 3 .OR. ! hb_HHasKey( hParams, "profile" ) .OR. ;
        ! hb_HHasKey( hParams, "sql" ) .OR. ! hb_HHasKey( hParams, "bindings" ) .OR. ;
        ! HB_ISSTRING( hParams[ "profile" ] ) .OR. Empty( AllTrim( hParams[ "profile" ] ) ) .OR. ;
        ! HB_ISSTRING( hParams[ "sql" ] ) .OR. Empty( AllTrim( hParams[ "sql" ] ) ) .OR. ;
        ! HB_ISHASH( hParams[ "bindings" ] ) .OR. ! hb_HHasKey( hContext, "registry" )
        RETURN HBBridgeJSONEncode( TurnoverError( "INVALID_PARAMS" ) )
    ENDIF
    /* The caller supplies a trusted, parameterized source and application context. */
    hQuery := { "requestVersion" => 1, "alias" => hParams[ "profile" ], ;
        "sql" => hParams[ "sql" ], "bindings" => hParams[ "bindings" ] }
    hResult := HBBridgeDispatch( hContext[ "registry" ], "RPCRDD.QueryTyped", hQuery, hContext )
    IF ! HB_ISHASH( hResult )
        RETURN HBBridgeJSONEncode( TurnoverError( "QUERY_FAILED" ) )
    ENDIF
    IF ! hb_HGetDef( hResult, "success", .F. )
        RETURN HBBridgeJSONEncode( hResult )
    ENDIF
    FOR EACH cField IN { "PERIOD", "COMPANY", "BRANCH", "COST_CENTER", "JOB", "EMPLOYEE", ;
        "ACTIVE", "ADMISSION", "DISMISSAL" }
        IF ! hb_HHasKey( hResult[ "header" ], cField )
            RETURN HBBridgeJSONEncode( TurnoverError( "INVALID_SOURCE" ) )
        ENDIF
    NEXT
    hRoot := TurnoverNode()
    FOR nRow := 1 TO hResult[ "rowCount" ]
        hRow := hResult[ "rows" ][ hb_ntos( nRow ) ]
        FOR EACH cField IN aDimensions
            IF ! HB_ISSTRING( hRow[ cField ] ) .OR. Chr( 0 ) $ hRow[ cField ] .OR. ;
                ( ( cField == "PERIOD" .OR. cField == "COMPANY" .OR. cField == "EMPLOYEE" ) .AND. ;
                    Empty( AllTrim( hRow[ cField ] ) ) )
                RETURN HBBridgeJSONEncode( TurnoverError( "INVALID_SOURCE" ) )
            ENDIF
        NEXT
        cPeriod := hRow[ "PERIOD" ]
        IF Len( cPeriod ) != 6 .OR. StrZero( Val( cPeriod ), 6 ) != cPeriod .OR. ;
            Val( Left( cPeriod, 4 ) ) < 1 .OR. Val( Right( cPeriod, 2 ) ) < 1 .OR. ;
            Val( Right( cPeriod, 2 ) ) > 12
            RETURN HBBridgeJSONEncode( TurnoverError( "INVALID_SOURCE" ) )
        ENDIF
        nActive := TurnoverBit( hRow[ "ACTIVE" ] )
        nAdmissions := TurnoverBit( hRow[ "ADMISSION" ] )
        nDismissals := TurnoverBit( hRow[ "DISMISSAL" ] )
        IF nActive != 1 .OR. nAdmissions < 0 .OR. nDismissals < 0
            RETURN HBBridgeJSONEncode( TurnoverError( "INVALID_SOURCE" ) )
        ENDIF
        hDetails := NIL
        nTransfersIn := -1
        nTransfersOut := -1
        IF hb_HHasKey( hResult[ "header" ], "DETAILS_JSON" ) .AND. ;
            ! TurnoverDetails( hRow[ "DETAILS_JSON" ], cPeriod, @hDetails, @nTransfersIn, @nTransfersOut )
            RETURN HBBridgeJSONEncode( TurnoverError( "INVALID_SOURCE" ) )
        ENDIF
        hNode := hRoot
        TurnoverAdd( hNode, nActive, nAdmissions, nDismissals, nTransfersIn, nTransfersOut )
        FOR EACH cField IN aDimensions
            cKey := hRow[ cField ]
            IF ! hb_HHasKey( hNode[ "children" ], cKey )
                hNode[ "children" ][ cKey ] := TurnoverNode()
            ENDIF
            hNode := hNode[ "children" ][ cKey ]
            TurnoverAdd( hNode, nActive, nAdmissions, nDismissals, nTransfersIn, nTransfersOut )
        NEXT
        hLeaf := hNode
        IF hLeaf[ "active" ] != 1
            RETURN HBBridgeJSONEncode( TurnoverError( "DUPLICATE_EMPLOYEE" ) )
        ENDIF
        hLeaf[ "details" ] := hDetails
    NEXT
    TurnoverFinish( hRoot )
RETURN HBBridgeJSONEncode( { "success" => .T., "schemaVersion" => 1, ;
    "definition" => "monthly-active-minus-admissions-v1", "rowCount" => hResult[ "rowCount" ], ;
    "hierarchy" => "period/company/branch/costCenter/job/employee", "result" => hRoot } )

STATIC FUNCTION TurnoverNode()
RETURN { "active" => 0, "admissions" => 0, "dismissals" => 0, ;
    "transferIn" => 0, "transferOut" => 0, "transferUnknown" => 0, "children" => {=>} }

STATIC PROCEDURE TurnoverAdd( hNode, nActive, nAdmissions, nDismissals, nTransfersIn, nTransfersOut )
    hNode[ "active" ] += nActive
    hNode[ "admissions" ] += nAdmissions
    hNode[ "dismissals" ] += nDismissals
    IF nTransfersIn < 0 .OR. nTransfersOut < 0
        hNode[ "transferUnknown" ]++
    ELSE
        hNode[ "transferIn" ] += nTransfersIn
        hNode[ "transferOut" ] += nTransfersOut
    ENDIF
RETURN

STATIC PROCEDURE TurnoverFinish( hNode )

    LOCAL hChild

    LOCAL nInitial := hNode[ "active" ] - hNode[ "admissions" ]

    hNode[ "initial" ] := nInitial
    hNode[ "transferEvidenceComplete" ] := hNode[ "transferUnknown" ] == 0
    IF ! hNode[ "transferEvidenceComplete" ]
        hNode[ "transferIn" ] := NIL
        hNode[ "transferOut" ] := NIL
    ENDIF
    hb_HDel( hNode, "transferUnknown" )
    hNode[ "turnoverPercent" ] := iif( nInitial == 0, 0, ;
        Round( ( hNode[ "admissions" ] + hNode[ "dismissals" ] ) * 50 / Max( nInitial, 1 ), 2 ) )
    hNode[ "dismissalPercent" ] := iif( nInitial == 0, 0, ;
        Round( hNode[ "dismissals" ] * 50 / Max( nInitial, 1 ), 2 ) )
    FOR EACH hChild IN hNode[ "children" ]
        TurnoverFinish( hChild )
    NEXT
RETURN

/* Detail text is optional. Missing movement evidence is never treated as zero. */
STATIC FUNCTION TurnoverDetails( xJSON, cPeriod, hDetails, nTransfersIn, nTransfersOut )

    LOCAL aDetailFields := { "employeeName", "admissionDate", "dismissalDate", "transfers" }
    LOCAL aEventFields := { "date", "direction", "fromBranch", "toBranch", "fromCostCenter", "toCostCenter" }

    LOCAL cField, cDate

    LOCAL hEvent, hEvents

    IF xJSON == NIL
        RETURN .T.
    ENDIF
    IF ! HB_ISSTRING( xJSON ) .OR. ! HBBridgeJSONComplete( xJSON, HBBridgeJSONDecode( xJSON, @hDetails ) ) .OR. ;
        ! HB_ISHASH( hDetails )
        RETURN .F.
    ENDIF
    FOR EACH cField IN aDetailFields
        IF ! hb_HHasKey( hDetails, cField )
            RETURN .F.
        ENDIF
    NEXT
    IF hDetails[ "employeeName" ] != NIL .AND. ! HB_ISSTRING( hDetails[ "employeeName" ] )
        RETURN .F.
    ENDIF
    IF ! TurnoverDate( hDetails[ "admissionDate" ] ) .OR. ! TurnoverDate( hDetails[ "dismissalDate" ] )
        RETURN .F.
    ENDIF
    hEvents := hDetails[ "transfers" ]
    IF hEvents == NIL
        RETURN .T.
    ENDIF
    IF ! HB_ISHASH( hEvents )
        RETURN .F.
    ENDIF
    nTransfersIn := 0
    nTransfersOut := 0
    FOR EACH hEvent IN hEvents
        IF ! HB_ISHASH( hEvent )
            RETURN .F.
        ENDIF
        FOR EACH cField IN aEventFields
            IF ! hb_HHasKey( hEvent, cField ) .OR. ! HB_ISSTRING( hEvent[ cField ] )
                RETURN .F.
            ENDIF
        NEXT
        cDate := hEvent[ "date" ]
        IF ! TurnoverDate( cDate ) .OR. ;
            ! ( hEvent[ "direction" ] == "in" .OR. hEvent[ "direction" ] == "out" )
            RETURN .F.
        ENDIF
        IF Left( StrTran( cDate, "-", "" ), 6 ) == cPeriod
            IF hEvent[ "direction" ] == "in"
                nTransfersIn++
            ELSE
                nTransfersOut++
            ENDIF
        ENDIF
    NEXT
RETURN .T.

STATIC FUNCTION TurnoverDate( xValue )

    LOCAL cDate

    LOCAL dDate

    IF xValue == NIL
        RETURN .T.
    ENDIF
    IF ! HB_ISSTRING( xValue ) .OR. Len( xValue ) != 10 .OR. ;
        SubStr( xValue, 5, 1 ) != "-" .OR. SubStr( xValue, 8, 1 ) != "-"
        RETURN .F.
    ENDIF
    cDate := StrTran( xValue, "-", "" )
    dDate := hb_SToD( cDate )
RETURN ! Empty( dDate ) .AND. DToS( dDate ) == cDate
STATIC FUNCTION TurnoverBit( xValue )
    IF HB_ISNUMERIC( xValue ) .AND. ( xValue == 0 .OR. xValue == 1 )
        RETURN xValue
    ENDIF
    IF HB_ISSTRING( xValue ) .AND. ( xValue == "0" .OR. xValue == "1" )
        RETURN Val( xValue )
    ENDIF
RETURN -1

STATIC FUNCTION TurnoverError( cCode )
RETURN HBBridgeError( cCode, "Turnover example could not process the supplied source." )
