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
#include "inkey.ch"
#include "hbinkey.ch"

PROCEDURE Main( ... )

   LOCAL hServer, cParam, cValue, nValue
   LOCAL nKey,nPort := 1512, nMaxWorkers := 64

   IF ! hb_mtvm()
      OutErr( "hbBridge requer Harbour multithread. Compile com -mt." + hb_eol() )
      ErrorLevel( 1 )
      RETURN
   ENDIF

   FOR EACH cParam IN hb_AParams()
      IF cParam == "--help" .OR. cParam == "-h"
         OutStd( "hbBridge [-port=1512] [-maxworkers=64] (<CTRL+Q> para encerrar)" + hb_eol() )
         RETURN
      ENDIF
      IF Left( cParam, 6 ) == "-port="
         cValue := SubStr( cParam, 7 )
      ELSEIF Left( cParam, 12 ) == "-maxworkers="
         cValue := SubStr( cParam, 13 )
      ELSE
         OutErr( "Opcao desconhecida: " + cParam + hb_eol() )
         ErrorLevel( 1 )
         RETURN
      ENDIF
      nValue := Val( cValue )
      IF cValue != hb_ntos( nValue ) .OR. nValue != Int( nValue )
         OutErr( "Valor invalido: " + cParam + hb_eol() )
         ErrorLevel( 1 )
         RETURN
      ENDIF
      IF Left( cParam, 6 ) == "-port="
         nPort := nValue
      ELSE
         nMaxWorkers := nValue
      ENDIF
   NEXT

   hServer := HBBridgeServerStart( nPort, nMaxWorkers )
   IF Empty( hServer )
      OutErr( "Nao foi possivel iniciar hbBridge. Verifique porta e limite de workers." + hb_eol() )
      ErrorLevel( 1 )
      RETURN
   ENDIF
   OutStd( ">>> HBBRIDGE MT OPERACIONAL [" + hb_ntos( hServer[ "port" ] ) + ;
      "] workers=" + hb_ntos( nMaxWorkers ) + " (<CTRL+Q> para encerrar) <<<" + hb_eol() )
   BEGIN SEQUENCE WITH {| oError | Break( oError ) }
      DO WHILE HBBridgeServerRunning( hServer )
         nKey:=Inkey(0.1,hb_bitOr(INKEY_ALL,HB_INKEY_GTEVENT))
         IF (nKey==HB_K_CTRL_Q)
            EXIT
         ENDIF
      ENDDO
      IF ! HBBridgeServerRunning( hServer )
         ErrorLevel( 1 )
      ENDIF
   RECOVER
      ErrorLevel( 1 )
   ALWAYS
      HBBridgeServerStop( hServer )
   END SEQUENCE
RETURN
