PROCEDURE m2clocktests( nFailures, nChecks )

    LOCAL nPrevious := hbbridgemonotonicms(), nSample, nIndex, nElapsed
    LOCAL lOrdered := .T., lJoined, hThread, hResult
    LOCAL aThreads := {}, aResults := {}, nWindowStart, nWindowEnd

    m1assert( HB_ISNUMERIC( nPrevious ) .AND. nPrevious >= 0 .AND. nPrevious == Int( nPrevious ), ;
        "M2 monotonic clock returns nonnegative integer milliseconds", @nFailures, @nChecks )

    // Coarse clocks may repeat a value; only backward movement is invalid.
    FOR nIndex := 1 TO 5000
        nSample := hbbridgemonotonicms()
        IF nSample < nPrevious
            lOrdered := .F.
        ENDIF
        nPrevious := nSample
    NEXT
    m1assert( lOrdered, "M2 repeated clock reads never move backward", @nFailures, @nChecks )

    nPrevious := hbbridgemonotonicms()
    hb_idleSleep( 0.06 )
    nElapsed := hbbridgemonotonicms() - nPrevious
    m1assert( nElapsed >= 30 .AND. nElapsed < 2000, ;
        "M2 monotonic clock advances during sleep within scheduler tolerance", @nFailures, @nChecks )

    nWindowStart := hbbridgemonotonicms()
    FOR nIndex := 1 TO 8
        hThread := hb_threadStart( 0, @m2clocksamples() )
        IF ! Empty( hThread )
            AAdd( aThreads, hThread )
        ENDIF
    NEXT
    m1assert( Len( aThreads ) == 8, "M2 eight clock sampling threads start", @nFailures, @nChecks )

    IF ! Empty( aThreads )
        m1assert( hb_threadWait( aThreads, 5, .T. ) == Len( aThreads ), ;
            "M2 concurrent clock readers finish within five seconds", @nFailures, @nChecks )
    ENDIF
    FOR nIndex := 1 TO Len( aThreads )
        hThread := aThreads[ nIndex ]
        hResult := NIL
        lJoined := .F.
        IF hb_threadWait( hThread, 0 ) != 0
            lJoined := hb_threadJoin( hThread, @hResult )
        ENDIF
        m1assert( lJoined .AND. HB_ISHASH( hResult ), ;
            "M2 clock reader returns its samples " + hb_ntos( nIndex ), @nFailures, @nChecks )
        IF lJoined .AND. HB_ISHASH( hResult )
            AAdd( aResults, hResult )
            m1assert( hResult[ "ordered" ] .AND. hResult[ "valid" ] .AND. hResult[ "samples" ] == 4097, ;
                "M2 thread clock samples stay ordered and integral " + hb_ntos( nIndex ), @nFailures, @nChecks )
        ENDIF
    NEXT
    nWindowEnd := hbbridgemonotonicms()
    FOR nIndex := 1 TO Len( aResults )
        hResult := aResults[ nIndex ]
        m1assert( hResult[ "first" ] >= nWindowStart .AND. hResult[ "last" ] <= nWindowEnd, ;
            "M2 thread clock uses the common interval " + hb_ntos( nIndex ), @nFailures, @nChecks )
    NEXT

RETURN

STATIC FUNCTION m2clocksamples()

    LOCAL nFirst := hbbridgemonotonicms(), nPrevious := nFirst, nSample, nIndex
    LOCAL lOrdered := .T., lValid := nFirst >= 0 .AND. nFirst == Int( nFirst )

    FOR nIndex := 1 TO 4096
        nSample := hbbridgemonotonicms()
        IF nSample < nPrevious
            lOrdered := .F.
        ENDIF
        IF nSample < 0 .OR. nSample != Int( nSample )
            lValid := .F.
        ENDIF
        nPrevious := nSample
        // Yield periodically so the eight readers overlap while sampling.
        IF nIndex % 128 == 0
            hb_idleSleep( 0.001 )
        ENDIF
    NEXT

RETURN { "first" => nFirst, "last" => nPrevious, "ordered" => lOrdered, ;
    "valid" => lValid, "samples" => 4097 }
