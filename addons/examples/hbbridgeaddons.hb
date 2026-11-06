/* Released to Public Domain. One HRB for the bundled, explicitly selected examples. */
FUNCTION Main( cJSON, hContext )

    LOCAL cAction, cParams

    LOCAL hActions, hEnvelope

    IF ! HB_ISSTRING( cJSON ) .OR. ! HBBridgeJSONComplete( cJSON, HBBridgeJSONDecode( cJSON, @hEnvelope ) ) .OR. ;
        ! HB_ISHASH( hEnvelope ) .OR. Len( hEnvelope ) != 2 .OR. ;
        ! hb_HHasKey( hEnvelope, "action" ) .OR. ! hb_HHasKey( hEnvelope, "params" ) .OR. ;
        ! HB_ISSTRING( hEnvelope[ "action" ] ) .OR. ! HB_ISHASH( hEnvelope[ "params" ] )
        RETURN HBBridgeJSONEncode( HBBridgeError( "INVALID_PARAMS", "An example action and parameter object are required." ) )
    ENDIF
    cAction := hEnvelope[ "action" ]
    /* Symbols are local to this HRB; the caller never supplies a function name. */
    hActions := { "sample" => @HBBridgeExampleSample(), ;
        "benchmark" => @HBBridgeExampleBenchmark(), ;
        "temporaryInsert" => @HBBridgeExampleTemporaryInsert(), ;
        "turnover" => @HBBridgeExampleTurnover(), ;
        "turnoverReport" => @HBBridgeExampleTurnoverReport() }
    hb_HCaseMatch( hActions, .T. )
    IF ! hb_HHasKey( hActions, cAction )
        RETURN HBBridgeJSONEncode( HBBridgeError( "UNKNOWN_ADDON_ACTION", "The example action is not supported." ) )
    ENDIF
    cParams := HBBridgeJSONEncode( hEnvelope[ "params" ] )
    /* The native calling API uses an ordered parameter array. */
RETURN hb_ExecFromArray( hActions[ cAction ], { cParams, hContext } )

/* Existing single-source addons retain their independent Main ABI. */
#define Main HBBridgeExampleSample
#include "hbbridgesampleaddon.hb"
#undef Main
#define Main HBBridgeExampleBenchmark
#include "hbbridgebenchmarkaddon.hb"
#undef Main
#define Main HBBridgeExampleTemporaryInsert
#include "hbbridgetemporaryinsertaddon.hb"
#undef Main
#define Main HBBridgeExampleTurnover
#include "hbbridgeturnoveraddon.hb"
#undef Main
#define Main HBBridgeExampleTurnoverReport
#include "hbbridgeturnoverreportaddon.hb"
#undef Main
