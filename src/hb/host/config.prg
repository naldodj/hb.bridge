/*
 _      _         _            _      _
| |__  | |__     | |__   _ __ (_)  __| |  __ _   ___
| '_ \ | '_ \    | '_ \ | '__|| | / _` | / _` | / _ \
| | | || |_) | _ | |_) || |   | || (_| || (_| ||  __/
|_| |_||_.__/ (_)|_.__/ |_|   |_| \__,_| \__, | \___|
                                         |___/
Released to Public Domain.
--------------------------------------------------------------------------------------
*/

/* Precedence: defaults < JSON file < CLI. No listeners or directory creation. */
FUNCTION HBBridgeConfig( aArgs, cError )

   LOCAL hConfig := { "protheusHost" => "0.0.0.0", "protheusPort" => 1512, ;
      "netioHost" => "0.0.0.0", "netioPort" => 2941, "netioRoot" => "data", ;
      "netioPassword" => "", "adminHost" => "127.0.0.1", "adminPort" => 2940, ;
      "adminPassword" => "", "addonRoot" => "addons", "maxWorkers" => 64, ;
      "netioTimeout" => 5000 }
   LOCAL hOptions := { "host" => "protheusHost", "port" => "protheusPort", ;
      "netiohost" => "netioHost", "netioport" => "netioPort", "netioroot" => "netioRoot", ;
      "adminhost" => "adminHost", "adminport" => "adminPort", "addonroot" => "addonRoot", ;
      "maxworkers" => "maxWorkers", "netiotimeout" => "netioTimeout" }
   LOCAL cArg, cName, cValue, cKey, cFile := "", hFile, cJson, nRead, nEqual

   hb_default( @aArgs, {} )
   cError := ""
   FOR EACH cKey IN { "netioRoot", "addonRoot" }
      hConfig[ cKey ] := HBBridgeAbsolutePath( hConfig[ cKey ], hb_cwd() )
   NEXT
   FOR EACH cArg IN aArgs
      IF Left( cArg, 8 ) == "-config="
         IF ! Empty( cFile ) .OR. Empty( SubStr( cArg, 9 ) )
            cError := "Informe um unico -config=<arquivo.json>"
            RETURN NIL
         ENDIF
         cFile := HBBridgeAbsolutePath( SubStr( cArg, 9 ), hb_cwd() )
      ENDIF
   NEXT
   IF ! Empty( cFile )
      IF ! hb_FileExists( cFile )
         cError := "Arquivo de configuracao nao encontrado"
         RETURN NIL
      ENDIF
      cJson := hb_MemoRead( cFile )
      nRead := hb_jsonDecode( cJson, @hFile )
      IF nRead == 0 .OR. ! HB_ISHASH( hFile ) .OR. ;
         ! Empty( AllTrim( SubStr( cJson, nRead + 1 ) ) )
         cError := "Configuracao JSON invalida"
         RETURN NIL
      ENDIF
      FOR EACH cKey IN hb_HKeys( hFile )
         IF ! hb_HHasKey( hConfig, cKey )
            cError := "Chave desconhecida na configuracao: " + cKey
            RETURN NIL
         ENDIF
         IF ValType( hFile[ cKey ] ) != ValType( hConfig[ cKey ] )
            cError := "Tipo invalido na configuracao: " + cKey
            RETURN NIL
         ENDIF
         hConfig[ cKey ] := hFile[ cKey ]
         IF cKey == "netioRoot" .OR. cKey == "addonRoot"
            IF Empty( hConfig[ cKey ] )
               cError := "Diretorio vazio: " + cKey
               RETURN NIL
            ENDIF
            hConfig[ cKey ] := HBBridgeAbsolutePath( hConfig[ cKey ], hb_FNameDir( cFile ) )
         ENDIF
      NEXT
   ENDIF
   FOR EACH cArg IN aArgs
      IF Left( cArg, 8 ) == "-config="
         LOOP
      ENDIF
      nEqual := At( "=", cArg )
      cName := SubStr( cArg, 2, Max( 0, nEqual - 2 ) )
      IF Left( cArg, 1 ) != "-" .OR. nEqual < 3 .OR. ! hb_HHasKey( hOptions, cName )
         cError := "Opcao desconhecida; consulte --help"
         RETURN NIL
      ENDIF
      cKey := hOptions[ cName ]
      cValue := SubStr( cArg, nEqual + 1 )
      IF Empty( cValue )
         cError := "Valor vazio: " + cName
         RETURN NIL
      ENDIF
      IF HB_ISNUMERIC( hConfig[ cKey ] )
         IF cValue != hb_ntos( Val( cValue ) )
            cError := "Numero invalido: " + cName
            RETURN NIL
         ENDIF
         hConfig[ cKey ] := Val( cValue )
      ELSEIF cKey == "netioRoot" .OR. cKey == "addonRoot"
         hConfig[ cKey ] := HBBridgeAbsolutePath( cValue, hb_cwd() )
      ELSE
         hConfig[ cKey ] := cValue
      ENDIF
   NEXT
   IF ! HBBridgeConfigValid( hConfig, @cError )
      RETURN NIL
   ENDIF

RETURN hConfig

FUNCTION HBBridgeConfigValid( hConfig, cError )

   LOCAL cKey, nValue, aChannels := { "protheus", "netio" }, nLeft, nRight, cLeft, cRight

   cError := ""
   FOR EACH cKey IN { "protheusPort", "netioPort", "adminPort", "maxWorkers", "netioTimeout" }
      nValue := hConfig[ cKey ]
      IF ! HB_ISNUMERIC( nValue )
         cError := "Numero invalido: " + cKey
         RETURN .F.
      ENDIF
      IF nValue != Int( nValue ) .OR. nValue < iif( cKey == "protheusPort", 0, 1 ) .OR. ;
         ( Right( cKey, 4 ) == "Port" .AND. nValue > 65535 )
         cError := "Valor fora da faixa: " + cKey
         RETURN .F.
      ENDIF
   NEXT
   FOR EACH cKey IN { "protheusHost", "netioHost", "adminHost" }
      IF ! ValidIPv4( hConfig[ cKey ] )
         cError := "Endereco IPv4 invalido: " + cKey
         RETURN .F.
      ENDIF
   NEXT
   FOR EACH cKey IN { "netioPassword", "adminPassword" }
      IF ! HB_ISSTRING( hConfig[ cKey ] )
         cError := "Credencial invalida: " + cKey
         RETURN .F.
      ENDIF
      /* NETIO truncates passwords at 64 bytes; fail instead of silently altering. */
      IF Len( hConfig[ cKey ] ) > 64 .OR. Chr( 0 ) $ hConfig[ cKey ]
         cError := "Credencial deve ter ate 64 bytes e nao conter NUL: " + cKey
         RETURN .F.
      ENDIF
   NEXT
   FOR EACH cKey IN { "netioRoot", "addonRoot" }
      IF ! HB_ISSTRING( hConfig[ cKey ] ) .OR. Empty( hConfig[ cKey ] ) .OR. Chr( 0 ) $ hConfig[ cKey ]
         cError := "Diretorio invalido: " + cKey
         RETURN .F.
      ENDIF
   NEXT
   IF ! Empty( hConfig[ "adminPassword" ] )
      AAdd( aChannels, "admin" )
   ENDIF
   FOR nLeft := 1 TO Len( aChannels ) - 1
      FOR nRight := nLeft + 1 TO Len( aChannels )
         cLeft := aChannels[ nLeft ]
         cRight := aChannels[ nRight ]
         IF hConfig[ cLeft + "Port" ] == hConfig[ cRight + "Port" ] .AND. ;
            ( hConfig[ cLeft + "Host" ] == hConfig[ cRight + "Host" ] .OR. ;
              hConfig[ cLeft + "Host" ] == "0.0.0.0" .OR. hConfig[ cRight + "Host" ] == "0.0.0.0" )
            cError := "Conflito entre endpoints: " + cLeft + "/" + cRight
            RETURN .F.
         ENDIF
      NEXT
   NEXT

RETURN .T.

STATIC FUNCTION ValidIPv4( cAddress )
   LOCAL aParts, cPart
   IF ! HB_ISSTRING( cAddress )
      RETURN .F.
   ENDIF
   aParts := hb_ATokens( cAddress, "." )
   IF Len( aParts ) != 4
      RETURN .F.
   ENDIF
   FOR EACH cPart IN aParts
      IF Empty( cPart ) .OR. cPart != hb_ntos( Val( cPart ) ) .OR. Val( cPart ) < 0 .OR. Val( cPart ) > 255
         RETURN .F.
      ENDIF
   NEXT
RETURN .T.

FUNCTION HBBridgeAbsolutePath( cPath, cBase )
RETURN hb_PathNormalize( hb_PathJoin( hb_DirSepAdd( cBase ), hb_DirSepToOS( cPath ) ) )

FUNCTION HBBridgeConfigHelp()
RETURN "hbBridge [-config=arquivo.json] [-host=0.0.0.0] [-port=1512]" + hb_eol() + ;
   "  [-netiohost=0.0.0.0] [-netioport=2941] [-netioroot=data]" + hb_eol() + ;
   "  [-adminhost=127.0.0.1] [-adminport=2940] [-addonroot=addons]" + hb_eol() + ;
   "  [-maxworkers=64] [-netiotimeout=5000]" + hb_eol() + ;
   "Senhas netioPassword/adminPassword somente no JSON; admin desativada sem senha." + hb_eol() + ;
   "Precedencia: padroes < JSON < CLI. CTRL+Q encerra o console." + hb_eol()
