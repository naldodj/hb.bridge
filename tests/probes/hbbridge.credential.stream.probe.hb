/* Released to Public Domain. Synthetic Windows stream enumeration probe. */
PROCEDURE HBBridgeCredentialStreamProbeMain( cPathHex, cMode )
    LOCAL cStage
    LOCAL nCode, nStatus

    IF cMode == "audit-fixture"
        nStatus := HBBridgeCredentialAuditFixture( hb_HexToStr( cPathHex ), @cStage, @nCode )
        OutStd( "AUDIT_STATUS=" + hb_ntos( nStatus ) + hb_eol() )
        IF nStatus != 0
            OutErr( "AUDIT_STAGE=" + cStage + " WIN32=" + hb_ntos( nCode ) + hb_eol() )
        ENDIF
    ELSEIF cMode == "metadata"
        OutStd( "METADATA_STATUS=" + hb_ntos( HBBridgeCredentialMetadataProbe( hb_HexToStr( cPathHex ) ) ) + hb_eol() )
    ELSEIF cMode == "sacl"
        OutStd( "SACL_STATUS=" + hb_ntos( HBBridgeCredentialSACLProbe( hb_HexToStr( cPathHex ) ) ) + hb_eol() )
    ELSE
        OutStd( "STREAM_STATUS=" + hb_ntos( HBBridgeCredentialStreamProbe( hb_HexToStr( cPathHex ) ) ) + hb_eol() )
    ENDIF
RETURN
