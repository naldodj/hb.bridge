/* Incremental gzip writer using Harbour's linked zlib runtime. */
#include "hbapi.h"
#include "hbapiitm.h"

#include <limits.h>
#include <string.h>
#include <zlib.h>

typedef struct
{
    z_stream stream;
    HB_BOOL initialized;
    HB_BOOL finished;
    HB_BOOL failed;
} HBBRIDGE_DEFLATER;

static void * bridge_deflate_zalloc( void * cargo, uInt items, uInt size )
{
    HB_SYMBOL_UNUSED( cargo );
    if( items == 0 || size == 0 || ( HB_SIZE ) items > HB_SIZE_MAX / size )
        return NULL;
    return hb_xalloc( ( HB_SIZE ) items * size );
}

static void bridge_deflate_zfree( void * cargo, void * address )
{
    HB_SYMBOL_UNUSED( cargo );
    if( address )
        hb_xfree( address );
}

static void bridge_deflate_end( HBBRIDGE_DEFLATER * state )
{
    if( state->initialized )
    {
        deflateEnd( &state->stream );
        state->initialized = HB_FALSE;
    }
}

static HB_GARBAGE_FUNC( bridge_deflate_release )
{
    bridge_deflate_end( ( HBBRIDGE_DEFLATER * ) Cargo );
}

static const HB_GC_FUNCS bridge_deflate_gc =
{
    bridge_deflate_release,
    hb_gcDummyMark
};

HB_FUNC( HBBRIDGEDEFLATEOPEN )
{
    HBBRIDGE_DEFLATER * state = ( HBBRIDGE_DEFLATER * ) hb_gcAllocate( sizeof( *state ), &bridge_deflate_gc );

    memset( state, 0, sizeof( *state ) );
    state->stream.zalloc = bridge_deflate_zalloc;
    state->stream.zfree = bridge_deflate_zfree;
    state->initialized = deflateInit2( &state->stream, Z_DEFAULT_COMPRESSION,
        Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY ) == Z_OK;
    state->failed = ! state->initialized;
    hb_retptrGC( state );
}

/* Result: { status (0=more, 1=complete, -1=invalid), output chunks, consumed }.
 * The uInt bound is per feed; neither the stream nor total payload is capped.
 */
HB_FUNC( HBBRIDGEDEFLATEFEED )
{
    HBBRIDGE_DEFLATER * state = ( HBBRIDGE_DEFLATER * ) hb_parptrGC( &bridge_deflate_gc, 1 );
    HB_SIZE length = hb_parclen( 2 );
    HB_BOOL finish = hb_parl( 3 );
    PHB_ITEM result = hb_itemArrayNew( 3 );
    PHB_ITEM chunks = hb_itemArrayNew( 0 );
    int status = -1;
    HB_SIZE consumed = 0;

    if( state && state->initialized && ! state->failed && ! state->finished &&
        HB_ISCHAR( 2 ) && HB_ISLOG( 3 ) && length <= UINT_MAX &&
        ( HB_MAXUINT ) length <= ( HB_MAXUINT ) HB_VMLONG_MAX )
    {
        unsigned char output[ 32768 ];
        int flush = finish ? Z_FINISH : Z_NO_FLUSH;

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
            code = deflate( &state->stream, flush );
            produced = sizeof( output ) - state->stream.avail_out;
            if( produced )
            {
                PHB_ITEM chunk = hb_itemPutCL( NULL, ( const char * ) output, produced );
                hb_arrayAddForward( chunks, chunk );
                hb_itemRelease( chunk );
            }
            if( code == Z_STREAM_END )
            {
                status = finish && state->stream.avail_in == 0 ? 1 : -1;
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
                if( finish || state->stream.avail_in != 0 )
                    status = -1;
                break;
            }
            if( ! finish && state->stream.avail_in == 0 && state->stream.avail_out != 0 )
                break;
        }
        consumed = length - state->stream.avail_in;
        /* VM strings and stack buffers are borrowed only for this call. */
        state->stream.next_in = NULL;
        state->stream.avail_in = 0;
        state->stream.next_out = NULL;
    }
    if( state && status != 0 )
        bridge_deflate_end( state );
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

HB_FUNC( HBBRIDGEDEFLATECLOSE )
{
    HBBRIDGE_DEFLATER * state = ( HBBRIDGE_DEFLATER * ) hb_parptrGC( &bridge_deflate_gc, 1 );

    if( state )
    {
        bridge_deflate_end( state );
        state->failed = HB_TRUE;
    }
    hb_retl( state != NULL );
}
