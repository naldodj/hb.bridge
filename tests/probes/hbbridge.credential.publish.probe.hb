/* Released to Public Domain. Synthetic file publication probe. */
PROCEDURE HBBridgeCredentialPublishProbe( cTarget, cExpected, cReplacement )
    LOCAL cSnapshot
    LOCAL nBytes := -1
    LOCAL nStatus := -1

    IF cTarget == "--snapshot"
        cSnapshot := HBBridgeCredentialSnapshot( cExpected, @nStatus )
        IF HB_ISSTRING( cSnapshot )
            nBytes := hb_BLen( cSnapshot )
        ENDIF
        OutStd( "SNAPSHOT_STATUS=" + hb_ntos( nStatus ) + ";BYTES=" + hb_ntos( nBytes ) + hb_eol() )
        RETURN
    ENDIF
    HBBridgeCredentialPublish( cTarget, hb_MemoRead( cExpected ), hb_MemoRead( cReplacement ), @nStatus )
    OutStd( "PUBLISH_STATUS=" + hb_ntos( nStatus ) + hb_eol() )
RETURN
