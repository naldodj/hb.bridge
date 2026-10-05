/* Released to Public Domain. */
#include "dbinfo.ch"
#include "dbstruct.ch"

REQUEST SQLMIX, SDDSQLITE3, SDDODBC

STATIC s_hSQLMutex

INIT PROCEDURE hbbridgesqlinit()
    s_hSQLMutex := hb_mutexCreate()
RETURN

/* Generic executor: callers resolve ERP table/branch/company/tenant rules.
 * Profile aliases are opaque keys, including names such as mssql/pData.
 * RDDSQL's connection table/default connection are process-global. Keep the
 * complete connect/open/fetch/close/disconnect lifecycle under one mutex.
 */
FUNCTION hbbridgesqlquery( hParams, hProfiles )

    LOCAL cProfile, cSQL, hPage := NIL, cError

    IF ! hb_HHasKey( hParams, "alias" ) .OR. ! hb_HHasKey( hParams, "sql" )
        RETURN hbbridgeerror( "INVALID_PARAMS", "Connection profile and SQL are required." )
    ENDIF
    cProfile := hParams[ "alias" ]
    cSQL := hParams[ "sql" ]
    IF ! HB_ISSTRING( cProfile ) .OR. ! HB_ISSTRING( cSQL )
        RETURN hbbridgeerror( "INVALID_PARAMS", "Connection profile and SQL must be strings." )
    ENDIF
    IF Empty( AllTrim( cProfile ) ) .OR. Empty( AllTrim( cSQL ) ) .OR. ;
        Chr( 0 ) $ cProfile .OR. Chr( 0 ) $ cSQL
        RETURN hbbridgeerror( "INVALID_PARAMS", "Connection profile and SQL must be nonempty and contain no NUL." )
    ENDIF
    IF ! hb_HHasKey( hProfiles, cProfile )
        RETURN hbbridgeerror( "PROFILE_NOT_FOUND", "Connection profile is not configured." )
    ENDIF

    IF hb_HHasKey( hParams, "page" )
        hPage := sqlpageplan( hParams[ "page" ], cSQL, @cError )
        IF hPage == NIL
            RETURN hbbridgeerror( "INVALID_PAGE", cError )
        ENDIF
        cSQL := hPage[ "sql" ]
    ENDIF

RETURN hb_mutexEval( s_hSQLMutex, {|| sqlquerylocked( cSQL, hProfiles[ cProfile ], hPage ) } )

STATIC FUNCTION sqlquerylocked( cSQL, hProfile, hPage )

    LOCAL nConnection := 0, nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    LOCAL nPreviousArea := Select(), nArea := 0, nField, nFields, nRow := 0
    LOCAL hHeader := {=>}, hRows := {=>}, hRow, hField, cName, hResult
    LOCAL cFailure := "CONNECTION_FAILED", cMessage := "Database connection is unavailable."
    LOCAL aConnection
    LOCAL nOffset := iif( hPage == NIL, 0, 1 ), lHasNext := .F.

    /* The positional connection array is required by the native RDD API. */
    IF hProfile[ "driver" ] == "sqlite"
        IF hProfile[ "database" ] != ":memory:" .AND. ! hb_FileExists( hProfile[ "database" ] )
            RETURN hbbridgeerror( cFailure, cMessage )
        ENDIF
        aConnection := { "SQLITE3", hProfile[ "database" ] }
    ELSE
        aConnection := { "ODBC", hProfile[ "connectionString" ] }
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        nConnection := rddInfo( RDDI_CONNECT, aConnection, "SQLMIX" )
        IF nConnection == 0
            Break( NIL )
        ENDIF
        cFailure := "QUERY_FAILED"
        cMessage := "Could not open or read the SQL query result."
        dbSelectArea( 0 )
        nArea := Select()
        IF ! dbUseArea( .F., "SQLMIX", cSQL, hb_rddGetTempAlias(), .T., .T., NIL, nConnection )
            Break( NIL )
        ENDIF
        nFields := FCount()
        IF nFields == 0
            Break( NIL )
        ENDIF
        IF nFields <= nOffset
            Break( NIL )
        ENDIF
        FOR nField := 1 + nOffset TO nFields
            cName := Upper( AllTrim( FieldName( nField ) ) )
            IF Empty( cName ) .OR. hb_HHasKey( hHeader, cName ) .OR. ;
                ( nOffset > 0 .AND. ( Left( cName, 16 ) == "__HBBRIDGE_ROWNO" .OR. ":" $ cName ) )
                cFailure := "AMBIGUOUS_COLUMN"
                cMessage := "Query columns must have distinct names; use SQL aliases."
                Break( NIL )
            ENDIF
            hHeader[ cName ] := { "position" => nField - nOffset, ;
                "type" => hb_FieldType( nField ), ;
                "length" => dbFieldInfo( DBS_LEN, nField ), ;
                "decimals" => dbFieldInfo( DBS_DEC, nField ) }
        NEXT
        DO WHILE ! eof()
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
                hRow[ cName ] := fieldget( hField[ "position" ] + nOffset )
            NEXT
            nRow++
            hRows[ hb_ntos( nRow ) ] := hRow
            dbSkip()
        ENDDO
        hResult := { "success" => .T., "header" => hHeader, "rows" => hRows, ;
            "rowCount" => nRow, "driver" => hProfile[ "driver" ], "resultVersion" => 1 }
        IF hPage != NIL
            hResult[ "page" ] := { "number" => hPage[ "number" ], "size" => hPage[ "size" ], ;
                "hasNext" => lHasNext, "firstRow" => iif( nRow == 0, 0, hPage[ "begin" ] ), ;
                "lastRow" => iif( nRow == 0, 0, hPage[ "begin" ] + nRow - 1 ) }
        ENDIF
    RECOVER
        /* Driver errors can include SQL/connection strings. Return a stable
         * service error rather than exposing those internal descriptions.
         */
        hResult := hbbridgeerror( cFailure, cMessage )
    ALWAYS
        IF nArea > 0
            dbSelectArea( nArea )
            IF Used()
                dbCloseArea()
            ENDIF
        ENDIF
        IF nConnection > 0
            IF ! rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection )
                hResult := hbbridgeerror( "CONNECTION_CLOSE_FAILED", "Could not release the SQL connection." )
            ENDIF
        ENDIF
        IF nPreviousConnection > 0
            rddInfo( RDDI_CONNECTION, nPreviousConnection, "SQLMIX" )
        ENDIF
        dbSelectArea( nPreviousArea )
    END SEQUENCE

RETURN hResult

/* Use result ordinals rather than primary-key values. Fetch one sentinel row
 * in the database to detect another page without a second COUNT query.
 */
STATIC FUNCTION sqlpageplan( hPage, cSQL, cError )

    LOCAL nNumber, nSize, nBegin, nEnd, cOrder, cToken, cColumn, cDirection
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
    cSQL := "SELECT HBBPAGE.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY " + cQualified + ;
        ") AS __HBBRIDGE_ROWNO, HBBSRC.* FROM (" + cSQL + ") AS HBBSRC) AS HBBPAGE " + ;
        "WHERE HBBPAGE.__HBBRIDGE_ROWNO BETWEEN " + hb_ntos( nBegin ) + " AND " + hb_ntos( nEnd ) + ;
        " ORDER BY HBBPAGE.__HBBRIDGE_ROWNO"

RETURN { "sql" => cSQL, "number" => nNumber, "size" => nSize, "begin" => nBegin }

/* Return a separate normalized map. Credentials stay in the server registry's
 * handler closure and never become service metadata or client parameters.
 */
FUNCTION hbbridgesqlprofiles( hProfiles, cBase, cError )

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
        cKey := iif( cDriver == "sqlite", "database", "connectionString" )
        IF Len( hProfile ) != 2 .OR. ! hb_HHasKey( hProfile, cKey )
            cError := "SQL profile requires only driver and " + cKey + ": " + cName
            RETURN NIL
        ENDIF
        cValue := hProfile[ cKey ]
        IF ! HB_ISSTRING( cValue ) .OR. Empty( AllTrim( cValue ) ) .OR. Chr( 0 ) $ cValue
            cError := "Invalid SQL profile " + cKey + ": " + cName
            RETURN NIL
        ENDIF
        IF cDriver == "sqlite" .AND. cValue != ":memory:"
            cValue := hbbridgeabsolutepath( cValue, cBase )
            IF Empty( cValue )
                cError := "Invalid SQL database path: " + cName
                RETURN NIL
            ENDIF
        ENDIF
        hNormalized[ cName ] := { "driver" => cDriver, cKey => cValue }
    NEXT

RETURN hNormalized
