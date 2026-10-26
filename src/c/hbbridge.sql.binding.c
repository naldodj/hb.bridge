/* Released to Public Domain. Wire binding validation; no business conversion. */
#include "hbbridge.sql.typed.h"

static HB_BOOL HBBridgeBindingInteger( PHB_ITEM value, double minimum, double maximum )
{
    double number;
    if( !value || !HB_IS_NUMERIC( value ) )
        return HB_FALSE;
    number = hb_itemGetND( value );
    return isfinite( number ) && number >= minimum && number <= maximum && trunc( number ) == number;
}

static HB_BOOL HBBridgeBindingDecimal( PHB_ITEM value, HB_MAXINT precision, HB_MAXINT scale )
{
    const char * text;
    HB_BOOL negative, dot = HB_FALSE, nonzero = HB_FALSE;
    HB_SIZE index, length, integers = 0, fractions = 0, start;

    if( !value || !HB_IS_STRING( value ) )
        return HB_FALSE;
    text = hb_itemGetCPtr( value );
    length = hb_itemGetCLen( value );
    if( !length )
        return HB_FALSE;
    negative = text[ 0 ] == '-';
    start = negative ? 1 : 0;
    if( start == length )
        return HB_FALSE;
    for( index = start; index < length; index++ )
    {
        unsigned char byte = ( unsigned char ) text[ index ];
        if( byte == '.' && !dot && integers > 0 )
        {
            dot = HB_TRUE;
            continue;
        }
        if( byte < '0' || byte > '9' )
            return HB_FALSE;
        nonzero = nonzero || byte != '0';
        if( dot )
            fractions++;
        else
            integers++;
    }
    if( ( negative && !nonzero ) || ( dot && fractions == 0 ) ||
        ( integers > 1 && text[ start ] == '0' ) )
        return HB_FALSE;
    if( integers == 1 && text[ start ] == '0' )
        integers = 0;
    return integers <= ( HB_MAXUINT ) ( precision - scale ) && fractions <= ( HB_MAXUINT ) scale;
}

HB_FUNC( HBBRIDGETYPEDBINDINGSVALID )
{
    const char * code = "INVALID_BINDINGS";
    const char * message = "Bindings require contiguous positional descriptors.";
    HB_BOOL valid = HB_TRUE;
    HB_SIZE index, count;
    PHB_ITEM bindings = hb_param( 1, HB_IT_HASH );

    if( !bindings )
        valid = HB_FALSE;
    count = bindings ? hb_hashLen( bindings ) : 0;
    for( index = 1; valid && index <= count; index++ )
    {
        char key[ 32 ];
        const char * type;
        HB_BOOL isNull, decimal;
        HB_MAXINT integer;
        PHB_ITEM descriptor = hb_hashGetCItemPtr( bindings, hb_numToStr( key, sizeof( key ), ( HB_MAXINT ) index ) );
        PHB_ITEM kind = HBBridgeTypedGet( descriptor, "type" );
        PHB_ITEM nullFlag = HBBridgeTypedGet( descriptor, "isNull" );
        PHB_ITEM value = HBBridgeTypedGet( descriptor, "value" );
        PHB_ITEM precision = HBBridgeTypedGet( descriptor, "precision" );
        PHB_ITEM scale = HBBridgeTypedGet( descriptor, "scale" );

        if( !descriptor || !HB_IS_HASH( descriptor ) || !kind || !HB_IS_STRING( kind ) ||
            !nullFlag || !HB_IS_LOGICAL( nullFlag ) ||
            strlen( hb_itemGetCPtr( kind ) ) != hb_itemGetCLen( kind ) )
        {
            valid = HB_FALSE;
            break;
        }
        type = hb_itemGetCPtr( kind );
        isNull = hb_itemGetL( nullFlag );
        decimal = strcmp( type, "decimal" ) == 0;
        if( hb_hashLen( descriptor ) != ( HB_SIZE ) ( ( isNull ? 2 : 3 ) + ( decimal ? 2 : 0 ) ) ||
            ( isNull ? value != NULL : value == NULL ) ||
            ( !decimal && ( precision || scale ) ) || ( decimal && ( !precision || !scale ) ) )
        {
            valid = HB_FALSE;
            break;
        }
        if( strcmp( type, "text" ) && strcmp( type, "integer" ) && strcmp( type, "int64" ) &&
            strcmp( type, "number" ) && strcmp( type, "decimal" ) && strcmp( type, "boolean" ) &&
            strcmp( type, "date" ) )
        {
            code = "UNSUPPORTED_BINDING_TYPE";
            message = "The requested binding type is unsupported.";
            valid = HB_FALSE;
            break;
        }
        code = "BINDING_RANGE_ERROR";
        message = "A binding value violates its canonical type, range or precision.";
        if( decimal && ( !HBBridgeBindingInteger( precision, 1, 9007199254740991.0 ) ||
            !HBBridgeBindingInteger( scale, 0, 9007199254740991.0 ) ||
            hb_itemGetNInt( scale ) > hb_itemGetNInt( precision ) ) )
        {
            valid = HB_FALSE;
            break;
        }
        if( !isNull )
        {
            if( !strcmp( type, "text" ) )
                valid = HB_IS_STRING( value ) && HBBridgeTypedValidUTF8( hb_itemGetCPtr( value ), hb_itemGetCLen( value ) );
            else if( !strcmp( type, "integer" ) )
                valid = HBBridgeBindingInteger( value, -9007199254740991.0, 9007199254740991.0 );
            else if( !strcmp( type, "int64" ) )
                valid = HB_IS_STRING( value ) && HBBridgeTypedParseInt64( hb_itemGetCPtr( value ), hb_itemGetCLen( value ), &integer );
            else if( !strcmp( type, "number" ) )
                valid = HB_IS_NUMERIC( value ) && isfinite( hb_itemGetND( value ) );
            else if( decimal )
                valid = HBBridgeBindingDecimal( value, hb_itemGetNInt( precision ), hb_itemGetNInt( scale ) );
            else if( !strcmp( type, "boolean" ) )
                valid = HB_IS_LOGICAL( value );
            else
                valid = HB_IS_STRING( value ) && HBBridgeTypedDateISOValid( hb_itemGetCPtr( value ), hb_itemGetCLen( value ) );
        }
        if( valid )
        {
            code = "INVALID_BINDINGS";
            message = "Bindings require contiguous positional descriptors.";
        }
    }
    hb_storc( valid ? "" : code, 2 );
    hb_storc( valid ? "" : message, 3 );
    hb_retl( valid );
}

HB_FUNC( HBBRIDGETYPEDSQLVALID )
{
    hb_retl( HBBridgeTypedSQLSingle( hb_parc( 1 ), hb_parclen( 1 ) ) );
}
