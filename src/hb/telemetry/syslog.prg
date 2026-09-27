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
#include "hbsocket.ch"

thread STATIC s_hSyslogSocket := NIL
thread STATIC s_cSyslogHost := "127.0.0.1"
thread STATIC s_nSyslogPort := 514
thread STATIC s_hSyslogMutex := hb_mutexCreate()

FUNCTION SyslogOpen( cHost, nPort , nHBBridgePort )
   LOCAL hSocket, lResult := .F.

   IF hb_mutexLock( s_hSyslogMutex )
      BEGIN SEQUENCE
         hSocket := hb_socketOpen( NIL, HB_SOCKET_PT_DGRAM )
         IF ! Empty( hSocket )
            IF ! Empty( s_hSyslogSocket )
               hb_socketClose( s_hSyslogSocket )
            ENDIF
            s_cSyslogHost := iif( Empty( cHost ), s_cSyslogHost, cHost )
            s_nSyslogPort := iif( Empty( nPort ), s_nSyslogPort, nPort )
            s_hSyslogSocket := hSocket
            SyslogSendLocked( "hbBridge iniciado na porta "+hb_NTOS(nHBBridgePort), 6 )
            lResult := .T.
         ENDIF
      ALWAYS
         hb_mutexUnlock( s_hSyslogMutex )
      END SEQUENCE
   ENDIF
RETURN lResult

FUNCTION SyslogWrite( cMessage, nSeverity )
   LOCAL lResult := .F.

   IF hb_mutexLock( s_hSyslogMutex )
      BEGIN SEQUENCE
         lResult := SyslogSendLocked( cMessage, nSeverity )
      ALWAYS
         hb_mutexUnlock( s_hSyslogMutex )
      END SEQUENCE
   ENDIF
RETURN lResult

// Called only while holding s_hSyslogMutex, including the opening message.
STATIC FUNCTION SyslogSendLocked( cMessage, nSeverity )
   LOCAL cPacket, aAddress

   IF Empty( s_hSyslogSocket )
      RETURN .F.
   ENDIF

   nSeverity := iif( nSeverity == NIL, 6, nSeverity )
   cPacket := "<" + hb_ntos( 16 * 8 + nSeverity ) + ">hbBridge: " + cMessage
   aAddress := { HB_SOCKET_AF_INET, s_cSyslogHost, s_nSyslogPort }
   RETURN hb_socketSendTo( s_hSyslogSocket, cPacket, NIL, NIL, aAddress ) >= 0

FUNCTION SyslogClose()
   LOCAL lResult := .T.

   IF hb_mutexLock( s_hSyslogMutex )
      BEGIN SEQUENCE
         IF ! Empty( s_hSyslogSocket )
            lResult := hb_socketClose( s_hSyslogSocket ) == 0
            s_hSyslogSocket := NIL
         ENDIF
      ALWAYS
         hb_mutexUnlock( s_hSyslogMutex )
      END SEQUENCE
   ELSE
      lResult := .F.
   ENDIF
RETURN lResult
