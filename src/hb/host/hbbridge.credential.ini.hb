/* Released to Public Domain. Prepare an existing credential update in memory. */

FUNCTION HBBridgeCredentialPlanINI( cContents, cCredential, cEnvelope, hDefaults, cError )
    LOCAL cBefore, cBody, cDecoded, cLine, cLineRaw, cName, cOutput, cSection
    LOCAL cBOM := Chr( 239 ) + Chr( 187 ) + Chr( 191 ), cCR := Chr( 13 ), cLF := Chr( 10 )
    LOCAL cWhitespace := " " + Chr( 9 ), cParseError
    LOCAL hBefore, hAfter, hCredentials, hCredential
    LOCAL lTarget := .F.
    LOCAL nEnd, nEqual, nLength, nStart, nValueEnd, nValueStart

    cError := "INVALID_CREDENTIAL_UPDATE"
    IF ! HB_ISSTRING( cContents ) .OR. ! HB_ISSTRING( cCredential ) .OR. Empty( cCredential ) .OR. ;
        ! HB_ISSTRING( cEnvelope ) .OR. ! HB_ISHASH( hDefaults ) .OR. ;
        hb_BLeft( cEnvelope, 7 ) != "enc:v1:" .OR. hb_BLen( cEnvelope ) > 5523
        RETURN NIL
    ENDIF
    cBody := hb_BSubStr( cEnvelope, 8 )
    cDecoded := hb_base64Decode( cBody )
    IF ! HB_ISSTRING( cDecoded ) .OR. hb_BLen( cDecoded ) < 41 .OR. ;
        hb_BLen( cDecoded ) > 4136 .OR. hb_base64Encode( cDecoded ) != cBody
        RETURN NIL
    ENDIF
    cDecoded := NIL
    cBefore := cContents
    nStart := 1
    IF hb_BLeft( cBefore, 3 ) == cBOM
        cBefore := hb_BSubStr( cBefore, 4 )
        nStart := 4
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hBefore := HBBridgeConfigINI( cBefore, hDefaults, @cParseError )
        IF ! HB_ISHASH( hBefore ) .OR. ! hb_HHasKey( hBefore, "credentials" ) .OR. ;
            ! HB_ISHASH( hBefore[ "credentials" ] )
            Break( NIL )
        ENDIF
        hCredentials := hBefore[ "credentials" ]
        IF ! hb_HHasKey( hCredentials, cCredential ) .OR. ! HB_ISHASH( hCredentials[ cCredential ] )
            Break( NIL )
        ENDIF
        hCredential := hCredentials[ cCredential ]
        IF Len( hCredential ) != 3 .OR. ! hb_HHasKey( hCredential, "user" ) .OR. ;
            ! hb_HHasKey( hCredential, "keyId" ) .OR. ! hb_HHasKey( hCredential, "password" ) .OR. ;
            ! HB_ISSTRING( hCredential[ "password" ] ) .OR. hb_BLeft( hCredential[ "password" ], 7 ) != "enc:v1:"
            Break( NIL )
        ENDIF
        nLength := hb_BLen( cContents )
        DO WHILE nStart <= nLength
            nEnd := hb_BAt( cLF, cContents, nStart )
            IF nEnd == 0
                nEnd := nLength + 1
            ENDIF
            cLineRaw := hb_BSubStr( cContents, nStart, nEnd - nStart )
            IF hb_BRight( cLineRaw, 1 ) == cCR
                cLineRaw := hb_BLeft( cLineRaw, hb_BLen( cLineRaw ) - 1 )
            ENDIF
            cLine := CredentialINITrim( cLineRaw )
            IF ! Empty( cLine ) .AND. ! ( hb_BLeft( cLine, 1 ) $ ";#" )
                IF hb_BLeft( cLine, 1 ) == "["
                    cSection := CredentialINITrim( hb_BSubStr( cLine, 2, hb_BLen( cLine ) - 2 ) )
                    lTarget := Upper( hb_BLeft( cSection, 11 ) ) == "CREDENTIAL/" .AND. ;
                        hb_BSubStr( cSection, 12 ) == cCredential
                ELSEIF lTarget
                    nEqual := hb_BAt( "=", cLineRaw )
                    cName := Upper( CredentialINITrim( hb_BLeft( cLineRaw, nEqual - 1 ) ) )
                    IF cName == "PASSWORD"
                        nValueStart := nEqual + 1
                        nValueEnd := hb_BLen( cLineRaw )
                        DO WHILE nValueStart <= nValueEnd .AND. ;
                            hb_BSubStr( cLineRaw, nValueStart, 1 ) $ cWhitespace
                            nValueStart++
                        ENDDO
                        DO WHILE nValueEnd >= nValueStart .AND. ;
                            hb_BSubStr( cLineRaw, nValueEnd, 1 ) $ cWhitespace
                            nValueEnd--
                        ENDDO
                        cOutput := hb_BLeft( cContents, nStart + nValueStart - 2 ) + cEnvelope + ;
                            hb_BSubStr( cContents, nStart + nValueEnd )
                        EXIT
                    ENDIF
                ENDIF
            ENDIF
            nStart := nEnd + 1
        ENDDO
        IF ! HB_ISSTRING( cOutput )
            Break( NIL )
        ENDIF
        cBody := cOutput
        IF hb_BLeft( cBody, 3 ) == cBOM
            cBody := hb_BSubStr( cBody, 4 )
        ENDIF
        hAfter := HBBridgeConfigINI( cBody, hDefaults, @cParseError )
        hCredential[ "password" ] := cEnvelope
        IF ! HB_ISHASH( hAfter ) .OR. hb_Serialize( hBefore ) != hb_Serialize( hAfter )
            Break( NIL )
        ENDIF
        cError := ""
    RECOVER
        cOutput := NIL
    END SEQUENCE
RETURN cOutput

STATIC FUNCTION CredentialINITrim( cText )
    LOCAL cWhitespace := " " + Chr( 9 )
    LOCAL nStart := 1, nEnd := hb_BLen( cText )
    DO WHILE nStart <= nEnd .AND. hb_BSubStr( cText, nStart, 1 ) $ cWhitespace
        nStart++
    ENDDO
    DO WHILE nEnd >= nStart .AND. hb_BSubStr( cText, nEnd, 1 ) $ cWhitespace
        nEnd--
    ENDDO
RETURN hb_BSubStr( cText, nStart, nEnd - nStart + 1 )
