/* Released to Public Domain. Synthetic ABI probe; not a credential provider. */
#include "hbapi.h"
#include <stdbool.h>
#include <stddef.h>

extern bool HBBridgeCredentialProbe( const unsigned char * data, size_t length );

HB_FUNC( HBBRIDGECREDENTIALPROBE )
{
    if( HB_ISCHAR( 1 ) )
        hb_retl( HBBridgeCredentialProbe( ( const unsigned char * ) hb_parc( 1 ), hb_parclen( 1 ) ) );
    else
        hb_retl( HB_FALSE );
}
