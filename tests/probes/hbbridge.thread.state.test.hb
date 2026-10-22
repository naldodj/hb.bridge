/* Released to Public Domain. */
#include "hbhrb.ch"

// This native symbol is called by the separately compiled HRB fixture.
EXTERNAL hb_threadID

STATIC s_hGate
STATIC s_nFailures := 0
STATIC s_nChecks := 0

PROCEDURE Main( cSource, cFile )

    // Ordered native arrays hold thread handles and sequential HRB results.
    LOCAL aThreads := {}, aResults

    LOCAL cHrb

    LOCAL hHrb, hThread
    LOCAL hFirst, hSecond, hA, hB, hAFirst, hBFirst, hASecond, hBSecond

    LOCAL nIndex, nThreads

    IF Empty( cSource ) .OR. Empty( cFile )
        OutStd( "Usage: hbbridge.thread.state.test <addon-source> <temporary-hrb>" + hb_eol() )
        ErrorLevel( 2 )
        RETURN
    ENDIF

    cHrb := hb_compileBuf( hb_argv( 0 ), "-n2", "-w", "-es2", "-q0", cSource )
    IF cHrb == NIL
        OutStd( "COMPILE FAILED" + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    hb_MemoWrit( cFile, cHrb )

    hHrb := hb_hrbLoad( HB_HRB_BIND_FORCELOCAL, cFile )
    hFirst := hb_hrbDo( hHrb, 100, .F. )
    hSecond := hb_hrbDo( hHrb, 101, .F. )
    ProbeOutput( "same-main-thread", { hFirst, hSecond } )
    ProbeAssert( hFirst[ "before" ] == 0 .AND. hSecond[ "before" ] == 1, ;
        "same thread keeps its THREAD STATIC values between calls" )

    s_hGate := { "mutex" => hb_mutexCreate(), "release" => hb_mutexCreate(), ;
        "participants" => {=>}, "expected" => 12 }
    FOR nIndex := 1 TO 12
        AAdd( aThreads, hb_threadStart( 0, @ThreadStaticWorker(), hHrb, nIndex ) )
    NEXT
    nThreads := Len( aThreads )
    FOR nIndex := 1 TO nThreads
        aResults := NIL
        ProbeAssert( hb_threadJoin( aThreads[ nIndex ], @aResults ), "shared HRB worker joins" )
        IF HB_ISARRAY( aResults ) .AND. Len( aResults ) == 2
            ProbeOutput( "shared-HRB-worker", aResults )
            ProbeAssert( aResults[ 1 ][ "before" ] == 0 .AND. ;
                aResults[ 1 ][ "counter" ] == 1 .AND. ;
                aResults[ 2 ][ "before" ] == 1 .AND. ;
                aResults[ 2 ][ "counter" ] == 2 .AND. ;
                aResults[ 1 ][ "owner" ] == nIndex .AND. ;
                aResults[ 2 ][ "owner" ] == nIndex .AND. ;
                aResults[ 1 ][ "allActive" ] == .T. .AND. ;
                aResults[ 1 ][ "thread" ] == aResults[ 2 ][ "thread" ], ;
                "same HRB isolates 12 threads while each thread keeps sequential values" )
        ELSE
            ProbeAssert( .F., "worker returns two results" )
        ENDIF
    NEXT
    s_hGate := NIL
    hb_hrbUnload( hHrb )

    hThread := hb_threadStart( 0, @ThreadStaticReloadWorker(), cFile )
    aResults := NIL
    ProbeAssert( hb_threadJoin( hThread, @aResults ), "persistent reload worker joins" )
    ProbeOutput( "same-persistent-thread-reloads", aResults )
    IF HB_ISARRAY( aResults ) .AND. Len( aResults ) == 4
        FOR nIndex := 1 TO 4
            ProbeAssert( aResults[ nIndex ][ "before" ] == nIndex - 1 .AND. ;
                aResults[ nIndex ][ "counter" ] == nIndex .AND. ;
                aResults[ nIndex ][ "thread" ] == aResults[ 1 ][ "thread" ], ;
                "reload in same persistent thread preserves previous THREAD STATIC counter" )
        NEXT
    ELSE
        ProbeAssert( .F., "reload worker returns four results" )
    ENDIF

    hA := hb_hrbLoad( HB_HRB_BIND_FORCELOCAL, cFile )
    hB := hb_hrbLoad( HB_HRB_BIND_FORCELOCAL, cFile )
    hAFirst := hb_hrbDo( hA, 200, .F. )
    hBFirst := hb_hrbDo( hB, 300, .F. )
    hASecond := hb_hrbDo( hA, 201, .F. )
    hBSecond := hb_hrbDo( hB, 301, .F. )
    ProbeOutput( "two-HRBs-same-thread", { hAFirst, hBFirst, hASecond, hBSecond } )
    ProbeAssert( hAFirst[ "before" ] == 2 .AND. hBFirst[ "before" ] == 0 .AND. ;
        hASecond[ "before" ] == 3 .AND. hBSecond[ "before" ] == 1 .AND. ;
        hASecond[ "counter" ] == 4 .AND. hBSecond[ "counter" ] == 2 .AND. ;
        hASecond[ "owner" ] == 201 .AND. hBSecond[ "owner" ] == 301, ;
        "active HRBs have separate THREAD STATIC storage, recycled HRB keeps main-thread value" )
    hb_hrbUnload( hA )
    hb_hrbUnload( hB )

    OutStd( "Harbour thread state checks=" + hb_ntos( s_nChecks ) + "; failures=" + hb_ntos( s_nFailures ) + hb_eol() )
    ErrorLevel( s_nFailures )

RETURN

FUNCTION ThreadStaticWorker( hHrb, nId )
RETURN { hb_hrbDo( hHrb, nId, .T. ), hb_hrbDo( hHrb, nId, .F. ) }

FUNCTION ThreadStaticReloadWorker( cFile )

    LOCAL aResults := {}

    LOCAL hHrb

    LOCAL nIndex

    FOR nIndex := 1 TO 4
        hHrb := hb_hrbLoad( HB_HRB_BIND_FORCELOCAL, cFile )
        AAdd( aResults, hb_hrbDo( hHrb, nIndex, .F. ) )
        hb_hrbUnload( hHrb )
    NEXT

RETURN aResults

FUNCTION ThreadStaticBarrier( nId )

    LOCAL lReady := .F.

    LOCAL nArrived, nRelease

    nArrived := hb_mutexEval( s_hGate[ "mutex" ], {|| ThreadStaticArrive( nId ) } )
    IF nArrived == s_hGate[ "expected" ]
        FOR nRelease := 1 TO s_hGate[ "expected" ]
            hb_mutexNotify( s_hGate[ "release" ], .T. )
        NEXT
    ENDIF

RETURN hb_mutexSubscribe( s_hGate[ "release" ], 2, @lReady ) .AND. lReady

STATIC FUNCTION ThreadStaticArrive( nId )
    s_hGate[ "participants" ][ hb_ntos( nId ) ] := .T.
RETURN Len( s_hGate[ "participants" ] )

STATIC PROCEDURE ProbeAssert( lCondition, cMessage )
    s_nChecks++
    IF ! lCondition
        s_nFailures++
        OutStd( "FAIL: " + cMessage + hb_eol() )
    ENDIF
RETURN

STATIC PROCEDURE ProbeOutput( cPhase, aResults )
    OutStd( hb_jsonEncode( { "phase" => cPhase, "results" => aResults } ) + hb_eol() )
RETURN
