/* Harbour C API adapter for the existing Zig demonstration library. */
#include "hbapi.h"

extern const char * hbbridge_zig_dispatch( const char * json_ptr );

HB_FUNC( ZIGENGINE_DISPATCH )
{
    const char * result = hbbridge_zig_dispatch( hb_parc( 1 ) );
    hb_retc( result != NULL ? result : "{\"success\": false, \"error\": \"Engine Zig sem resposta\"}" );
}
