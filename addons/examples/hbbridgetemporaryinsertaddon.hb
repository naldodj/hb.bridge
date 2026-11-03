/* Released to Public Domain. The Protheus caller owns the target table. */
FUNCTION Main( cJSON, hContext )

    LOCAL cPart, cQualified := "", cRemaining, cSQL, cTarget

    LOCAL hParams, hResult

    LOCAL nDot, nParts := 0, nFirst := 1, nSecond

    IF ! HB_ISSTRING( cJSON ) .OR. ! HBBridgeJSONComplete( cJSON, HBBridgeJSONDecode( cJSON, @hParams ) ) .OR. ;
        ! HB_ISHASH( hParams ) .OR. ! HB_ISHASH( hContext )
        RETURN HBBridgeJSONEncode( HBBridgeError( "INVALID_PARAMS", "A parameter object and addon context are required." ) )
    ENDIF
    IF ( Len( hParams ) != 2 .AND. Len( hParams ) != 4 ) .OR. ;
        ! hb_HHasKey( hParams, "alias" ) .OR. ! hb_HHasKey( hParams, "target" ) .OR. ;
        ! hb_HHasKey( hContext, "registry" )
        RETURN HBBridgeJSONEncode( HBBridgeError( "INVALID_PARAMS", "Profile and target are required." ) )
    ENDIF
    cTarget := hParams[ "target" ]
    IF ! HB_ISSTRING( cTarget ) .OR. Empty( cTarget ) .OR. Chr( 0 ) $ cTarget
        RETURN HBBridgeJSONEncode( HBBridgeError( "INVALID_PARAMS", "Target name is invalid." ) )
    ENDIF
    cRemaining := cTarget
    DO WHILE .T.
        nDot := At( ".", cRemaining )
        cPart := iif( nDot > 0, Left( cRemaining, nDot - 1 ), cRemaining )
        nParts++
        IF nParts > 3 .OR. Len( cPart ) > 128 .OR. ;
            ( Empty( cPart ) .AND. ( nParts != 2 .OR. nDot == 0 ) )
            RETURN HBBridgeJSONEncode( HBBridgeError( "INVALID_PARAMS", "Target name is invalid." ) )
        ENDIF
        IF nParts > 1
            cQualified += "."
        ENDIF
        IF ! Empty( cPart )
            cQualified += "[" + StrTran( cPart, "]", "]]" ) + "]"
        ENDIF
        IF nDot == 0
            EXIT
        ENDIF
        cRemaining := SubStr( cRemaining, nDot + 1 )
    ENDDO
    IF Len( hParams ) == 4
        IF ! hb_HHasKey( hParams, "columns" ) .OR. ! hb_HHasKey( hParams, "select" ) .OR. ;
            ! HB_ISSTRING( hParams[ "columns" ] ) .OR. ! HB_ISSTRING( hParams[ "select" ] )
            RETURN HBBridgeJSONEncode( HBBridgeError( "INVALID_PARAMS", "Columns and select SQL are required." ) )
        ENDIF
        /* SQL is supplied by a trusted caller; this example does not parse it. */
        cSQL := "INSERT INTO " + cQualified + " (" + hParams[ "columns" ] + ") " + hParams[ "select" ]
    ELSE
        /* A small in-process computation; production addons define their own logic. */
        nSecond := nFirst + 1
        cSQL := "INSERT INTO " + cQualified + " (TESTID, TESTTEXT) " + ;
            "SELECT " + hb_ntos( nFirst ) + ", 'hbBridge' UNION ALL SELECT " + ;
            hb_ntos( nSecond ) + ", 'temporary'"
    ENDIF
    hResult := HBBridgeDispatch( hContext[ "registry" ], "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => hParams[ "alias" ], "sql" => cSQL }, hContext )

RETURN HBBridgeJSONEncode( hResult )
