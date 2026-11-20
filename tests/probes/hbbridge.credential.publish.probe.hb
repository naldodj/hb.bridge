/* Released to Public Domain. Synthetic file publication probe. */
PROCEDURE HBBridgeCredentialPublishProbe( cTarget, cExpected, cReplacement )
    LOCAL nStatus := -1

    HBBridgeCredentialPublish( cTarget, hb_MemoRead( cExpected ), hb_MemoRead( cReplacement ), @nStatus )
    OutStd( "PUBLISH_STATUS=" + hb_ntos( nStatus ) + hb_eol() )
RETURN
