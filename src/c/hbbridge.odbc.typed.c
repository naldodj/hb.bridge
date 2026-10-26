/* Released to Public Domain.
 * Included by the managed SDDODBC core; the caller owns the connection/lease.
 * The shared hbbridge.sql.typed.h helpers must be defined before this file.
 */
#include <math.h>
#include <stdint.h>
#include <limits.h>
#include <string.h>

typedef struct
{
    SQLLEN indicator;
    SQLLEN bufferSize;
    SQLSMALLINT cType;
    SQLSMALLINT sqlType;
    SQLULEN precision;
    SQLSMALLINT scale;
    SQLPOINTER data;
    void * allocation;
    union
    {
        SQLBIGINT integer;
        SQLDOUBLE number;
        SQLCHAR logical;
        SQL_DATE_STRUCT date;
    } value;
} HBBridgeODBCTypedBinding;

enum
{
    HB_BRIDGE_ODBC_TEXT,
    HB_BRIDGE_ODBC_INTEGER,
    HB_BRIDGE_ODBC_INT64,
    HB_BRIDGE_ODBC_DECIMAL,
    HB_BRIDGE_ODBC_NUMBER,
    HB_BRIDGE_ODBC_BOOLEAN,
    HB_BRIDGE_ODBC_DATE
};

typedef struct
{
    PHB_ITEM name;
    const char * key;
    SQLUSMALLINT ordinal;
    SQLSMALLINT type;
    SQLULEN precision;
    SQLSMALLINT scale;
    int kind;
} HBBridgeODBCTypedColumn;

static HB_BOOL HBBridgeODBCTypedState( SQLHSTMT statement, const char * expected, HB_SIZE length )
{
    SQLCHAR state[ 6 ] = { 0 };
    SQLINTEGER nativeCode;

    return SQL_SUCCEEDED( SQLGetDiagRecA( SQL_HANDLE_STMT, statement, 1,
        state, &nativeCode, NULL, 0, NULL ) ) &&
        memcmp( state, expected, length ) == 0;
}

static HB_BOOL HBBridgeODBCTypedTimeout( SQLHSTMT statement, HB_MAXINT seconds )
{
    SQLULEN requested, effective = 0;

    if( seconds < 0 )
        return seconds == -1;
    requested = ( SQLULEN ) seconds;
    return ( HB_MAXINT ) requested == seconds && seconds <= INT64_C( 9007199254740991 ) &&
        SQL_SUCCEEDED( SQLSetStmtAttr( statement, SQL_ATTR_QUERY_TIMEOUT,
            ( SQLPOINTER ) ( HB_PTRUINT ) requested, SQL_IS_UINTEGER ) ) &&
        SQL_SUCCEEDED( SQLGetStmtAttr( statement, SQL_ATTR_QUERY_TIMEOUT,
            &effective, sizeof( effective ), NULL ) ) && effective == requested;
}

/* Always use the wide ODBC API, independently of UNICODE and the OS codepage.
 * Explicit lengths preserve U+0000; supplementary scalars use surrogate pairs.
 */
static SQLWCHAR * HBBridgeODBCTypedWide( const char * text, HB_SIZE bytes, HB_SIZE * units )
{
    HB_SIZE offset = 0, written = 0;
    HB_WCHAR32 scalar;
    SQLWCHAR * wide;

    if( sizeof( SQLWCHAR ) != 2 || !HBBridgeTypedValidUTF8( text, bytes ) ||
        bytes > HB_SIZE_MAX / sizeof( SQLWCHAR ) - 1 )
        return NULL;
    wide = ( SQLWCHAR * ) hb_xgrab( ( bytes + 1 ) * sizeof( SQLWCHAR ) );
    while( offset < bytes )
    {
        if( !hb_cdpUTF8GetU32( text, bytes, &offset, &scalar ) )
        {
            hb_xfree( wide );
            return NULL;
        }
        if( scalar > 0xFFFF )
        {
            scalar -= 0x10000;
            wide[ written++ ] = ( SQLWCHAR ) ( 0xD800 + ( scalar >> 10 ) );
            wide[ written++ ] = ( SQLWCHAR ) ( 0xDC00 + ( scalar & 0x3FF ) );
        }
        else
            wide[ written++ ] = ( SQLWCHAR ) scalar;
    }
    wide[ written ] = 0;
    *units = written;
    return wide;
}

static PHB_ITEM HBBridgeODBCTypedUTF8( const SQLWCHAR * wide, HB_SIZE units )
{
    char * text;
    HB_SIZE index, written = 0;
    PHB_ITEM result;

    if( sizeof( SQLWCHAR ) != 2 || units > ( HB_SIZE_MAX - 1 ) / 3 )
        return NULL;
    text = ( char * ) hb_xgrab( units * 3 + 1 );
    for( index = 0; index < units; index++ )
    {
        HB_WCHAR32 scalar = wide[ index ];
        if( scalar >= 0xD800 && scalar <= 0xDBFF )
        {
            HB_WCHAR32 low;
            if( ++index >= units )
                goto failure;
            low = wide[ index ];
            if( low < 0xDC00 || low > 0xDFFF )
                goto failure;
            scalar = 0x10000 + ( ( scalar - 0xD800 ) << 10 ) + low - 0xDC00;
        }
        else if( scalar >= 0xDC00 && scalar <= 0xDFFF )
            goto failure;
        written += hb_cdpU32CharToUTF8( text + written, scalar );
    }
    result = hb_itemPutCL( NULL, text, written );
    hb_xfree( text );
    return result;

failure:
    hb_xfree( text );
    return NULL;
}

static PHB_ITEM HBBridgeODBCTypedAttribute( SQLHSTMT statement, SQLUSMALLINT column,
    SQLUSMALLINT attribute )
{
    SQLWCHAR buffer[ 256 ];
    SQLSMALLINT bytes = 0;

    if( SQLColAttributeW( statement, column, attribute, buffer, sizeof( buffer ),
        &bytes, NULL ) != SQL_SUCCESS || bytes < 0 ||
        ( HB_SIZE ) bytes > sizeof( buffer ) - sizeof( SQLWCHAR ) ||
        bytes % sizeof( SQLWCHAR ) != 0 )
        return NULL;
    return HBBridgeODBCTypedUTF8( buffer, ( HB_SIZE ) bytes / sizeof( SQLWCHAR ) );
}

static void HBBridgeODBCTypedPutAttribute( PHB_ITEM source, const char * key,
    SQLHSTMT statement, SQLUSMALLINT column, SQLUSMALLINT attribute )
{
    PHB_ITEM value = HBBridgeODBCTypedAttribute( statement, column, attribute );

    if( value && hb_itemGetCLen( value ) != 0 )
        HBBridgeTypedPut( source, key, value );
    else
        HBBridgeTypedPutNil( source, key );
    if( value )
        hb_itemRelease( value );
}

static void HBBridgeODBCTypedPutIntegerAttribute( PHB_ITEM source, const char * key,
    SQLHSTMT statement, SQLUSMALLINT column, SQLUSMALLINT attribute )
{
    SQLLEN value = -1;

    if( SQLColAttributeW( statement, column, attribute, NULL, 0, NULL, &value ) == SQL_SUCCESS &&
        value >= 0 && ( HB_MAXINT ) value >= 0 )
        HBBridgeTypedPutN( source, key, ( HB_MAXINT ) value );
    else
        HBBridgeTypedPutNil( source, key );
}

static HB_BOOL HBBridgeODBCTypedDate( PHB_ITEM value, SQL_DATE_STRUCT * date )
{
    const char * text;
    HB_SIZE index;
    int year = 0, month = 0, day = 0;

    if( !value || !HB_IS_STRING( value ) ||
        !HBBridgeTypedDateISOValid( hb_itemGetCPtr( value ), hb_itemGetCLen( value ) ) )
        return HB_FALSE;
    text = hb_itemGetCPtr( value );
    for( index = 0; index < 10; index++ )
    {
        if( index == 4 || index == 7 )
        {
            if( text[ index ] != '-' )
                return HB_FALSE;
        }
        else if( text[ index ] < '0' || text[ index ] > '9' )
            return HB_FALSE;
        else if( index < 4 )
            year = year * 10 + text[ index ] - '0';
        else if( index < 7 )
            month = month * 10 + text[ index ] - '0';
        else
            day = day * 10 + text[ index ] - '0';
    }
    if( year < 1 || hb_dateEncode( year, month, day ) == 0 )
        return HB_FALSE;
    date->year = ( SQLSMALLINT ) year;
    date->month = ( SQLUSMALLINT ) month;
    date->day = ( SQLUSMALLINT ) day;
    return HB_TRUE;
}

static HB_BOOL HBBridgeODBCTypedDecimalInput( const char * text, HB_SIZE length,
    HB_MAXINT precision, HB_MAXINT scale )
{
    HB_BOOL negative, nonzero = HB_FALSE;
    HB_SIZE index, first, digits;

    if( !length || length > ( HB_SIZE ) precision + 3 )
        return HB_FALSE;
    negative = text[ 0 ] == '-';
    first = index = negative ? 1 : 0;
    while( index < length && text[ index ] >= '0' && text[ index ] <= '9' )
    {
        nonzero = nonzero || text[ index ] != '0';
        index++;
    }
    digits = index - first;
    if( !digits || ( digits > 1 && text[ first ] == '0' ) ||
        ( text[ first ] != '0' && digits > ( HB_SIZE ) ( precision - scale ) ) )
        return HB_FALSE;
    if( index < length && text[ index ] == '.' )
    {
        first = ++index;
        while( index < length && text[ index ] >= '0' && text[ index ] <= '9' )
        {
            nonzero = nonzero || text[ index ] != '0';
            index++;
        }
        if( index == first || index - first > ( HB_SIZE ) scale )
            return HB_FALSE;
    }
    return index == length && ( !negative || nonzero );
}

static HB_BOOL HBBridgeODBCTypedBind( SQLHSTMT statement, SQLUSMALLINT ordinal,
    PHB_ITEM descriptor, HBBridgeODBCTypedBinding * binding, const char ** error )
{
    PHB_ITEM type = HBBridgeTypedGet( descriptor, "type" );
    PHB_ITEM nullValue = HBBridgeTypedGet( descriptor, "isNull" );
    PHB_ITEM value = HBBridgeTypedGet( descriptor, "value" );
    const char * kind;
    HB_BOOL isNull;

    *error = "INVALID_BINDINGS";
    if( !type || !HB_IS_STRING( type ) || !nullValue || !HB_IS_LOGICAL( nullValue ) )
        return HB_FALSE;
    kind = hb_itemGetCPtr( type );
    if( strlen( kind ) != hb_itemGetCLen( type ) )
        return HB_FALSE;
    isNull = hb_itemGetL( nullValue );
    if( ( isNull && value ) || ( !isNull && !value ) )
        return HB_FALSE;
    binding->indicator = isNull ? SQL_NULL_DATA : 0;
    if( strcmp( kind, "text" ) == 0 )
    {
        HB_SIZE units = 0, bytes;
        SQLWCHAR * wide;

        if( !isNull && !HB_IS_STRING( value ) )
            return HB_FALSE;
        wide = HBBridgeODBCTypedWide( isNull ? "" : hb_itemGetCPtr( value ),
            isNull ? 0 : hb_itemGetCLen( value ), &units );
        if( !wide )
            return HB_FALSE;
        binding->allocation = wide;
        bytes = units * sizeof( SQLWCHAR );
        binding->bufferSize = ( SQLLEN ) ( bytes + sizeof( SQLWCHAR ) );
        if( binding->bufferSize < 0 || ( HB_SIZE ) binding->bufferSize != bytes + sizeof( SQLWCHAR ) )
        {
            *error = "BINDING_RANGE_ERROR";
            return HB_FALSE;
        }
        binding->data = wide;
        binding->cType = SQL_C_WCHAR;
        binding->sqlType = units > 4000 ? SQL_WLONGVARCHAR : SQL_WVARCHAR;
        binding->precision = units ? ( SQLULEN ) units : 1;
        if( !isNull )
            binding->indicator = ( SQLLEN ) bytes;
    }
    else if( strcmp( kind, "integer" ) == 0 || strcmp( kind, "int64" ) == 0 )
    {
        HB_MAXINT integer = 0;

        binding->cType = SQL_C_SBIGINT;
        binding->sqlType = SQL_BIGINT;
        binding->precision = 19;
        binding->data = &binding->value.integer;
        binding->bufferSize = sizeof( binding->value.integer );
        if( !isNull )
        {
            if( strcmp( kind, "int64" ) == 0 )
            {
                if( !HB_IS_STRING( value ) || !HBBridgeTypedParseInt64( hb_itemGetCPtr( value ),
                    hb_itemGetCLen( value ), &integer ) )
                {
                    *error = "BINDING_RANGE_ERROR";
                    return HB_FALSE;
                }
            }
            else
            {
                double number;

                if( !HB_IS_NUMERIC( value ) )
                    return HB_FALSE;
                number = hb_itemGetND( value );
                if( !isfinite( number ) || number < -9007199254740991.0 ||
                    number > 9007199254740991.0 || floor( number ) != number )
                {
                    *error = "BINDING_RANGE_ERROR";
                    return HB_FALSE;
                }
                integer = hb_itemGetNInt( value );
            }
            binding->value.integer = ( SQLBIGINT ) integer;
            if( ( HB_MAXINT ) binding->value.integer != integer )
            {
                *error = "BINDING_RANGE_ERROR";
                return HB_FALSE;
            }
        }
    }
    else if( strcmp( kind, "number" ) == 0 )
    {
        binding->cType = SQL_C_DOUBLE;
        binding->sqlType = SQL_DOUBLE;
        binding->precision = 15;
        binding->data = &binding->value.number;
        binding->bufferSize = sizeof( binding->value.number );
        if( !isNull )
        {
            if( !HB_IS_NUMERIC( value ) )
                return HB_FALSE;
            binding->value.number = hb_itemGetND( value );
            if( !isfinite( binding->value.number ) )
            {
                *error = "BINDING_RANGE_ERROR";
                return HB_FALSE;
            }
        }
    }
    else if( strcmp( kind, "decimal" ) == 0 )
    {
        PHB_ITEM precision = HBBridgeTypedGet( descriptor, "precision" );
        PHB_ITEM scale = HBBridgeTypedGet( descriptor, "scale" );
        HB_MAXINT digits, decimals;
        HB_SIZE bytes;

        if( !precision || !HB_IS_NUMERIC( precision ) || !scale || !HB_IS_NUMERIC( scale ) ||
            ( !isNull && !HB_IS_STRING( value ) ) )
            return HB_FALSE;
        digits = hb_itemGetNInt( precision );
        decimals = hb_itemGetNInt( scale );
        if( digits < 1 || digits > 38 || decimals < 0 || decimals > digits ||
            hb_itemGetND( precision ) != ( double ) digits || hb_itemGetND( scale ) != ( double ) decimals )
        {
            *error = "BINDING_RANGE_ERROR";
            return HB_FALSE;
        }
        bytes = isNull ? 0 : hb_itemGetCLen( value );
        if( !isNull && !HBBridgeODBCTypedDecimalInput( hb_itemGetCPtr( value ), bytes, digits, decimals ) )
        {
            *error = "BINDING_RANGE_ERROR";
            return HB_FALSE;
        }
        binding->allocation = hb_xgrab( bytes + 1 );
        memcpy( binding->allocation, isNull ? "" : hb_itemGetCPtr( value ), bytes );
        ( ( char * ) binding->allocation )[ bytes ] = '\0';
        binding->cType = SQL_C_CHAR;
        binding->sqlType = SQL_DECIMAL;
        binding->precision = ( SQLULEN ) digits;
        binding->scale = ( SQLSMALLINT ) decimals;
        binding->data = binding->allocation;
        binding->bufferSize = ( SQLLEN ) bytes + 1;
        if( !isNull )
            binding->indicator = ( SQLLEN ) bytes;
    }
    else if( strcmp( kind, "boolean" ) == 0 )
    {
        binding->cType = SQL_C_BIT;
        binding->sqlType = SQL_BIT;
        binding->precision = 1;
        binding->data = &binding->value.logical;
        binding->bufferSize = sizeof( binding->value.logical );
        if( !isNull && !HB_IS_LOGICAL( value ) )
            return HB_FALSE;
        if( !isNull )
            binding->value.logical = hb_itemGetL( value ) ? 1 : 0;
    }
    else if( strcmp( kind, "date" ) == 0 )
    {
        binding->cType = SQL_C_TYPE_DATE;
        binding->sqlType = SQL_TYPE_DATE;
        binding->precision = 10;
        binding->data = &binding->value.date;
        binding->bufferSize = sizeof( binding->value.date );
        if( !isNull && !HBBridgeODBCTypedDate( value, &binding->value.date ) )
        {
            *error = "BINDING_RANGE_ERROR";
            return HB_FALSE;
        }
    }
    else
    {
        *error = "UNSUPPORTED_BINDING_TYPE";
        return HB_FALSE;
    }
    if( SQLBindParameter( statement, ordinal, SQL_PARAM_INPUT, binding->cType,
        binding->sqlType, binding->precision, binding->scale, binding->data,
        binding->bufferSize, &binding->indicator ) != SQL_SUCCESS )
    {
        *error = HBBridgeODBCTypedState( statement, "22", 2 ) ?
            "BINDING_RANGE_ERROR" : "STATEMENT_BIND_FAILED";
        return HB_FALSE;
    }
    return HB_TRUE;
}

static HB_BOOL HBBridgeODBCTypedMetadata( SQLHSTMT statement, HBBridgeODBCTypedColumn * column,
    SQLUSMALLINT ordinal, HB_SIZE position, PHB_ITEM header )
{
    SQLWCHAR nameBuffer[ 256 ];
    SQLSMALLINT nameLength = 0, nullable = SQL_NULLABLE_UNKNOWN;
    PHB_ITEM field, source, rdd, wire, name;
    const char * kind, *jsonType;
    HB_BOOL numeric = HB_FALSE;

    if( SQLDescribeColW( statement, ordinal, nameBuffer,
        sizeof( nameBuffer ) / sizeof( nameBuffer[ 0 ] ), &nameLength,
        &column->type, &column->precision, &column->scale, &nullable ) != SQL_SUCCESS ||
        nameLength <= 0 || ( HB_SIZE ) nameLength >= sizeof( nameBuffer ) / sizeof( nameBuffer[ 0 ] ) )
        return HB_FALSE;
    name = HBBridgeODBCTypedUTF8( nameBuffer, ( HB_SIZE ) nameLength );
    if( !name || memchr( hb_itemGetCPtr( name ), 0, hb_itemGetCLen( name ) ) != NULL )
    {
        if( name )
            hb_itemRelease( name );
        return HB_FALSE;
    }
    column->name = HBBridgeTypedName( hb_itemGetCPtr( name ), hb_itemGetCLen( name ) );
    hb_itemRelease( name );
    if( !column->name || !HB_IS_STRING( column->name ) || hb_itemGetCLen( column->name ) == 0 ||
        HBBridgeTypedGet( header, hb_itemGetCPtr( column->name ) ) != NULL )
        return HB_FALSE;
    column->key = hb_itemGetCPtr( column->name );
    column->ordinal = ordinal;
    switch( column->type )
    {
        case SQL_CHAR:
        case SQL_VARCHAR:
        case SQL_LONGVARCHAR:
        case SQL_WCHAR:
        case SQL_WVARCHAR:
        case SQL_WLONGVARCHAR:
            column->kind = HB_BRIDGE_ODBC_TEXT;
            kind = "text";
            jsonType = "string";
            break;
        case SQL_TINYINT:
        case SQL_SMALLINT:
        case SQL_INTEGER:
            column->kind = HB_BRIDGE_ODBC_INTEGER;
            kind = "integer";
            jsonType = "number";
            numeric = HB_TRUE;
            break;
        case SQL_BIGINT:
            column->kind = HB_BRIDGE_ODBC_INT64;
            kind = "int64";
            jsonType = "string";
            numeric = HB_TRUE;
            break;
        case SQL_NUMERIC:
        case SQL_DECIMAL:
            if( column->precision < 1 || column->precision > 38 || column->scale < 0 ||
                ( SQLULEN ) column->scale > column->precision )
                return HB_FALSE;
            column->kind = HB_BRIDGE_ODBC_DECIMAL;
            kind = "decimal";
            jsonType = "string";
            numeric = HB_TRUE;
            break;
        case SQL_REAL:
        case SQL_FLOAT:
        case SQL_DOUBLE:
            column->kind = HB_BRIDGE_ODBC_NUMBER;
            kind = "number";
            jsonType = "number";
            numeric = HB_TRUE;
            break;
        case SQL_BIT:
            column->kind = HB_BRIDGE_ODBC_BOOLEAN;
            kind = "boolean";
            jsonType = "boolean";
            numeric = HB_TRUE;
            break;
        case SQL_DATE:
        case SQL_TYPE_DATE:
            column->kind = HB_BRIDGE_ODBC_DATE;
            kind = "date";
            jsonType = "string";
            break;
        default:
            return HB_FALSE;
    }
    if( column->precision > ( SQLULEN ) HB_VMLONG_MAX )
        return HB_FALSE;
    field = hb_hashNew( NULL );
    source = hb_hashNew( NULL );
    rdd = hb_hashNew( NULL );
    wire = hb_hashNew( NULL );
    HBBridgeTypedPutN( field, "position", ( HB_MAXINT ) position );
    HBBridgeTypedPutNil( rdd, "type" );
    HBBridgeTypedPutNil( rdd, "length" );
    HBBridgeTypedPutNil( rdd, "decimals" );
    HBBridgeTypedPutN( source, "typeCode", column->type );
    HBBridgeODBCTypedPutAttribute( source, "typeName", statement, ordinal, SQL_DESC_TYPE_NAME );
    if( numeric )
    {
        HBBridgeTypedPutN( source, "precision", ( HB_MAXINT ) column->precision );
        HBBridgeTypedPutN( source, "scale", column->scale );
        HBBridgeODBCTypedPutIntegerAttribute( source, "precisionRadix", statement, ordinal, SQL_DESC_NUM_PREC_RADIX );
    }
    else
    {
        HBBridgeTypedPutNil( source, "precision" );
        HBBridgeTypedPutNil( source, "scale" );
        HBBridgeTypedPutNil( source, "precisionRadix" );
    }
    if( column->kind == HB_BRIDGE_ODBC_TEXT )
        HBBridgeTypedPutN( source, "characterLength", ( HB_MAXINT ) column->precision );
    else
        HBBridgeTypedPutNil( source, "characterLength" );
    HBBridgeODBCTypedPutIntegerAttribute( source, "octetLength", statement, ordinal, SQL_DESC_OCTET_LENGTH );
    if( nullable == SQL_NULLABLE || nullable == SQL_NO_NULLS )
        HBBridgeTypedPutL( source, "nullable", nullable == SQL_NULLABLE );
    else
        HBBridgeTypedPutNil( source, "nullable" );
    HBBridgeODBCTypedPutAttribute( source, "catalog", statement, ordinal, SQL_DESC_CATALOG_NAME );
    HBBridgeODBCTypedPutAttribute( source, "schema", statement, ordinal, SQL_DESC_SCHEMA_NAME );
    HBBridgeODBCTypedPutAttribute( source, "table", statement, ordinal, SQL_DESC_BASE_TABLE_NAME );
    HBBridgeODBCTypedPutAttribute( source, "column", statement, ordinal, SQL_DESC_BASE_COLUMN_NAME );
    HBBridgeTypedPutNil( source, "collation" );
    HBBridgeTypedPutC( wire, "kind", kind );
    HBBridgeTypedPutC( wire, "jsonType", jsonType );
    if( strcmp( jsonType, "string" ) == 0 )
        HBBridgeTypedPutC( wire, "encoding", "UTF-8" );
    else
        HBBridgeTypedPutNil( wire, "encoding" );
    HBBridgeTypedPut( field, "rdd", rdd );
    HBBridgeTypedPut( field, "source", source );
    HBBridgeTypedPut( field, "wire", wire );
    HBBridgeTypedPut( header, column->key, field );
    hb_itemRelease( wire );
    hb_itemRelease( rdd );
    hb_itemRelease( source );
    hb_itemRelease( field );
    return HB_TRUE;
}

static HB_BOOL HBBridgeODBCTypedReadText( SQLHSTMT statement, SQLUSMALLINT column, PHB_ITEM * value )
{
    SQLWCHAR buffer[ 2048 ];
    char * bytes = NULL;
    HB_SIZE length = 0, capacity = 0;
    const HB_SIZE payload = sizeof( buffer ) - sizeof( SQLWCHAR );
    HB_BOOL success = HB_FALSE;

    for( ;; )
    {
        SQLLEN indicator = SQL_NULL_DATA;
        SQLRETURN result = SQLGetData( statement, column, SQL_C_WCHAR, buffer, sizeof( buffer ), &indicator );
        HB_SIZE chunk, needed;
        HB_BOOL more = HB_FALSE;

        if( result != SQL_SUCCESS && result != SQL_SUCCESS_WITH_INFO )
            break;
        if( indicator == SQL_NULL_DATA )
        {
            if( length != 0 )
                break;
            *value = hb_itemNew( NULL );
            success = HB_TRUE;
            break;
        }
        if( result == SQL_SUCCESS_WITH_INFO && !HBBridgeODBCTypedState( statement, "01004", 5 ) )
            break;
        if( indicator == SQL_NO_TOTAL )
        {
            if( result != SQL_SUCCESS_WITH_INFO )
                break;
            chunk = payload;
            more = HB_TRUE;
        }
        else
        {
            if( indicator < 0 )
                break;
            chunk = ( HB_SIZE ) indicator;
            if( chunk > payload )
            {
                if( result != SQL_SUCCESS_WITH_INFO )
                    break;
                chunk = payload;
                more = HB_TRUE;
            }
            else if( result == SQL_SUCCESS_WITH_INFO )
                break;
        }
        if( chunk % sizeof( SQLWCHAR ) != 0 || length > HB_SIZE_MAX - chunk - sizeof( SQLWCHAR ) )
            break;
        needed = length + chunk + sizeof( SQLWCHAR );
        if( needed > capacity )
        {
            HB_SIZE grown = capacity ? capacity : sizeof( buffer );
            while( grown < needed )
            {
                if( grown > HB_SIZE_MAX / 2 )
                {
                    grown = needed;
                    break;
                }
                grown *= 2;
            }
            bytes = ( char * ) ( bytes ? hb_xrealloc( bytes, grown ) : hb_xgrab( grown ) );
            capacity = grown;
        }
        memcpy( bytes + length, buffer, chunk );
        length += chunk;
        if( !more )
        {
            *value = HBBridgeODBCTypedUTF8( ( SQLWCHAR * ) bytes, length / sizeof( SQLWCHAR ) );
            success = *value != NULL;
            break;
        }
    }
    if( bytes )
        hb_xfree( bytes );
    return success;
}

/* Canonicalize the driver's exact ASCII, including .00000000, without double.
 * Padding trailing zeroes changes spelling only; excess scale is never rounded.
 */
static PHB_ITEM HBBridgeODBCTypedDecimal( const char * input, HB_SIZE length,
    SQLULEN precision, SQLSMALLINT scale )
{
    char output[ 80 ];
    HB_SIZE index = 0, first, integerEnd, fraction = 0, written = 0;
    HB_BOOL negative = HB_FALSE, nonzero = HB_FALSE;

    if( !length || precision < 1 || precision > 38 || scale < 0 || ( SQLULEN ) scale > precision )
        return NULL;
    if( input[ index ] == '-' )
    {
        negative = HB_TRUE;
        index++;
    }
    first = index;
    while( index < length && input[ index ] >= '0' && input[ index ] <= '9' )
    {
        nonzero = nonzero || input[ index ] != '0';
        index++;
    }
    integerEnd = index;
    if( index < length && input[ index ] == '.' )
    {
        index++;
        fraction = index;
        while( index < length && input[ index ] >= '0' && input[ index ] <= '9' )
        {
            nonzero = nonzero || input[ index ] != '0';
            index++;
        }
        if( index == fraction )
            return NULL;
    }
    if( index != length || ( integerEnd == first && fraction == 0 ) )
        return NULL;
    while( first < integerEnd && input[ first ] == '0' )
        first++;
    if( integerEnd - first > precision - scale ||
        ( fraction && length - fraction > ( HB_SIZE ) scale ) )
        return NULL;
    if( negative && nonzero )
        output[ written++ ] = '-';
    if( first == integerEnd )
        output[ written++ ] = '0';
    else
    {
        memcpy( output + written, input + first, integerEnd - first );
        written += integerEnd - first;
    }
    if( scale )
    {
        HB_SIZE digits = fraction ? length - fraction : 0;
        output[ written++ ] = '.';
        if( digits )
        {
            memcpy( output + written, input + fraction, digits );
            written += digits;
        }
        while( digits++ < ( HB_SIZE ) scale )
            output[ written++ ] = '0';
    }
    return hb_itemPutCL( NULL, output, written );
}

static HB_BOOL HBBridgeODBCTypedRead( SQLHSTMT statement,
    const HBBridgeODBCTypedColumn * column, PHB_ITEM * value, const char ** error )
{
    SQLLEN indicator = SQL_NULL_DATA;
    SQLRETURN result;

    *error = "STATEMENT_FETCH_FAILED";
    if( column->kind == HB_BRIDGE_ODBC_TEXT )
        return HBBridgeODBCTypedReadText( statement, column->ordinal, value );
    if( column->kind == HB_BRIDGE_ODBC_INTEGER || column->kind == HB_BRIDGE_ODBC_INT64 )
    {
        SQLBIGINT integer = 0;

        result = SQLGetData( statement, column->ordinal, SQL_C_SBIGINT,
            &integer, sizeof( integer ), &indicator );
        if( result != SQL_SUCCESS )
            goto rangeFailure;
        if( indicator == SQL_NULL_DATA )
            *value = hb_itemNew( NULL );
        else if( indicator != sizeof( integer ) )
            goto rangeFailure;
        else if( column->kind == HB_BRIDGE_ODBC_INT64 )
            *value = HBBridgeTypedIntegerText( ( HB_MAXINT ) integer );
        else if( integer >= -INT64_C( 9007199254740991 ) && integer <= INT64_C( 9007199254740991 ) )
            *value = hb_itemPutNInt( NULL, ( HB_MAXINT ) integer );
        else
            goto rangeFailure;
    }
    else if( column->kind == HB_BRIDGE_ODBC_DECIMAL )
    {
        char buffer[ 80 ] = { 0 };

        result = SQLGetData( statement, column->ordinal, SQL_C_CHAR, buffer, sizeof( buffer ), &indicator );
        if( result != SQL_SUCCESS )
            goto rangeFailure;
        if( indicator == SQL_NULL_DATA )
            *value = hb_itemNew( NULL );
        else if( indicator >= 0 && ( HB_SIZE ) indicator < sizeof( buffer ) )
            *value = HBBridgeODBCTypedDecimal( buffer, ( HB_SIZE ) indicator, column->precision, column->scale );
        if( !*value )
            goto rangeFailure;
    }
    else if( column->kind == HB_BRIDGE_ODBC_NUMBER )
    {
        SQLDOUBLE number = 0;

        result = SQLGetData( statement, column->ordinal, SQL_C_DOUBLE, &number, sizeof( number ), &indicator );
        if( result != SQL_SUCCESS )
            goto rangeFailure;
        if( indicator == SQL_NULL_DATA )
            *value = hb_itemNew( NULL );
        else if( indicator == sizeof( number ) && isfinite( number ) )
            *value = hb_itemPutND( NULL, number );
        else
            goto rangeFailure;
    }
    else if( column->kind == HB_BRIDGE_ODBC_BOOLEAN )
    {
        SQLCHAR logical = 0;

        result = SQLGetData( statement, column->ordinal, SQL_C_BIT, &logical, sizeof( logical ), &indicator );
        if( result != SQL_SUCCESS )
            goto rangeFailure;
        if( indicator == SQL_NULL_DATA )
            *value = hb_itemNew( NULL );
        else if( indicator == sizeof( logical ) && logical <= 1 )
            *value = hb_itemPutL( NULL, logical != 0 );
        else
            goto rangeFailure;
    }
    else if( column->kind == HB_BRIDGE_ODBC_DATE )
    {
        char text[ 11 ];
        SQL_DATE_STRUCT date = { 0, 0, 0 };

        result = SQLGetData( statement, column->ordinal, SQL_C_TYPE_DATE, &date, sizeof( date ), &indicator );
        if( result != SQL_SUCCESS )
            goto rangeFailure;
        if( indicator == SQL_NULL_DATA )
            *value = hb_itemNew( NULL );
        else if( indicator == sizeof( date ) && date.year >= 1 && date.year <= 9999 &&
            hb_dateEncode( date.year, date.month, date.day ) != 0 )
        {
            hb_snprintf( text, sizeof( text ), "%04d-%02u-%02u", ( int ) date.year,
                ( unsigned int ) date.month, ( unsigned int ) date.day );
            *value = hb_itemPutCL( NULL, text, 10 );
        }
        else
            goto rangeFailure;
    }
    else
        return HB_FALSE;
    return HB_TRUE;

rangeFailure:
    *error = "RESULT_RANGE_ERROR";
    return HB_FALSE;
}

static HB_BOOL HBBridgeODBCTypedExecute( SQLHDBC connection, PHB_ITEM request,
    HB_MAXINT timeoutSeconds )
{
    HBBridgeODBCTypedBinding * bindings = NULL;
    HBBridgeODBCTypedColumn * columns = NULL;
    HB_BOOL success = HB_FALSE, hasNext = HB_FALSE, buffersReleased = HB_TRUE, countMode;
    HB_SIZE index, bindingCount = 0, columnCount = 0, rowCount = 0, units = 0;
    HB_MAXINT skip, rowLimit, totalRows = 0;
    PHB_ITEM bindingMap, sql, header = NULL, rows = NULL, output = NULL, row = NULL;
    SQLHSTMT statement = SQL_NULL_HSTMT;
    SQLSMALLINT nativeParameters = 0, nativeColumns = 0;
    SQLWCHAR * wide = NULL;
    const char * error = "STATEMENT_PREPARE_FAILED";
    const char * message = "The native typed SQL operation failed.";

    if( !HBBridgeTypedIsRequest( request ) )
        return HBBridgeTypedError( request, "INVALID_TYPED_REQUEST", "The internal typed SQL request is invalid." );
    sql = HBBridgeTypedGet( request, "sql" );
    bindingMap = HBBridgeTypedGet( request, "bindings" );
    countMode = strcmp( hb_itemGetCPtr( HBBridgeTypedGet( request, "operation" ) ),
        "hbbridge.querytyped.count.v1" ) == 0;
    skip = hb_itemGetNInt( HBBridgeTypedGet( request, "skipColumns" ) );
    rowLimit = hb_itemGetNInt( HBBridgeTypedGet( request, "rowLimit" ) );
    if( !HBBridgeTypedSQLSingle( hb_itemGetCPtr( sql ), hb_itemGetCLen( sql ) ) ||
        skip < 0 || rowLimit < 0 || sizeof( SQLWCHAR ) != 2 || sizeof( SQLBIGINT ) != 8 ||
        sizeof( HB_MAXINT ) < 8 || ( countMode && ( skip != 0 || rowLimit != 0 ) ) )
        return HBBridgeTypedError( request, "INVALID_TYPED_REQUEST", "A single supported SQL query is required." );
    bindingCount = hb_hashLen( bindingMap );
    if( bindingCount > SHRT_MAX )
        return HBBridgeTypedError( request, "INVALID_BINDINGS", "The native parameter count is out of range." );
    wide = HBBridgeODBCTypedWide( hb_itemGetCPtr( sql ), hb_itemGetCLen( sql ), &units );
    if( !wide || units > INT_MAX )
    {
        error = "INVALID_TYPED_REQUEST";
        goto cleanup;
    }
    if( !SQL_SUCCEEDED( SQLAllocHandle( SQL_HANDLE_STMT, connection, &statement ) ) ||
        !HBBridgeODBCTypedTimeout( statement, timeoutSeconds ) ||
        !SQL_SUCCEEDED( SQLPrepareW( statement, wide, ( SQLINTEGER ) units ) ) ||
        !SQL_SUCCEEDED( SQLNumParams( statement, &nativeParameters ) ) )
        goto cleanup;
    if( nativeParameters < 0 || ( HB_SIZE ) nativeParameters != bindingCount )
    {
        error = "INVALID_BINDINGS";
        goto cleanup;
    }
    if( bindingCount )
        bindings = ( HBBridgeODBCTypedBinding * ) hb_xgrabz( bindingCount * sizeof( *bindings ) );
    for( index = 0; index < bindingCount; index++ )
    {
        char ordinal[ 32 ];
        PHB_ITEM descriptor;

        hb_snprintf( ordinal, sizeof( ordinal ), "%u", ( unsigned int ) index + 1 );
        descriptor = HBBridgeTypedGet( bindingMap, ordinal );
        if( !descriptor || !HB_IS_HASH( descriptor ) )
        {
            error = "INVALID_BINDINGS";
            goto cleanup;
        }
        if( !HBBridgeODBCTypedBind( statement, ( SQLUSMALLINT ) index + 1,
            descriptor, &bindings[ index ], &error ) )
            goto cleanup;
    }
    if( SQLNumResultCols( statement, &nativeColumns ) != SQL_SUCCESS || nativeColumns <= skip ||
        ( countMode && nativeColumns != 1 ) )
    {
        error = "UNSUPPORTED_RESULT_TYPE";
        goto cleanup;
    }
    columnCount = ( HB_SIZE ) ( nativeColumns - skip );
    columns = ( HBBridgeODBCTypedColumn * ) hb_xgrabz( columnCount * sizeof( *columns ) );
    header = hb_hashNew( NULL );
    rows = hb_hashNew( NULL );
    for( index = 0; index < columnCount; index++ )
    {
        if( !HBBridgeODBCTypedMetadata( statement, &columns[ index ],
            ( SQLUSMALLINT ) ( index + skip + 1 ), index + 1, header ) )
        {
            error = "UNSUPPORTED_RESULT_TYPE";
            goto cleanup;
        }
    }
    if( countMode && ( strcmp( hb_itemGetCPtr( columns[ 0 ].name ), "__HBBRIDGE_COUNT" ) != 0 ||
        ( columns[ 0 ].kind != HB_BRIDGE_ODBC_INTEGER && columns[ 0 ].kind != HB_BRIDGE_ODBC_INT64 ) ) )
    {
        error = "UNSUPPORTED_RESULT_TYPE";
        goto cleanup;
    }
    if( SQLExecute( statement ) != SQL_SUCCESS )
    {
        error = HBBridgeODBCTypedState( statement, "22", 2 ) ?
            "BINDING_RANGE_ERROR" : "STATEMENT_EXECUTE_FAILED";
        goto cleanup;
    }
    if( countMode )
    {
        SQLBIGINT count = 0;
        SQLLEN indicator = SQL_NULL_DATA;

        if( SQLFetch( statement ) != SQL_SUCCESS ||
            SQLGetData( statement, 1, SQL_C_SBIGINT, &count, sizeof( count ), &indicator ) != SQL_SUCCESS ||
            indicator != sizeof( count ) || count < 0 || count > INT64_C( 9007199254740991 ) )
        {
            error = "RESULT_RANGE_ERROR";
            goto cleanup;
        }
        totalRows = ( HB_MAXINT ) count;
        if( SQLFetch( statement ) != SQL_NO_DATA || SQLMoreResults( statement ) != SQL_NO_DATA )
        {
            error = "STATEMENT_FETCH_FAILED";
            goto cleanup;
        }
        success = HB_TRUE;
        goto cleanup;
    }
    for( ;; )
    {
        SQLRETURN fetched = SQLFetch( statement );
        char ordinal[ 32 ];

        if( fetched == SQL_NO_DATA )
            break;
        if( fetched != SQL_SUCCESS )
        {
            error = "STATEMENT_FETCH_FAILED";
            goto cleanup;
        }
        if( rowLimit && rowCount >= ( HB_SIZE ) rowLimit )
        {
            hasNext = HB_TRUE;
            break;
        }
        if( rowCount >= INT64_C( 9007199254740991 ) )
        {
            error = "RESULT_RANGE_ERROR";
            goto cleanup;
        }
        row = hb_hashNew( NULL );
        for( index = 0; index < columnCount; index++ )
        {
            PHB_ITEM value = NULL;

            if( !HBBridgeODBCTypedRead( statement, &columns[ index ], &value, &error ) )
            {
                if( value )
                    hb_itemRelease( value );
                goto cleanup;
            }
            HBBridgeTypedPut( row, columns[ index ].key, value );
            hb_itemRelease( value );
        }
        rowCount++;
        hb_snprintf( ordinal, sizeof( ordinal ), "%" HB_PFS "u", rowCount );
        HBBridgeTypedPut( rows, ordinal, row );
        hb_itemRelease( row );
        row = NULL;
    }
    if( SQLMoreResults( statement ) != SQL_NO_DATA )
    {
        error = "UNSUPPORTED_RESULT_TYPE";
        goto cleanup;
    }
    success = HB_TRUE;

cleanup:
    if( statement != SQL_NULL_HSTMT )
    {
        SQLRETURN unbound = SQLFreeStmt( statement, SQL_RESET_PARAMS );
        SQLRETURN released = SQLFreeHandle( SQL_HANDLE_STMT, statement );

        buffersReleased = SQL_SUCCEEDED( unbound ) || SQL_SUCCEEDED( released );
        if( !SQL_SUCCEEDED( released ) )
        {
            success = HB_FALSE;
            error = "STATEMENT_FETCH_FAILED";
            message = "The native typed SQL statement could not be released.";
        }
    }
    /* Never invalidate bound pointers if the driver refuses both unbind/close.
     * That catastrophic cleanup failure is reported rather than hiding success.
     */
    if( bindings && buffersReleased )
    {
        for( index = 0; index < bindingCount; index++ )
        {
            if( bindings[ index ].allocation )
                hb_xfree( bindings[ index ].allocation );
        }
        hb_xfree( bindings );
    }
    if( wide )
        hb_xfree( wide );
    if( columns )
    {
        for( index = 0; index < columnCount; index++ )
        {
            if( columns[ index ].name )
                hb_itemRelease( columns[ index ].name );
        }
        hb_xfree( columns );
    }
    if( row )
        hb_itemRelease( row );
    if( success )
    {
        output = hb_hashNew( NULL );
        HBBridgeTypedPutL( output, "success", HB_TRUE );
        if( countMode )
            HBBridgeTypedPutN( output, "totalRows", totalRows );
        else
        {
            HBBridgeTypedPut( output, "header", header );
            HBBridgeTypedPut( output, "rows", rows );
            HBBridgeTypedPutN( output, "rowCount", ( HB_MAXINT ) rowCount );
            HBBridgeTypedPutL( output, "hasNext", hasNext );
        }
        HBBridgeTypedPut( request, "output", output );
        hb_itemRelease( output );
    }
    else
        HBBridgeTypedError( request, error, message );
    if( rows )
        hb_itemRelease( rows );
    if( header )
        hb_itemRelease( header );
    return success;
}
