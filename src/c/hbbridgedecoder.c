/* Incremental gzip reader using Harbour's linked zlib runtime. */
#include "hbapi.h"
#include "hbapiitm.h"

#include <limits.h>
#include <string.h>
#include <zlib.h>

typedef struct
{
    z_stream stream;
    HB_SIZE limit;
    HB_SIZE expanded;
    HB_BOOL initialized;
    HB_BOOL finished;
    HB_BOOL failed;
} HBBRIDGE_INFLATER;

static void * bridge_zalloc( void * cargo, uInt items, uInt size )
{
    HB_SYMBOL_UNUSED( cargo );
    if( items == 0 || size == 0 || ( HB_SIZE ) items > HB_SIZE_MAX / size )
        return NULL;
    return hb_xalloc( ( HB_SIZE ) items * size );
}

static void bridge_zfree( void * cargo, void * address )
{
    HB_SYMBOL_UNUSED( cargo );
    if( address )
        hb_xfree( address );
}

static void bridge_inflate_end( HBBRIDGE_INFLATER * state )
{
    if( state->initialized )
    {
        inflateEnd( &state->stream );
        state->initialized = HB_FALSE;
    }
}

static HB_GARBAGE_FUNC( bridge_inflate_release )
{
    bridge_inflate_end( ( HBBRIDGE_INFLATER * ) Cargo );
}

static const HB_GC_FUNCS bridge_inflate_gc =
{
    bridge_inflate_release,
    hb_gcDummyMark
};

static HB_SIZE bridge_string_limit( void )
{
    HB_MAXUINT sizeLimit = ( HB_MAXUINT ) HB_SIZE_MAX - 1;
    HB_MAXUINT integerLimit = ( HB_MAXUINT ) HB_VMLONG_MAX;

    return ( HB_SIZE ) ( sizeLimit < integerLimit ? sizeLimit : integerLimit );
}

/* maximum is always an exact unsigned form of a nonnegative HB_MAXINT. */
static HB_BOOL bridge_integer_value( PHB_ITEM item, HB_MAXUINT maximum, HB_MAXINT * result )
{
    HB_MAXINT integer;

    if( ! item )
        return HB_FALSE;
    if( HB_IS_NUMINT( item ) )
    {
        integer = hb_itemGetNInt( item );
        if( integer < 0 || ( HB_MAXUINT ) integer > maximum )
            return HB_FALSE;
    }
    else
    {
        double value = hb_itemGetND( item );
        HB_MAXUINT unsignedValue;

        /* Reject NaN/infinity before conversion. Unsigned conversion detects
         * a double rounded above signed max without an undefined signed cast.
         */
        if( ! ( value >= 0 && value <= ( double ) maximum ) )
            return HB_FALSE;
        unsignedValue = ( HB_MAXUINT ) value;
        if( unsignedValue > maximum || ( double ) unsignedValue != value )
            return HB_FALSE;
        integer = ( HB_MAXINT ) unsignedValue;
    }
    *result = integer;
    return HB_TRUE;
}

HB_FUNC( HBBRIDGEINTEGERVALID )
{
    HB_MAXINT maximum;
    HB_MAXINT value;
    HB_BOOL valid = bridge_integer_value( hb_param( 2, HB_IT_NUMERIC ),
        ( HB_MAXUINT ) HB_VMLONG_MAX, &maximum );

    if( valid )
        valid = bridge_integer_value( hb_param( 1, HB_IT_NUMERIC ),
            ( HB_MAXUINT ) maximum, &value );
    hb_retl( valid );
}

static void bridge_hash_limit( PHB_ITEM hash, const char * name, HB_MAXINT limit )
{
    PHB_ITEM key = hb_itemPutC( NULL, name );
    PHB_ITEM value = hb_itemPutNInt( NULL, limit );

    hb_hashAdd( hash, key, value );
    hb_itemRelease( key );
    hb_itemRelease( value );
}

/* Representable lengths, not promises about available process memory. */
HB_FUNC( HBBRIDGERUNTIMELIMITS )
{
    HB_SIZE stringLimit = bridge_string_limit();
    HB_SIZE socketLimit = stringLimit < ( HB_SIZE ) LONG_MAX ? stringLimit : ( HB_SIZE ) LONG_MAX;
    HB_SIZE zlibLimit = stringLimit < ( HB_SIZE ) UINT_MAX ? stringLimit : ( HB_SIZE ) UINT_MAX;
    PHB_ITEM limits = hb_hashNew( NULL );

    bridge_hash_limit( limits, "stringBytesMax", ( HB_MAXINT ) stringLimit );
    bridge_hash_limit( limits, "socketChunkBytesMax", ( HB_MAXINT ) socketLimit );
    bridge_hash_limit( limits, "zlibChunkBytesMax", ( HB_MAXINT ) zlibLimit );
    bridge_hash_limit( limits, "netioTimeoutMsMax", ( HB_MAXINT ) INT_MAX );
    hb_itemReturnRelease( limits );
}

HB_FUNC( HBBRIDGEINFLATEOPEN )
{
    HB_SIZE stringLimit = bridge_string_limit();
    HB_MAXINT limit;
    HBBRIDGE_INFLATER * state;

    if( ! bridge_integer_value( hb_param( 1, HB_IT_NUMERIC ),
        ( HB_MAXUINT ) stringLimit, &limit ) )
        return;
    state = ( HBBRIDGE_INFLATER * ) hb_gcAllocate( sizeof( *state ), &bridge_inflate_gc );
    memset( state, 0, sizeof( *state ) );
    /* Zero disables the application cap; representation checks remain. */
    state->limit = limit == 0 ? stringLimit : ( HB_SIZE ) limit;
    state->stream.zalloc = bridge_zalloc;
    state->stream.zfree = bridge_zfree;
    /* HBBRIDGE/1 requires gzip; zlib and raw DEFLATE are not wire profiles. */
    state->initialized = inflateInit2( &state->stream, 15 + 16 ) == Z_OK;
    state->failed = ! state->initialized;
    hb_retptrGC( state );
}

/* Result: { status (0=more, 1=complete, -1=invalid), output chunks, consumed }. */
HB_FUNC( HBBRIDGEINFLATEFEED )
{
    HBBRIDGE_INFLATER * state = ( HBBRIDGE_INFLATER * ) hb_parptrGC( &bridge_inflate_gc, 1 );
    HB_SIZE length = hb_parclen( 2 );
    PHB_ITEM result = hb_itemArrayNew( 3 );
    PHB_ITEM chunks = hb_itemArrayNew( 0 );
    int status = -1;
    HB_SIZE consumed = 0;

    if( state && state->initialized && ! state->failed && ! state->finished &&
        HB_ISCHAR( 2 ) && length <= UINT_MAX && length <= bridge_string_limit() )
    {
        unsigned char output[ 32768 ];
        state->stream.next_in = ( Bytef * ) HB_UNCONST( hb_parc( 2 ) );
        state->stream.avail_in = ( uInt ) length;
        status = 0;
        for( ;; )
        {
            uInt before = state->stream.avail_in;
            HB_SIZE produced;
            int code;

            state->stream.next_out = output;
            state->stream.avail_out = sizeof( output );
            code = inflate( &state->stream, Z_NO_FLUSH );
            produced = sizeof( output ) - state->stream.avail_out;
            if( state->expanded > state->limit ||
                produced > HB_SIZE_MAX - state->expanded ||
                produced > state->limit - state->expanded )
            {
                status = -1;
                break;
            }
            state->expanded += produced;
            if( produced )
            {
                PHB_ITEM chunk = hb_itemPutCL( NULL, ( const char * ) output, produced );
                hb_arrayAddForward( chunks, chunk );
                hb_itemRelease( chunk );
            }
            if( code == Z_STREAM_END )
            {
                /* One compressed unit per call: reject coalesced extras. */
                status = state->stream.avail_in == 0 ? 1 : -1;
                state->finished = status == 1;
                break;
            }
            if( code != Z_OK && code != Z_BUF_ERROR )
            {
                status = -1;
                break;
            }
            if( ! produced && before == state->stream.avail_in )
            {
                if( state->stream.avail_in != 0 )
                    status = -1;
                break;
            }
            if( state->stream.avail_in == 0 && state->stream.avail_out != 0 )
                break;
        }
        consumed = length - state->stream.avail_in;
        /* Never retain VM string pointers across calls or GC safepoints. */
        state->stream.next_in = NULL;
        state->stream.avail_in = 0;
        state->stream.next_out = NULL;
    }
    if( state && status != 0 )
        bridge_inflate_end( state );
    if( status < 0 )
    {
        if( state )
            state->failed = HB_TRUE;
        hb_arraySize( chunks, 0 );
    }
    hb_arraySetNI( result, 1, status );
    hb_arraySetForward( result, 2, chunks );
    hb_arraySetNInt( result, 3, ( HB_MAXINT ) consumed );
    hb_itemRelease( chunks );
    hb_itemReturnRelease( result );
}

HB_FUNC( HBBRIDGEINFLATECLOSE )
{
    HBBRIDGE_INFLATER * state = ( HBBRIDGE_INFLATER * ) hb_parptrGC( &bridge_inflate_gc, 1 );
    if( state )
    {
        bridge_inflate_end( state );
        state->failed = HB_TRUE;
    }
    hb_retl( state != NULL );
}
