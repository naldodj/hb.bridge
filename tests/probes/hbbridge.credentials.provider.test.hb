/* Released to Public Domain. Synthetic tests for the production credential provider. */

REQUEST HB_CODEPAGE_UTF8EX

#define CREDENTIAL_PREFIX "enc:v1:"
#define CREDENTIAL_KEY_SIZE 32
#define CREDENTIAL_MAX_PASSWORD 4096

STATIC s_nChecks := 0
STATIC s_nFailures := 0

PROCEDURE Main( cDirectory )

    LOCAL cKeyPath, cError, cOriginalKey

    LOCAL hContext := { "profile" => "sql/example", "credential" => "reporting", ;
        "key" => "primary", "user" => "synthetic_reader" }

    hb_cdpSelect( "UTF8EX" )
    IF ! HB_ISSTRING( cDirectory ) .OR. ! hb_DirExists( cDirectory )
        ProbeAssert( .F., "synthetic fixture directory exists" )
        ProbeFinish()
        RETURN
    ENDIF

    cKeyPath := cDirectory + hb_ps() + "synthetic " + hb_UTF8Chr( 233 ) + ".key"
    cError := "stale"
    ProbeAssert( HBBridgeCredentialCreateKey( cKeyPath, @cError ) .AND. cError == NIL, ;
        "create a binary key at a Unicode path" )
    cOriginalKey := hb_MemoRead( cKeyPath )
    IF hb_BLen( cOriginalKey ) != CREDENTIAL_KEY_SIZE
        ProbeAssert( .F., "created key contains exactly 32 bytes" )
        ProbeFinish()
        RETURN
    ENDIF
    ProbeAssert( .T., "created key contains exactly 32 bytes" )
    ProbeAssert( ! HBBridgeCredentialCreateKey( cKeyPath, @cError ) .AND. cError == "KEY_EXISTS" .AND. ;
        hb_MemoRead( cKeyPath ) == cOriginalKey, "exclusive creation preserves the existing key" )
    cOriginalKey := NIL
    ProbeAssert( ! HBBridgeCredentialCreateKey( cDirectory + hb_ps() + "absent" + hb_ps() + "new.key", @cError ) .AND. ;
        cError == "KEY_WRITE_FAILED", "creation fails when the parent directory is absent" )

    ProbeEnvelope( cKeyPath, hContext )
    ProbeKeyFailures( cDirectory, cKeyPath, hContext )
    ProbeConcurrency( cDirectory + hb_ps() + "concurrent.key", cKeyPath, hContext )
    ProbeFinish()

RETURN

STATIC PROCEDURE ProbeEnvelope( cKeyPath, hContext )

    LOCAL cCase, cError, cRaw, cSecond, cCipher, cPadding, cWrongPadding, cEnvelope
    LOCAL cPassword := "  synthetic;" + hb_UTF8Chr( 233 ) + hb_UTF8Chr( 128640 ) + "  "
    LOCAL cAlphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    LOCAL hBadEnvelopes, hBadPasswords, hChanged

    LOCAL nPadIndex, nSextet

    cEnvelope := ProbeEncrypt( cKeyPath, hContext, cPassword, @cError )
    IF ! HB_ISSTRING( cEnvelope ) .OR. cError != NIL .OR. hb_BLeft( cEnvelope, 7 ) != CREDENTIAL_PREFIX
        ProbeAssert( .F., "seal an envelope with a v1 prefix" )
        RETURN
    ENDIF
    ProbeAssert( .T., "seal an envelope with a v1 prefix" )
    cRaw := hb_base64Decode( hb_BSubStr( cEnvelope, 8 ) )
    ProbeAssert( hb_BLen( cRaw ) == 40 + hb_BLen( cPassword ) .AND. ;
        CREDENTIAL_PREFIX + hb_base64Encode( cRaw ) == cEnvelope, "wire format has a 24-byte nonce and a 16-byte tag" )
    ProbeAssert( ProbeDecrypt( cKeyPath, hContext, cEnvelope, @cError ) == cPassword .AND. cError == NIL, ;
        "open preserves UTF-8 bytes and edge whitespace" )

    cSecond := ProbeEncrypt( cKeyPath, hContext, cPassword, @cError )
    ProbeAssert( HB_ISSTRING( cSecond ) .AND. cError == NIL .AND. ;
        hb_BLeft( hb_base64Decode( hb_BSubStr( cSecond, 8 ) ), 24 ) != hb_BLeft( cRaw, 24 ), ;
        "each seal generates a fresh nonce" )
    cCipher := ProbeEncrypt( cKeyPath, hContext, " ", @cError )
    ProbeAssert( ProbeDecrypt( cKeyPath, hContext, cCipher, @cError ) == " " .AND. cError == NIL, ;
        "whitespace-only SQL password is preserved" )
    cCipher := ProbeEncrypt( cKeyPath, hContext, Replicate( "x", CREDENTIAL_MAX_PASSWORD ), @cError )
    ProbeAssert( ProbeDecrypt( cKeyPath, hContext, cCipher, @cError ) == Replicate( "x", CREDENTIAL_MAX_PASSWORD ) .AND. ;
        cError == NIL, "maximum-size password round trips" )

    hBadPasswords := { "empty" => "", "NUL" => "x" + hb_BChar( 0 ), "carriage return" => "x" + hb_BChar( 13 ), ;
        "line feed" => "x" + hb_BChar( 10 ), "malformed UTF-8" => hb_BChar( 192 ) + hb_BChar( 175 ), ;
        "oversized" => Replicate( "x", CREDENTIAL_MAX_PASSWORD + 1 ), "non-string" => 17 }
    FOR EACH cCase IN hb_HKeys( hBadPasswords )
        ProbeAssert( ProbeEncrypt( cKeyPath, hContext, hBadPasswords[ cCase ], @cError ) == NIL .AND. ;
            cError == "INVALID_INPUT", "reject password case " + cCase )
    NEXT

    hb_BPoke( @cRaw, hb_BLen( cRaw ), hb_bitXor( hb_BCode( hb_BRight( cRaw, 1 ) ), 1 ) )
    ProbeAssert( ProbeDecrypt( cKeyPath, hContext, CREDENTIAL_PREFIX + hb_base64Encode( cRaw ), @cError ) == NIL .AND. ;
        cError == "AUTHENTICATION_FAILED", "reject a modified authentication tag" )

    FOR EACH cCase IN hb_HKeys( hContext )
        hChanged := hb_HClone( hContext )
        hChanged[ cCase ] += "-other"
        ProbeAssert( ProbeDecrypt( cKeyPath, hChanged, cEnvelope, @cError ) == NIL .AND. ;
            cError == "AUTHENTICATION_FAILED", "bind context field " + cCase )
    NEXT
    hChanged := hb_HClone( hContext )
    hChanged[ "profile" ] := hContext[ "profile" ] + hb_BLeft( hContext[ "credential" ], 1 )
    hChanged[ "credential" ] := hb_BSubStr( hContext[ "credential" ], 2 )
    ProbeAssert( ProbeDecrypt( cKeyPath, hChanged, cEnvelope, @cError ) == NIL .AND. cError == "AUTHENTICATION_FAILED", ;
        "length-prefixed fields cannot be recombined" )

    cPadding := ProbeEncrypt( cKeyPath, hContext, "x", @cError )
    IF HB_ISSTRING( cPadding ) .AND. hb_BRight( cPadding, 1 ) == "="
        nPadIndex := hb_BLen( cPadding ) - 1
        nSextet := At( hb_BSubStr( cPadding, nPadIndex, 1 ), cAlphabet )
        cWrongPadding := hb_BStuff( cPadding, nPadIndex, 1, hb_BSubStr( cAlphabet, nSextet + 1, 1 ) )
        ProbeAssert( ProbeDecrypt( cKeyPath, hContext, cWrongPadding, @cError ) == NIL .AND. cError == "INVALID_ENVELOPE", ;
            "reject non-canonical padding bits" )
        ProbeAssert( ProbeDecrypt( cKeyPath, hContext, hb_BLeft( cPadding, hb_BLen( cPadding ) - 1 ), @cError ) == NIL .AND. ;
            cError == "INVALID_ENVELOPE", "reject omitted padding" )
    ELSE
        ProbeAssert( .F., "single-byte fixture has one Base64 padding character" )
    ENDIF

    hBadEnvelopes := { "plaintext" => cPassword, "empty payload" => CREDENTIAL_PREFIX, ;
        "invalid character" => CREDENTIAL_PREFIX + "%" + hb_BSubStr( cEnvelope, 9 ), ;
        "whitespace" => cEnvelope + " ", "truncated binary" => CREDENTIAL_PREFIX + hb_base64Encode( hb_BLeft( cRaw, 40 ) ) }
    FOR EACH cCase IN hb_HKeys( hBadEnvelopes )
        ProbeAssert( ProbeDecrypt( cKeyPath, hContext, hBadEnvelopes[ cCase ], @cError ) == NIL .AND. ;
            cError == "INVALID_ENVELOPE", "reject envelope case " + cCase )
    NEXT
    ProbeAssert( ProbeDecrypt( cKeyPath, hContext, "enc:v2:" + hb_BSubStr( cEnvelope, 8 ), @cError ) == NIL .AND. ;
        cError == "UNSUPPORTED_VERSION", "reject an unsupported envelope version" )
    ProbeAssert( ProbeDecrypt( cKeyPath, hContext, cEnvelope, @cError ) == cPassword .AND. cError == NIL, ;
        "valid open succeeds after rejected inputs" )

RETURN

STATIC PROCEDURE ProbeKeyFailures( cDirectory, cKeyPath, hContext )

    LOCAL cBadKey, cError, cEnvelope, cMissingKey, cWrongKey

    cMissingKey := cDirectory + hb_ps() + "missing.key"
    cWrongKey := cDirectory + hb_ps() + "other.key"
    cBadKey := cDirectory + hb_ps() + "size.key"
    cEnvelope := ProbeEncrypt( cKeyPath, hContext, "fixture", @cError )
    ProbeAssert( ProbeEncrypt( cMissingKey, hContext, "fixture", @cError ) == NIL .AND. cError == "KEY_UNAVAILABLE", ;
        "seal fails closed when the key is absent" )
    ProbeAssert( ProbeDecrypt( cMissingKey, hContext, cEnvelope, @cError ) == NIL .AND. cError == "KEY_UNAVAILABLE", ;
        "open fails closed when the key is absent" )
    ProbeAssert( HBBridgeCredentialCreateKey( cWrongKey, @cError ) .AND. cError == NIL, "create an independent key" )
    ProbeAssert( ProbeDecrypt( cWrongKey, hContext, cEnvelope, @cError ) == NIL .AND. cError == "AUTHENTICATION_FAILED", ;
        "reject an unrelated key" )
    ProbeAssert( hb_MemoWrit( cBadKey, Replicate( hb_BChar( 0 ), CREDENTIAL_KEY_SIZE - 1 ) ), "write a short synthetic key" )
    ProbeAssert( ProbeDecrypt( cBadKey, hContext, cEnvelope, @cError ) == NIL .AND. cError == "KEY_INVALID", ;
        "reject a short key" )
    ProbeAssert( hb_MemoWrit( cBadKey, Replicate( hb_BChar( 0 ), CREDENTIAL_KEY_SIZE ) + hb_BChar( 26 ) ), ;
        "write a synthetic key with a trailing byte" )
    ProbeAssert( ProbeDecrypt( cBadKey, hContext, cEnvelope, @cError ) == NIL .AND. cError == "KEY_INVALID", ;
        "reject an oversized key" )

RETURN

STATIC PROCEDURE ProbeConcurrency( cRacePath, cKeyPath, hContext )

    // Native thread handles and join results are kept in ordered arrays.
    LOCAL aThreads := {}

    LOCAL cPrior

    LOCAL hGate := hb_mutexCreate(), hResult

    LOCAL nIndex, nCreated := 0

    FOR nIndex := 1 TO 2
        AAdd( aThreads, hb_threadStart( 0, @ProbeWorker(), hGate, cRacePath, cKeyPath, hContext ) )
    NEXT
    FOR nIndex := 1 TO 2
        hb_mutexNotify( hGate, .T. )
    NEXT
    FOR nIndex := 1 TO 2
        hResult := NIL
        IF ! hb_threadJoin( aThreads[ nIndex ], @hResult ) .OR. ! HB_ISHASH( hResult )
            ProbeAssert( .F., "worker completes" )
            LOOP
        ENDIF
        ProbeAssert( hResult[ "opened" ], "worker round trips its own envelope" )
        IF hResult[ "created" ]
            nCreated++
        ELSE
            ProbeAssert( hResult[ "keyError" ] == "KEY_EXISTS", "losing creation observes an existing key" )
        ENDIF
        IF nIndex == 2
            ProbeAssert( cPrior != NIL .AND. hResult[ "nonce" ] != NIL .AND. hResult[ "nonce" ] != cPrior, ;
                "workers generate different nonces" )
        ENDIF
        cPrior := hResult[ "nonce" ]
    NEXT
    ProbeAssert( nCreated == 1 .AND. hb_BLen( hb_MemoRead( cRacePath ) ) == CREDENTIAL_KEY_SIZE, ;
        "concurrent creation publishes one complete key" )

RETURN

STATIC FUNCTION ProbeWorker( hGate, cRacePath, cKeyPath, hContext )

    LOCAL cEnvelope, cError

    LOCAL hResult := { "opened" => .F., "created" => .F., "keyError" => NIL, "nonce" => NIL }

    IF hb_mutexSubscribe( hGate, 5 )
        hResult[ "created" ] := HBBridgeCredentialCreateKey( cRacePath, @cError )
        hResult[ "keyError" ] := cError
        cEnvelope := ProbeEncrypt( cKeyPath, hContext, "concurrent fixture", @cError )
        IF HB_ISSTRING( cEnvelope ) .AND. cError == NIL
            hResult[ "nonce" ] := hb_BLeft( hb_base64Decode( hb_BSubStr( cEnvelope, 8 ) ), 24 )
            hResult[ "opened" ] := ProbeDecrypt( cKeyPath, hContext, cEnvelope, @cError ) == "concurrent fixture" .AND. cError == NIL
        ENDIF
    ENDIF

RETURN hResult

STATIC FUNCTION ProbeEncrypt( cKeyPath, hContext, xPassword, cError )
RETURN HBBridgeCredentialEncrypt( cKeyPath, hContext[ "profile" ], hContext[ "credential" ], ;
    hContext[ "key" ], hContext[ "user" ], xPassword, @cError )

STATIC FUNCTION ProbeDecrypt( cKeyPath, hContext, cEnvelope, cError )
RETURN HBBridgeCredentialDecrypt( cKeyPath, hContext[ "profile" ], hContext[ "credential" ], ;
    hContext[ "key" ], hContext[ "user" ], cEnvelope, @cError )

STATIC PROCEDURE ProbeAssert( lOK, cMessage )
    s_nChecks++
    IF ! lOK
        s_nFailures++
    ENDIF
    OutStd( iif( lOK, "PASS ", "FAIL " ) + cMessage + hb_eol() )
RETURN

STATIC PROCEDURE ProbeFinish()
    OutStd( "Credential provider checks=" + hb_ntos( s_nChecks ) + ", failures=" + hb_ntos( s_nFailures ) + hb_eol() )
    ErrorLevel( s_nFailures )
RETURN
