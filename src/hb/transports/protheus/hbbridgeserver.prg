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

/* The listener owns its socket and thread handles. Each worker owns one
 * client socket and a fresh VM context (no inherited PUBLIC/PRIVATE vars).
 * Only lifecycle flags and counters are shared, always under the mutex.
 */
FUNCTION hbbridgeserverstart( nPort, nMaxWorkers, cHost, hRegistry, hContext, hIOConfig )

    LOCAL hListenSocket, hServer, aAddress, hPolicy := hbbridgeprotheuspolicy( hIOConfig )

    hb_default( @nPort, 1512 )
    hb_default( @nMaxWorkers, 64 )
    hb_default( @cHost, "0.0.0.0" )
    IF hRegistry == NIL
        hRegistry := hbbridgebuiltinregistry()
    ENDIF
    IF hContext == NIL
        hContext := hbbridgecontext( "protheus" )
    ENDIF
    IF ! hb_mtvm() .OR. hPolicy == NIL
        RETURN NIL
    ENDIF
    IF ! HB_ISNUMERIC( nPort ) .OR. ! HB_ISNUMERIC( nMaxWorkers )
        RETURN NIL
    ENDIF
    IF nPort < 0 .OR. nPort > 65535 .OR. nPort != Int( nPort ) .OR. ;
        nMaxWorkers < 1 .OR. nMaxWorkers != Int( nMaxWorkers )
        RETURN NIL
    ENDIF

    hListenSocket := hb_socketOpen( HB_SOCKET_AF_INET, HB_SOCKET_PT_STREAM, HB_SOCKET_IPPROTO_IP )
    IF Empty( hListenSocket )
        RETURN NIL
    ENDIF
    hb_socketSetReuseAddr( hListenSocket, .T. )
    IF ! hb_socketBind( hListenSocket, { HB_SOCKET_AF_INET, cHost, nPort } ) .OR. ;
        ! hb_socketListen( hListenSocket, 128 )
        hb_socketClose( hListenSocket )
        RETURN NIL
    ENDIF

    aAddress := hb_socketGetSockName( hListenSocket )
    hServer := { "mutex" => hb_mutexCreate(), "stopMutex" => hb_mutexCreate(), ;
        "logMutex" => hb_mutexCreate(), "stopping" => .F., "active" => 0, ;
        "port" => aAddress[ HB_SOCKET_ADINFO_PORT ], "maxWorkers" => nMaxWorkers, ;
        "listener" => NIL, "host" => cHost, "registry" => hRegistry, "context" => hContext, ;
        "ioPolicy" => hPolicy }
    hServer[ "listener" ] := hb_threadStart( 0, @hbbridgeacceptloop(), hServer, hListenSocket )
    IF Empty( hServer[ "listener" ] )
        hb_socketClose( hListenSocket )
        RETURN NIL
    ENDIF

RETURN hServer

FUNCTION hbbridgeserverrunning( hServer )
RETURN hb_mutexEval( hServer[ "mutex" ], {|| ! hServer[ "stopping" ] } )

FUNCTION hbbridgeserveractive( hServer )
RETURN hb_mutexEval( hServer[ "mutex" ], {|| hServer[ "active" ] } )

/* Call from the owner/controller, never from a request worker: the listener
 * joins all admitted workers before Stop returns. Concurrent stops serialize.
 */
FUNCTION hbbridgeserverstop( hServer )
RETURN hb_mutexEval( hServer[ "stopMutex" ], {|| hbbridgestopandjoin( hServer ) } )

STATIC FUNCTION hbbridgestopandjoin( hServer )

    LOCAL lStopped := .T.

    hb_mutexEval( hServer[ "mutex" ], {|| hServer[ "stopping" ] := .T. } )
    IF ! Empty( hServer[ "listener" ] )
        lStopped := hb_threadJoin( hServer[ "listener" ] )
        hServer[ "listener" ] := NIL
    ENDIF

RETURN lStopped

STATIC PROCEDURE hbbridgeacceptloop( hServer, hListenSocket )

    LOCAL hClientSocket := NIL, hWorker, aWorkers := {}, nWorker, nError

    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        DO WHILE hbbridgeserverrunning( hServer )
            /* Reap finished threads while serving, so handles do not accumulate. */
            FOR nWorker := Len( aWorkers ) TO 1 STEP -1
                IF hb_threadWait( aWorkers[ nWorker ], 0 ) > 0
                    hb_threadJoin( aWorkers[ nWorker ] )
                    hb_ADel( aWorkers, nWorker, .T. )
                ENDIF
            NEXT

            hClientSocket := hb_socketAccept( hListenSocket, NIL, 250 )
            IF Empty( hClientSocket )
                nError := hb_socketGetError()
                IF nError != HB_SOCKET_ERR_TIMEOUT .AND. nError != HB_SOCKET_ERR_AGAIN .AND. ;
                    nError != HB_SOCKET_ERR_INTERRUPT
                    hbbridgeserverlog( hServer, "Falha no accept: " + hb_ntos( nError ) )
                    EXIT
                ENDIF
                LOOP
            ENDIF

            IF hb_mutexEval( hServer[ "mutex" ], {|| hbbridgereserveworker( hServer ) } )
                /* Pass values as arguments; never capture the changing accept variable. */
                hWorker := hb_threadStart( 0, @hbbridgeclientworker(), hServer, hClientSocket )
                IF ! Empty( hWorker )
                    AAdd( aWorkers, hWorker )
                    hClientSocket := NIL  /* Ownership transferred to the worker. */
                ELSE
                    hb_mutexEval( hServer[ "mutex" ], {|| hServer[ "active" ]-- } )
                    hbbridgeserverlog( hServer, "Nao foi possivel iniciar a thread da conexao" )
                ENDIF
            ENDIF
            IF ! Empty( hClientSocket )
                /* At capacity (or stopping), reject before reading any request. */
                hb_socketClose( hClientSocket )
                hClientSocket := NIL
            ENDIF
        ENDDO
    RECOVER
        hbbridgeserverlog( hServer, "Falha no listener; encerrando servidor" )
    ALWAYS
        hb_mutexEval( hServer[ "mutex" ], {|| hServer[ "stopping" ] := .T. } )
        hb_socketClose( hListenSocket )
        IF ! Empty( hClientSocket )
            hb_socketClose( hClientSocket )
        ENDIF
        FOR EACH hWorker IN aWorkers
            hb_threadJoin( hWorker )
        NEXT
    END SEQUENCE

RETURN

/* Called only while holding the lifecycle mutex. */
STATIC FUNCTION hbbridgereserveworker( hServer )

    IF hServer[ "stopping" ] .OR. hServer[ "active" ] >= hServer[ "maxWorkers" ]
        RETURN .F.
    ENDIF
    hServer[ "active" ]++

RETURN .T.

STATIC PROCEDURE hbbridgeclientworker( hServer, hClientSocket )

    LOCAL cRequest, cResponse

    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        IF receiverequest( hClientSocket, @cRequest, hServer[ "ioPolicy" ] )
            /* An application error becomes a reply on this connection only. */
            BEGIN SEQUENCE WITH {| oError | Break( oError ) }
                cResponse := dispatcherrequest( cRequest, hServer[ "registry" ], hServer[ "context" ] )
            RECOVER
                cResponse := '{"success": false, "error": "Falha ao executar servico"}'
                hbbridgeserverlog( hServer, "Erro no servico da thread " + hb_ntos( hb_threadID() ) )
            END SEQUENCE
            IF ! sendresponse( hClientSocket, cResponse, hServer[ "ioPolicy" ] )
                hbbridgeserverlog( hServer, "Falha ao enviar resposta" )
            ENDIF
        ELSE
            hbbridgeserverlog( hServer, "Requisicao invalida ou incompleta" )
        ENDIF
    RECOVER
        hbbridgeserverlog( hServer, "Falha na conexao da thread " + hb_ntos( hb_threadID() ) )
    ALWAYS
        hb_socketClose( hClientSocket )
        hb_mutexEval( hServer[ "mutex" ], {|| hServer[ "active" ]-- } )
    END SEQUENCE

RETURN

STATIC PROCEDURE hbbridgeserverlog( hServer, cMessage )

    hb_mutexEval( hServer[ "logMutex" ], {|| OutStd( "[RPC] " + cMessage + hb_eol() ) } )

RETURN
