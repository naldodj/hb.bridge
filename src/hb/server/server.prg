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
#include "hbsocket.ch"

#define HBBRIDGE_LEGACY_SIGNATURE   "HBS1"
#define HBBRIDGE_PROTOCOL_SIGNATURE "HBBRIDGE/1"

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

FUNCTION ReceiveRequest( hSocket, cPayload as character, lFramed as logical, cFrameSignature as character )

   LOCAL cChr10 as character:=hb_BChar( 10 )
   LOCAL cBuffer as character := "", cChunk as character := Space( 65535 ), nBytesRead as numeric, nHeaderEnd as numeric
   LOCAL cHeader as character, aHeader as array, nPayloadSize as numeric, nPayloadStart as numeric

   lFramed := .F.
   cFrameSignature := HBBRIDGE_PROTOCOL_SIGNATURE
   nBytesRead := hb_socketRecv( hSocket, @cChunk, 65535, 0, 5000 )
   IF nBytesRead <= 0
      RETURN .F.
   ENDIF
   cChunk := hb_ZUncompress( hb_BLeft( cChunk, nBytesRead ) )
   IF ! HB_ISSTRING( cChunk )
      RETURN .F.
   ENDIF
   nBytesRead := hb_BLen( cChunk )
   cBuffer := hb_BLeft( cChunk, nBytesRead )

   IF hb_BLeft( cBuffer, hb_BLen( HBBRIDGE_PROTOCOL_SIGNATURE ) + 1 ) == HBBRIDGE_PROTOCOL_SIGNATURE + "|"
      cFrameSignature := HBBRIDGE_PROTOCOL_SIGNATURE
   ELSEIF hb_BLeft( cBuffer, hb_BLen( HBBRIDGE_LEGACY_SIGNATURE ) + 1 ) == HBBRIDGE_LEGACY_SIGNATURE + "|"
      cFrameSignature := HBBRIDGE_LEGACY_SIGNATURE
   ELSE
      cPayload := cBuffer
      RETURN .T.
   ENDIF

   lFramed := .T.
   nHeaderEnd := hb_BAt( cChr10, cBuffer )
   DO WHILE nHeaderEnd == 0
      nBytesRead := hb_socketRecv( hSocket, @cChunk, 65535, 0, 5000 )
      IF nBytesRead <= 0
         RETURN .F.
      ENDIF
      cChunk := hb_ZUncompress( hb_BLeft( cChunk, nBytesRead ) )
      IF ! HB_ISSTRING( cChunk )
         RETURN .F.
      ENDIF
      nBytesRead := hb_BLen( cChunk )
      cBuffer += hb_BLeft( cChunk, nBytesRead )
      nHeaderEnd := hb_BAt( cChr10, cBuffer )
      IF hb_BLen( cBuffer ) > 128
         RETURN .F.
      ENDIF
   ENDDO

   cHeader := hb_BLeft( cBuffer, nHeaderEnd - 1 )
   aHeader := hb_ATokens( cHeader, "|" )
   IF Len( aHeader ) != 3 .OR. aHeader[ 1 ] != cFrameSignature .OR. aHeader[ 2 ] != "JSON"
      RETURN .F.
   ENDIF

   nPayloadSize := Val( aHeader[ 3 ] )
   IF nPayloadSize <= 0 .OR. nPayloadSize > 16777216
      RETURN .F.
   ENDIF

   nPayloadStart := nHeaderEnd + 1
   DO WHILE hb_BLen( cBuffer ) - nPayloadStart + 1 < nPayloadSize
      nBytesRead := hb_socketRecv( hSocket, @cChunk, 65535, 0, 5000 )
      IF nBytesRead <= 0
         RETURN .F.
      ENDIF
      cChunk := hb_ZUncompress( hb_BLeft( cChunk, nBytesRead ) )
      IF ! HB_ISSTRING( cChunk )
         RETURN .F.
      ENDIF
      nBytesRead := hb_BLen( cChunk )
      cBuffer += hb_BLeft( cChunk, nBytesRead )
   ENDDO

   cPayload := hb_BSubStr( cBuffer, nPayloadStart, nPayloadSize )

RETURN .T.

FUNCTION SendResponse( hSocket, cPayload as character, lFramed as logical, cFrameSignature as character )

   LOCAL cResponse as character := cPayload
   LOCAL nResponse as numeric, nSent as numeric := 0, nBytes as numeric

   IF ! HB_ISSTRING( cPayload )
      RETURN .F.
   ENDIF

   IF lFramed
      hb_default( @cFrameSignature, HBBRIDGE_PROTOCOL_SIGNATURE )
      cResponse := cFrameSignature + "|JSON|" + hb_ntos( hb_BLen( cPayload ) ) + hb_BChar( 10 ) + cPayload
   ENDIF

   cResponse := hb_gzCompress( cResponse, NIL, @nResponse )
   IF nResponse != 0 .OR. ! HB_ISSTRING( cResponse )
      RETURN .F.
   ENDIF
   DO WHILE nSent < hb_BLen( cResponse )
      nBytes := hb_socketSend( hSocket, hb_BSubStr( cResponse, nSent + 1 ), NIL, 0, 5000 )
      IF nBytes <= 0
         RETURN .F.
      ENDIF
      nSent += nBytes
   ENDDO

RETURN .T.
