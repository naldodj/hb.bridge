/* Released to Public Domain. */

/* A strict INI adapter. Native hb_iniReadStr has inline # comments, includes
 * and permissive malformed/duplicate handling. Preserve complete ODBC values
 * and reject mistakes before converting to the shared configuration schema.
 */
FUNCTION hbbridgeconfigini( cContents, hDefaults, cError )

    LOCAL hSections := { ;
        "GENERAL" => { "MAXWORKERS" => "maxWorkers", "ADDONROOT" => "addonRoot" }, ;
        "PROTHEUS" => { "HOST" => "protheusHost", "PORT" => "protheusPort", ;
            "MAXPAYLOADBYTES" => "protheusMaxPayloadBytes", "MAXWIREBYTES" => "protheusMaxWireBytes", ;
            "READCHUNKBYTES" => "protheusReadChunkBytes", "TIMEOUTMS" => "protheusTimeoutMs" }, ;
        "NETIO" => { "HOST" => "netioHost", "PORT" => "netioPort", "ROOT" => "netioRoot", ;
            "PASSWORD" => "netioPassword", "TIMEOUTMS" => "netioTimeout" }, ;
        "ADMIN" => { "HOST" => "adminHost", "PORT" => "adminPort", "PASSWORD" => "adminPassword" } }
    LOCAL hProfileKeys := { "DRIVER" => "driver", "DATABASE" => "database", ;
        "CONNECTIONSTRING" => "connectionString" }
    LOCAL hFile := {=>}, hSeenSections := {=>}, hSeenKeys := {=>}
    LOCAL cSection := "", cProfile := "", cSectionID, cLine, cKey, cValue, cTarget
    LOCAL nStart := 1, nEnd, nLine := 0, nEqual, lHasSection := .F.

    cError := ""
    DO WHILE nStart <= hb_BLen( cContents )
        nEnd := hb_BAt( Chr( 10 ), cContents, nStart )
        IF nEnd == 0
            nEnd := hb_BLen( cContents ) + 1
        ENDIF
        cLine := hb_BSubStr( cContents, nStart, nEnd - nStart )
        nStart := nEnd + 1
        nLine++
        IF Right( cLine, 1 ) == Chr( 13 )
            cLine := Left( cLine, Len( cLine ) - 1 )
        ENDIF
        cLine := initrim( cLine )
        IF Empty( cLine ) .OR. Left( cLine, 1 ) $ ";#"
            LOOP
        ENDIF
        cError := "Configuracao INI invalida na linha " + hb_ntos( nLine ) + "."
        IF Chr( 0 ) $ cLine .OR. Chr( 13 ) $ cLine
            RETURN NIL
        ENDIF
        IF Left( cLine, 1 ) == "["
            IF Right( cLine, 1 ) != "]"
                RETURN NIL
            ENDIF
            cSection := initrim( SubStr( cLine, 2, Len( cLine ) - 2 ) )
            IF Empty( cSection ) .OR. "[" $ cSection .OR. "]" $ cSection
                RETURN NIL
            ENDIF
            cProfile := ""
            IF Upper( Left( cSection, 4 ) ) == "SQL/"
                cProfile := SubStr( cSection, 5 )
                IF Empty( AllTrim( cProfile ) )
                    RETURN NIL
                ENDIF
                cSectionID := "SQL/" + cProfile
            ELSE
                cSection := Upper( cSection )
                IF ! hb_HHasKey( hSections, cSection )
                    cError := "Secao INI desconhecida na linha " + hb_ntos( nLine ) + "."
                    RETURN NIL
                ENDIF
                cSectionID := cSection
            ENDIF
            IF hb_HHasKey( hSeenSections, cSectionID )
                cError := "Secao INI repetida na linha " + hb_ntos( nLine ) + "."
                RETURN NIL
            ENDIF
            hSeenSections[ cSectionID ] := .T.
            hSeenKeys := {=>}
            lHasSection := .T.
            IF ! Empty( cProfile )
                IF ! hb_HHasKey( hFile, "sqlProfiles" )
                    hFile[ "sqlProfiles" ] := {=>}
                ENDIF
                hFile[ "sqlProfiles" ][ cProfile ] := {=>}
            ENDIF
            LOOP
        ENDIF
        nEqual := At( "=", cLine )
        IF ! lHasSection .OR. nEqual < 2
            RETURN NIL
        ENDIF
        cKey := Upper( initrim( Left( cLine, nEqual - 1 ) ) )
        cValue := initrim( SubStr( cLine, nEqual + 1 ) )
        IF hb_HHasKey( hSeenKeys, cKey )
            cError := "Chave INI repetida na linha " + hb_ntos( nLine ) + "."
            RETURN NIL
        ENDIF
        hSeenKeys[ cKey ] := .T.
        IF ! Empty( cProfile )
            IF ! hb_HHasKey( hProfileKeys, cKey )
                cError := "Chave de perfil SQL INI desconhecida na linha " + hb_ntos( nLine ) + "."
                RETURN NIL
            ENDIF
            cTarget := hProfileKeys[ cKey ]
            hFile[ "sqlProfiles" ][ cProfile ][ cTarget ] := iif( cTarget == "driver", Lower( cValue ), cValue )
        ELSE
            IF ! hb_HHasKey( hSections[ cSection ], cKey )
                cError := "Chave INI desconhecida na linha " + hb_ntos( nLine ) + "."
                RETURN NIL
            ENDIF
            cTarget := hSections[ cSection ][ cKey ]
            IF HB_ISNUMERIC( hDefaults[ cTarget ] )
                IF Empty( cValue ) .OR. ! ( cValue == hb_ntos( Val( cValue ) ) )
                    cError := "Numero INI invalido na linha " + hb_ntos( nLine ) + "."
                    RETURN NIL
                ENDIF
                hFile[ cTarget ] := Val( cValue )
            ELSE
                hFile[ cTarget ] := cValue
            ENDIF
        ENDIF
    ENDDO
    IF ! lHasSection
        cError := "Configuracao INI sem secoes."
        RETURN NIL
    ENDIF
    cError := ""

RETURN hFile

STATIC FUNCTION initrim( cText )
    LOCAL nStart := 1, nEnd := hb_BLen( cText )
    DO WHILE nStart <= nEnd .AND. hb_BSubStr( cText, nStart, 1 ) $ " " + Chr( 9 )
        nStart++
    ENDDO
    DO WHILE nEnd >= nStart .AND. hb_BSubStr( cText, nEnd, 1 ) $ " " + Chr( 9 )
        nEnd--
    ENDDO
RETURN hb_BSubStr( cText, nStart, nEnd - nStart + 1 )
