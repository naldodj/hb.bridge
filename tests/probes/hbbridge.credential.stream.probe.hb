/* Released to Public Domain. Synthetic Windows stream enumeration probe. */
PROCEDURE HBBridgeCredentialStreamProbeMain( cPathHex, cMode )
    IF cMode == "metadata"
        OutStd( "METADATA_STATUS=" + hb_ntos( HBBridgeCredentialMetadataProbe( hb_HexToStr( cPathHex ) ) ) + hb_eol() )
    ELSEIF cMode == "sacl"
        OutStd( "SACL_STATUS=" + hb_ntos( HBBridgeCredentialSACLProbe( hb_HexToStr( cPathHex ) ) ) + hb_eol() )
    ELSE
        OutStd( "STREAM_STATUS=" + hb_ntos( HBBridgeCredentialStreamProbe( hb_HexToStr( cPathHex ) ) ) + hb_eol() )
    ENDIF
RETURN
