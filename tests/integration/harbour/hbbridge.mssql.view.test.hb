/* Released to Public Domain. Opt-in DDL: one uniquely named fixture view. */
PROCEDURE MSSQLViewTest( cConfigPath, cProfile, cSuffix )

    LOCAL cError, cName, cSQL, cCodepage

    LOCAL hConfig, hRegistry, hResult, hTyped, hContext

    LOCAL lCreated := .F., lCreationUnknown := .F., lClean := .F., lOK := .T.

    IF ! HB_ISSTRING( cConfigPath ) .OR. ! HB_ISSTRING( cProfile ) .OR. ! HB_ISSTRING( cSuffix )
        ? "View prerequisite: CONFIG_PROFILE_AND_SUFFIX_REQUIRED"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    IF Len( cSuffix ) != 32 .OR. ! ViewHexValid( cSuffix )
        ? "View prerequisite: INVALID_SUFFIX"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    cName := "hbbridge_view_test_" + Upper( cSuffix )
    cCodepage := hb_cdpSelect()
    hConfig := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )
    IF hConfig == NIL
        ? "View prerequisite: CONFIG_INVALID"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    IF ! hb_HHasKey( hConfig[ "sqlProfiles" ], cProfile )
        ? "View prerequisite: PROFILE_NOT_FOUND"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    IF hConfig[ "sqlProfiles" ][ cProfile ][ "driver" ] != "mssql" .OR. ;
        ! HBBridgeSQLConfigure( hConfig[ "sqlODBCPooling" ], @cError )
        ? "View prerequisite: MSSQL_OR_POOLING_UNAVAILABLE"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    hRegistry := HBBridgeBuiltinRegistry( { cProfile => hConfig[ "sqlProfiles" ][ cProfile ] } )
    hContext := HBBridgeContext( "mssql-view-test" )
    hb_cdpSelect( "UTF8EX" )
    BEGIN SEQUENCE WITH __BreakBlock()
        cSQL := "SELECT OBJECT_ID('dbo." + cName + "') AS OBJECTID"
        hResult := ViewCall( hRegistry, hContext, "RPCRDD.Query", ;
            { "alias" => cProfile, "sql" => cSQL } )
        IF ! ViewSuccess( hResult ) .OR. hResult[ "rowCount" ] != 1 .OR. ;
            hResult[ "rows" ][ "1" ][ "OBJECTID" ] != NIL
            ? "View prerequisite: NAME_NOT_AVAILABLE_OR_CHECK_FAILED"
            lOK := .F.
            Break( NIL )
        ENDIF
        cSQL := "CREATE VIEW [dbo].[" + cName + "] AS " + ;
            "SELECT CAST(1 AS int) AS ID, CAST('alpha' AS varchar(20)) AS LABEL " + ;
            "UNION ALL SELECT CAST(2 AS int), CAST('beta' AS varchar(20))"
        /* If the reply is lost, ownership is uncertain: do not drop blindly. */
        lCreationUnknown := .T.
        hResult := ViewCall( hRegistry, hContext, "RPCRDD.Execute", ;
            { "requestVersion" => 1, "alias" => cProfile, "sql" => cSQL } )
        IF ! ViewSuccess( hResult )
            IF HB_ISHASH( hResult ) .AND. hb_HGetDef( hResult, "outcome", "unknown" ) == "notStarted"
                lCreationUnknown := .F.
            ENDIF
            ? "View create: FAILED; outcome=" + hb_HGetDef( hResult, "outcome", "unknown" )
            lOK := .F.
            Break( NIL )
        ENDIF
        lCreated := .T.
        lCreationUnknown := .F.
        ? "View create: PASS"
        cSQL := "SELECT ID, LABEL FROM [dbo].[" + cName + "] ORDER BY ID"
        hResult := ViewCall( hRegistry, hContext, "RPCRDD.Query", { "alias" => cProfile, "sql" => cSQL } )
        IF ViewSuccess( hResult ) .AND. hResult[ "rowCount" ] == 2 .AND. ;
            hResult[ "rows" ][ "1" ][ "ID" ] == 1 .AND. AllTrim( hResult[ "rows" ][ "2" ][ "LABEL" ] ) == "beta"
            ? "View Query: PASS"
        ELSE
            ? "View Query: FAILED"
            lOK := .F.
        ENDIF
        cSQL := "SELECT ID, LABEL FROM [dbo].[" + cName + "] WHERE ID > ? ORDER BY ID"
        hTyped := { "requestVersion" => 1, "alias" => cProfile, "sql" => cSQL, ;
            "bindings" => { "1" => { "type" => "integer", "isNull" => .F., "value" => 1 } } }
        hResult := ViewCall( hRegistry, hContext, "RPCRDD.QueryTyped", hTyped )
        IF ViewSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1 .AND. ;
            hResult[ "rows" ][ "1" ][ "ID" ] == 2 .AND. AllTrim( hResult[ "rows" ][ "1" ][ "LABEL" ] ) == "beta"
            ? "View QueryTyped with binding: PASS"
        ELSE
            ? "View QueryTyped with binding: FAILED; code=" + hb_HGetDef( hResult, "code", "INVALID_RESULT" )
            lOK := .F.
        ENDIF
    RECOVER
        ? "View test: UNEXPECTED_RUNTIME_ERROR"
        lOK := .F.
    ALWAYS
        IF lCreated
            BEGIN SEQUENCE WITH __BreakBlock()
                hResult := ViewCall( hRegistry, hContext, "RPCRDD.Execute", ;
                    { "requestVersion" => 1, "alias" => cProfile, "sql" => "DROP VIEW [dbo].[" + cName + "]" } )
                IF ViewSuccess( hResult )
                    hResult := ViewCall( hRegistry, hContext, "RPCRDD.Query", ;
                        { "alias" => cProfile, "sql" => "SELECT OBJECT_ID('dbo." + cName + "') AS OBJECTID" } )
                    lClean := ViewSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1 .AND. ;
                        hResult[ "rows" ][ "1" ][ "OBJECTID" ] == NIL
                ENDIF
            RECOVER
                lClean := .F.
            END SEQUENCE
            IF lClean
                ? "View cleanup and absence: PASS"
            ELSE
                ? "View cleanup: FAILED; inspect dbo." + cName
                lOK := .F.
            ENDIF
        ELSEIF lCreationUnknown
            ? "View creation outcome unknown; inspect dbo." + cName
        ENDIF
        hb_cdpSelect( cCodepage )
    END SEQUENCE
    ? "MSSQL view test: " + iif( lOK .AND. lCreated .AND. lClean, "OK", "FAILED" )
    ErrorLevel( iif( lOK .AND. lCreated .AND. lClean, 0, 1 ) )
RETURN

STATIC FUNCTION ViewHexValid( cText )
    LOCAL cChar
    FOR EACH cChar IN Upper( cText )
        IF ! ( cChar $ "0123456789ABCDEF" )
            RETURN .F.
        ENDIF
    NEXT
RETURN .T.

STATIC FUNCTION ViewCall( hRegistry, hContext, cService, hParams )
RETURN HBBridgeDispatch( hRegistry, cService, hParams, hContext )

STATIC FUNCTION ViewSuccess( hResult )
RETURN HB_ISHASH( hResult ) .AND. hb_HGetDef( hResult, "success", .F. )
