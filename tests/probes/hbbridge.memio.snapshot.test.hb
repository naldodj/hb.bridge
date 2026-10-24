/* Released to Public Domain. */
#require "hbmemio"

REQUEST HB_MEMIO, DBFCDX

STATIC s_nChecks := 0
STATIC s_nFailures := 0

PROCEDURE Main( cMode )

    // Native arrays hold the ordered thread handles and their results.
    LOCAL aThreads := {}, aResults := {}

    LOCAL cBase := "mem:hbbridge_future_snapshot"

    LOCAL hThread, hReady, hRelease, hResult

    LOCAL nIndex

    IF cMode == "absent"
        ProbeAssert( ! hb_vfExists( cBase + ".sentinel" ), "new process has no previous memory file" )
        ProbeFinish()
        RETURN
    ENDIF

    hThread := hb_threadStart( 0, @SnapshotProducer(), cBase )
    hResult := NIL
    ProbeAssert( hb_threadJoin( hThread, @hResult ), "producer joins" )
    ProbeAssert( HB_ISHASH( hResult ) .AND. hResult[ "rows" ] == 3, "producer created three rows" )
    ProbeAssert( hb_vfExists( cBase + ".dbf" ), "DBF survives producer close and thread exit" )
    ProbeAssert( hb_vfExists( cBase + ".fpt" ), "memo survives producer close and thread exit" )
    ProbeAssert( hb_vfExists( cBase + ".cdx" ), "index survives producer close and thread exit" )
    ProbeAssert( Select( "SNAP" ) == 0, "producer alias is absent in main thread" )
    dbUseArea( .T., "DBFCDX", cBase, "SNAP", .T., .T. )
    ProbeAssert( Used() .AND. LastRec() == 3, "main reopens DBF shared readonly" )
    ordListAdd( cBase + ".cdx" )
    ProbeAssert( dbSeek( 1 ) .AND. FieldGet( 1 ) == 1, "main seeks persisted index" )
    ProbeAssert( FieldGet( 3 ) == SnapshotMemoPayload( 1 ), "main reads persisted memo including NUL" )

    hReady := hb_mutexCreate()
    hRelease := hb_mutexCreate()
    FOR nIndex := 2 TO 3
        AAdd( aThreads, hb_threadStart( 0, @SnapshotReader(), cBase, nIndex, hReady, hRelease ) )
    NEXT
    FOR nIndex := 1 TO 2
        hResult := NIL
        ProbeAssert( hb_mutexSubscribe( hReady, 5, @hResult ) .AND. hResult, "reader opened its own workarea" )
    NEXT
    ProbeAssert( Used() .AND. RecNo() == 1, "concurrent readers leave main cursor unchanged" )
    FOR nIndex := 1 TO 2
        hb_mutexNotify( hRelease, .T. )
    NEXT
    FOR nIndex := 1 TO 2
        hResult := NIL
        ProbeAssert( hb_threadJoin( aThreads[ nIndex ], @hResult ), "reader joins" )
        AAdd( aResults, hResult )
        ProbeAssert( HB_ISHASH( hResult ) .AND. hResult[ "ok" ], ;
            "reader owns the same alias independently and seeks DBF with memo" )
    NEXT
    ProbeAssert( aResults[ 1 ][ "thread" ] != aResults[ 2 ][ "thread" ], "two distinct native reader threads" )
    ProbeAssert( RecNo() == 1, "reader completion leaves main cursor unchanged" )
    dbCloseAll()
    ProbeAssert( hb_vfExists( cBase + ".dbf" ), "closing all workareas retains DBF name" )
    ProbeAssert( dbDrop( cBase, NIL, "DBFCDX" ), "explicit dbDrop succeeds" )
    ProbeAssert( ! hb_vfExists( cBase + ".dbf" ) .AND. ! hb_vfExists( cBase + ".fpt" ) .AND. ;
        ! hb_vfExists( cBase + ".cdx" ), "dbDrop frees DBF memo and index names" )

    // Leave a file allocated intentionally for the separate-process check.
    ProbeAssert( hb_vfSave( cBase + ".sentinel", "process-owned-only" ) .AND. ;
        hb_vfExists( cBase + ".sentinel" ), "restart fixture exists before process exit" )
    ProbeFinish()

RETURN

FUNCTION SnapshotProducer( cBase )

    LOCAL nId, nRows

    dbCreate( cBase, { { "ID", "N", 9, 0 }, { "NAME", "C", 20, 0 }, { "PAYLOAD", "M", 10, 0 } }, ;
        "DBFCDX", .T., "SNAP" )
    FOR nId := 1 TO 3
        dbAppend()
        FieldPut( 1, nId )
        FieldPut( 2, "row-" + hb_ntos( nId ) )
        FieldPut( 3, SnapshotMemoPayload( nId ) )
    NEXT
    INDEX ON FIELD->ID TAG ID
    dbCommitAll()
    nRows := LastRec()
    dbCloseAll()

RETURN { "rows" => nRows }

FUNCTION SnapshotReader( cBase, nId, hReady, hRelease )

    LOCAL hResult := { "ok" => .F., "thread" => hb_threadID() }

    LOCAL lAliasAbsent := Select( "SNAP" ) == 0, lReleased := .F.

    dbUseArea( .T., "DBFCDX", cBase, "SNAP", .T., .T. )
    ordListAdd( cBase + ".cdx" )
    hResult[ "ok" ] := lAliasAbsent .AND. Used() .AND. dbSeek( nId ) .AND. FieldGet( 1 ) == nId .AND. ;
        FieldGet( 3 ) == SnapshotMemoPayload( nId )
    hb_mutexNotify( hReady, hResult[ "ok" ] )
    hResult[ "ok" ] := hb_mutexSubscribe( hRelease, 5, @lReleased ) .AND. lReleased .AND. ;
        hResult[ "ok" ] .AND. RecNo() == nId
    dbCloseAll()

RETURN hResult

FUNCTION SnapshotMemoPayload( nId )
RETURN "memo-" + hb_ntos( nId ) + ":" + Replicate( "m", 400 ) + Chr( 0 ) + "end"

STATIC PROCEDURE ProbeAssert( lOK, cMessage )
    s_nChecks++
    IF ! lOK
        s_nFailures++
    ENDIF
    OutStd( iif( lOK, "PASS ", "FAIL " ) + cMessage + hb_eol() )
RETURN

STATIC PROCEDURE ProbeFinish()
    OutStd( "MEMIO snapshot checks=" + hb_ntos( s_nChecks ) + "; failures=" + hb_ntos( s_nFailures ) + hb_eol() )
    ErrorLevel( s_nFailures )
RETURN
