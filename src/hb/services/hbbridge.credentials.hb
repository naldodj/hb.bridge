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

/* Local command accepts identifiers only. No password or SQL is accepted. */
FUNCTION HBBridgeCredentialTestCommand( aArgs )
    LOCAL cArg, cConfig := "", cError, cProfile := ""
    LOCAL hConfig
    LOCAL lConfigSeen := .F., lMode := .F., lProfileSeen := .F., lSuccess := .F.

    IF ! HB_ISARRAY( aArgs )
        RETURN .F.
    ENDIF
    FOR EACH cArg IN aArgs
        IF ! HB_ISSTRING( cArg )
            RETURN .F.
        ELSEIF cArg == "--credential-test" .AND. ! lMode
            lMode := .T.
        ELSEIF hb_BLeft( cArg, 9 ) == "--config=" .AND. ! lConfigSeen
            cConfig := hb_BSubStr( cArg, 10 )
            lConfigSeen := .T.
        ELSEIF hb_BLeft( cArg, 10 ) == "--profile=" .AND. ! lProfileSeen
            cProfile := hb_BSubStr( cArg, 11 )
            lProfileSeen := .T.
        ELSE
            RETURN .F.
        ENDIF
    NEXT
    IF ! lMode .OR. Empty( cConfig ) .OR. Empty( cProfile )
        RETURN .F.
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hConfig := HBBridgeConfig( { "-config=" + cConfig }, @cError )
        IF HB_ISHASH( hConfig ) .AND. HBBridgeSQLConfigure( hConfig[ "sqlODBCPooling" ], @cError )
            lSuccess := HBBridgeCredentialTestProfile( hConfig, cProfile )
        ENDIF
    RECOVER
        lSuccess := .F.
    END SEQUENCE
RETURN lSuccess

FUNCTION HBBridgeCredentialTestProfile( hConfig, cProfile )
    LOCAL hProfiles, hProfile, hResult, hRows, hRow

    IF ! HB_ISHASH( hConfig ) .OR. ! HB_ISSTRING( cProfile ) .OR. ;
        ! hb_HHasKey( hConfig, "sqlProfiles" ) .OR. ! HB_ISHASH( hConfig[ "sqlProfiles" ] )
        RETURN .F.
    ENDIF
    hProfiles := hConfig[ "sqlProfiles" ]
    IF ! hb_HHasKey( hProfiles, cProfile ) .OR. ! HB_ISHASH( hProfiles[ cProfile ] )
        RETURN .F.
    ENDIF
    hProfile := hProfiles[ cProfile ]
    IF hb_HGetDef( hProfile, "driver", "" ) != "mssql" .OR. ;
        ! HBBridgeCredentialBoundValid( hb_HGetDef( hProfile, "credential", NIL ) )
        RETURN .F.
    ENDIF
    hResult := HBBridgeSQLQuery( { "alias" => cProfile, "sql" => "SELECT 1 AS ID" }, hProfiles )
    IF ! HB_ISHASH( hResult ) .OR. ! hb_HGetDef( hResult, "success", .F. )
        RETURN .F.
    ENDIF
    hRows := hb_HGetDef( hResult, "rows", NIL )
    IF ! HB_ISHASH( hRows ) .OR. Len( hRows ) != 1
        RETURN .F.
    ENDIF
    hRow := hb_HGetDef( hRows, "1", NIL )
RETURN HB_ISHASH( hRow ) .AND. hb_HGetDef( hRow, "ID", NIL ) == 1

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
