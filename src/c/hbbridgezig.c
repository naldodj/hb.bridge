/* Harbour C API adapter for the existing Zig demonstration library. */
#include "hbapi.h"

extern const char * HBBridgeZigDispatch( const char * json_ptr );

HB_FUNC( ZIGENGINEDISPATCH )
{
    const char * result = HBBridgeZigDispatch( hb_parc( 1 ) );
    hb_retc( result != NULL ? result : "{\"success\": false, \"error\": \"Engine Zig sem resposta\"}" );
}
