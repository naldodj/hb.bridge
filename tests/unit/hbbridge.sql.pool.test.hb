/* Released to Public Domain. */
#include "dbinfo.ch"

/* Logical ownership tests use only private SQLite :memory: connections.
 * The alternate file profile is registered, never opened or created.
 */
PROCEDURE HBBridgeSQLPoolTests( nFailures, nChecks )

    LOCAL cPhysicalStatus, cKey

    LOCAL hProfile, hOther, hLease, hNext, hForged, hStatus, hThread

    LOCAL lForeignDenied, lJoined, lWaited

    LOCAL nPreviousArea, nReaderArea, nConnection, nStarted, nPreviousConnection

    LOCAL oPool

    LOCAL xValue

    oPool := HBBridgeSQLPool():New( hb_mutexCreate() )
    hProfile := { "driver" => "sqlite", "database" => ":memory:" }
    hOther := { "driver" => "sqlite", "database" => "sql-pool-never-opened.sqlite3" }
    hLease := NIL
    hNext := NIL
    nPreviousArea := Select()
    nReaderArea := 0
    nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    hThread := NIL
    lForeignDenied := .F.
    lJoined := .F.

    BEGIN SEQUENCE WITH __BreakBlock()
        hStatus := oPool:Status()
        M1Assert( ! hStatus[ "closed" ] .AND. hStatus[ "profiles" ] == 0 .AND. hStatus[ "activeLeases" ] == 0, ;
            "SQL pool starts open without profiles or logical leases", @nFailures, @nChecks )
        nStarted := HBBridgeMonotonicMs()
        M1Assert( oPool:Acquire( "unknown" ) == NIL .AND. HBBridgeMonotonicMs() - nStarted < 1000, ;
            "unknown SQL pool profile fails without an acquisition retry loop", @nFailures, @nChecks )
        M1Assert( ! oPool:RegisterProfile( "", hProfile ), ;
            "SQL pool rejects an empty profile alias", @nFailures, @nChecks )
        M1Assert( ! oPool:RegisterProfile( "invalid", { "driver" => "sqlite" } ), ;
            "SQL pool validates the complete profile before registration", @nFailures, @nChecks )
        M1Assert( oPool:RegisterProfile( "memory", hProfile ), ;
            "SQL pool registers an isolated SQLite memory profile", @nFailures, @nChecks )
        hProfile[ "database" ] := "changed-outside-the-pool.sqlite3"
        hLease := oPool:Acquire( "memory" )
        M1Assert( SQLPoolLeaseValid( hLease ) .AND. hLease[ "profile" ] == "memory" .AND. ;
            hLease[ "thread" ] == hb_threadID(), ;
            "SQL pool owns a profile snapshot and returns the requesting thread's lease", @nFailures, @nChecks )
        IF ! SQLPoolLeaseValid( hLease )
            Break( NIL )
        ENDIF
        nConnection := hLease[ "connection" ]
        M1Assert( rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
            "SQL pool acquisition establishes this thread's native connection", @nFailures, @nChecks )
        hStatus := oPool:Status()
        M1Assert( hStatus[ "profiles" ] == 1 .AND. hStatus[ "activeLeases" ] == 1, ;
            "SQL pool status exposes counts without disclosing connection profiles", @nFailures, @nChecks )
        cPhysicalStatus := hb_Serialize( hStatus[ "physicalPooling" ] )
        hStatus[ "closed" ] := .T.
        hStatus[ "profiles" ] := 99
        hStatus[ "activeLeases" ] := 99
        hStatus[ "physicalPooling" ][ "mode" ] := "changed-by-status-caller"
        hStatus := oPool:Status()
        M1Assert( ! hStatus[ "closed" ] .AND. hStatus[ "profiles" ] == 1 .AND. ;
            hStatus[ "activeLeases" ] == 1 .AND. hb_Serialize( hStatus[ "physicalPooling" ] ) == cPhysicalStatus, ;
            "SQL pool status and nested physical policy are defensive snapshots", @nFailures, @nChecks )

        FOR EACH xValue IN { "profile" => "forged-profile", "thread" => hb_threadID() + 1, ;
            "connection" => nConnection + 1 }
            cKey := xValue:__enumKey()
            hForged := hb_HClone( hLease )
            hForged[ cKey ] := xValue
            M1Assert( ! oPool:Release( hForged ) .AND. oPool:Status()[ "activeLeases" ] == 1 .AND. ;
                rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
                "SQL pool rejects a forged lease " + cKey + " without touching its owner", @nFailures, @nChecks )
        NEXT
        M1Assert( ! oPool:Release( { "profile" => "memory", "connection" => nConnection } ), ;
            "SQL pool rejects a release without a lease identity", @nFailures, @nChecks )
        M1Assert( ! oPool:Destroy() .AND. ! oPool:Status()[ "closed" ] .AND. oPool:Status()[ "activeLeases" ] == 1, ;
            "SQL pool shutdown refuses to disconnect a live caller lease", @nFailures, @nChecks )
        M1Assert( ! oPool:RegisterProfile( "memory", hOther ), ;
            "SQL pool refuses to replace a profile while its caller owns a lease", @nFailures, @nChecks )
        M1Assert( oPool:RegisterProfile( "memory", { "driver" => "sqlite", "database" => ":memory:" } ), ;
            "SQL pool accepts unchanged registration while the lease is active", @nFailures, @nChecks )

        M1Assert( hb_mtvm(), "SQL pool ownership fixture has a multithread runtime", @nFailures, @nChecks )
        IF hb_mtvm()
            hThread := hb_threadStart( 0, @SQLPoolForeignRelease(), oPool, hLease )
            M1Assert( ! Empty( hThread ), "SQL pool foreign-release worker starts", @nFailures, @nChecks )
            IF ! Empty( hThread )
                lWaited := hb_threadWait( hThread, 5 ) != 0
                M1Assert( lWaited, "SQL pool foreign release completes within five seconds", @nFailures, @nChecks )
                IF lWaited
                    lJoined := hb_threadJoin( hThread, @lForeignDenied )
                    M1Assert( lJoined .AND. lForeignDenied .AND. oPool:Status()[ "activeLeases" ] == 1, ;
                        "another thread cannot return or borrow the caller's lease", @nFailures, @nChecks )
                ELSE
                    Break( NIL )
                ENDIF
            ENDIF
        ENDIF

        M1Assert( rddInfo( RDDI_EXECUTE, "CREATE TABLE hbbridge_pool_fixture (ID INTEGER)", "SQLMIX", nConnection ) .AND. ;
            rddInfo( RDDI_EXECUTE, "INSERT INTO hbbridge_pool_fixture VALUES (42)", "SQLMIX", nConnection ), ;
            "SQL pool memory lease owns test-local table state", @nFailures, @nChecks )
        dbSelectArea( 0 )
        nReaderArea := Select()
        M1Assert( dbUseArea( .F., "SQLMIX", "SELECT ID FROM hbbridge_pool_fixture", ;
            hb_rddGetTempAlias(), .T., .T., NIL, nConnection ), ;
            "SQL pool fixture opens a reader on its own reserved workarea", @nFailures, @nChecks )
        M1Assert( Used() .AND. FieldGet( 1 ) == 42, ;
            "SQL pool fixture reader sees its connection-local data", @nFailures, @nChecks )
        M1Assert( ! oPool:Release( hLease ) .AND. oPool:Status()[ "activeLeases" ] == 1 .AND. ;
            Used() .AND. FieldGet( 1 ) == 42 .AND. rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
            "reader-open release fails visibly and retains logical and native ownership", @nFailures, @nChecks )
        dbCloseArea()
        nReaderArea := 0
        dbSelectArea( nPreviousArea )
        M1Assert( oPool:Release( hLease ) .AND. oPool:Status()[ "activeLeases" ] == 0, ;
            "closing the owned reader allows the same lease to be released", @nFailures, @nChecks )
        M1Assert( rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == 0 .AND. Select() == nPreviousArea, ;
            "successful lease release clears the native default and preserves the caller area", @nFailures, @nChecks )
        M1Assert( ! oPool:Release( hLease ) .AND. oPool:Status()[ "activeLeases" ] == 0, ;
            "SQL pool rejects a duplicate release", @nFailures, @nChecks )

        hNext := oPool:Acquire( "memory" )
        M1Assert( SQLPoolLeaseValid( hNext ), "SQL pool reacquires after an earlier release", @nFailures, @nChecks )
        IF ! SQLPoolLeaseValid( hNext )
            Break( NIL )
        ENDIF
        M1Assert( hNext[ "connection" ] == nConnection .AND. hNext[ "id" ] != hLease[ "id" ], ;
            "recycled native connection handle receives a distinct logical lease identity", @nFailures, @nChecks )
        M1Assert( ! oPool:Release( hLease ) .AND. oPool:Status()[ "activeLeases" ] == 1 .AND. ;
            rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == hNext[ "connection" ], ;
            "a stale lease cannot release a new owner after native handle reuse", @nFailures, @nChecks )
        M1Assert( SQLPoolScalar( hNext[ "connection" ], "SELECT COUNT(*) FROM sqlite_master " + ;
            "WHERE type = 'table' AND name = 'hbbridge_pool_fixture'" ) == 0, ;
            "each SQLite memory lease starts without the previous lease's table", @nFailures, @nChecks )
        M1Assert( SQLPoolScalar( hNext[ "connection" ], "SELECT 73" ) == 73, ;
            "a rejected stale release leaves the fresh connection usable", @nFailures, @nChecks )
        M1Assert( oPool:Release( hNext ) .AND. oPool:Status()[ "activeLeases" ] == 0 .AND. ;
            rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == 0, ;
            "fresh logical lease releases its own native connection", @nFailures, @nChecks )
        M1Assert( oPool:Destroy() .AND. oPool:Status()[ "closed" ] .AND. oPool:Status()[ "profiles" ] == 0, ;
            "SQL pool shutdown clears registrations after all callers release", @nFailures, @nChecks )
        nStarted := HBBridgeMonotonicMs()
        M1Assert( oPool:Acquire( "memory" ) == NIL .AND. HBBridgeMonotonicMs() - nStarted < 1000, ;
            "closed SQL pool rejects acquisition without retrying", @nFailures, @nChecks )
        M1Assert( ! oPool:RegisterProfile( "memory", { "driver" => "sqlite", "database" => ":memory:" } ), ;
            "closed SQL pool rejects new registration", @nFailures, @nChecks )
        M1Assert( oPool:Destroy() .AND. oPool:Status()[ "closed" ], ;
            "SQL pool shutdown is idempotent", @nFailures, @nChecks )
    RECOVER
        M1Assert( .F., "SQL pool ownership fixture completed without an unexpected runtime error", @nFailures, @nChecks )
    ALWAYS
        IF nReaderArea > 0
            dbSelectArea( nReaderArea )
            IF Used()
                dbCloseArea()
            ENDIF
        ENDIF
        IF ! Empty( hThread ) .AND. ! lJoined
            IF hb_threadWait( hThread, 0 ) == 0
                hb_threadQuitRequest( hThread )
            ENDIF
            IF hb_threadWait( hThread, 1 ) != 0
                lJoined := hb_threadJoin( hThread )
            ENDIF
            M1Assert( lJoined, "SQL pool foreign-release worker is joined during cleanup", @nFailures, @nChecks )
        ENDIF
        IF HB_ISHASH( hLease )
            oPool:Release( hLease )
        ENDIF
        IF HB_ISHASH( hNext )
            oPool:Release( hNext )
        ENDIF
        M1Assert( oPool:Status()[ "activeLeases" ] == 0 .AND. oPool:Destroy(), ;
            "SQL pool fixture leaves no owned native lease behind", @nFailures, @nChecks )
        IF nPreviousConnection > 0
            rddInfo( RDDI_CONNECTION, nPreviousConnection, "SQLMIX" )
        ENDIF
        dbSelectArea( nPreviousArea )
        M1Assert( Select() == nPreviousArea .AND. ;
            rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
            "SQL pool fixture restores the original caller area and connection", @nFailures, @nChecks )
    END SEQUENCE

RETURN

STATIC FUNCTION SQLPoolForeignRelease( oPool, hLease )
RETURN ! oPool:Release( hLease )

STATIC FUNCTION SQLPoolLeaseValid( hLease )
RETURN HB_ISHASH( hLease ) .AND. hb_HHasKey( hLease, "id" ) .AND. HB_ISSTRING( hLease[ "id" ] ) .AND. ;
    ! Empty( hLease[ "id" ] ) .AND. hb_HHasKey( hLease, "profile" ) .AND. HB_ISSTRING( hLease[ "profile" ] ) .AND. ;
    hb_HHasKey( hLease, "thread" ) .AND. HB_ISNUMERIC( hLease[ "thread" ] ) .AND. ;
    hb_HHasKey( hLease, "connection" ) .AND. HB_ISNUMERIC( hLease[ "connection" ] ) .AND. hLease[ "connection" ] > 0

STATIC FUNCTION SQLPoolScalar( nConnection, cSQL )

    LOCAL nPreviousArea := Select(), nQueryArea := 0

    LOCAL xResult := NIL

    BEGIN SEQUENCE WITH __BreakBlock()
        dbSelectArea( 0 )
        nQueryArea := Select()
        IF dbUseArea( .F., "SQLMIX", cSQL, hb_rddGetTempAlias(), .T., .T., NIL, nConnection ) .AND. ! Eof()
            xResult := FieldGet( 1 )
        ENDIF
    RECOVER
        xResult := NIL
    ALWAYS
        IF nQueryArea > 0
            dbSelectArea( nQueryArea )
            IF Used()
                dbCloseArea()
            ENDIF
        ENDIF
        dbSelectArea( nPreviousArea )
    END SEQUENCE

RETURN xResult
