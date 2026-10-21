/* Released to Public Domain. */
#include "hbapi.h"
#include <stdint.h>
#include <string.h>

/* Construct exact IEEE-754 inputs independently of either JSON parser. */
HB_FUNC( HBBRIDGEJSONTESTDOUBLE )
{
    const char * text = hb_parc( 1 );

    double value;

    int index;

    uint64_t bits = 0;
    if( text == NULL || hb_parclen( 1 ) != 16 )
    {
        hb_ret();
        return;
    }
    for( index = 0; index < 16; ++index )
    {
        unsigned char digit = ( unsigned char ) text[ index ];
        bits = ( bits << 4 ) | ( digit >= 'A' ? digit - 'A' + 10 : digit - '0' );
    }
    memcpy( &value, &bits, sizeof( value ) );
    hb_retndlen( value, 0, hb_parnidef( 2, 0 ) );
}

HB_FUNC( HBBRIDGEJSONTESTSAME )
{
    double first = hb_parnd( 1 ), second = hb_parnd( 2 );
    hb_retl( memcmp( &first, &second, sizeof( first ) ) == 0 );
}
