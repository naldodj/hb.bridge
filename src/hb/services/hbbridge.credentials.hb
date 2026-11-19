/* Local credential provider for the version 1 SQL password envelope. */

FUNCTION HBBridgeCredentialCreateKey( cKeyPath, cError )
    LOCAL lCreated
    LOCAL nStatus

    lCreated := HBBridgeCredentialFileCreate( cKeyPath, @nStatus )
    cError := CredentialErrorCode( nStatus )
RETURN lCreated

FUNCTION HBBridgeCredentialEncrypt( cKeyPath, cProfile, cCredential, cKeyId, cUser, cPassword, cError )
    LOCAL cAAD := CredentialAAD( cProfile, cCredential, cKeyId, cUser )
    LOCAL cEnvelope
    LOCAL nStatus

    IF cAAD == NIL
        cError := "INVALID_INPUT"
        RETURN NIL
    ENDIF
    cEnvelope := HBBridgeCredentialFileEncrypt( cKeyPath, cPassword, cAAD, @nStatus )
    cError := CredentialErrorCode( nStatus )
RETURN cEnvelope

FUNCTION HBBridgeCredentialDecrypt( cKeyPath, cProfile, cCredential, cKeyId, cUser, cEnvelope, cError )
    LOCAL cAAD := CredentialAAD( cProfile, cCredential, cKeyId, cUser )
    LOCAL cPassword
    LOCAL nStatus

    IF cAAD == NIL
        cError := "INVALID_INPUT"
        RETURN NIL
    ENDIF
    cPassword := HBBridgeCredentialFileDecrypt( cKeyPath, cEnvelope, cAAD, @nStatus )
    cError := CredentialErrorCode( nStatus )
RETURN cPassword

STATIC FUNCTION CredentialAAD( cProfile, cCredential, cKeyId, cUser )
    LOCAL cAAD := "hbbridge/credential/v1", cField
    LOCAL nBytes

    FOR EACH cField IN { "sql", cProfile, cCredential, cKeyId, cUser }
        IF ! HB_ISSTRING( cField ) .OR. Empty( cField )
            RETURN NIL
        ENDIF
        nBytes := hb_BLen( cField )
        IF nBytes > 1024 .OR. ! HBBridgeUTF8Valid( cField ) .OR. ;
            Chr( 0 ) $ cField .OR. Chr( 13 ) $ cField .OR. Chr( 10 ) $ cField
            RETURN NIL
        ENDIF
        /* The first two bytes of the big-endian length are zero under the field limit. */
        cAAD += hb_BChar( 0 ) + hb_BChar( 0 ) + hb_BChar( Int( nBytes / 256 ) ) + ;
            hb_BChar( nBytes % 256 ) + cField
    NEXT
RETURN cAAD

STATIC FUNCTION CredentialErrorCode( nStatus )
    /* Status values are shared with the native file bridge and Zig ABI. */
    STATIC aErrors := { "INVALID_INPUT", "INVALID_ENVELOPE", "UNSUPPORTED_VERSION", ;
        "AUTHENTICATION_FAILED", "ENTROPY_UNAVAILABLE", "KEY_UNAVAILABLE", "KEY_INVALID", ;
        "KEY_EXISTS", "KEY_WRITE_FAILED", "KEY_CLEANUP_FAILED", "KEY_PERMISSIONS_UNSAFE" }

    IF nStatus == 0
        RETURN NIL
    ENDIF
    IF ! HB_ISNUMERIC( nStatus ) .OR. nStatus < 1 .OR. nStatus > Len( aErrors )
        RETURN "PROVIDER_ERROR"
    ENDIF
RETURN aErrors[ nStatus ]
