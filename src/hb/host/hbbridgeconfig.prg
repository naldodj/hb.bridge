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

/* Precedence: defaults < INI/JSON file < CLI. No listeners/directory creation. */
#include "hbbridge.h"
FUNCTION hbbridgeconfig( aArgs, cError )

    LOCAL hConfig := {;
            "protheusHost" => "0.0.0.0";
            ,"protheusPort" => 1512;
            ,"protheusMaxPayloadBytes" => 0;
            ,"protheusMaxWireBytes" => 0;
            ,"protheusReadChunkBytes" => HBBRIDGE_IO_CHUNK_DEFAULT_BYTES;
            ,"protheusTimeoutMs" => HBBRIDGE_IO_TIMEOUT_DEFAULT_MS;
            ,"netioHost" => "0.0.0.0";
            ,"netioPort" => 2941;
            ,"netioRoot" => "data";
            ,"netioPassword" => "";
            ,"adminHost" => "127.0.0.1";
            ,"adminPort" => 2940;
            ,"adminPassword" => "";
            ,"addonRoot" => "addons";
            ,"maxWorkers" => 64;
            ,"netioTimeout" => 0;
            ,"sqlProfiles" => {=>};
        }
    LOCAL hOptions := {;
            "host" => "protheusHost";
            ,"port" => "protheusPort";
            ,"maxpayloadbytes" => "protheusMaxPayloadBytes";
            ,"maxwirebytes" => "protheusMaxWireBytes";
            ,"readchunkbytes" => "protheusReadChunkBytes";
            ,"iotimeout" => "protheusTimeoutMs";
            ,"netiohost" => "netioHost";
            ,"netioport" => "netioPort";
            ,"netioroot" => "netioRoot";
            ,"adminhost" => "adminHost";
            ,"adminport" => "adminPort";
            ,"addonroot" => "addonRoot";
            ,"maxworkers" => "maxWorkers";
            ,"netiotimeout" => "netioTimeout";
        }
    LOCAL cArg, cName, cValue, cKey, cFile := "", hFile, cContents, nRead, nEqual, xValue
    LOCAL lExplicitConfig := .F., cAutoFile

    cError := ""
    IF aArgs == NIL
        aArgs := {}
    ENDIF
    IF ! HB_ISARRAY( aArgs )
        cError := "Argumentos devem ser um array"
        RETURN NIL
    ENDIF
    FOR EACH cKey IN { "netioRoot", "addonRoot" }
        hConfig[ cKey ] := hbbridgeabsolutepath( hConfig[ cKey ], hb_cwd() )
    NEXT
    FOR EACH cArg IN aArgs
        IF ! HB_ISSTRING( cArg )
            cError := "Argumento deve ser texto"
            RETURN NIL
        ENDIF
        IF Chr( 0 ) $ cArg
            cError := "Argumento contem NUL"
            RETURN NIL
        ENDIF
        IF Left( cArg, 8 ) == "-config="
            IF lExplicitConfig .OR. Empty( SubStr( cArg, 9 ) )
                cError := "Informe um unico -config=<arquivo.ini|arquivo.json>"
                RETURN NIL
            ENDIF
            lExplicitConfig := .T.
            cFile := hbbridgeabsolutepath( SubStr( cArg, 9 ), hb_cwd() )
            IF Empty( cFile )
                cError := "Caminho de configuracao invalido"
                RETURN NIL
            ENDIF
        ENDIF
    NEXT
    IF ! lExplicitConfig
        cAutoFile := hb_FNameDir( hb_ProgName() ) + "hbbridge.ini"
        IF hb_FileExists( cAutoFile )
            cFile := hbbridgeabsolutepath( cAutoFile, hb_cwd() )
        ENDIF
    ENDIF
    IF ! Empty( cFile )
        IF ! hb_FileExists( cFile )
            cError := "Arquivo de configuracao nao encontrado"
            RETURN NIL
        ENDIF
        cContents := hb_MemoRead( cFile )
        IF hb_BLeft( cContents, 3 ) == Chr( 239 ) + Chr( 187 ) + Chr( 191 )
            cContents := hb_BSubStr( cContents, 4 )
        ENDIF
        IF Lower( hb_FNameExt( cFile ) ) == ".ini"
            hFile := hbbridgeconfigini( cContents, hConfig, @cError )
        ELSE
            nRead := hb_jsonDecode( cContents, @hFile )
            IF nRead == 0 .OR. ! HB_ISHASH( hFile ) .OR. ;
                ! Empty( AllTrim( SubStr( cContents, nRead + 1 ) ) )
                cError := "Configuracao JSON invalida"
                RETURN NIL
            ENDIF
        ENDIF
        IF hFile == NIL
            RETURN NIL
        ENDIF
        FOR EACH xValue IN hFile
            cKey := xValue:__enumKey()
            IF ! hb_HHasKey( hConfig, cKey )
                cError := "Chave desconhecida na configuracao: " + cKey
                RETURN NIL
            ENDIF
            IF ValType( xValue ) != ValType( hConfig[ cKey ] )
                cError := "Tipo invalido na configuracao: " + cKey
                RETURN NIL
            ENDIF
            hConfig[ cKey ] := xValue
            IF cKey == "netioRoot" .OR. cKey == "addonRoot"
                IF Empty( hConfig[ cKey ] ) .OR. Chr( 0 ) $ hConfig[ cKey ]
                    cError := "Diretorio vazio ou com NUL: " + cKey
                    RETURN NIL
                ENDIF
                hConfig[ cKey ] := hbbridgeabsolutepath( hConfig[ cKey ], hb_FNameDir( cFile ) )
            ENDIF
        NEXT
    ENDIF
    hConfig[ "sqlProfiles" ] := hbbridgesqlprofiles( hConfig[ "sqlProfiles" ], ;
        iif( Empty( cFile ), hb_cwd(), hb_FNameDir( cFile ) ), @cError )
    IF hConfig[ "sqlProfiles" ] == NIL
        RETURN NIL
    ENDIF
    FOR EACH cArg IN aArgs
        IF Left( cArg, 8 ) == "-config=" .OR. cArg == "--config-info"
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
            IF ! ( cValue == hb_ntos( Val( cValue ) ) )
                cError := "Numero invalido: " + cName
                RETURN NIL
            ENDIF
            hConfig[ cKey ] := Val( cValue )
        ELSEIF cKey == "netioRoot" .OR. cKey == "addonRoot"
            hConfig[ cKey ] := hbbridgeabsolutepath( cValue, hb_cwd() )
        ELSE
            hConfig[ cKey ] := cValue
        ENDIF
    NEXT
    IF ! hbbridgeconfigvalid( hConfig, @cError )
        RETURN NIL
    ENDIF

RETURN hConfig

/* Machine-readable launcher metadata, without credentials or storage paths. */
FUNCTION hbbridgeconfiginfo( hConfig )
    LOCAL hProfiles := {=>}, hProfile
    FOR EACH hProfile IN hConfig[ "sqlProfiles" ]
        hProfiles[ hProfile:__enumKey() ] := { "driver" => hProfile[ "driver" ] }
    NEXT
RETURN { "configVersion" => 1, "protheusHost" => hConfig[ "protheusHost" ], ;
    "protheusPort" => hConfig[ "protheusPort" ], "maxWorkers" => hConfig[ "maxWorkers" ], ;
    "sqlProfiles" => hProfiles }

FUNCTION hbbridgeconfigvalid( hConfig, cError )

    LOCAL cKey, nValue, aChannels := { "protheus", "netio" }, nLeft, nRight, cLeft, cRight
    LOCAL hRuntimeLimits

    cError := ""
    IF ! HB_ISHASH( hConfig )
        cError := "Configuracao deve ser um hash"
        RETURN .F.
    ENDIF
    FOR EACH cKey IN {;
        "protheusHost";
        ,"protheusPort";
        ,"protheusMaxPayloadBytes";
        ,"protheusMaxWireBytes";
        ,"protheusReadChunkBytes";
        ,"protheusTimeoutMs";
        ,"netioHost";
        ,"netioPort";
        ,"netioRoot";
        ,"netioPassword";
        ,"adminHost";
        ,"adminPort";
        ,"adminPassword";
        ,"addonRoot";
        ,"maxWorkers";
        ,"netioTimeout";
        ,"sqlProfiles" }
        IF ! hb_HHasKey( hConfig, cKey )
            cError := "Chave ausente: " + cKey
            RETURN .F.
        ENDIF
    NEXT
    IF hbbridgesqlprofiles( hConfig[ "sqlProfiles" ], hb_cwd(), @cError ) == NIL
        RETURN .F.
    ENDIF
    hRuntimeLimits := hbbridgeruntimelimits()
    FOR EACH cKey IN { "protheusMaxPayloadBytes", "protheusMaxWireBytes", "protheusTimeoutMs" }
        nValue := hConfig[ cKey ]
        IF ! HB_ISNUMERIC( nValue )
            cError := "Numero invalido: " + cKey
            RETURN .F.
        ENDIF
        IF ! HBBridgeIntegerValid( nValue, hRuntimeLimits[ "stringBytesMax" ] )
            cError := "Valor fora da faixa do runtime: " + cKey
            RETURN .F.
        ENDIF
    NEXT
    nValue := hConfig[ "protheusReadChunkBytes" ]
    IF ! HB_ISNUMERIC( nValue )
        cError := "Numero invalido: protheusReadChunkBytes"
        RETURN .F.
    ENDIF
    IF ! HBBridgeIntegerValid( nValue, Min( hRuntimeLimits[ "socketChunkBytesMax" ], ;
        hRuntimeLimits[ "zlibChunkBytesMax" ] ) ) .OR. nValue == 0
        cError := "Valor fora da faixa do runtime: protheusReadChunkBytes"
        RETURN .F.
    ENDIF
    FOR EACH cKey IN {;
        "protheusPort";
        ,"netioPort";
        ,"adminPort";
        ,"maxWorkers";
        ,"netioTimeout" }
        nValue := hConfig[ cKey ]
        IF ! HB_ISNUMERIC( nValue )
            cError := "Numero invalido: " + cKey
            RETURN .F.
        ENDIF
        IF nValue != Int( nValue ) .OR. nValue < iif( cKey == "protheusPort" .OR. cKey == "netioTimeout", 0, 1 ) .OR. ;
            ( Right( cKey, 4 ) == "Port" .AND. nValue > 65535 ) .OR. ;
            ( cKey == "netioTimeout" .AND. nValue > hRuntimeLimits[ "netioTimeoutMsMax" ] )
            cError := "Valor fora da faixa: " + cKey
            RETURN .F.
        ENDIF
    NEXT
    FOR EACH cKey IN { "protheusHost", "netioHost", "adminHost" }
        IF ! validipv4( hConfig[ cKey ] )
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

STATIC FUNCTION validipv4( cAddress )
    LOCAL aParts, cPart
    IF ! HB_ISSTRING( cAddress )
        RETURN .F.
    ENDIF
    aParts := hb_ATokens( cAddress, "." )
    IF Len( aParts ) != 4
        RETURN .F.
    ENDIF
    FOR EACH cPart IN aParts
        IF Empty( cPart ) .OR. ! ( cPart == hb_ntos( Val( cPart ) ) ) .OR. Val( cPart ) < 0 .OR. Val( cPart ) > 255
            RETURN .F.
        ENDIF
    NEXT
RETURN .T.

FUNCTION hbbridgeabsolutepath( cPath, cBase )
    LOCAL nDriveEnd, cBaseDrive
    IF ! HB_ISSTRING( cPath ) .OR. Chr( 0 ) $ cPath
        RETURN ""
    ENDIF
    cPath := hb_DirSepToOS( cPath )
    IF ! Empty( hb_osDriveSeparator() )
        nDriveEnd := At( hb_osDriveSeparator(), cPath )
        IF nDriveEnd > 0 .AND. SubStr( cPath, nDriveEnd + 1, 1 ) != hb_ps()
            /* Drive-relative paths depend on hidden per-drive working directories. */
            RETURN ""
        ENDIF
        IF nDriveEnd == 0 .AND. Left( cPath, 1 ) == hb_ps() .AND. Left( cPath, 2 ) != hb_ps() + hb_ps()
            cBaseDrive := Left( cBase, At( hb_osDriveSeparator(), cBase ) )
            IF Empty( cBaseDrive )
                RETURN ""
            ENDIF
            cPath := cBaseDrive + cPath
        ENDIF
    ENDIF
RETURN hb_PathNormalize( hb_PathJoin( hb_DirSepAdd( cBase ), cPath ) )

FUNCTION hbbridgeconfighelp()
    local cConfigHelp
    #pragma __cstream | cConfigHelp:=%s
hbBridge [-config=arquivo.ini|arquivo.json] [-host=0.0.0.0] [-port=1512]
[-netiohost=0.0.0.0] [-netioport=2941] [-netioroot=data]
[-adminhost=127.0.0.1] [-adminport=2940] [-addonroot=addons]
[-maxworkers=64] [-netiotimeout=0]
[-maxpayloadbytes=0] [-maxwirebytes=0] [-readchunkbytes=65536] [-iotimeout=30000]
Payload/wire: 0 sem teto de aplicacao; valores positivos limitam bytes por mensagem.
Readchunkbytes dimensiona o buffer de leitura, sem limitar o tamanho da mensagem.
Iotimeout em ms por transferencia; 0 sem prazo total. Faixas respeitam o runtime.
Netiotimeout: 0 usa espera nativa sem prazo; valores positivos em ms.
Senhas NETIO/admin somente no arquivo; admin desativada sem senha.
Perfis SQL no INI/JSON habilitam RPCRDD.Query com SQLite ou MSSQL via ODBC.
Sem -config, procura hbbridge.ini ao lado do executavel.
--config-info valida e mostra metadados JSON sem credenciais, sem iniciar listeners.
Precedencia: padroes < arquivo INI/JSON < CLI. CTRL+Q encerra o console.
#pragma __endtext
RETURN cConfigHelp
