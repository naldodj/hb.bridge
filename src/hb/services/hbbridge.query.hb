/* Released to Public Domain. */
#include "dbinfo.ch"
#include "dbstruct.ch"

REQUEST SQLMIX, SDDSQLITE3, SDDODBC

STATIC s_hSQLMutex

INIT PROCEDURE HBBridgeSQLInit()
    s_hSQLMutex := hb_mutexCreate()
RETURN

/* Generic executor: callers resolve ERP table/branch/company/tenant rules.
 * Profile aliases are opaque keys, including names such as mssql/pData.
 * RDDSQL's connection table is process-global; the active connection is
 * thread-local. Keep shared table access and the complete
 * connect/open/fetch/close/disconnect lifecycle under one mutex.
 */
FUNCTION HBBridgeSQLQuery( hParams, hProfiles )

    LOCAL cProfile, cSQL, hPage := NIL, cError

    IF ! hb_HHasKey( hParams, "alias" ) .OR. ! hb_HHasKey( hParams, "sql" )
        RETURN HBBridgeError( "INVALID_PARAMS", "Connection profile and SQL are required." )
    ENDIF
    cProfile := hParams[ "alias" ]
    cSQL := hParams[ "sql" ]
    IF ! HB_ISSTRING( cProfile ) .OR. ! HB_ISSTRING( cSQL )
        RETURN HBBridgeError( "INVALID_PARAMS", "Connection profile and SQL must be strings." )
    ENDIF
    IF Empty( AllTrim( cProfile ) ) .OR. Empty( AllTrim( cSQL ) ) .OR. ;
        Chr( 0 ) $ cProfile .OR. Chr( 0 ) $ cSQL
        RETURN HBBridgeError( "INVALID_PARAMS", "Connection profile and SQL must be nonempty and contain no NUL." )
    ENDIF
    IF ! hb_HHasKey( hProfiles, cProfile )
        RETURN HBBridgeError( "PROFILE_NOT_FOUND", "Connection profile is not configured." )
    ENDIF

    IF hb_HHasKey( hParams, "page" )
        hPage := SQLPagePlan( hParams[ "page" ], cSQL, @cError )
        IF hPage == NIL
            RETURN HBBridgeError( "INVALID_PAGE", cError )
        ENDIF
        cSQL := hPage[ "sqlpage" ]
    ENDIF

RETURN hb_mutexEval( s_hSQLMutex, {|| SQLQueryLocked( cSQL, hProfiles[ cProfile ], hPage ) } )

STATIC FUNCTION SQLQueryLocked( cSQL, hProfile, hPage )

    LOCAL nConnection := 0, nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    LOCAL nPreviousArea := Select(), nQueryArea := 0, nField, nFields, nRow := 0
    LOCAL hHeader := {=>}, hRows := {=>}, hRow, hField, cName, hResult
    LOCAL cFailure := "CONNECTION_FAILED", cMessage := "Database connection is unavailable."
    LOCAL aConnection
    LOCAL nOffset := iif( hPage == NIL, 0, 1 ), lHasNext := .F.
    LOCAL cAlias, nTotalRows, nTotalPages

    /* The positional connection array is required by the native RDD API. */
    IF hProfile[ "driver" ] == "sqlite"
        IF hProfile[ "database" ] != ":memory:" .AND. ! hb_FileExists( hProfile[ "database" ] )
            RETURN HBBridgeError( cFailure, cMessage )
        ENDIF
        aConnection := { "SQLITE3", hProfile[ "database" ] }
    ELSE
        aConnection := { "ODBC", hProfile[ "connectionString" ] }
    ENDIF
    BEGIN SEQUENCE WITH __BreakBlock()
        nConnection := rddInfo( RDDI_CONNECT, aConnection, "SQLMIX" )
        IF nConnection == 0
            Break( NIL )
        ENDIF
        cFailure := "QUERY_FAILED"
        cMessage := "Could not open or read the SQL query result."
        /* Select zero reserves the first unused area number, not the caller's
         * open area. Capture it before OPEN: a failed OPEN can leave an area
         * without an assigned alias, which numeric cleanup must still own.
         */
        dbSelectArea( 0 )
        cAlias := hb_rddGetTempAlias()
        IF !dbUseArea( .T., "SQLMIX", cSQL, cAlias, .T., .T., NIL, nConnection )
            Break( NIL )
        ENDIF
        nQueryArea := Select()
        nFields := ( cAlias )->( FCount() )
        IF nFields == 0
            Break( NIL )
        ENDIF
        IF nFields <= nOffset
            Break( NIL )
        ENDIF
        FOR nField := 1 + nOffset TO nFields
            cName := ( cAlias )->( Upper( AllTrim( FieldName( nField ) ) ) )
            IF Empty( cName ) .OR. hb_HHasKey( hHeader, cName ) .OR. ;
                ( nOffset > 0 .AND. ( Left( cName, 16 ) == "__HBBRIDGE_ROWNO" .OR. ":" $ cName ) )
                cFailure := "AMBIGUOUS_COLUMN"
                cMessage := "Query columns must have distinct names; use SQL aliases."
                Break( NIL )
            ENDIF
            hHeader[ cName ] := { "position" => nField - nOffset, ;
                "type" => ( cAlias )->( hb_FieldType( nField ) ), ;
                "length" => ( cAlias )->( hb_FieldLen( nField ) ), ;
                "decimals" => ( cAlias )->( hb_FieldDec( nField ) ) }
        NEXT
        DO WHILE ( cAlias )->( ! Eof() )
            IF hPage != NIL
                IF nRow == hPage[ "size" ]
                    lHasNext := .T.
                    EXIT
                ENDIF
            ENDIF
            hRow := {=>}
            FOR EACH hField IN hHeader
                /* Enumerate keys without an additional hb_HKeys array. */
                cName := hField:__enumKey()
                hRow[ cName ] := ( cAlias )->( FieldGet( hField[ "position" ] + nOffset ) )
            NEXT
            nRow++
            hRows[ hb_ntos( nRow ) ] := hRow
            ( cAlias )->( dbSkip() )
        ENDDO
        /* Release the reader before opening the count statement on the same
         * connection. The count helper explicitly owns its own free area.
         */
        ( cAlias )->( dbCloseArea() )
        IF hPage != NIL
            cMessage := "Could not count the SQL query result rows."
            nTotalRows := SQLTotalRows( hPage[ "sql" ], nConnection, hProfile[ "driver" ] )
            IF nTotalRows == NIL
                Break( NIL )
            ENDIF
            /* Keep the real count unchanged and avoid an increment loop or
             * an overflowing (total + size - 1) ceiling expression.
             */
            nTotalPages := Int( nTotalRows / hPage[ "size" ] ) + ;
                iif( Mod( nTotalRows, hPage[ "size" ] ) == 0, 0, 1 )
        ENDIF
        hResult := { "success" => .T., "header" => hHeader, "rows" => hRows, ;
            "rowCount" => nRow, "driver" => hProfile[ "driver" ], "resultVersion" => 1 }
        IF hPage != NIL
            hResult[ "page" ] := { "number" => hPage[ "number" ], "size" => hPage[ "size" ], ;
                "hasNext" => lHasNext, "firstRow" => iif( nRow == 0, 0, hPage[ "begin" ] ), ;
                "lastRow" => iif( nRow == 0, 0, hPage[ "begin" ] + nRow - 1 ) }
            hResult[ "totalRows" ] := nTotalRows
            hResult[ "totalPages" ] := nTotalPages
        ENDIF
    RECOVER
        /* Driver errors can include SQL/connection strings. Return a stable
         * service error rather than exposing those internal descriptions.
         */
        hResult := HBBridgeError( cFailure, cMessage )
    ALWAYS
        BEGIN SEQUENCE WITH __BreakBlock()
            IF nQueryArea > 0
                dbSelectArea( nQueryArea )
                IF Used()
                    dbCloseArea()
                ENDIF
            ENDIF
        RECOVER
            hResult := HBBridgeError( "QUERY_CLOSE_FAILED", "Could not release the SQL query area." )
        END SEQUENCE
        BEGIN SEQUENCE WITH __BreakBlock()
            IF nConnection > 0
                IF ! rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection )
                    hResult := HBBridgeError( "CONNECTION_CLOSE_FAILED", "Could not release the SQL connection." )
                ENDIF
            ENDIF
        RECOVER
            hResult := HBBridgeError( "CONNECTION_CLOSE_FAILED", "Could not release the SQL connection." )
        ALWAYS
            /* RDDSQL ignores a zero assignment. Disconnecting this call's
             * current connection already restores zero when no prior one
             * existed; explicitly restore a nonzero caller connection.
             */
            IF nPreviousConnection > 0
                rddInfo( RDDI_CONNECTION, nPreviousConnection, "SQLMIX" )
            ENDIF
            dbSelectArea( nPreviousArea )
        END SEQUENCE
    END SEQUENCE

RETURN hResult

/* Use result ordinals rather than primary-key values. Fetch one sentinel row
 * to detect another page. The separate COUNT supplies the requested totals.
 */
STATIC FUNCTION SQLPagePlan( hPage, cSQL, cError )

    LOCAL nNumber, nSize, nBegin, nEnd, cOrder, cToken, cColumn, cDirection
    LOCAL cSQLPage
    LOCAL cQualified := "", nComma, nSpace, nChar, cChar
    LOCAL nMaxInteger := 9007199254740991

    cError := "Page requires number, size and orderBy."
    IF ! HB_ISHASH( hPage )
        RETURN NIL
    ENDIF
    IF Len( hPage ) != 3 .OR. ! hb_HHasKey( hPage, "number" ) .OR. ;
        ! hb_HHasKey( hPage, "size" ) .OR. ! hb_HHasKey( hPage, "orderBy" )
        RETURN NIL
    ENDIF
    nNumber := hPage[ "number" ]
    nSize := hPage[ "size" ]
    cOrder := hPage[ "orderBy" ]
    cError := "Page number/size must be positive exact integers with representable bounds."
    IF ! HB_ISNUMERIC( nNumber ) .OR. ! HB_ISNUMERIC( nSize )
        RETURN NIL
    ENDIF
    IF nNumber < 1 .OR. nSize < 1 .OR. nNumber != Int( nNumber ) .OR. ;
        nSize != Int( nSize ) .OR. nSize >= nMaxInteger
        RETURN NIL
    ENDIF
    IF nNumber > Int( ( nMaxInteger - 1 ) / nSize )
        RETURN NIL
    ENDIF
    nBegin := ( nNumber - 1 ) * nSize + 1
    nEnd := nNumber * nSize + 1
    IF nEnd > nMaxInteger
        RETURN NIL
    ENDIF
    cError := "orderBy requires comma-separated column names with optional ASC or DESC."
    IF ! HB_ISSTRING( cOrder )
        RETURN NIL
    ENDIF
    cOrder := AllTrim( cOrder )
    IF Empty( cOrder )
        RETURN NIL
    ENDIF
    DO WHILE ! Empty( cOrder )
        nComma := At( ",", cOrder )
        cToken := AllTrim( iif( nComma == 0, cOrder, Left( cOrder, nComma - 1 ) ) )
        nSpace := At( " ", cToken )
        cColumn := iif( nSpace == 0, cToken, Left( cToken, nSpace - 1 ) )
        cDirection := iif( nSpace == 0, "ASC", Upper( AllTrim( SubStr( cToken, nSpace + 1 ) ) ) )
        IF Empty( cColumn ) .OR. ! ( cDirection == "ASC" .OR. cDirection == "DESC" )
            RETURN NIL
        ENDIF
        FOR nChar := 1 TO Len( cColumn )
            cChar := Upper( SubStr( cColumn, nChar, 1 ) )
            IF ! ( cChar $ "ABCDEFGHIJKLMNOPQRSTUVWXYZ_" )
                IF nChar == 1 .OR. ! ( cChar $ "0123456789" )
                    RETURN NIL
                ENDIF
            ENDIF
        NEXT
        cQualified += iif( Empty( cQualified ), "", ", " ) + "HBBSRC.[" + cColumn + "] " + cDirection
        IF nComma == 0
            EXIT
        ENDIF
        cOrder := AllTrim( SubStr( cOrder, nComma + 1 ) )
        IF Empty( cOrder )
            RETURN NIL
        ENDIF
    ENDDO
    cSQL := AllTrim( cSQL )
    IF Right( cSQL, 1 ) == ";"
        cSQL := RTrim( Left( cSQL, Len( cSQL ) - 1 ) )
    ENDIF
    cSQLPage := "SELECT HBBPAGE.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY " + cQualified + ;
        ") AS __HBBRIDGE_ROWNO, HBBSRC.* FROM (" + cSQL + ") AS HBBSRC) AS HBBPAGE " + ;
        "WHERE HBBPAGE.__HBBRIDGE_ROWNO BETWEEN " + hb_ntos( nBegin ) + " AND " + hb_ntos( nEnd ) + ;
        " ORDER BY HBBPAGE.__HBBRIDGE_ROWNO"

RETURN { "sqlpage" => cSQLPage, "sql" => cSQL, "number" => nNumber, "size" => nSize, "begin" => nBegin }

/* Return a separate normalized map. Credentials stay in the server registry's
 * handler closure and never become service metadata or client parameters.
 */
FUNCTION HBBridgeSQLProfiles( hProfiles, cBase, cError )

    LOCAL hNormalized := {=>}, hProfile, cName, cKey, cDriver, cValue

    cError := ""
    IF ! HB_ISHASH( hProfiles )
        cError := "sqlProfiles must be an object."
        RETURN NIL
    ENDIF
    FOR EACH hProfile IN hProfiles
        cName := hProfile:__enumKey()
        IF ! HB_ISSTRING( cName ) .OR. Empty( AllTrim( cName ) ) .OR. Chr( 0 ) $ cName .OR. ;
            ! HB_ISHASH( hProfile )
            cError := "Invalid SQL profile."
            RETURN NIL
        ENDIF
        IF ! hb_HHasKey( hProfile, "driver" ) .OR. ! HB_ISSTRING( hProfile[ "driver" ] )
            cError := "SQL profile driver is required: " + cName
            RETURN NIL
        ENDIF
        cDriver := hProfile[ "driver" ]
        IF ! ( cDriver == "sqlite" .OR. cDriver == "mssql" )
            cError := "Unsupported SQL profile driver: " + cName
            RETURN NIL
        ENDIF
        IF cDriver == "mssql"
            cKey := "connectionString"
            cValue := SQLMSSQLConnection( hProfile, @cError )
            IF cValue == NIL
                RETURN NIL
            ENDIF
        ELSE
            cKey := "database"
            IF Len( hProfile ) != 2 .OR. ! hb_HHasKey( hProfile, cKey )
                cError := "SQL profile requires only driver and database: " + cName
                RETURN NIL
            ENDIF
            cValue := hProfile[ cKey ]
            IF ! HB_ISSTRING( cValue ) .OR. Empty( AllTrim( cValue ) ) .OR. Chr( 0 ) $ cValue
                cError := "Invalid SQL profile database: " + cName
                RETURN NIL
            ENDIF
            IF cValue != ":memory:"
                cValue := HBBridgeAbsolutePath( cValue, cBase )
                IF Empty( cValue )
                    cError := "Invalid SQL database path: " + cName
                    RETURN NIL
                ENDIF
            ENDIF
        ENDIF
        hNormalized[ cName ] := { "driver" => cDriver, cKey => cValue }
    NEXT

RETURN hNormalized

/* Both configuration forms reach the existing SDDODBC query path. Never put
 * credential values or arbitrary input keys into a validation error.
 */
STATIC FUNCTION SQLMSSQLConnection( hProfile, cError )

    LOCAL hAllowed := { "driver" => .T., "authentication" => .T., "dsn" => .T., ;
        "odbcDriver" => .T., "server" => .T., "database" => .T., "username" => .T., ;
        "password" => .T., "encrypt" => .T., "trustServerCertificate" => .T. }
    LOCAL cKey, xValue, cAuthentication, cConnection, cEncrypt

    IF hb_HHasKey( hProfile, "connectionString" )
        IF Len( hProfile ) != 2
            cError := "SQL connectionString cannot be combined with structured connection keys."
            RETURN NIL
        ENDIF
        IF ! SQLProfileTextValid( hProfile[ "connectionString" ] )
            cError := "Invalid SQL profile connectionString."
            RETURN NIL
        ENDIF
        RETURN hProfile[ "connectionString" ]
    ENDIF
    FOR EACH xValue IN hProfile
        cKey := xValue:__enumKey()
        IF ! HB_ISSTRING( cKey ) .OR. ! hb_HHasKey( hAllowed, cKey )
            cError := "Unknown structured SQL connection key."
            RETURN NIL
        ENDIF
        IF cKey == "trustServerCertificate"
            IF ! HB_ISLOGICAL( xValue )
                cError := "SQL trustServerCertificate must be logical."
                RETURN NIL
            ENDIF
        ELSEIF ! SQLProfileTextValid( xValue, cKey == "password" )
            cError := "Structured SQL connection values must be nonempty strings without NUL, CR or LF."
            RETURN NIL
        ENDIF
    NEXT
    IF ! hb_HHasKey( hProfile, "authentication" )
        cError := "SQL authentication is required: sql or integrated."
        RETURN NIL
    ENDIF
    cAuthentication := hProfile[ "authentication" ]
    IF ! ( cAuthentication == "sql" .OR. cAuthentication == "integrated" )
        cError := "SQL authentication must be sql or integrated."
        RETURN NIL
    ENDIF
    IF hb_HHasKey( hProfile, "dsn" )
        IF hb_HHasKey( hProfile, "odbcDriver" ) .OR. hb_HHasKey( hProfile, "server" )
            cError := "SQL dsn cannot be combined with odbcDriver or server."
            RETURN NIL
        ENDIF
        IF ! SQLDSNValid( hProfile[ "dsn" ] )
            cError := "SQL dsn contains characters unsupported by the ODBC Driver Manager."
            RETURN NIL
        ENDIF
        /* Driver Manager lookup uses the literal DSN value, including braces.
         * Validate this identifier before appending it without braces.
         */
        cConnection := "DSN=" + hProfile[ "dsn" ] + ";"
    ELSE
        IF ! hb_HHasKey( hProfile, "odbcDriver" ) .OR. ! hb_HHasKey( hProfile, "server" ) .OR. ;
            ! hb_HHasKey( hProfile, "database" )
            cError := "SQL connection requires dsn or odbcDriver, server and database."
            RETURN NIL
        ENDIF
        cConnection := SQLODBCAttribute( "DRIVER", hProfile[ "odbcDriver" ] ) + ;
            SQLODBCAttribute( "SERVER", hProfile[ "server" ] )
    ENDIF
    IF hb_HHasKey( hProfile, "database" )
        cConnection += SQLODBCAttribute( "DATABASE", hProfile[ "database" ] )
    ENDIF
    IF cAuthentication == "sql"
        IF ! hb_HHasKey( hProfile, "username" ) .OR. ! hb_HHasKey( hProfile, "password" )
            cError := "SQL authentication requires username and password."
            RETURN NIL
        ENDIF
        cConnection += "Trusted_Connection=No;" + ;
            SQLODBCAttribute( "UID", hProfile[ "username" ] ) + ;
            SQLODBCAttribute( "PWD", hProfile[ "password" ] )
    ELSE
        IF hb_HHasKey( hProfile, "username" ) .OR. hb_HHasKey( hProfile, "password" )
            cError := "Integrated SQL authentication cannot include username or password."
            RETURN NIL
        ENDIF
        cConnection += "Trusted_Connection=Yes;"
    ENDIF
    IF hb_HHasKey( hProfile, "encrypt" )
        cEncrypt := hProfile[ "encrypt" ]
        DO CASE
        CASE cEncrypt == "optional"
            cEncrypt := "No"
        CASE cEncrypt == "mandatory"
            cEncrypt := "Yes"
        CASE cEncrypt == "strict"
            cEncrypt := "Strict"
        OTHERWISE
            cError := "SQL encrypt must be optional, mandatory or strict."
            RETURN NIL
        ENDCASE
        cConnection += "Encrypt=" + cEncrypt + ";"
    ENDIF
    IF hb_HHasKey( hProfile, "trustServerCertificate" )
        cConnection += "TrustServerCertificate=" + ;
            iif( hProfile[ "trustServerCertificate" ], "Yes", "No" ) + ";"
    ENDIF

RETURN cConnection

STATIC FUNCTION SQLProfileTextValid( xValue, lAllowWhitespace )
    IF ! HB_ISSTRING( xValue )
        RETURN .F.
    ENDIF
    IF ! HB_ISLOGICAL( lAllowWhitespace )
        lAllowWhitespace := .F.
    ENDIF
RETURN Len( xValue ) > 0 .AND. ( lAllowWhitespace .OR. ! Empty( AllTrim( xValue ) ) ) .AND. ;
    ! ( Chr( 0 ) $ xValue ) .AND. ! ( Chr( 13 ) $ xValue ) .AND. ! ( Chr( 10 ) $ xValue )

/* SQLValidDSN documents the invalid punctuation. Keep the identifier literal
 * and reject whitespace edges/control bytes instead of silently changing it.
 * The installed ODBC manager remains responsible for its native length limit.
 */
STATIC FUNCTION SQLDSNValid( cValue )
    LOCAL cInvalid := "[]{}(),;?*=!@" + Chr( 92 ), nIndex, cByte, nCode
    IF ! ( cValue == AllTrim( cValue ) )
        RETURN .F.
    ENDIF
    FOR nIndex := 1 TO hb_BLen( cValue )
        cByte := hb_BSubStr( cValue, nIndex, 1 )
        nCode := hb_BCode( cByte )
        IF cByte $ cInvalid .OR. nCode < 32 .OR. nCode == 127
            RETURN .F.
        ENDIF
    NEXT
RETURN .T.

/* Enclose free-text driver attributes with braces and double closing braces.
 * A semicolon in a password stays inside that single value. DSN identifiers
 * and fixed scalar choices have separate serialization above.
 */
STATIC FUNCTION SQLODBCAttribute( cKey, cValue )
RETURN cKey + "={" + StrTran( cValue, "}", "}}" ) + "};"

/* Counting does not resolve ERP metadata. Use the caller's original SELECT
 * and an independent, explicitly owned workarea, even if OPEN fails before
 * assigning its alias. NIL means failure; zero is a valid empty result.
 */
STATIC FUNCTION SQLTotalRows( cSQL, nConnection, cDriver )

    LOCAL nPreviousArea := Select(), nCountArea := 0, nTotalRows := NIL
    LOCAL cAlias, cCount := iif( cDriver == "mssql", "COUNT_BIG(*)", "COUNT(*)" )
    LOCAL cCountSQL := "SELECT " + cCount + " AS QTOTAL FROM (" + cSQL + ") AS HBBCOUNT"

    BEGIN SEQUENCE WITH __BreakBlock()
        dbSelectArea( 0 )
        nCountArea := Select()
        cAlias := hb_rddGetTempAlias()
        IF ! dbUseArea( .F., "SQLMIX", cCountSQL, cAlias, .T., .T., NIL, nConnection )
            Break( NIL )
        ENDIF
        IF ( cAlias )->( FCount() ) != 1 .OR. ( cAlias )->( Eof() )
            Break( NIL )
        ENDIF
        nTotalRows := ( cAlias )->( FieldGet( 1 ) )
        /* Keep totals exact in the current JSON numeric contract. */
        IF ! HB_ISNUMERIC( nTotalRows )
            nTotalRows := NIL
        ELSEIF nTotalRows < 0 .OR. nTotalRows != Int( nTotalRows ) .OR. nTotalRows > 9007199254740991
            nTotalRows := NIL
        ENDIF
    RECOVER
        nTotalRows := NIL
    ALWAYS
        BEGIN SEQUENCE WITH __BreakBlock()
            IF nCountArea > 0
                dbSelectArea( nCountArea )
                IF Used()
                    dbCloseArea()
                    IF Used()
                        nTotalRows := NIL
                    ENDIF
                ENDIF
            ENDIF
        RECOVER
            nTotalRows := NIL
        ALWAYS
            dbSelectArea( nPreviousArea )
        END SEQUENCE
    END SEQUENCE

RETURN nTotalRows
