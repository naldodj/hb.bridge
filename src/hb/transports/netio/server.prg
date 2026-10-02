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

/* Own the thread handles around native NETIO APIs so Stop can join them.
 * netio_MTServer() detaches threads and does not offer this lifecycle contract.
 */
FUNCTION HBBridgeNetioStart( hConfig, hRegistry, hState, lAdmin )

   LOCAL cPrefix, cRoot, pListen, hServer, hContext, hFilter

   hb_default( @lAdmin, .F. )
   cPrefix := iif( lAdmin, "admin", "netio" )
   cRoot := iif( lAdmin, "*?:*?:", hConfig[ "netioRoot" ] )
   IF lAdmin .AND. Empty( hConfig[ "adminPassword" ] )
      RETURN NIL
   ENDIF
   pListen := netio_Listen( hConfig[ cPrefix + "Port" ], hConfig[ cPrefix + "Host" ], cRoot, .T. )
   IF Empty( pListen )
      RETURN NIL
   ENDIF
   hContext := HBBridgeContext( cPrefix, hConfig[ "addonRoot" ], hState, lAdmin )
   hFilter := { "HBBridge.Call" => {| cService, xParams, nVersion | ;
      HBBridgeDispatch( hRegistry, cService, xParams, hContext, nVersion ) } }
   IF lAdmin
      hFilter[ "HBBridge.Admin.Status" ] := {|| HBBridgeHostStatus( hState ) }
   ENDIF
   hServer := { "mutex" => hb_mutexCreate(), "stopMutex" => hb_mutexCreate(), ;
      "stopping" => .F., "active" => 0, "connections" => {}, ;
      "port" => hConfig[ cPrefix + "Port" ], "host" => hConfig[ cPrefix + "Host" ], ;
      "maxWorkers" => hConfig[ "maxWorkers" ], "timeout" => hConfig[ "netioTimeout" ], ;
      "listener" => NIL }
   hServer[ "listener" ] := hb_threadStart( 0, @NetioAcceptLoop(), hServer, pListen, ;
      hFilter, hConfig[ cPrefix + "Password" ] )
   IF Empty( hServer[ "listener" ] )
      netio_ServerStop( pListen )
      pListen := NIL
      hb_gcAll( .T. )
      RETURN NIL
   ENDIF

RETURN hServer

FUNCTION HBBridgeNetioStop( hServer )
RETURN hb_mutexEval( hServer[ "stopMutex" ], {|| NetioStopAndJoin( hServer ) } )

STATIC FUNCTION NetioStopAndJoin( hServer )
   LOCAL lStopped := .T.
   hb_mutexEval( hServer[ "mutex" ], {|| NetioSignalStop( hServer ) } )
   IF ! Empty( hServer[ "listener" ] )
      lStopped := hb_threadJoin( hServer[ "listener" ] )
      hServer[ "listener" ] := NIL
   ENDIF
   /* NETIO socket descriptors belong to GC handles, not hb_socketClose(). */
   hb_gcAll( .T. )
RETURN lStopped

STATIC PROCEDURE NetioSignalStop( hServer )
   LOCAL pConnection
   hServer[ "stopping" ] := .T.
   FOR EACH pConnection IN hServer[ "connections" ]
      netio_ServerStop( pConnection )
   NEXT
RETURN

STATIC PROCEDURE NetioAcceptLoop( hServer, pListen, hFilter, cPassword )

   LOCAL pConnection := NIL, hWorker, aWorkers := {}, nWorker, nError

   BEGIN SEQUENCE WITH {| oError | Break( oError ) }
      DO WHILE HBBridgeServerRunning( hServer )
         FOR nWorker := Len( aWorkers ) TO 1 STEP -1
            IF hb_threadWait( aWorkers[ nWorker ], 0 ) > 0
               hb_threadJoin( aWorkers[ nWorker ] )
               hb_ADel( aWorkers, nWorker, .T. )
            ENDIF
         NEXT
         pConnection := netio_Accept( pListen, 250, cPassword )
         IF Empty( pConnection )
            nError := hb_socketGetError()
            IF nError != HB_SOCKET_ERR_TIMEOUT .AND. nError != HB_SOCKET_ERR_AGAIN .AND. ;
               nError != HB_SOCKET_ERR_INTERRUPT
               EXIT
            ENDIF
            LOOP
         ENDIF
         netio_RPCFilter( pConnection, hFilter )
         netio_ServerTimeOut( pConnection, hServer[ "timeout" ] )
         IF hb_mutexEval( hServer[ "mutex" ], {|| NetioReserve( hServer, pConnection ) } )
            hWorker := hb_threadStart( 0, @NetioWorker(), hServer, pConnection )
            IF ! Empty( hWorker )
               AAdd( aWorkers, hWorker )
               pConnection := NIL
            ELSE
               hb_mutexEval( hServer[ "mutex" ], {|| NetioRelease( hServer, pConnection ) } )
            ENDIF
         ENDIF
         IF ! Empty( pConnection )
            netio_ServerStop( pConnection )
            pConnection := NIL
            hb_gcAll( .T. )
         ENDIF
      ENDDO
   RECOVER
      OutErr( "[NETIO] Falha no listener" + hb_eol() )
   ALWAYS
      hb_mutexEval( hServer[ "mutex" ], {|| NetioSignalStop( hServer ) } )
      netio_ServerStop( pListen )
      pListen := NIL
      IF ! Empty( pConnection )
         netio_ServerStop( pConnection )
         pConnection := NIL
      ENDIF
      FOR EACH hWorker IN aWorkers
         hb_threadJoin( hWorker )
      NEXT
   END SEQUENCE
RETURN

STATIC FUNCTION NetioReserve( hServer, pConnection )
   IF hServer[ "stopping" ] .OR. hServer[ "active" ] >= hServer[ "maxWorkers" ]
      RETURN .F.
   ENDIF
   hServer[ "active" ]++
   AAdd( hServer[ "connections" ], pConnection )
RETURN .T.

STATIC PROCEDURE NetioRelease( hServer, pConnection )
   LOCAL nIndex := AScan( hServer[ "connections" ], {| p | p == pConnection } )
   IF nIndex > 0
      hb_ADel( hServer[ "connections" ], nIndex, .T. )
      hServer[ "active" ]--
   ENDIF
RETURN

STATIC PROCEDURE NetioWorker( hServer, pConnection )
   BEGIN SEQUENCE WITH {| oError | Break( oError ) }
      netio_Server( pConnection )
   RECOVER
      OutErr( "[NETIO] Falha na conexao" + hb_eol() )
   ALWAYS
      netio_ServerStop( pConnection )
      hb_mutexEval( hServer[ "mutex" ], {|| NetioRelease( hServer, pConnection ) } )
   END SEQUENCE
RETURN
