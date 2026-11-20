/* Released to Public Domain. Synthetic Windows stream enumeration probe. */
PROCEDURE HBBridgeCredentialStreamProbeMain( cPathHex )
    OutStd( "STREAM_STATUS=" + hb_ntos( HBBridgeCredentialStreamProbe( hb_HexToStr( cPathHex ) ) ) + hb_eol() )
RETURN
