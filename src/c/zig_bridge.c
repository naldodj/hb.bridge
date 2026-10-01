/* Harbour C API adapter for the existing Zig demonstration library. */
#include "hbapi.h"

extern const char * ZigEngine_Dispatch( const char * json_ptr );

HB_FUNC( ZIGENGINE_DISPATCH )
{
   const char * result = ZigEngine_Dispatch( hb_parc( 1 ) );
   hb_retc( result != NULL ? result : "{\"success\": false, \"error\": \"Engine Zig sem resposta\"}" );
}
