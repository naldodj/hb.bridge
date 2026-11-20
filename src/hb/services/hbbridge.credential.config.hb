/* Released to Public Domain. Bind server-owned SQL credential references. */

FUNCTION HBBridgeCredentialBindProfiles( hProfiles, hCredentials, hKeys, cBase, cError )

    LOCAL cName, cId, cKeyId, cPath

    LOCAL hBound := {=>}, hProfile, hCredential, hKey, hNew

    cError := "Invalid credential configuration."
    IF ! HB_ISHASH( hProfiles ) .OR. ! HB_ISHASH( hCredentials ) .OR. ! HB_ISHASH( hKeys )
        RETURN NIL
    ENDIF
    FOR EACH hCredential IN hCredentials
        cName := hCredential:__enumKey()
        IF ! CredentialConfigText( cName ) .OR. ! HB_ISHASH( hCredential ) .OR. Len( hCredential ) != 3 .OR. ;
            ! hb_HHasKey( hCredential, "user" ) .OR. ! hb_HHasKey( hCredential, "keyId" ) .OR. ;
            ! hb_HHasKey( hCredential, "password" ) .OR. ! CredentialConfigText( hCredential[ "user" ] ) .OR. ;
            ! CredentialConfigText( hCredential[ "keyId" ] ) .OR. ! CredentialConfigText( hCredential[ "password" ] ) .OR. ;
            hb_BLeft( hCredential[ "password" ], 7 ) != "enc:v1:"
            RETURN NIL
        ENDIF
    NEXT
    FOR EACH hKey IN hKeys
        cName := hKey:__enumKey()
        IF ! CredentialConfigText( cName ) .OR. ! HB_ISHASH( hKey ) .OR. Len( hKey ) != 2 .OR. ;
            ! hb_HHasKey( hKey, "provider" ) .OR. ! hb_HHasKey( hKey, "location" ) .OR. ;
            ! HB_ISSTRING( hKey[ "provider" ] ) .OR. hKey[ "provider" ] != "file" .OR. ;
            ! CredentialConfigText( hKey[ "location" ] )
            RETURN NIL
        ENDIF
    NEXT
    FOR EACH hProfile IN hProfiles
        cName := hProfile:__enumKey()
        IF ! HB_ISHASH( hProfile )
            RETURN NIL
        ENDIF
        hNew := hb_HClone( hProfile )
        IF hb_HHasKey( hNew, "credential" )
            cId := hNew[ "credential" ]
            IF ! CredentialConfigText( cName ) .OR. ! CredentialConfigText( cId ) .OR. ! hb_HHasKey( hCredentials, cId )
                RETURN NIL
            ENDIF
            hCredential := hCredentials[ cId ]
            cKeyId := hCredential[ "keyId" ]
            IF ! hb_HHasKey( hKeys, cKeyId )
                RETURN NIL
            ENDIF
            hKey := hKeys[ cKeyId ]
            cPath := HBBridgeAbsolutePath( hKey[ "location" ], cBase )
            IF ! CredentialConfigText( cPath )
                RETURN NIL
            ENDIF
            hNew[ "credential" ] := { "id" => cId, "keyId" => cKeyId, "user" => hCredential[ "user" ], ;
                "envelope" => hCredential[ "password" ], "keyPath" => cPath }
        ENDIF
        hBound[ cName ] := hNew
    NEXT
    cError := ""
RETURN hBound

FUNCTION HBBridgeCredentialBoundValid( hCredential )
    LOCAL cField
    IF ! HB_ISHASH( hCredential ) .OR. Len( hCredential ) != 5
        RETURN .F.
    ENDIF
    FOR EACH cField IN { "id", "keyId", "user", "envelope", "keyPath" }
        IF ! hb_HHasKey( hCredential, cField ) .OR. ! CredentialConfigText( hCredential[ cField ] )
            RETURN .F.
        ENDIF
    NEXT
RETURN hb_BLeft( hCredential[ "envelope" ], 7 ) == "enc:v1:"

STATIC FUNCTION CredentialConfigText( xValue )
RETURN HB_ISSTRING( xValue ) .AND. ! Empty( AllTrim( xValue ) ) .AND. HBBridgeUTF8Valid( xValue ) .AND. ;
    ! ( Chr( 0 ) $ xValue ) .AND. ! ( Chr( 13 ) $ xValue ) .AND. ! ( Chr( 10 ) $ xValue )
