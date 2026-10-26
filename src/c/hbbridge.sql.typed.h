/* Released to Public Domain. Shared native typed-reader primitives. */
#ifndef HBBRIDGE_SQL_TYPED_H
#define HBBRIDGE_SQL_TYPED_H

#include "hbapi.h"
#include "hbapiitm.h"
#include "hbapicdp.h"
#include <stdint.h>
#include <string.h>
#include <math.h>

static inline PHB_ITEM HBBridgeTypedGet( PHB_ITEM hash, const char * key )
{
    return hash && HB_IS_HASH( hash ) ? hb_hashGetCItemPtr( hash, key ) : NULL;
}

static inline void HBBridgeTypedPut( PHB_ITEM hash, const char * key, PHB_ITEM value )
{
    PHB_ITEM name = hb_itemPutC( NULL, key );
    PHB_ITEM nil = value ? NULL : hb_itemNew( NULL );
    hb_hashAdd( hash, name, value ? value : nil );
    if( nil )
        hb_itemRelease( nil );
    hb_itemRelease( name );
}

static inline void HBBridgeTypedPutC( PHB_ITEM hash, const char * key, const char * value )
{
    PHB_ITEM item = hb_itemPutC( NULL, value );
    HBBridgeTypedPut( hash, key, item );
    hb_itemRelease( item );
}

static inline void HBBridgeTypedPutCL( PHB_ITEM hash, const char * key, const char * value, HB_SIZE length )
{
    PHB_ITEM item = hb_itemPutCL( NULL, value, length );
    HBBridgeTypedPut( hash, key, item );
    hb_itemRelease( item );
}

static inline void HBBridgeTypedPutN( PHB_ITEM hash, const char * key, HB_MAXINT value )
{
    PHB_ITEM item = hb_itemPutNInt( NULL, value );
    HBBridgeTypedPut( hash, key, item );
    hb_itemRelease( item );
}

static inline void HBBridgeTypedPutD( PHB_ITEM hash, const char * key, double value )
{
    PHB_ITEM item = hb_itemPutND( NULL, value );
    HBBridgeTypedPut( hash, key, item );
    hb_itemRelease( item );
}

static inline void HBBridgeTypedPutL( PHB_ITEM hash, const char * key, HB_BOOL value )
{
    PHB_ITEM item = hb_itemPutL( NULL, value );
    HBBridgeTypedPut( hash, key, item );
    hb_itemRelease( item );
}

static inline void HBBridgeTypedPutNil( PHB_ITEM hash, const char * key )
{
    HBBridgeTypedPut( hash, key, NULL );
}

static inline HB_BOOL HBBridgeTypedError( PHB_ITEM request, const char * code, const char * message )
{
    if( request && HB_IS_HASH( request ) )
    {
        PHB_ITEM output = hb_hashNew( NULL );
        PHB_ITEM error = hb_hashNew( NULL );
        HBBridgeTypedPutC( error, "code", code );
        HBBridgeTypedPutC( error, "message", message );
        HBBridgeTypedPutL( output, "success", HB_FALSE );
        HBBridgeTypedPut( output, "error", error );
        HBBridgeTypedPut( request, "output", output );
        hb_itemRelease( error );
        hb_itemRelease( output );
    }
    return HB_FALSE;
}

static inline HB_BOOL HBBridgeTypedValidUTF8( const char * value, HB_SIZE length )
{
    return value && hb_cdpUTF8Validate( value, length );
}

static inline HB_BOOL HBBridgeTypedParseInt64( const char * value, HB_SIZE length, HB_MAXINT * output )
{
    HB_BOOL negative;
    HB_MAXUINT magnitude = 0, limit;
    HB_SIZE index;

    if( !value || !output || length == 0 || length > 20 || sizeof( HB_MAXINT ) < 8 )
        return HB_FALSE;
    negative = value[ 0 ] == '-';
    index = negative ? 1 : 0;
    if( index == length || length - index > 19 ||
        ( value[ index ] == '0' && ( negative || length - index != 1 ) ) )
        return HB_FALSE;
    limit = ( HB_MAXUINT ) INT64_MAX + ( negative ? 1 : 0 );
    for( ; index < length; index++ )
    {
        unsigned int digit = ( unsigned char ) value[ index ] - '0';
        if( digit > 9 || magnitude > ( limit - digit ) / 10 )
            return HB_FALSE;
        magnitude = magnitude * 10 + digit;
    }
    *output = negative ? ( magnitude == ( HB_MAXUINT ) INT64_MAX + 1 ?
        -( HB_MAXINT ) INT64_MAX - 1 : -( HB_MAXINT ) magnitude ) : ( HB_MAXINT ) magnitude;
    return HB_TRUE;
}

static inline PHB_ITEM HBBridgeTypedIntegerText( HB_MAXINT value )
{
    char buffer[ 32 ];
    HB_BOOL negative = value < 0;
    HB_MAXUINT magnitude = negative ? ( HB_MAXUINT ) ( -( value + 1 ) ) + 1 : ( HB_MAXUINT ) value;
    HB_SIZE index = sizeof( buffer ) - 1;
    buffer[ index ] = 0;
    do
    {
        buffer[ --index ] = ( char ) ( '0' + magnitude % 10 );
        magnitude /= 10;
    }
    while( magnitude );
    if( negative )
        buffer[ --index ] = '-';
    return hb_itemPutCL( NULL, buffer + index, sizeof( buffer ) - index - 1 );
}

static inline HB_BOOL HBBridgeTypedDateISOValid( const char * value, HB_SIZE length )
{
    static const unsigned int monthDays[] = { 31,28,31,30,31,30,31,31,30,31,30,31 };
    unsigned int year = 0, month, day, maximum;
    HB_SIZE index;

    if( !value || length != 10 || value[ 4 ] != '-' || value[ 7 ] != '-' )
        return HB_FALSE;
    for( index = 0; index < length; index++ )
    {
        if( index == 4 || index == 7 )
            continue;
        if( value[ index ] < '0' || value[ index ] > '9' )
            return HB_FALSE;
        if( index < 4 )
            year = year * 10 + value[ index ] - '0';
    }
    month = ( value[ 5 ] - '0' ) * 10 + value[ 6 ] - '0';
    day = ( value[ 8 ] - '0' ) * 10 + value[ 9 ] - '0';
    if( year == 0 || month == 0 || month > 12 || day == 0 )
        return HB_FALSE;
    maximum = monthDays[ month - 1 ];
    if( month == 2 && year % 4 == 0 && ( year % 100 != 0 || year % 400 == 0 ) )
        maximum++;
    return day <= maximum;
}

static inline PHB_ITEM HBBridgeTypedName( const char * value, HB_SIZE length )
{
    char * upper;
    PHB_ITEM result;
    PHB_CODEPAGE utf8 = hb_cdpFind( "UTF8EX" );

    if( !value || !utf8 || !HBBridgeTypedValidUTF8( value, length ) || memchr( value, 0, length ) )
        return NULL;
    while( length && ( unsigned char ) *value <= 32 )
    {
        value++;
        length--;
    }
    while( length && ( unsigned char ) value[ length - 1 ] <= 32 )
        length--;
    if( !length )
        return NULL;
    upper = hb_cdpnDupUpper( utf8, value, &length );
    result = hb_itemPutCL( NULL, upper, length );
    hb_xfree( upper );
    return result;
}

/* This bounds the supported statement form; it is not a SQL dialect parser.
 * Native prepare/discovery still decides syntax, markers and result types.
 */
static inline HB_BOOL HBBridgeTypedSQLSingle( const char * sql, HB_SIZE length )
{
    HB_BOOL first = HB_TRUE, selected = HB_FALSE, setSelect = HB_FALSE, ended = HB_FALSE;
    HB_SIZE index = 0, depth = 0;

    if( !sql || !length || memchr( sql, 0, length ) || !HBBridgeTypedValidUTF8( sql, length ) )
        return HB_FALSE;
    while( index < length )
    {
        unsigned char byte = ( unsigned char ) sql[ index ];
        if( byte <= 32 )
        {
            index++;
            continue;
        }
        if( byte == '-' && index + 1 < length && sql[ index + 1 ] == '-' )
        {
            index += 2;
            while( index < length && sql[ index ] != '\r' && sql[ index ] != '\n' )
                index++;
            continue;
        }
        if( byte == '/' && index + 1 < length && sql[ index + 1 ] == '*' )
        {
            HB_SIZE comments = 1;
            index += 2;
            while( index < length && comments )
            {
                if( index + 1 < length && sql[ index ] == '/' && sql[ index + 1 ] == '*' )
                {
                    comments++;
                    index += 2;
                }
                else if( index + 1 < length && sql[ index ] == '*' && sql[ index + 1 ] == '/' )
                {
                    comments--;
                    index += 2;
                }
                else
                    index++;
            }
            if( comments )
                return HB_FALSE;
            continue;
        }
        if( ended )
            return HB_FALSE;
        if( byte == '\'' || byte == '"' || byte == '[' || byte == '`' )
        {
            unsigned char close = byte == '[' ? ']' : byte;
            HB_BOOL closed = HB_FALSE;
            if( first )
                return HB_FALSE;
            index++;
            while( index < length )
            {
                if( ( unsigned char ) sql[ index++ ] == close )
                {
                    if( index < length && ( unsigned char ) sql[ index ] == close )
                        index++;
                    else
                    {
                        closed = HB_TRUE;
                        break;
                    }
                }
            }
            if( !closed )
                return HB_FALSE;
            continue;
        }
        if( byte == '(' )
            depth++;
        else if( byte == ')' )
        {
            if( !depth )
                return HB_FALSE;
            depth--;
        }
        else if( byte == ';' )
        {
            if( first || depth )
                return HB_FALSE;
            ended = HB_TRUE;
        }
        else if( byte == '@' && ( index + 1 >= length || sql[ index + 1 ] != '@' ) )
            return HB_FALSE;
        else if( byte == '@' )
            index++;
        else if( ( byte >= 'A' && byte <= 'Z' ) || ( byte >= 'a' && byte <= 'z' ) || byte == '_' )
        {
            char word[ 32 ];
            HB_SIZE size = 0;
            while( index < length )
            {
                byte = ( unsigned char ) sql[ index ];
                if( !( ( byte >= 'A' && byte <= 'Z' ) || ( byte >= 'a' && byte <= 'z' ) ||
                       ( byte >= '0' && byte <= '9' ) || byte == '_' ) )
                    break;
                if( size + 1 < sizeof( word ) )
                    word[ size++ ] = byte >= 'a' && byte <= 'z' ? byte - 32 : byte;
                index++;
            }
            word[ size ] = 0;
            if( first )
            {
                if( strcmp( word, "SELECT" ) && strcmp( word, "WITH" ) )
                    return HB_FALSE;
                first = HB_FALSE;
            }
            if( !strcmp( word, "INSERT" ) || !strcmp( word, "UPDATE" ) || !strcmp( word, "DELETE" ) ||
                !strcmp( word, "MERGE" ) || !strcmp( word, "INTO" ) || !strcmp( word, "EXEC" ) ||
                !strcmp( word, "EXECUTE" ) || !strcmp( word, "CREATE" ) || !strcmp( word, "ALTER" ) ||
                !strcmp( word, "DROP" ) || !strcmp( word, "TRUNCATE" ) || !strcmp( word, "DECLARE" ) ||
                !strcmp( word, "SET" ) || !strcmp( word, "USE" ) || !strcmp( word, "GRANT" ) ||
                !strcmp( word, "REVOKE" ) || !strcmp( word, "DENY" ) || !strcmp( word, "WAITFOR" ) ||
                !strcmp( word, "BACKUP" ) || !strcmp( word, "RESTORE" ) || !strcmp( word, "DBCC" ) ||
                !strcmp( word, "KILL" ) || !strcmp( word, "BEGIN" ) || !strcmp( word, "COMMIT" ) ||
                !strcmp( word, "ROLLBACK" ) || !strcmp( word, "SAVE" ) ||
                !strcmp( word, "PRINT" ) || !strcmp( word, "RETURN" ) || !strcmp( word, "SHUTDOWN" ) ||
                !strcmp( word, "RECONFIGURE" ) || !strcmp( word, "CHECKPOINT" ) || !strcmp( word, "IF" ) ||
                !strcmp( word, "WHILE" ) || !strcmp( word, "GOTO" ) || !strcmp( word, "THROW" ) ||
                !strcmp( word, "RAISERROR" ) || !strcmp( word, "BREAK" ) || !strcmp( word, "CONTINUE" ) ||
                !strcmp( word, "OPEN" ) || !strcmp( word, "CLOSE" ) || !strcmp( word, "FETCH" ) ||
                !strcmp( word, "DEALLOCATE" ) || !strcmp( word, "SEND" ) || !strcmp( word, "RECEIVE" ) ||
                !strcmp( word, "BULK" ) || !strcmp( word, "DUMP" ) || !strcmp( word, "LOAD" ) ||
                !strcmp( word, "READTEXT" ) || !strcmp( word, "WRITETEXT" ) || !strcmp( word, "UPDATETEXT" ) ||
                !strcmp( word, "ENABLE" ) || !strcmp( word, "DISABLE" ) || !strcmp( word, "GO" ) )
                return HB_FALSE;
            if( depth == 0 && !strcmp( word, "SELECT" ) )
            {
                if( selected && !setSelect )
                    return HB_FALSE;
                selected = HB_TRUE;
                setSelect = HB_FALSE;
            }
            else if( depth == 0 && ( !strcmp( word, "UNION" ) || !strcmp( word, "INTERSECT" ) ||
                                    !strcmp( word, "EXCEPT" ) ) )
                setSelect = HB_TRUE;
            else if( depth == 0 && strcmp( word, "ALL" ) && strcmp( word, "DISTINCT" ) )
                setSelect = HB_FALSE;
            continue;
        }
        index++;
    }
    return !first && selected && !setSelect && depth == 0;
}

static inline HB_BOOL HBBridgeTypedIsRequest( PHB_ITEM request )
{
    PHB_ITEM operation = HBBridgeTypedGet( request, "operation" );
    PHB_ITEM sql = HBBridgeTypedGet( request, "sql" );
    PHB_ITEM bindings = HBBridgeTypedGet( request, "bindings" );
    PHB_ITEM skip = HBBridgeTypedGet( request, "skipColumns" );
    PHB_ITEM limit = HBBridgeTypedGet( request, "rowLimit" );
    PHB_ITEM output = HBBridgeTypedGet( request, "output" );

    return request && HB_IS_HASH( request ) && hb_hashLen( request ) == 6 &&
        operation && HB_IS_STRING( operation ) &&
        ( ( hb_itemGetCLen( operation ) == sizeof( "hbbridge.querytyped.v1" ) - 1 &&
            !strcmp( hb_itemGetCPtr( operation ), "hbbridge.querytyped.v1" ) ) ||
          ( hb_itemGetCLen( operation ) == sizeof( "hbbridge.querytyped.count.v1" ) - 1 &&
            !strcmp( hb_itemGetCPtr( operation ), "hbbridge.querytyped.count.v1" ) ) ) &&
        sql && HB_IS_STRING( sql ) && hb_itemGetCLen( sql ) > 0 &&
        bindings && HB_IS_HASH( bindings ) && output && HB_IS_NIL( output ) &&
        skip && HB_IS_NUMERIC( skip ) && ( hb_itemGetND( skip ) == 0 || hb_itemGetND( skip ) == 1 ) &&
        limit && HB_IS_NUMERIC( limit ) && hb_itemGetND( limit ) >= 0 &&
        hb_itemGetND( limit ) <= 9007199254740991.0 &&
        hb_itemGetND( limit ) == ( double ) hb_itemGetNInt( limit ) &&
        ( strcmp( hb_itemGetCPtr( operation ), "hbbridge.querytyped.count.v1" ) ||
          ( hb_itemGetND( skip ) == 0 && hb_itemGetND( limit ) == 0 ) );
}

#endif
