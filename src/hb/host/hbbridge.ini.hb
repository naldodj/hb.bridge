/* Released to Public Domain. */

/* A strict INI adapter. Native hb_iniReadStr has inline # comments, includes
 * and permissive malformed/duplicate handling. Preserve complete ODBC values
 * and reject mistakes before converting to the shared configuration schema.
 */
FUNCTION HBBridgeConfigINI( cContents, hDefaults, cError )

    LOCAL cCR := Chr( 13 ), cLF := Chr( 10 ), cNul := Chr( 0 )
    LOCAL cSection, cProfile, cSectionID, cLine, cKey, cValue, cTarget

    LOCAL hSections, hProfileKeys, hFile, hSeenSections, hSeenKeys

    LOCAL lHasSection

    LOCAL nStart, nEnd, nLine, nEqual, nContentsLength

    hSections := { ;
        "GENERAL" => { "MAXWORKERS" => "maxWorkers", "ADDONROOT" => "addonRoot" }, ;
        "SQL" => { "ODBCPOOLING" => "sqlODBCPooling" }, ;
        "PROTHEUS" => { "HOST" => "protheusHost", "PORT" => "protheusPort", ;
            "MAXPAYLOADBYTES" => "protheusMaxPayloadBytes", "MAXWIREBYTES" => "protheusMaxWireBytes", ;
            "READCHUNKBYTES" => "protheusReadChunkBytes", "TIMEOUTMS" => "protheusTimeoutMs" }, ;
        "NETIO" => { "HOST" => "netioHost", "PORT" => "netioPort", "ROOT" => "netioRoot", ;
            "PASSWORD" => "netioPassword", "TIMEOUTMS" => "netioTimeout" }, ;
        "ADMIN" => { "HOST" => "adminHost", "PORT" => "adminPort", "PASSWORD" => "adminPassword" }, ;
        "HTTP" => { "ENABLED" => "httpEnabled", "HOST" => "httpHost", "PORT" => "httpPort", ;
            "LISTENBACKLOG" => "httpListenBacklog", ;
            "PASSWORD" => "httpPassword", "TLS" => "httpTLS", "CERTIFICATE" => "httpCertificate", ;
            "PRIVATEKEY" => "httpPrivateKey" } }
    hProfileKeys := { "DRIVER" => "driver", "DATABASE" => "database", ;
        "CONNECTIONSTRING" => "connectionString", "AUTHENTICATION" => "authentication", ;
        "DSN" => "dsn", "ODBCDRIVER" => "odbcDriver", "SERVER" => "server", ;
        "USERNAME" => "username", "PASSWORD" => "password", "ENCRYPT" => "encrypt", ;
        "TRUSTSERVERCERTIFICATE" => "trustServerCertificate", ;
        "LOGINTIMEOUTSECONDS" => "loginTimeoutSeconds", "QUERYTIMEOUTSECONDS" => "queryTimeoutSeconds" }
    hFile := {=>}
    hSeenSections := {=>}
    hSeenKeys := {=>}
    cSection := ""
    cProfile := ""
    nStart := 1
    nLine := 0
    lHasSection := .F.

    cError := ""
    nContentsLength := hb_BLen( cContents )
    DO WHILE nStart <= nContentsLength
        nEnd := hb_BAt( cLF, cContents, nStart )
        IF nEnd == 0
            nEnd := nContentsLength + 1
        ENDIF
        cLine := hb_BSubStr( cContents, nStart, nEnd - nStart )
        nStart := nEnd + 1
        nLine++
        IF Right( cLine, 1 ) == cCR
            cLine := Left( cLine, Len( cLine ) - 1 )
        ENDIF
        cLine := INITrim( cLine )
        IF Empty( cLine ) .OR. Left( cLine, 1 ) $ ";#"
            LOOP
        ENDIF
        cError := "Invalid INI configuration at line " + hb_ntos( nLine ) + "."
        IF cNul $ cLine .OR. cCR $ cLine
            RETURN NIL
        ENDIF
        IF Left( cLine, 1 ) == "["
            IF Right( cLine, 1 ) != "]"
                RETURN NIL
            ENDIF
            cSection := INITrim( SubStr( cLine, 2, Len( cLine ) - 2 ) )
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
                    cError := "Unknown INI section at line " + hb_ntos( nLine ) + "."
                    RETURN NIL
                ENDIF
                cSectionID := cSection
            ENDIF
            IF hb_HHasKey( hSeenSections, cSectionID )
                cError := "Duplicate INI section at line " + hb_ntos( nLine ) + "."
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
        cKey := Upper( INITrim( Left( cLine, nEqual - 1 ) ) )
        cValue := INITrim( SubStr( cLine, nEqual + 1 ) )
        IF hb_HHasKey( hSeenKeys, cKey )
            cError := "Duplicate INI key at line " + hb_ntos( nLine ) + "."
            RETURN NIL
        ENDIF
        hSeenKeys[ cKey ] := .T.
        IF ! Empty( cProfile )
            IF ! hb_HHasKey( hProfileKeys, cKey )
                cError := "Unknown SQL profile INI key at line " + hb_ntos( nLine ) + "."
                RETURN NIL
            ENDIF
            cTarget := hProfileKeys[ cKey ]
            IF cTarget == "loginTimeoutSeconds" .OR. cTarget == "queryTimeoutSeconds"
                IF Empty( cValue ) .OR. ! ( cValue == hb_ntos( Val( cValue ) ) )
                    cError := "Invalid SQL timeout number at line " + hb_ntos( nLine ) + "."
                    RETURN NIL
                ENDIF
                hFile[ "sqlProfiles" ][ cProfile ][ cTarget ] := Val( cValue )
            ELSEIF cTarget == "trustServerCertificate"
                IF ! ( Lower( cValue ) == "true" .OR. Lower( cValue ) == "false" )
                    cError := "INI logical values must be true or false at line " + hb_ntos( nLine ) + "."
                    RETURN NIL
                ENDIF
                hFile[ "sqlProfiles" ][ cProfile ][ cTarget ] := Lower( cValue ) == "true"
            ELSEIF cTarget == "driver" .OR. cTarget == "authentication" .OR. cTarget == "encrypt"
                hFile[ "sqlProfiles" ][ cProfile ][ cTarget ] := Lower( cValue )
            ELSE
                hFile[ "sqlProfiles" ][ cProfile ][ cTarget ] := cValue
            ENDIF
        ELSE
            IF ! hb_HHasKey( hSections[ cSection ], cKey )
                cError := "Unknown INI key at line " + hb_ntos( nLine ) + "."
                RETURN NIL
            ENDIF
            cTarget := hSections[ cSection ][ cKey ]
            IF HB_ISLOGICAL( hDefaults[ cTarget ] )
                IF ! ( Lower( cValue ) == "true" .OR. Lower( cValue ) == "false" )
                    cError := "INI logical values must be true or false at line " + hb_ntos( nLine ) + "."
                    RETURN NIL
                ENDIF
                hFile[ cTarget ] := Lower( cValue ) == "true"
            ELSEIF HB_ISNUMERIC( hDefaults[ cTarget ] )
                IF Empty( cValue ) .OR. ! ( cValue == hb_ntos( Val( cValue ) ) )
                    cError := "Invalid INI number at line " + hb_ntos( nLine ) + "."
                    RETURN NIL
                ENDIF
                hFile[ cTarget ] := Val( cValue )
            ELSE
                hFile[ cTarget ] := cValue
            ENDIF
        ENDIF
    ENDDO
    IF ! lHasSection
        cError := "INI configuration has no sections."
        RETURN NIL
    ENDIF
    cError := ""

RETURN hFile

STATIC FUNCTION INITrim( cText )
    LOCAL cWhitespace := " " + Chr( 9 )

    LOCAL nStart := 1, nEnd := hb_BLen( cText )
    DO WHILE nStart <= nEnd .AND. hb_BSubStr( cText, nStart, 1 ) $ cWhitespace
        nStart++
    ENDDO
    DO WHILE nEnd >= nStart .AND. hb_BSubStr( cText, nEnd, 1 ) $ cWhitespace
        nEnd--
    ENDDO
RETURN hb_BSubStr( cText, nStart, nEnd - nStart + 1 )
