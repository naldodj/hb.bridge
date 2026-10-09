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

/* Native service contract. Transport codecs belong to their adapters. */
#ifdef HB_EXTERN
REQUEST __HB_EXTERN__
#endif

#include "error.ch"

FUNCTION HBBridgeRegistry()
RETURN { "services" => {=>}, "sealed" => .F. }

FUNCTION HBBridgeRegister( hRegistry, hSpec, bHandler )

    LOCAL cKey, cField, hEntry

    IF hRegistry[ "sealed" ] .OR. ! HB_ISHASH( hSpec ) .OR. ! HB_ISBLOCK( bHandler )
        RETURN .F.
    ENDIF
    FOR EACH cField IN { "name", "version", "params", "result", "permission", "dependencies", "modes" }
        IF ! hb_HHasKey( hSpec, cField )
            RETURN .F.
        ENDIF
    NEXT
    IF ! HB_ISSTRING( hSpec[ "name" ] ) .OR. Empty( hSpec[ "name" ] ) .OR. ;
        ! HB_ISNUMERIC( hSpec[ "version" ] )
        RETURN .F.
    ENDIF
    IF hSpec[ "version" ] < 1 .OR. hSpec[ "version" ] != Int( hSpec[ "version" ] ) .OR. ;
        ! HB_ISSTRING( hSpec[ "params" ] ) .OR. ! HB_ISSTRING( hSpec[ "result" ] ) .OR. ;
        ! HB_ISSTRING( hSpec[ "permission" ] ) .OR. ;
        ! HB_ISARRAY( hSpec[ "dependencies" ] ) .OR. ! HB_ISARRAY( hSpec[ "modes" ] )
        RETURN .F.
    ENDIF
    cKey := hSpec[ "name" ] + "/" + hb_ntos( hSpec[ "version" ] )
    IF hb_HHasKey( hRegistry[ "services" ], cKey )
        RETURN .F.
    ENDIF
    hEntry := { "spec" => hb_HClone( hSpec ), "handler" => bHandler }
    hRegistry[ "services" ][ cKey ] := hEntry

RETURN .T.

FUNCTION HBBridgeRegistrySeal( hRegistry )
    hRegistry[ "sealed" ] := .T.
RETURN hRegistry

FUNCTION HBBridgeContext( cTransport, cAddonRoot, hState, lAdmin )

    hb_default( @cTransport, "local" )
    hb_default( @cAddonRoot, hb_cwd() + "addons" )
    hb_default( @lAdmin, .F. )

RETURN { "transport" => cTransport, "addonRoot" => cAddonRoot, "state" => hState, ;
    "permissions" => iif( lAdmin, { "admin.read", "capabilities.read" }, ;
        { "service.call", "addon.execute", "core.call", "capabilities.read" } ) }

FUNCTION HBBridgeDispatch( hRegistry, cService, xParams, hContext, nVersion )

    LOCAL cKey, hEntry, hCall, xResult, cType,oError

    IF nVersion == NIL
        nVersion := 1
    ENDIF
    IF ! HB_ISSTRING( cService ) .OR. Empty( cService )
        RETURN HBBridgeError( "INVALID_SERVICE", "Invalid service" )
    ENDIF
    IF ! HB_ISNUMERIC( nVersion )
        RETURN HBBridgeError( "INVALID_VERSION", "Invalid version" )
    ENDIF
    IF nVersion < 1 .OR. nVersion != Int( nVersion )
        RETURN HBBridgeError( "INVALID_VERSION", "Invalid version" )
    ENDIF
    cKey := cService + "/" + hb_ntos( nVersion )
    IF ! hb_HHasKey( hRegistry[ "services" ], cKey )
        RETURN HBBridgeError( "SERVICE_NOT_FOUND", "Unsupported service" )
    ENDIF
    hEntry := hRegistry[ "services" ][ cKey ]
    IF ! HBBridgePermitted( hEntry[ "spec" ], hContext )
        RETURN HBBridgeError( "FORBIDDEN", "Service is not authorized on this channel" )
    ENDIF
    cType := hEntry[ "spec" ][ "params" ]
    IF ! HBBridgeValueAllowed( xParams ) .OR. ;
        ( cType != "any" .AND. cType != ValType( xParams ) )
        RETURN HBBridgeError( "INVALID_PARAMS", "Unsupported parameter type" )
    ENDIF
    /* Arguments and context belong to this call; no shared mutable executor. */
    hCall := { "transport" => hContext[ "transport" ], "addonRoot" => hContext[ "addonRoot" ], ;
        "state" => hContext[ "state" ], "permissions" => AClone( hContext[ "permissions" ] ), ;
        "registry" => hRegistry, "service" => cService, "version" => nVersion }
    BEGIN SEQUENCE WITH __BreakBlock()
        xResult := Eval( hEntry[ "handler" ], xParams, hCall )
        cType := hEntry[ "spec" ][ "result" ]
        IF ! HBBridgeValueAllowed( xResult ) .OR. ;
            ( cType != "any" .AND. cType != ValType( xResult ) )
            xResult := HBBridgeError( "INVALID_RESULT", "Unsupported result type" )
        ENDIF
    RECOVER USING oError
        xResult := HBBridgeError( "SERVICE_ERROR", "Service execution failed" , oError )
    END SEQUENCE

RETURN xResult

FUNCTION HBBridgeError( cCode, cError , oError )
    LOCAL cMessage:=HBBridgeErrorMessage( oError )
RETURN { "success" => .F., "error" => cError, "code" => cCode , "message" => cMessage }

FUNCTION HBBridgeErrorMessage( oError )
    LOCAL cMessage

    if (ValType(oError)=="O")

        /* start error message */
        cMessage := iif( oError:severity > ES_WARNING, "Error", "Warning" ) + " "

        /* add subsystem name if available */
        cMessage += iif( HB_ISSTRING( oError:subsystem ), oError:subsystem(), "???" )

        /* add subsystem's error code if available */
        cMessage += "/" + iif( HB_ISNUMERIC( oError:subCode ), hb_ntos( oError:subCode ), "???" )

        /* add error description if available */
        IF HB_ISSTRING( oError:description )
            cMessage += "  " + oError:description
        ENDIF

        /* add either filename or operation */
        DO CASE
        CASE ! Empty( oError:filename )
            cMessage += ": " + oError:filename
        CASE ! Empty( oError:operation )
            cMessage += ": " + oError:operation
        ENDCASE

    else

        cMessage:=""

    endif

RETURN cMessage

FUNCTION HBBridgeCatalog( hRegistry, hContext )

    LOCAL aServices := {}, hEntry

    FOR EACH hEntry IN hRegistry[ "services" ]
        IF HBBridgePermitted( hEntry[ "spec" ], hContext )
            AAdd( aServices, hb_HClone( hEntry[ "spec" ] ) )
        ENDIF
    NEXT

RETURN aServices

STATIC FUNCTION HBBridgePermitted( hSpec, hContext )
RETURN AScan( hContext[ "permissions" ], {| cPermission | cPermission == hSpec[ "permission" ] } ) > 0

/* Portable native values, with string hash keys. Reject live resources and
 * cyclic containers. Native strings are bytes; dates/timestamps stay native.
 */
FUNCTION HBBridgeValueAllowed( xValue, aParents )

    LOCAL cType := ValType( xValue ), xChild, cKey

    hb_default( @aParents, {} )
    IF cType $ "UCLNDT"
        RETURN .T.
    ENDIF
    IF cType != "A" .AND. cType != "H"
        RETURN .F.
    ENDIF
    IF AScan( aParents, {| xParent | ValType( xParent ) == cType .AND. xParent == xValue } ) > 0
        RETURN .F.
    ENDIF
    AAdd( aParents, xValue )
    IF cType == "H"
        FOR EACH cKey IN hb_HKeys( xValue )
            IF ! HB_ISSTRING( cKey )
                RETURN .F.
            ENDIF
        NEXT
    ENDIF
    FOR EACH xChild IN xValue
        IF ! HBBridgeValueAllowed( xChild, aParents )
            RETURN .F.
        ENDIF
    NEXT
    ASize( aParents, Len( aParents ) - 1 )

RETURN .T.
