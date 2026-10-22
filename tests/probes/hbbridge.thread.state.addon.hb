/* Released to Public Domain. Native thread-state probe fixture. */
FUNCTION ThreadStaticAddon( nId, lSynchronize )

    THREAD STATIC nCounter := 0
    THREAD STATIC nOwner := NIL
    LOCAL lAllActive := .T.

    LOCAL nBefore := nCounter

    nCounter++
    nOwner := nId
    IF lSynchronize == .T.
        lAllActive := ThreadStaticBarrier( nId )
    ENDIF

RETURN { "before" => nBefore, "counter" => nCounter, "owner" => nOwner, ;
    "thread" => hb_threadID(), "allActive" => lAllActive }
