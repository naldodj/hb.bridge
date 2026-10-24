/* Released to Public Domain. */
#include "hbapi.h"
#include "hbapiitm.h"
#include "hbapicdp.h"
#include "hbjson.h"
#include <string.h>
#include <stdbool.h>

extern HB_SIZE HBBridgeNumberFormat( double value, char * output, HB_SIZE capacity );
extern bool HBBridgeNumberParse( const char * input, HB_SIZE length, double * output );

typedef struct
{
    char * data;
    HB_SIZE size;
    HB_SIZE capacity;
    void ** ancestors;
    HB_SIZE depth;
    HB_SIZE ancestorCapacity;
    PHB_CODEPAGE utf8;
} HBBridgeJSONBuffer;

static void HBBridgeJSONAppend( HBBridgeJSONBuffer * buffer, const char * data, HB_SIZE size )
{
    if( buffer->size + size + 1 > buffer->capacity )
    {
        buffer->capacity = buffer->size + size + 1 + buffer->capacity;
        buffer->data = ( char * ) hb_xrealloc( buffer->data, buffer->capacity );
    }
    memcpy( buffer->data + buffer->size, data, size );
    buffer->size += size;
}

static HB_BOOL HBBridgeJSONWrite( PHB_ITEM value, HBBridgeJSONBuffer * buffer )
{
    HB_BOOL result = HB_TRUE;
    if( HB_IS_ARRAY( value ) || HB_IS_HASH( value ) )
    {
        HB_BOOL hash = HB_IS_HASH( value ), first = HB_TRUE;

        HB_SIZE index, size = hb_itemSize( value );

        void * identity = hash ? hb_hashId( value ) : hb_arrayId( value );
        for( index = 0; index < buffer->depth; index++ )
        {
            if( buffer->ancestors[ index ] == identity )
            {
                HBBridgeJSONAppend( buffer, "null", 4 );
                return HB_TRUE;
            }
        }
        if( buffer->depth == buffer->ancestorCapacity )
        {
            buffer->ancestorCapacity += 16;
            buffer->ancestors = ( void ** ) hb_xrealloc( buffer->ancestors,
                buffer->ancestorCapacity * sizeof( void * ) );
        }
        buffer->ancestors[ buffer->depth++ ] = identity;
        HBBridgeJSONAppend( buffer, hash ? "{" : "[", 1 );
        for( index = 1; index <= size && result; index++ )
        {
            PHB_ITEM item;
            if( hash )
            {
                PHB_ITEM key = hb_hashGetKeyAt( value, index );
                if( ! HB_IS_STRING( key ) )
                    continue;
                if( ! first )
                    HBBridgeJSONAppend( buffer, ",", 1 );
                result = HBBridgeJSONWrite( key, buffer );
                HBBridgeJSONAppend( buffer, ":", 1 );
                item = hb_hashGetValueAt( value, index );
            }
            else
            {
                if( ! first )
                    HBBridgeJSONAppend( buffer, ",", 1 );
                item = hb_arrayGetItemPtr( value, index );
            }
            first = HB_FALSE;
            result = result && HBBridgeJSONWrite( item, buffer );
        }
        HBBridgeJSONAppend( buffer, hash ? "}" : "]", 1 );
        buffer->depth--;
    }
    else if( HB_IS_NUMINT( value ) )
    {
        char token[ 32 ];

        HB_MAXINT number = hb_itemGetNInt( value );
        HB_MAXUINT magnitude = number < 0 ? ( HB_MAXUINT ) ( -( number + 1 ) ) + 1 : ( HB_MAXUINT ) number;
        HB_SIZE offset = sizeof( token );
        do
        {
            token[ --offset ] = ( char ) ( '0' + magnitude % 10 );
            magnitude /= 10;
        }
        while( magnitude );
        if( number < 0 )
            token[ --offset ] = '-';
        HBBridgeJSONAppend( buffer, token + offset, sizeof( token ) - offset );
    }
    else if( HB_IS_NUMERIC( value ) )
    {
        char shortest[ 64 ];

        double number = hb_itemGetND( value ), parsed;

        HB_SIZE size = HBBridgeNumberFormat( number, shortest, sizeof( shortest ) );
        if( size == 0 )
            return HB_FALSE;
        else
        {
            char * fixed;

            HB_SIZE fixedSize;

            fixed = hb_jsonEncode( value, &fixedSize, 0 );
            /* Retain declared DECIMAL scale only when formatting preserves the
             * actual double. Zero decimal metadata must not truncate FLOAT.
             * Compare bits so that negative zero remains negative zero. */
            if( ( fixedSize <= 18 || strchr( fixed, '.' ) != NULL ) &&
                HBBridgeNumberParse( fixed, fixedSize, &parsed ) &&
                memcmp( &number, &parsed, sizeof( number ) ) == 0 )
                HBBridgeJSONAppend( buffer, fixed, fixedSize );
            else
                HBBridgeJSONAppend( buffer, shortest, size );
            hb_xfree( fixed );
        }
    }
    else
    {
        char * scalar;

        HB_SIZE size;

        scalar = hb_jsonEncodeCP( value, &size, 0, buffer->utf8 );
        HBBridgeJSONAppend( buffer, scalar, size );
        hb_xfree( scalar );
    }
    return result;
}

HB_FUNC( HBBRIDGEJSONENCODE )
{
    HBBridgeJSONBuffer buffer;

    PHB_CODEPAGE previous;
    PHB_ITEM value;

    value = hb_param( 1, HB_IT_ANY );
    previous = hb_vmCDP();
    memset( &buffer, 0, sizeof( buffer ) );
    /* One request-local lookup also serves every scalar in this document. */
    buffer.utf8 = hb_cdpFindExt( "UTF8" );
    hb_vmSetCDP( buffer.utf8 );
    buffer.capacity = 256;
    buffer.data = ( char * ) hb_xgrab( buffer.capacity );
    buffer.ancestorCapacity = 16;
    buffer.ancestors = ( void ** ) hb_xgrab( buffer.ancestorCapacity * sizeof( void * ) );
    if( value && HBBridgeJSONWrite( value, &buffer ) )
    {
        buffer.data[ buffer.size ] = '\0';
        hb_retclen_buffer( buffer.data, buffer.size );
    }
    else
    {
        hb_xfree( buffer.data );
        hb_ret();
    }
    hb_xfree( buffer.ancestors );
    hb_vmSetCDP( previous );
}

typedef struct
{
    const char * data;
    HB_SIZE size;
    HB_SIZE position;
} HBBridgeJSONReader;

static void HBBridgeJSONSpace( HBBridgeJSONReader * reader )
{
    while( reader->position < reader->size )
    {
        char byte = reader->data[ reader->position ];
        if( byte != ' ' && byte != '\t' && byte != '\r' && byte != '\n' )
            break;
        reader->position++;
    }
}

static HB_BOOL HBBridgeJSONDigit( char byte )
{
    return byte >= '0' && byte <= '9';
}

static HB_BOOL HBBridgeJSONNumber( HBBridgeJSONReader * reader, PHB_ITEM value )
{
    double number;

    HB_BOOL negative = reader->data[ reader->position ] == '-', floating = HB_FALSE;

    HB_MAXUINT integer = 0, limit;

    HB_SIZE start = reader->position, digits, fraction = 0;

    int exponent = 0, exponentSign = 1, decimals;
    if( negative )
        reader->position++;
    digits = reader->position;
    if( reader->position == reader->size || ! HBBridgeJSONDigit( reader->data[ reader->position ] ) )
        return HB_FALSE;
    if( reader->data[ reader->position ] == '0' )
        reader->position++;
    else
        while( reader->position < reader->size && HBBridgeJSONDigit( reader->data[ reader->position ] ) )
            reader->position++;
    if( reader->position < reader->size && reader->data[ reader->position ] == '.' )
    {
        HB_SIZE begin = ++reader->position;
        floating = HB_TRUE;
        while( reader->position < reader->size && HBBridgeJSONDigit( reader->data[ reader->position ] ) )
            reader->position++;
        fraction = reader->position - begin;
        if( fraction == 0 )
            return HB_FALSE;
    }
    if( reader->position < reader->size &&
        ( reader->data[ reader->position ] == 'e' || reader->data[ reader->position ] == 'E' ) )
    {
        HB_SIZE begin;
        floating = HB_TRUE;
        reader->position++;
        if( reader->position < reader->size &&
            ( reader->data[ reader->position ] == '+' || reader->data[ reader->position ] == '-' ) )
        {
            if( reader->data[ reader->position ] == '-' )
                exponentSign = -1;
            reader->position++;
        }
        begin = reader->position;
        while( reader->position < reader->size && HBBridgeJSONDigit( reader->data[ reader->position ] ) )
        {
            if( exponent < 100000 )
                exponent = exponent * 10 + reader->data[ reader->position ] - '0';
            reader->position++;
        }
        if( reader->position == begin )
            return HB_FALSE;
    }
    if( ! floating )
    {
        HB_SIZE index;
        /* Derive signed bounds without negating the minimum signed integer. */
        limit = ( ( HB_MAXUINT ) -1 ) >> 1;
        if( negative )
            limit++;
        for( index = digits; index < reader->position; index++ )
        {
            unsigned int digit = ( unsigned int ) ( reader->data[ index ] - '0' );
            if( integer > ( limit - digit ) / 10 )
                return HB_FALSE;
            integer = integer * 10 + digit;
        }
        if( integer != 0 || ! negative )
        {
            hb_itemPutNInt( value, negative ? -( HB_MAXINT ) ( integer - 1 ) - 1 : ( HB_MAXINT ) integer );
            return HB_TRUE;
        }
        /* A JSON -0 token is a binary64 negative zero, not integer zero. */
    }
    if( ! HBBridgeNumberParse( reader->data + start, reader->position - start, &number ) )
        return HB_FALSE;
    decimals = fraction > 65535 ? 65535 : ( int ) fraction;
    decimals -= exponentSign * exponent;
    decimals = decimals < 0 ? 0 : ( decimals > 65535 ? 65535 : decimals );
    hb_itemPutNDDec( value, number, decimals );
    return HB_TRUE;
}

static HB_BOOL HBBridgeJSONRead( HBBridgeJSONReader * reader, PHB_ITEM value );

static HB_BOOL HBBridgeJSONString( HBBridgeJSONReader * reader, PHB_ITEM value )
{
    HB_SIZE start = reader->position++, decoded;
    while( reader->position < reader->size )
    {
        unsigned char byte = ( unsigned char ) reader->data[ reader->position++ ];
        if( byte == '"' )
        {
            decoded = hb_jsonDecodeCP( reader->data + start, value, hb_cdpFindExt( "UTF8" ) );
            return decoded == reader->position - start && HB_IS_STRING( value );
        }
        if( byte < 32 )
            return HB_FALSE;
        if( byte == '\\' )
        {
            if( reader->position == reader->size )
                return HB_FALSE;
            byte = ( unsigned char ) reader->data[ reader->position++ ];
            if( byte == 'u' )
            {
                int digit;
                if( reader->size - reader->position < 4 )
                    return HB_FALSE;
                for( digit = 0; digit < 4; digit++ )
                {
                    byte = ( unsigned char ) reader->data[ reader->position++ ];
                    if( ! HBBridgeJSONDigit( ( char ) byte ) &&
                        ! ( byte >= 'a' && byte <= 'f' ) && ! ( byte >= 'A' && byte <= 'F' ) )
                        return HB_FALSE;
                }
            }
            else if( byte != '"' && byte != '\\' && byte != '/' && byte != 'b' &&
                byte != 'f' && byte != 'n' && byte != 'r' && byte != 't' )
                return HB_FALSE;
        }
    }
    return HB_FALSE;
}

static HB_BOOL HBBridgeJSONRead( HBBridgeJSONReader * reader, PHB_ITEM value )
{
    char byte;
    HBBridgeJSONSpace( reader );
    if( reader->position == reader->size )
        return HB_FALSE;
    byte = reader->data[ reader->position ];
    if( byte == '"' )
        return HBBridgeJSONString( reader, value );
    if( byte == '-' || HBBridgeJSONDigit( byte ) )
        return HBBridgeJSONNumber( reader, value );
    if( byte == '[' || byte == '{' )
    {
        char close;

        HB_BOOL hash = byte == '{', result = HB_TRUE;

        PHB_ITEM key = hb_itemNew( NULL ), item = hb_itemNew( NULL );

        close = hash ? '}' : ']';
        reader->position++;
        if( hash )
            hb_hashNew( value );
        else
            hb_arrayNew( value, 0 );
        HBBridgeJSONSpace( reader );
        if( reader->position < reader->size && reader->data[ reader->position ] == close )
            reader->position++;
        else
        {
            for( ;; )
            {
                if( hash )
                {
                    result = reader->position < reader->size && reader->data[ reader->position ] == '"' &&
                        HBBridgeJSONString( reader, key );
                    HBBridgeJSONSpace( reader );
                    if( ! result || reader->position == reader->size || reader->data[ reader->position++ ] != ':' )
                    {
                        result = HB_FALSE;
                        break;
                    }
                }
                if( ! HBBridgeJSONRead( reader, item ) )
                {
                    result = HB_FALSE;
                    break;
                }
                if( hash )
                    hb_hashAdd( value, key, item );
                else
                    hb_arrayAdd( value, item );
                HBBridgeJSONSpace( reader );
                if( reader->position == reader->size )
                {
                    result = HB_FALSE;
                    break;
                }
                byte = reader->data[ reader->position++ ];
                if( byte == close )
                    break;
                if( byte != ',' )
                {
                    result = HB_FALSE;
                    break;
                }
                HBBridgeJSONSpace( reader );
            }
        }
        hb_itemRelease( key );
        hb_itemRelease( item );
        return result;
    }
    if( reader->size - reader->position >= 4 &&
        memcmp( reader->data + reader->position, "null", 4 ) == 0 )
    {
        hb_itemClear( value );
        reader->position += 4;
        return HB_TRUE;
    }
    if( reader->size - reader->position >= 4 &&
        memcmp( reader->data + reader->position, "true", 4 ) == 0 )
    {
        hb_itemPutL( value, HB_TRUE );
        reader->position += 4;
        return HB_TRUE;
    }
    if( reader->size - reader->position >= 5 &&
        memcmp( reader->data + reader->position, "false", 5 ) == 0 )
    {
        hb_itemPutL( value, HB_FALSE );
        reader->position += 5;
        return HB_TRUE;
    }
    return HB_FALSE;
}

HB_FUNC( HBBRIDGEJSONDECODE )
{
    HBBridgeJSONReader reader;

    HB_SIZE size = 0;

    PHB_CODEPAGE previous = hb_vmCDP();
    PHB_ITEM value = hb_itemNew( NULL );
    reader.data = hb_parc( 1 );
    reader.size = hb_parclen( 1 );
    reader.position = 0;
    hb_vmSetCDP( hb_cdpFindExt( "UTF8" ) );
    if( reader.data && HBBridgeJSONRead( &reader, value ) )
        size = reader.position;
    else
        hb_itemClear( value );
    if( HB_ISBYREF( 2 ) )
    {
        hb_retns( size );
        hb_itemParamStoreForward( 2, value );
        hb_itemRelease( value );
    }
    else
        hb_itemReturnRelease( value );
    hb_vmSetCDP( previous );
}
