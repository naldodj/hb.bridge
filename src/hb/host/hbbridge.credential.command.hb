/* Released to Public Domain. Local credential administration commands. */

/* Key creation is exclusive; a preexisting key is never replaced. */
FUNCTION HBBridgeCredentialKeyCommand( aArgs )
    LOCAL cArg, cError, cKeyPath := ""
    LOCAL lKeySeen := .F., lMode := .F., lSuccess

    IF ! HB_ISARRAY( aArgs )
        RETURN .F.
    ENDIF
    FOR EACH cArg IN aArgs
        IF ! HB_ISSTRING( cArg )
            RETURN .F.
        ELSEIF cArg == "--credential-create-key" .AND. ! lMode
            lMode := .T.
        ELSEIF hb_BLeft( cArg, 6 ) == "--key=" .AND. ! lKeySeen
            cKeyPath := hb_BSubStr( cArg, 7 )
            lKeySeen := .T.
        ELSE
            RETURN .F.
        ENDIF
    NEXT
    IF ! lMode .OR. Empty( cKeyPath )
        RETURN .F.
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        lSuccess := HBBridgeCredentialCreateKey( cKeyPath, @cError )
    RECOVER
        lSuccess := .F.
    END SEQUENCE
RETURN lSuccess

/* Local command accepts identifiers only. No password or SQL is accepted. */
FUNCTION HBBridgeCredentialTestCommand( aArgs )
    LOCAL cArg, cConfig := "", cError, cProfile := ""
    LOCAL hConfig
    LOCAL lConfigSeen := .F., lMode := .F., lProfileSeen := .F., lSuccess := .F.

    IF ! HB_ISARRAY( aArgs )
        RETURN .F.
    ENDIF
    FOR EACH cArg IN aArgs
        IF ! HB_ISSTRING( cArg )
            RETURN .F.
        ELSEIF cArg == "--credential-test" .AND. ! lMode
            lMode := .T.
        ELSEIF hb_BLeft( cArg, 9 ) == "--config=" .AND. ! lConfigSeen
            cConfig := hb_BSubStr( cArg, 10 )
            lConfigSeen := .T.
        ELSEIF hb_BLeft( cArg, 10 ) == "--profile=" .AND. ! lProfileSeen
            cProfile := hb_BSubStr( cArg, 11 )
            lProfileSeen := .T.
        ELSE
            RETURN .F.
        ENDIF
    NEXT
    IF ! lMode .OR. Empty( cConfig ) .OR. Empty( cProfile )
        RETURN .F.
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hConfig := HBBridgeConfig( { "-config=" + cConfig }, @cError )
        IF HB_ISHASH( hConfig ) .AND. HBBridgeSQLConfigure( hConfig[ "sqlODBCPooling" ], @cError )
            lSuccess := HBBridgeCredentialTestProfile( hConfig, cProfile )
        ENDIF
    RECOVER
        lSuccess := .F.
    END SEQUENCE
RETURN lSuccess

FUNCTION HBBridgeCredentialTestProfile( hConfig, cProfile )
    LOCAL hProfiles, hProfile, hResult, hRows, hRow

    IF ! HB_ISHASH( hConfig ) .OR. ! HB_ISSTRING( cProfile ) .OR. ;
        ! hb_HHasKey( hConfig, "sqlProfiles" ) .OR. ! HB_ISHASH( hConfig[ "sqlProfiles" ] )
        RETURN .F.
    ENDIF
    hProfiles := hConfig[ "sqlProfiles" ]
    IF ! hb_HHasKey( hProfiles, cProfile ) .OR. ! HB_ISHASH( hProfiles[ cProfile ] )
        RETURN .F.
    ENDIF
    hProfile := hProfiles[ cProfile ]
    IF hb_HGetDef( hProfile, "driver", "" ) != "mssql" .OR. ;
        ! HBBridgeCredentialBoundValid( hb_HGetDef( hProfile, "credential", NIL ) )
        RETURN .F.
    ENDIF
    hResult := HBBridgeSQLQuery( { "alias" => cProfile, "sql" => "SELECT 1 AS ID" }, hProfiles )
    IF ! HB_ISHASH( hResult ) .OR. ! hb_HGetDef( hResult, "success", .F. )
        RETURN .F.
    ENDIF
    hRows := hb_HGetDef( hResult, "rows", NIL )
    IF ! HB_ISHASH( hRows ) .OR. Len( hRows ) != 1
        RETURN .F.
    ENDIF
    hRow := hb_HGetDef( hRows, "1", NIL )
RETURN HB_ISHASH( hRow ) .AND. hb_HGetDef( hRow, "ID", NIL ) == 1
