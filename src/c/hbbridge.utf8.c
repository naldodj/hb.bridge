/* Released to Public Domain. */
#include "hbapi.h"
#include "hbapicdp.h"
#include <string.h>

/* Validate Unicode scalar values with Harbour's native UTF-8 decoder.
 * Unlike encoding detection, valid ASCII and an empty string are accepted.
 */
HB_FUNC( HBBRIDGEUTF8VALID )
{
    const char * data = hb_parc( 1 );
    hb_retl( data != NULL && hb_cdpUTF8Validate( data, hb_parclen( 1 ) ) );
}

static HB_BOOL HBBridgeJSONHex4( const char * data, HB_WCHAR32 * scalar )
{
    int index;
    *scalar = 0;
    for( index = 0; index < 4; index++ )
    {
        unsigned char digit = ( unsigned char ) data[ index ];
        *scalar <<= 4;
        if( digit >= '0' && digit <= '9' )
            *scalar += digit - '0';
        else if( digit >= 'a' && digit <= 'f' )
            *scalar += digit - 'a' + 10;
        else if( digit >= 'A' && digit <= 'F' )
            *scalar += digit - 'A' + 10;
        else
            return HB_FALSE;
    }
    return HB_TRUE;
}

/* Harbour's JSON decoder reads each escaped UTF-16 code unit separately.
 * Normalize surrogate pairs only inside JSON strings before that decoder;
 * leave ordinary syntax and escaped backslashes for the native decoder.
 * Allocate a replacement only when the first valid pair needs conversion.
 */
HB_FUNC( HBBRIDGEHTTPJSONNORMALIZE )
{
    const char * data = hb_parc( 1 );
    HB_SIZE size = hb_parclen( 1 ), offset = 0, written = 0;
    char * output = NULL;
    HB_BOOL inString = HB_FALSE, valid = data != NULL;

    while( valid && offset < size )
    {
        HB_SIZE count = 1;
        if( inString && data[ offset ] == '\\' && offset + 1 < size )
        {
            if( data[ offset + 1 ] == 'u' )
            {
                HB_WCHAR32 first, second;
                if( size - offset < 6 || ! HBBridgeJSONHex4( data + offset + 2, &first ) )
                {
                    valid = HB_FALSE;
                    break;
                }
                if( first >= 0xD800 && first <= 0xDBFF )
                {
                    if( size - offset < 12 || data[ offset + 6 ] != '\\' ||
                        data[ offset + 7 ] != 'u' ||
                        ! HBBridgeJSONHex4( data + offset + 8, &second ) ||
                        second < 0xDC00 || second > 0xDFFF )
                    {
                        valid = HB_FALSE;
                        break;
                    }
                    if( output == NULL )
                    {
                        output = ( char * ) hb_xgrab( size + 1 );
                        memcpy( output, data, offset );
                        written = offset;
                    }
                    written += hb_cdpU32CharToUTF8( output + written,
                        0x10000 + ( ( first - 0xD800 ) << 10 ) + second - 0xDC00 );
                    offset += 12;
                    continue;
                }
                if( first >= 0xDC00 && first <= 0xDFFF )
                {
                    valid = HB_FALSE;
                    break;
                }
                count = 6;
            }
            else
                count = 2;
        }
        else if( data[ offset ] == '"' )
            inString = ! inString;

        if( output != NULL )
        {
            memcpy( output + written, data + offset, count );
            written += count;
        }
        offset += count;
    }

    if( ! valid )
    {
        if( output != NULL )
            hb_xfree( output );
        hb_ret();
    }
    else if( output != NULL )
    {
        output[ written ] = '\0';
        hb_retclen_buffer( output, written );
    }
    else
        hb_retclen( data, size );
}
