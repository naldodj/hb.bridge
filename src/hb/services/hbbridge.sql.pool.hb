/* Released to Public Domain. */
#include "hbclass.ch"
#include "dbinfo.ch"

/* Logical leases belong to one caller. Physical MSSQL reuse belongs to the
 * native ODBC driver manager, selected before the first ODBC environment.
 * Keep the shared SQL lifecycle mutex; do not cache global RDDSQL handles.
 * SQLite keeps its per-call lifetime, including isolated :memory: databases.
 */
CREATE CLASS HBBridgeSQLPool
    PROTECTED:
        VAR pMutex
        VAR hProfiles AS HASH INIT {=>}
        VAR hLeases AS HASH INIT {=>}
        VAR nNextLease AS NUMERIC INIT 0
        VAR lClosed AS LOGICAL INIT .F.
        METHOD RegisterLocked( cProfile, hProfile )
        METHOD AcquireLocked( cProfile )
        METHOD ReleaseLocked( hLease )
        METHOD DestroyLocked()
        METHOD StatusLocked()
    EXPORTED:
        METHOD New( pSQLMutex )
        METHOD RegisterProfile( cProfile, hProfile )
        METHOD Acquire( cProfile )
        METHOD Release( hLease )
        METHOD Destroy()
        METHOD Status()
ENDCLASS

METHOD New( pSQLMutex ) CLASS HBBridgeSQLPool
    ::pMutex := iif( pSQLMutex == NIL, hb_mutexCreate(), pSQLMutex )
RETURN Self

METHOD RegisterProfile( cProfile, hProfile ) CLASS HBBridgeSQLPool
RETURN hb_mutexEval( ::pMutex, {|| ::RegisterLocked( cProfile, hProfile ) } )

METHOD RegisterLocked( cProfile, hProfile ) CLASS HBBridgeSQLPool
    LOCAL hLease, hNormalized, cError
    IF ::lClosed .OR. ! HB_ISSTRING( cProfile ) .OR. ! HB_ISHASH( hProfile )
        RETURN .F.
    ENDIF
    IF Empty( cProfile ) .OR. ! hb_HHasKey( hProfile, "driver" )
        RETURN .F.
    ENDIF
    hNormalized := HBBridgeSQLProfiles( { cProfile => hProfile }, hb_cwd(), @cError )
    IF hNormalized == NIL
        RETURN .F.
    ENDIF
    hProfile := hNormalized[ cProfile ]
    IF hb_HHasKey( ::hProfiles, cProfile )
        IF hb_Serialize( ::hProfiles[ cProfile ] ) == hb_Serialize( hProfile )
            RETURN .T.
        ENDIF
        FOR EACH hLease IN ::hLeases
            IF hLease[ "profile" ] == cProfile
                RETURN .F.
            ENDIF
        NEXT
    ENDIF
    ::hProfiles[ cProfile ] := hb_HClone( hProfile )
RETURN .T.

METHOD Acquire( cProfile ) CLASS HBBridgeSQLPool
RETURN hb_mutexEval( ::pMutex, {|| ::AcquireLocked( cProfile ) } )

METHOD AcquireLocked( cProfile ) CLASS HBBridgeSQLPool
    LOCAL hProfile, aConnection, nConnection, hLease, cID
    IF ::lClosed .OR. ! HB_ISSTRING( cProfile ) .OR. ! hb_HHasKey( ::hProfiles, cProfile )
        RETURN NIL
    ENDIF
    hProfile := ::hProfiles[ cProfile ]
    /* Positional arrays are required by native RDDI_CONNECT. There are no
     * available/in-use arrays to copy or search and no unbounded retry loop.
     */
    IF hProfile[ "driver" ] == "sqlite"
        IF hProfile[ "database" ] != ":memory:" .AND. ! hb_FileExists( hProfile[ "database" ] )
            RETURN NIL
        ENDIF
        aConnection := { "SQLITE3", hProfile[ "database" ] }
    ELSE
        aConnection := { "ODBC", hProfile[ "connectionString" ], ;
            hb_HGetDef( hProfile, "loginTimeoutSeconds", NIL ), ;
            hb_HGetDef( hProfile, "queryTimeoutSeconds", NIL ) }
    ENDIF
    BEGIN SEQUENCE WITH __BreakBlock()
        nConnection := rddInfo( RDDI_CONNECT, aConnection, "SQLMIX" )
    RECOVER
        nConnection := 0
    END SEQUENCE
    IF nConnection > 0
        ::nNextLease++
        cID := hb_ntos( ::nNextLease )
        hLease := { "id" => cID, "profile" => cProfile, ;
            "thread" => hb_threadID(), "connection" => nConnection }
        ::hLeases[ cID ] := hLease
        RETURN hb_HClone( hLease )
    ENDIF
RETURN NIL

METHOD Release( hLease ) CLASS HBBridgeSQLPool
RETURN hb_mutexEval( ::pMutex, {|| ::ReleaseLocked( hLease ) } )

METHOD ReleaseLocked( hLease ) CLASS HBBridgeSQLPool
    LOCAL hOwned, lOK, cKey, xValue
    IF ! HB_ISHASH( hLease ) .OR. ! hb_HHasKey( hLease, "id" )
        RETURN .F.
    ENDIF
    IF ! HB_ISSTRING( hLease[ "id" ] ) .OR. ! hb_HHasKey( ::hLeases, hLease[ "id" ] )
        RETURN .F.
    ENDIF
    hOwned := ::hLeases[ hLease[ "id" ] ]
    IF hOwned[ "thread" ] != hb_threadID()
        RETURN .F.
    ENDIF
    FOR EACH xValue IN hOwned
        cKey := xValue:__enumKey()
        IF ! hb_HHasKey( hLease, cKey ) .OR. ValType( hLease[ cKey ] ) != ValType( xValue )
            RETURN .F.
        ENDIF
        IF hLease[ cKey ] != xValue
            RETURN .F.
        ENDIF
    NEXT
    BEGIN SEQUENCE WITH __BreakBlock()
        lOK := rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", hOwned[ "connection" ] )
    RECOVER
        lOK := .F.
    END SEQUENCE
    IF lOK
        hb_HDel( ::hLeases, hOwned[ "id" ] )
    ENDIF
    /* A failed close retains ownership; do not lend it or hide the failure.
     * Successful disconnect also clears this thread's current handle when
     * appropriate. Driver-manager pooling may keep the physical session.
     */
RETURN lOK

METHOD Destroy() CLASS HBBridgeSQLPool
RETURN hb_mutexEval( ::pMutex, {|| ::DestroyLocked() } )

METHOD DestroyLocked() CLASS HBBridgeSQLPool
    IF ! Empty( ::hLeases )
        RETURN .F.
    ENDIF
    ::lClosed := .T.
    ::hProfiles := {=>}
RETURN .T.

METHOD Status() CLASS HBBridgeSQLPool
RETURN hb_mutexEval( ::pMutex, {|| ::StatusLocked() } )

METHOD StatusLocked() CLASS HBBridgeSQLPool
RETURN { "closed" => ::lClosed, "profiles" => Len( ::hProfiles ), ;
    "activeLeases" => Len( ::hLeases ), "physicalPooling" => HBBridgeODBCPoolingInfo() }
