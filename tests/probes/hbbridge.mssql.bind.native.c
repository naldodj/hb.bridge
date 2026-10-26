/* Released to Public Domain. Native ODBC proof, not a product connector. */
#include "hbapi.h"
#include "hbapiitm.h"
#include <windows.h>
#include <sql.h>
#include <sqlext.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <limits.h>

typedef struct
{
    SQLHENV environment;
    SQLHDBC connection;
    SQLHSTMT statement;
    HB_BOOL connected;
    PHB_ITEM report;
    PHB_ITEM checks;
    PHB_ITEM capabilities;
    unsigned int checkCount;
    unsigned int failureCount;
    unsigned int allocatedStatements;
    unsigned int releasedStatements;
    unsigned int statementReleaseFailures;
    SQLRETURN lastPrepareReturn;
} HBBindContext;

static void HBBindString( PHB_ITEM hash, const char * key, const char * text )
{
    PHB_ITEM itemKey = hb_itemPutC( NULL, key );
    PHB_ITEM itemValue = hb_itemPutC( NULL, text );
    hb_hashAdd( hash, itemKey, itemValue );
    hb_itemRelease( itemValue );
    hb_itemRelease( itemKey );
}

static void HBBindInteger( PHB_ITEM hash, const char * key, HB_MAXINT value )
{
    PHB_ITEM itemKey = hb_itemPutC( NULL, key );
    PHB_ITEM itemValue = hb_itemPutNInt( NULL, value );
    hb_hashAdd( hash, itemKey, itemValue );
    hb_itemRelease( itemValue );
    hb_itemRelease( itemKey );
}

static void HBBindLogical( PHB_ITEM hash, const char * key, HB_BOOL value )
{
    PHB_ITEM itemKey = hb_itemPutC( NULL, key );
    PHB_ITEM itemValue = hb_itemPutL( NULL, value );
    hb_hashAdd( hash, itemKey, itemValue );
    hb_itemRelease( itemValue );
    hb_itemRelease( itemKey );
}

static void HBBindHash( PHB_ITEM hash, const char * key, PHB_ITEM value )
{
    PHB_ITEM itemKey = hb_itemPutC( NULL, key );
    hb_hashAdd( hash, itemKey, value );
    hb_itemRelease( itemKey );
}

static HB_BOOL HBBindCheck( HBBindContext * context, const char * name, HB_BOOL passed )
{
    HBBindLogical( context->checks, name, passed );
    context->checkCount++;
    if( !passed )
        context->failureCount++;
    return passed;
}

static void HBBindState( HBBindContext * context, SQLSMALLINT type, SQLHANDLE handle, const char * key )
{
    SQLCHAR state[ 6 ] = { 0 };
    SQLINTEGER nativeCode;
    /* The diagnostic message can contain private values; never retrieve it. */
    if( SQL_SUCCEEDED( SQLGetDiagRecA( type, handle, 1, state, &nativeCode, NULL, 0, NULL ) ) )
        HBBindString( context->report, key, ( const char * ) state );
}

static HB_BOOL HBBindReleaseStatement( HBBindContext * context )
{
    if( context->statement == SQL_NULL_HSTMT )
        return HB_TRUE;
    if( !SQL_SUCCEEDED( SQLFreeHandle( SQL_HANDLE_STMT, context->statement ) ) )
    {
        context->statementReleaseFailures++;
        return HB_FALSE;
    }
    context->releasedStatements++;
    context->statement = SQL_NULL_HSTMT;
    return HB_TRUE;
}

static HB_BOOL HBBindPrepare( HBBindContext * context, const char * sql, SQLSMALLINT expected )
{
    SQLSMALLINT count = -1;
    context->lastPrepareReturn = SQL_NO_DATA;
    if( !HBBindReleaseStatement( context ) )
        return HB_FALSE;
    if( !SQL_SUCCEEDED( SQLAllocHandle( SQL_HANDLE_STMT, context->connection, &context->statement ) ) )
        return HB_FALSE;
    context->allocatedStatements++;
    if( !SQL_SUCCEEDED( SQLSetStmtAttr( context->statement, SQL_ATTR_QUERY_TIMEOUT, ( SQLPOINTER ) ( uintptr_t ) 15, 0 ) ) )
        return HB_FALSE;
    context->lastPrepareReturn = SQLPrepareA( context->statement, ( SQLCHAR * ) sql, SQL_NTS );
    if( !SQL_SUCCEEDED( context->lastPrepareReturn ) ||
        !SQL_SUCCEEDED( SQLNumParams( context->statement, &count ) ) )
    {
        HBBindState( context, SQL_HANDLE_STMT, context->statement, "lastNativeSQLState" );
        return HB_FALSE;
    }
    return count == expected;
}

static HB_BOOL HBBindExecute( HBBindContext * context )
{
    if( !SQL_SUCCEEDED( SQLExecute( context->statement ) ) ||
        !SQL_SUCCEEDED( SQLFetch( context->statement ) ) )
    {
        HBBindState( context, SQL_HANDLE_STMT, context->statement, "lastNativeSQLState" );
        return HB_FALSE;
    }
    return HB_TRUE;
}

static HB_BOOL HBBindScalar( HBBindContext * context, const char * sql, SQLSMALLINT cType,
    SQLSMALLINT sqlType, SQLULEN precision, SQLSMALLINT scale, SQLPOINTER input,
    SQLLEN bufferSize, SQLLEN * indicator, SQLPOINTER output, SQLLEN outputSize )
{
    SQLLEN outputLength = 0;
    if( !HBBindPrepare( context, sql, 1 ) ||
        !SQL_SUCCEEDED( SQLBindParameter( context->statement, 1, SQL_PARAM_INPUT, cType,
            sqlType, precision, scale, input, bufferSize, indicator ) ) || !HBBindExecute( context ) )
        return HB_FALSE;
    return SQLGetData( context->statement, 1, cType, output, outputSize, &outputLength ) == SQL_SUCCESS &&
        outputLength != SQL_NULL_DATA && SQLFetch( context->statement ) == SQL_NO_DATA;
}

static HB_BOOL HBBindText( HBBindContext * context, const SQLWCHAR * input, SQLULEN units,
    const char * utf8Input, int utf8Bytes )
{
    char utf8Output[ 256 ] = { 0 };

    HB_BOOL passed;

    SQLWCHAR output[ 128 ] = { 0 };
    SQLINTEGER bytesOnServer = -1;
    SQLLEN inputLength = ( SQLLEN ) ( units * sizeof( SQLWCHAR ) );
    SQLLEN outputLength = -1;
    SQLLEN lengthIndicator = 0;
    SQLULEN size = units == 0 ? 1 : units;
    passed = HBBindPrepare( context,
        "SELECT CAST(? AS NVARCHAR(64)) AS V, DATALENGTH(CAST(? AS NVARCHAR(64))) AS L", 2 ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 1, SQL_PARAM_INPUT, SQL_C_WCHAR,
            SQL_WVARCHAR, size, 0, ( SQLPOINTER ) input, inputLength + sizeof( SQLWCHAR ), &inputLength ) ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 2, SQL_PARAM_INPUT, SQL_C_WCHAR,
            SQL_WVARCHAR, size, 0, ( SQLPOINTER ) input, inputLength + sizeof( SQLWCHAR ), &inputLength ) ) &&
        HBBindExecute( context ) &&
        SQLGetData( context->statement, 1, SQL_C_WCHAR, output, sizeof( output ), &outputLength ) == SQL_SUCCESS &&
        outputLength == inputLength && memcmp( input, output, ( size_t ) inputLength ) == 0 &&
        SQLGetData( context->statement, 2, SQL_C_SLONG, &bytesOnServer,
            sizeof( bytesOnServer ), &lengthIndicator ) == SQL_SUCCESS &&
        bytesOnServer == inputLength && SQLFetch( context->statement ) == SQL_NO_DATA;
    if( passed && units != 0 )
    {
        int bytes = WideCharToMultiByte( CP_UTF8, WC_ERR_INVALID_CHARS, ( const WCHAR * ) output,
            ( int ) units, utf8Output, sizeof( utf8Output ), NULL, NULL );
        passed = bytes == utf8Bytes && memcmp( utf8Input, utf8Output, ( size_t ) utf8Bytes ) == 0;
    }
    /* Stack indicators and caller buffers remain alive through descriptor cleanup. */
    return HBBindReleaseStatement( context ) && passed;
}

static HB_BOOL HBBindStateClass( HBBindContext * context, const char * expected )
{
    SQLCHAR state[ 6 ] = { 0 };
    SQLINTEGER code = 0;

    return context->statement != SQL_NULL_HSTMT &&
        SQL_SUCCEEDED( SQLGetDiagRecA( SQL_HANDLE_STMT, context->statement, 1, state, &code, NULL, 0, NULL ) ) &&
        memcmp( state, expected, 2 ) == 0;
}

static HB_BOOL HBBindConversionError( HBBindContext * context, const char * sql,
    SQLSMALLINT cType, SQLSMALLINT sqlType, SQLULEN precision, SQLSMALLINT scale,
    SQLPOINTER input, SQLLEN size, SQLLEN inputLength, const char * stateKey )
{
    HB_BOOL passed = HBBindPrepare( context, sql, 1 );

    SQLRETURN result = SQL_NO_DATA;

    if( passed )
    {
        result = SQLBindParameter( context->statement, 1, SQL_PARAM_INPUT, cType,
            sqlType, precision, scale, input, size, &inputLength );
        if( SQL_SUCCEEDED( result ) )
            result = SQLExecute( context->statement );
        passed = result == SQL_ERROR && HBBindStateClass( context, "22" );
        HBBindState( context, SQL_HANDLE_STMT, context->statement, stateKey );
    }
    return HBBindReleaseStatement( context ) && passed;
}

static HB_BOOL HBBindUTF8Text( HBBindContext * context, const char * input, int bytes, int expectedUnits )
{
    SQLWCHAR * wide;
    int units = bytes == 0 ? 0 : MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, input, bytes, NULL, 0 );
    HB_BOOL passed;
    if( units != expectedUnits )
        return HB_FALSE;
    wide = ( SQLWCHAR * ) hb_xgrabz( ( units + 1 ) * sizeof( SQLWCHAR ) );
    passed = bytes == 0 || MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, input, bytes,
        ( WCHAR * ) wide, units ) == units;
    if( passed )
        passed = HBBindText( context, wide, ( SQLULEN ) units, input, bytes );
    /* Release the descriptors before releasing buffers supplied to the driver. */
    if( context->statement != SQL_NULL_HSTMT )
    {
        passed = HBBindReleaseStatement( context ) && passed;
    }
    hb_xfree( wide );
    return passed;
}

static HB_BOOL HBBindNull( HBBindContext * context, const char * sql, SQLSMALLINT cType,
    SQLSMALLINT sqlType, SQLULEN precision, SQLSMALLINT scale )
{
    char output[ 64 ] = { 0 };

    HB_BOOL passed;

    SQLLEN inputLength = SQL_NULL_DATA;
    SQLLEN outputLength = 0;

    passed = HBBindPrepare( context, sql, 1 ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 1, SQL_PARAM_INPUT, cType,
            sqlType, precision, scale, NULL, 0, &inputLength ) ) && HBBindExecute( context ) &&
        SQLGetData( context->statement, 1, SQL_C_CHAR, output, sizeof( output ), &outputLength ) == SQL_SUCCESS &&
        outputLength == SQL_NULL_DATA && SQLFetch( context->statement ) == SQL_NO_DATA;
    return HBBindReleaseStatement( context ) && passed;
}

static HB_BOOL HBBindCommand( HBBindContext * context, const char * sql )
{
    HB_BOOL passed = HBBindReleaseStatement( context );

    if( passed )
    {
        passed = SQL_SUCCEEDED( SQLAllocHandle( SQL_HANDLE_STMT, context->connection, &context->statement ) );
        if( passed )
        {
            context->allocatedStatements++;
            /* SQL Server prepared DDL can scope #tables to its internal procedure. */
            passed = SQL_SUCCEEDED( SQLSetStmtAttr( context->statement, SQL_ATTR_QUERY_TIMEOUT,
                ( SQLPOINTER ) ( uintptr_t ) 15, 0 ) ) &&
                SQL_SUCCEEDED( SQLExecDirectA( context->statement, ( SQLCHAR * ) sql, SQL_NTS ) );
        }
    }

    if( !passed && context->statement != SQL_NULL_HSTMT )
        HBBindState( context, SQL_HANDLE_STMT, context->statement, "lastNativeSQLState" );
    return HBBindReleaseStatement( context ) && passed;
}

static HB_BOOL HBBindDeclaredMetadata( HBBindContext * context, const char * key )
{
    /* ODBC exposes columns by ordinal; this fixed array describes the native fixture. */
    static const struct
    {
        const char * name;
        SQLSMALLINT type;
        SQLULEN precision;
        SQLSMALLINT scale;
    } expected[] = {
        { "TXT", SQL_WVARCHAR, 64, 0 },
        { "AMOUNT", SQL_DECIMAL, 38, 8 },
        { "BIG_VALUE", SQL_BIGINT, 19, 0 },
        { "FLAG", SQL_BIT, 1, 0 },
        { "DAY", SQL_TYPE_DATE, 10, 0 },
        { "APPROX", SQL_DOUBLE, 53, 0 }
    };
    const SQLUSMALLINT columnCount = sizeof( expected ) / sizeof( expected[ 0 ] );

    HB_BOOL passed = HB_TRUE;

    PHB_ITEM metadata = hb_hashNew( NULL );

    SQLSMALLINT nativeCount = 0;
    SQLUSMALLINT column;

    passed = SQL_SUCCEEDED( SQLNumResultCols( context->statement, &nativeCount ) ) && nativeCount == columnCount;
    for( column = 1; passed && column <= columnCount; column++ )
    {
        char name[ 128 ] = { 0 };

        PHB_ITEM field = hb_hashNew( NULL );

        SQLLEN octets = -1;
        SQLLEN radix = -1;
        SQLSMALLINT nameLength = 0, type = 0, scale = -1, nullable = SQL_NULLABLE_UNKNOWN;
        SQLULEN precision = 0;
        SQLWCHAR wideName[ 128 ] = { 0 };

        passed = SQLDescribeColW( context->statement, column, wideName, sizeof( wideName ) / sizeof( wideName[ 0 ] ),
            &nameLength, &type, &precision, &scale, &nullable ) == SQL_SUCCESS &&
            WideCharToMultiByte( CP_UTF8, WC_ERR_INVALID_CHARS, ( const WCHAR * ) wideName,
                nameLength, name, sizeof( name ) - 1, NULL, NULL ) > 0 &&
            strcmp( name, expected[ column - 1 ].name ) == 0 && nullable == SQL_NULLABLE &&
            ( type == expected[ column - 1 ].type ||
                ( column == columnCount && type == SQL_FLOAT ) ) &&
            precision == expected[ column - 1 ].precision && scale == expected[ column - 1 ].scale;
        HBBindString( field, "name", name );
        HBBindInteger( field, "typeCode", type );
        HBBindInteger( field, "precision", ( HB_MAXINT ) precision );
        HBBindInteger( field, "scale", scale );
        HBBindInteger( field, "nullableCode", nullable );
        if( SQL_SUCCEEDED( SQLColAttributeA( context->statement, column, SQL_DESC_OCTET_LENGTH,
            NULL, 0, NULL, &octets ) ) )
        {
            HBBindInteger( field, "octetLength", ( HB_MAXINT ) octets );
            if( column == 1 )
                passed = passed && octets == 128;
        }
        else if( column == 1 )
            passed = HB_FALSE;
        if( SQL_SUCCEEDED( SQLColAttributeA( context->statement, column, SQL_DESC_NUM_PREC_RADIX,
            NULL, 0, NULL, &radix ) ) )
        {
            HBBindInteger( field, "precisionRadix", ( HB_MAXINT ) radix );
            if( column == columnCount )
                passed = passed && radix == 2;
        }
        else if( column == columnCount )
            passed = HB_FALSE;
        HBBindHash( metadata, expected[ column - 1 ].name, field );
        hb_itemRelease( field );
    }
    HBBindHash( context->report, key, metadata );
    hb_itemRelease( metadata );
    return passed;
}

static HB_BOOL HBBindDeclaredRows( HBBindContext * context )
{
    char decimalInput[] = "-123456789012345678901234567890.12345678";

    HB_BOOL passed;

    SQLWCHAR text[] = { 'a', 0x00e7, 0x00e3, 'o', 0, 0xd83d, 0xde80, 0 };
    SQLCHAR bit = 1;
    SQL_DATE_STRUCT date = { 2024, 2, 29 };
    SQLDOUBLE approximate = 1.2345678901234567;
    SQLINTEGER id = 1;
    SQLBIGINT large = -INT64_C( 9223372036854775807 ) - 1;
    /* The ODBC API requires persistent per-ordinal indicator slots until close. */
    SQLLEN lengths[ 7 ] = { 0, SQL_NULL_DATA, SQL_NULL_DATA, SQL_NULL_DATA,
        SQL_NULL_DATA, SQL_NULL_DATA, SQL_NULL_DATA };
    SQLLEN affected = -1;

    passed = HBBindPrepare( context,
        "INSERT INTO #hbbridge_bind_probe(ID,TXT,AMOUNT,BIG_VALUE,FLAG,DAY,APPROX) VALUES(?,?,?,?,?,?,?)", 7 ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 1, SQL_PARAM_INPUT, SQL_C_SLONG,
            SQL_INTEGER, 10, 0, &id, sizeof( id ), &lengths[ 0 ] ) ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 2, SQL_PARAM_INPUT, SQL_C_WCHAR,
            SQL_WVARCHAR, 64, 0, text, sizeof( text ), &lengths[ 1 ] ) ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 3, SQL_PARAM_INPUT, SQL_C_CHAR,
            SQL_DECIMAL, 38, 8, decimalInput, sizeof( decimalInput ), &lengths[ 2 ] ) ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 4, SQL_PARAM_INPUT, SQL_C_SBIGINT,
            SQL_BIGINT, 19, 0, &large, sizeof( large ), &lengths[ 3 ] ) ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 5, SQL_PARAM_INPUT, SQL_C_BIT,
            SQL_BIT, 1, 0, &bit, sizeof( bit ), &lengths[ 4 ] ) ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 6, SQL_PARAM_INPUT, SQL_C_TYPE_DATE,
            SQL_TYPE_DATE, 10, 0, &date, sizeof( date ), &lengths[ 5 ] ) ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 7, SQL_PARAM_INPUT, SQL_C_DOUBLE,
            SQL_DOUBLE, 15, 0, &approximate, sizeof( approximate ), &lengths[ 6 ] ) );
    HBBindCheck( context, "declaredInsertPreparedAndBound", passed );
    if( passed )
    {
        passed = SQL_SUCCEEDED( SQLExecute( context->statement ) ) &&
            SQL_SUCCEEDED( SQLRowCount( context->statement, &affected ) ) && affected == 1 &&
            SQL_SUCCEEDED( SQLFreeStmt( context->statement, SQL_CLOSE ) );
        HBBindCheck( context, "declaredTypedNullRowInserted", passed );
    }
    if( passed )
    {
        id = 2;
        lengths[ 1 ] = 7 * sizeof( SQLWCHAR );
        lengths[ 2 ] = sizeof( decimalInput ) - 1;
        lengths[ 3 ] = lengths[ 4 ] = lengths[ 5 ] = lengths[ 6 ] = 0;
        passed = SQL_SUCCEEDED( SQLExecute( context->statement ) ) &&
            SQL_SUCCEEDED( SQLRowCount( context->statement, &affected ) ) && affected == 1 &&
            SQL_SUCCEEDED( SQLFreeStmt( context->statement, SQL_CLOSE ) );
        HBBindCheck( context, "declaredExactValuesRowInserted", passed );
    }
    if( passed )
    {
        id = 3;
        lengths[ 1 ] = 0;
        strcpy( decimalInput, "0.00000000" );
        lengths[ 2 ] = strlen( decimalInput );
        large = 0;
        bit = 0;
        approximate = 0;
        lengths[ 5 ] = SQL_NULL_DATA;
        passed = SQL_SUCCEEDED( SQLExecute( context->statement ) ) &&
            SQL_SUCCEEDED( SQLRowCount( context->statement, &affected ) ) && affected == 1;
        HBBindCheck( context, "declaredEmptyZeroFalseRowInserted", passed );
    }
    return HBBindReleaseStatement( context ) && passed;
}

static HB_BOOL HBBindNullColumns( HBBindContext * context )
{
    char buffer[ 128 ];

    SQLLEN length = 0;
    SQLUSMALLINT column;

    for( column = 1; column <= 6; column++ )
    {
        memset( buffer, 0x7f, sizeof( buffer ) );
        if( SQLGetData( context->statement, column, SQL_C_CHAR, buffer, sizeof( buffer ), &length ) != SQL_SUCCESS ||
            length != SQL_NULL_DATA )
            return HB_FALSE;
    }
    return HB_TRUE;
}

static void HBBindDeclaredCases( HBBindContext * context )
{
    char decimal[ 64 ] = { 0 };

    HB_BOOL passed;

    SQLWCHAR text[ 64 ] = { 0 };
    const SQLWCHAR expectedText[] = { 'a', 0x00e7, 0x00e3, 'o', 0, 0xd83d, 0xde80 };
    SQLCHAR bit = 0;
    SQL_DATE_STRUCT date = { 0, 0, 0 };
    SQLDOUBLE approximate = 0;
    SQLBIGINT large = 0;
    SQLLEN length = -1;

    passed = HBBindCommand( context,
        "CREATE TABLE #hbbridge_bind_probe (ID INT NOT NULL,TXT NVARCHAR(64) NULL,AMOUNT DECIMAL(38,8) NULL,"
        "BIG_VALUE BIGINT NULL,FLAG BIT NULL,DAY DATE NULL,APPROX FLOAT NULL)" );
    HBBindCheck( context, "sessionTemporaryTableCreated", passed );
    if( !passed )
        return;
    if( !HBBindDeclaredRows( context ) )
        goto cleanup;
    passed = HBBindPrepare( context,
        "SELECT TXT,AMOUNT,BIG_VALUE,FLAG,DAY,APPROX FROM #hbbridge_bind_probe ORDER BY ID", 0 );
    HBBindCheck( context, "declaredResultPrepared", passed );
    if( !passed )
        goto cleanup;
    HBBindCheck( context, "declaredMetadataBeforeFetch", HBBindDeclaredMetadata( context, "declaredMetadata" ) );
    passed = HBBindExecute( context );
    HBBindCheck( context, "declaredFirstRowFetched", passed );
    if( !passed )
        goto cleanup;
    HBBindCheck( context, "declaredFirstRowAllNull", HBBindNullColumns( context ) );
    passed = SQLFetch( context->statement ) == SQL_SUCCESS;
    HBBindCheck( context, "declaredSecondRowFetched", passed );
    if( !passed )
        goto cleanup;
    HBBindCheck( context, "declaredUnicodeSupplementaryAndNul", SQLGetData( context->statement, 1,
        SQL_C_WCHAR, text, sizeof( text ), &length ) == SQL_SUCCESS && length == sizeof( expectedText ) &&
        memcmp( text, expectedText, sizeof( expectedText ) ) == 0 );
    HBBindCheck( context, "declaredNegativeDecimal38Exact", SQLGetData( context->statement, 2,
        SQL_C_CHAR, decimal, sizeof( decimal ), &length ) == SQL_SUCCESS &&
        strcmp( decimal, "-123456789012345678901234567890.12345678" ) == 0 );
    HBBindCheck( context, "declaredInt64MinimumExact", SQLGetData( context->statement, 3,
        SQL_C_SBIGINT, &large, sizeof( large ), &length ) == SQL_SUCCESS &&
        length != SQL_NULL_DATA && large == -INT64_C( 9223372036854775807 ) - 1 );
    HBBindCheck( context, "declaredBooleanTrue", SQLGetData( context->statement, 4,
        SQL_C_BIT, &bit, sizeof( bit ), &length ) == SQL_SUCCESS && length != SQL_NULL_DATA && bit == 1 );
    HBBindCheck( context, "declaredDateLeapDay", SQLGetData( context->statement, 5,
        SQL_C_TYPE_DATE, &date, sizeof( date ), &length ) == SQL_SUCCESS && length != SQL_NULL_DATA &&
        date.year == 2024 && date.month == 2 && date.day == 29 );
    HBBindCheck( context, "declaredFloatValue", SQLGetData( context->statement, 6,
        SQL_C_DOUBLE, &approximate, sizeof( approximate ), &length ) == SQL_SUCCESS &&
        length != SQL_NULL_DATA && approximate == 1.2345678901234567 );
    passed = SQLFetch( context->statement ) == SQL_SUCCESS;
    HBBindCheck( context, "declaredThirdRowFetched", passed );
    if( !passed )
        goto cleanup;
    HBBindCheck( context, "declaredEmptyTextIsNotNull", SQLGetData( context->statement, 1,
        SQL_C_WCHAR, text, sizeof( text ), &length ) == SQL_SUCCESS && length == 0 && text[ 0 ] == 0 );
    HBBindCheck( context, "declaredZeroDecimalKeepsScale", SQLGetData( context->statement, 2,
        SQL_C_CHAR, decimal, sizeof( decimal ), &length ) == SQL_SUCCESS &&
        ( strcmp( decimal, "0.00000000" ) == 0 || strcmp( decimal, ".00000000" ) == 0 ) );
    HBBindString( context->report, "nativeFixtureZeroDecimalText", decimal );
    HBBindCheck( context, "declaredIntegerZeroIsNotNull", SQLGetData( context->statement, 3,
        SQL_C_SBIGINT, &large, sizeof( large ), &length ) == SQL_SUCCESS && length != SQL_NULL_DATA && large == 0 );
    HBBindCheck( context, "declaredBooleanFalseIsNotNull", SQLGetData( context->statement, 4,
        SQL_C_BIT, &bit, sizeof( bit ), &length ) == SQL_SUCCESS && length != SQL_NULL_DATA && bit == 0 );
    HBBindCheck( context, "declaredDateNull", SQLGetData( context->statement, 5,
        SQL_C_TYPE_DATE, &date, sizeof( date ), &length ) == SQL_SUCCESS && length == SQL_NULL_DATA );
    HBBindCheck( context, "declaredFloatZeroIsNotNull", SQLGetData( context->statement, 6,
        SQL_C_DOUBLE, &approximate, sizeof( approximate ), &length ) == SQL_SUCCESS &&
        length != SQL_NULL_DATA && approximate == 0 );
    HBBindCheck( context, "declaredResultEnds", SQLFetch( context->statement ) == SQL_NO_DATA );
    {
        SQLINTEGER input = 1;
        const SQLINTEGER snapshot = input;
        SQLINTEGER pageId = 0;
        SQLINTEGER count = 0;
        SQLLEN indicator = 0;

        input = 100;
        HBBindCheck( context, "pageUsesOriginalBindingSnapshot", HBBindScalar( context,
            "SELECT ID FROM #hbbridge_bind_probe WHERE ID>? ORDER BY ID OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY",
            SQL_C_SLONG, SQL_INTEGER, 10, 0, ( SQLPOINTER ) &snapshot, sizeof( snapshot ), &indicator,
            &pageId, sizeof( pageId ) ) && pageId == 2 && input == 100 );
        HBBindCheck( context, "countIndependentlyBindsSameSnapshot", HBBindScalar( context,
            "SELECT COUNT(*) FROM #hbbridge_bind_probe WHERE ID>?", SQL_C_SLONG, SQL_INTEGER,
            10, 0, ( SQLPOINTER ) &snapshot, sizeof( snapshot ), &indicator, &count, sizeof( count ) ) && count == 2 );
        HBBindCheck( context, "pageCountDescriptorsReleasedBeforeSnapshotLeavesScope", HBBindReleaseStatement( context ) );
    }
    passed = HBBindPrepare( context,
        "SELECT TXT,AMOUNT,BIG_VALUE,FLAG,DAY,APPROX FROM #hbbridge_bind_probe WHERE ID=1", 0 );
    HBBindCheck( context, "allNullResultPrepared", passed );
    if( passed )
    {
        HBBindCheck( context, "allNullMetadataBeforeFetch", HBBindDeclaredMetadata( context, "allNullMetadata" ) );
        HBBindCheck( context, "allNullResultPreserved", HBBindExecute( context ) && HBBindNullColumns( context ) &&
            SQLFetch( context->statement ) == SQL_NO_DATA );
    }
    passed = HBBindPrepare( context,
        "SELECT TXT,AMOUNT,BIG_VALUE,FLAG,DAY,APPROX FROM #hbbridge_bind_probe WHERE ID>100", 0 );
    HBBindCheck( context, "emptyResultPrepared", passed );
    if( passed )
    {
        HBBindCheck( context, "emptyMetadataBeforeFetch", HBBindDeclaredMetadata( context, "emptyMetadata" ) );
        HBBindCheck( context, "emptyResultEndsWithoutInventedRow", SQL_SUCCEEDED( SQLExecute( context->statement ) ) &&
            SQLFetch( context->statement ) == SQL_NO_DATA );
    }

cleanup:
    HBBindCheck( context, "sessionTemporaryTableDropped", HBBindCommand( context, "DROP TABLE #hbbridge_bind_probe" ) );
}

static void HBBindCases( HBBindContext * context )
{
    SQLINTEGER integerInput = -2147483647;
    SQLINTEGER integerOutput = 0;
    SQLDOUBLE doubleInput = 1.2345678901234567;
    SQLDOUBLE doubleOutput = 0;
    SQLCHAR bitInput = 1;
    SQLCHAR bitOutput = 0;
    SQL_DATE_STRUCT dateInput = { 2024, 2, 29 };
    SQL_DATE_STRUCT dateOutput = { 0, 0, 0 };
    SQLBIGINT integer64Input = INT64_C( 9223372036854775807 );
    SQLBIGINT integer64Output = 0;
    SQLLEN indicator = 0;
    SQLLEN outputLength = 0;
    SQLWCHAR nullOutput[ 32 ] = { 0 };
    SQLWCHAR empty[] = { 0 };
    char decimalInput[] = "123456789012345678901234567890.12345678";
    char decimalOutput[ 64 ] = { 0 };
    char overflowInteger[] = "9223372036854775808";
    char overflowDecimal[] = "1000.00";
    HB_BOOL passed;

    passed = HBBindScalar( context, "SELECT CAST(? AS INT)", SQL_C_SLONG, SQL_INTEGER,
        10, 0, &integerInput, sizeof( integerInput ), &indicator, &integerOutput, sizeof( integerOutput ) ) &&
        integerOutput == integerInput;
    HBBindCheck( context, "integerValue", passed );
    HBBindLogical( context->capabilities, "integer", passed );
    passed = HBBindScalar( context, "SELECT CAST(? AS FLOAT)", SQL_C_DOUBLE, SQL_DOUBLE,
        15, 0, &doubleInput, sizeof( doubleInput ), &indicator, &doubleOutput, sizeof( doubleOutput ) ) &&
        doubleOutput == doubleInput;
    HBBindCheck( context, "floatValue", passed );
    HBBindLogical( context->capabilities, "float", passed );
    passed = HBBindScalar( context, "SELECT CAST(? AS BIT)", SQL_C_BIT, SQL_BIT,
        1, 0, &bitInput, sizeof( bitInput ), &indicator, &bitOutput, sizeof( bitOutput ) ) && bitOutput == bitInput;
    HBBindCheck( context, "booleanTrue", passed );
    HBBindLogical( context->capabilities, "boolean", passed );
    bitInput = 0;
    HBBindCheck( context, "booleanFalse", HBBindScalar( context, "SELECT CAST(? AS BIT)", SQL_C_BIT, SQL_BIT,
        1, 0, &bitInput, sizeof( bitInput ), &indicator, &bitOutput, sizeof( bitOutput ) ) && bitOutput == bitInput );
    passed = HBBindScalar( context, "SELECT CAST(? AS DATE)", SQL_C_TYPE_DATE, SQL_TYPE_DATE,
        10, 0, &dateInput, sizeof( dateInput ), &indicator, &dateOutput, sizeof( dateOutput ) ) &&
        dateInput.year == dateOutput.year && dateInput.month == dateOutput.month && dateInput.day == dateOutput.day;
    HBBindCheck( context, "dateLeapDay", passed );
    HBBindLogical( context->capabilities, "date", passed );
    passed = HBBindScalar( context, "SELECT CAST(? AS BIGINT)", SQL_C_SBIGINT, SQL_BIGINT,
        19, 0, &integer64Input, sizeof( integer64Input ), &indicator, &integer64Output, sizeof( integer64Output ) ) &&
        integer64Output == integer64Input;
    HBBindCheck( context, "int64MaximumExact", passed );
    HBBindLogical( context->capabilities, "int64", passed );
    integer64Input = -INT64_C( 9223372036854775807 ) - 1;
    HBBindCheck( context, "int64MinimumExact", HBBindScalar( context, "SELECT CAST(? AS BIGINT)",
        SQL_C_SBIGINT, SQL_BIGINT, 19, 0, &integer64Input, sizeof( integer64Input ), &indicator,
        &integer64Output, sizeof( integer64Output ) ) && integer64Output == integer64Input );
    integer64Input = INT64_C( 9007199254740991 );
    HBBindCheck( context, "safeIntegerMaximumExact", HBBindScalar( context, "SELECT CAST(? AS BIGINT)",
        SQL_C_SBIGINT, SQL_BIGINT, 19, 0, &integer64Input, sizeof( integer64Input ), &indicator,
        &integer64Output, sizeof( integer64Output ) ) && integer64Output == integer64Input );
    integer64Input = -INT64_C( 9007199254740991 );
    HBBindCheck( context, "safeIntegerMinimumExact", HBBindScalar( context, "SELECT CAST(? AS BIGINT)",
        SQL_C_SBIGINT, SQL_BIGINT, 19, 0, &integer64Input, sizeof( integer64Input ), &indicator,
        &integer64Output, sizeof( integer64Output ) ) && integer64Output == integer64Input );
    indicator = sizeof( decimalInput ) - 1;
    passed = HBBindScalar( context, "SELECT CAST(? AS DECIMAL(38,8))", SQL_C_CHAR, SQL_DECIMAL,
        38, 8, decimalInput, sizeof( decimalInput ), &indicator, decimalOutput, sizeof( decimalOutput ) ) &&
        strcmp( decimalInput, decimalOutput ) == 0;
    HBBindCheck( context, "decimal38ExactText", passed );
    HBBindLogical( context->capabilities, "decimal", passed );
    HBBindString( context->capabilities, "decimalBinding", "SQL_C_CHAR to SQL_DECIMAL(38,8); exact ASCII, no binary64 conversion" );
    HBBindCheck( context, "unicodeAccent", HBBindUTF8Text( context, "a\xc3\xa7\xc3\xa3o", 6, 4 ) );
    HBBindCheck( context, "unicodeSupplementary", HBBindUTF8Text( context, "\xf0\x9f\x9a\x80", 4, 2 ) );
    HBBindCheck( context, "unicodeEmbeddedNul", HBBindUTF8Text( context, "A\0B", 3, 3 ) );
    HBBindCheck( context, "unicodeLeadingNul", HBBindUTF8Text( context, "\0AB", 3, 3 ) );
    HBBindCheck( context, "unicodeTrailingNul", HBBindUTF8Text( context, "AB\0", 3, 3 ) );
    HBBindCheck( context, "unicodeOnlyNul", HBBindUTF8Text( context, "\0", 1, 1 ) );
    HBBindCheck( context, "unicodeEmpty", HBBindUTF8Text( context, "", 0, 0 ) );
    HBBindString( context->capabilities, "textBinding", "SQL_C_WCHAR/SQL_WVARCHAR; explicit UTF-16 code units and byte indicators" );

    indicator = SQL_NULL_DATA;
    passed = HBBindPrepare( context, "SELECT CAST(? AS NVARCHAR(32))", 1 ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 1, SQL_PARAM_INPUT, SQL_C_WCHAR,
            SQL_WVARCHAR, 32, 0, empty, sizeof( empty ), &indicator ) ) && HBBindExecute( context ) &&
        SQL_SUCCEEDED( SQLGetData( context->statement, 1, SQL_C_WCHAR, nullOutput, sizeof( nullOutput ), &outputLength ) ) &&
        outputLength == SQL_NULL_DATA && SQLFetch( context->statement ) == SQL_NO_DATA;
    HBBindCheck( context, "typedTextNull", passed );
    HBBindLogical( context->capabilities, "null", passed );
    HBBindCheck( context, "typedIntegerNull", HBBindNull( context, "SELECT CAST(? AS BIGINT)",
        SQL_C_SBIGINT, SQL_BIGINT, 19, 0 ) );
    HBBindCheck( context, "typedDecimalNull", HBBindNull( context, "SELECT CAST(? AS DECIMAL(38,8))",
        SQL_C_CHAR, SQL_DECIMAL, 38, 8 ) );
    HBBindCheck( context, "typedFloatNull", HBBindNull( context, "SELECT CAST(? AS FLOAT)",
        SQL_C_DOUBLE, SQL_DOUBLE, 15, 0 ) );
    HBBindCheck( context, "typedBooleanNull", HBBindNull( context, "SELECT CAST(? AS BIT)",
        SQL_C_BIT, SQL_BIT, 1, 0 ) );
    HBBindCheck( context, "typedDateNull", HBBindNull( context, "SELECT CAST(? AS DATE)",
        SQL_C_TYPE_DATE, SQL_TYPE_DATE, 10, 0 ) );

    indicator = 0;
    passed = HBBindPrepare( context, "SELECT '?' AS L, CAST(? AS INT) AS V /* ? */ -- ?\n", 1 ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 1, SQL_PARAM_INPUT, SQL_C_SLONG,
            SQL_INTEGER, 10, 0, &integerInput, sizeof( integerInput ), &indicator ) ) && HBBindExecute( context );
    if( passed )
    {
        char literal[ 4 ] = { 0 };
        passed = SQL_SUCCEEDED( SQLGetData( context->statement, 1, SQL_C_CHAR, literal, sizeof( literal ), &outputLength ) ) &&
            strcmp( literal, "?" ) == 0 && SQL_SUCCEEDED( SQLGetData( context->statement, 2, SQL_C_SLONG,
                &integerOutput, sizeof( integerOutput ), &outputLength ) ) && integerOutput == integerInput;
    }
    HBBindCheck( context, "nativeMarkerCountIgnoresLiteralsAndComments", passed );
    passed = HBBindPrepare( context, "SELECT CAST(? AS INT) + CAST(? AS INT)", 2 ) &&
        SQL_SUCCEEDED( SQLBindParameter( context->statement, 1, SQL_PARAM_INPUT, SQL_C_SLONG,
            SQL_INTEGER, 10, 0, &integerInput, sizeof( integerInput ), &indicator ) ) &&
        SQLExecute( context->statement ) == SQL_ERROR;
    HBBindCheck( context, "missingBindingRejected", passed );
    if( passed )
        HBBindState( context, SQL_HANDLE_STMT, context->statement, "missingBindingSQLState" );
    HBBindCheck( context, "recoveryAfterMissingBinding", HBBindScalar( context, "SELECT CAST(? AS INT)",
        SQL_C_SLONG, SQL_INTEGER, 10, 0, &integerInput, sizeof( integerInput ), &indicator,
        &integerOutput, sizeof( integerOutput ) ) && integerOutput == integerInput );
    passed = HBBindPrepare( context, "SELECT FROM", 0 );
    passed = ( passed ? SQLExecute( context->statement ) : context->lastPrepareReturn ) == SQL_ERROR &&
        HBBindStateClass( context, "42" );
    HBBindCheck( context, "invalidSqlRejected", passed );
    if( context->statement != SQL_NULL_HSTMT )
        HBBindState( context, SQL_HANDLE_STMT, context->statement, "invalidSqlSQLState" );
    HBBindCheck( context, "recoveryAfterInvalidSql", HBBindScalar( context, "SELECT CAST(? AS INT)",
        SQL_C_SLONG, SQL_INTEGER, 10, 0, &integerInput, sizeof( integerInput ), &indicator,
        &integerOutput, sizeof( integerOutput ) ) && integerOutput == integerInput );
    HBBindCheck( context, "nativeInt64OverflowRejected", HBBindConversionError( context,
        "SELECT CAST(? AS BIGINT)", SQL_C_CHAR, SQL_BIGINT, 19, 0, overflowInteger,
        sizeof( overflowInteger ), sizeof( overflowInteger ) - 1, "int64OverflowSQLState" ) );
    HBBindCheck( context, "recoveryAfterInt64Overflow", HBBindScalar( context, "SELECT CAST(? AS INT)",
        SQL_C_SLONG, SQL_INTEGER, 10, 0, &integerInput, sizeof( integerInput ), &indicator,
        &integerOutput, sizeof( integerOutput ) ) && integerOutput == integerInput );
    HBBindCheck( context, "nativeDecimalOverflowRejected", HBBindConversionError( context,
        "SELECT CAST(? AS DECIMAL(5,2))", SQL_C_CHAR, SQL_DECIMAL, 5, 2, overflowDecimal,
        sizeof( overflowDecimal ), sizeof( overflowDecimal ) - 1, "decimalOverflowSQLState" ) );
    HBBindCheck( context, "recoveryAfterDecimalOverflow", HBBindScalar( context, "SELECT CAST(? AS INT)",
        SQL_C_SLONG, SQL_INTEGER, 10, 0, &integerInput, sizeof( integerInput ), &indicator,
        &integerOutput, sizeof( integerOutput ) ) && integerOutput == integerInput );
    dateInput.year = 2023;
    HBBindCheck( context, "nativeInvalidDateRejected", HBBindConversionError( context,
        "SELECT CAST(? AS DATE)", SQL_C_TYPE_DATE, SQL_TYPE_DATE, 10, 0, &dateInput,
        sizeof( dateInput ), 0, "invalidDateSQLState" ) );
    HBBindCheck( context, "recoveryAfterInvalidDate", HBBindScalar( context, "SELECT CAST(? AS INT)",
        SQL_C_SLONG, SQL_INTEGER, 10, 0, &integerInput, sizeof( integerInput ), &indicator,
        &integerOutput, sizeof( integerOutput ) ) && integerOutput == integerInput );
    HBBindCheck( context, "statementReleased", HBBindReleaseStatement( context ) );
}

HB_FUNC( HBBRIDGEMSSQLBINDPROBE )
{
    HBBindContext context;
    const char * connectionText = hb_parc( 1 );
    HB_SIZE connectionBytes = hb_parclen( 1 );
    SQLWCHAR * wideConnection = NULL;
    int units;
    SQLCHAR information[ 256 ] = { 0 };
    SQLSMALLINT informationLength;
    HB_BOOL available = HB_FALSE;

    memset( &context, 0, sizeof( context ) );
    context.report = hb_hashNew( NULL );
    context.checks = hb_hashNew( NULL );
    context.capabilities = hb_hashNew( NULL );
    HBBindInteger( context.report, "schemaVersion", 1 );
    HBBindString( context.report, "connector", "Windows ODBC 3; SQLPrepare/SQLNumParams/SQLBindParameter/SQLExecute/SQLGetData" );
    if( connectionText == NULL || connectionBytes == 0 || connectionBytes > SHRT_MAX ||
        strlen( connectionText ) != connectionBytes )
        goto cleanup;
    units = MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, connectionText, ( int ) connectionBytes, NULL, 0 );
    if( units <= 0 || units > SHRT_MAX )
        goto cleanup;
    wideConnection = ( SQLWCHAR * ) hb_xgrabz( ( units + 1 ) * sizeof( SQLWCHAR ) );
    if( MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, connectionText, ( int ) connectionBytes,
        ( WCHAR * ) wideConnection, units ) != units )
        goto cleanup;
    if( !SQL_SUCCEEDED( SQLAllocHandle( SQL_HANDLE_ENV, SQL_NULL_HANDLE, &context.environment ) ) ||
        !SQL_SUCCEEDED( SQLSetEnvAttr( context.environment, SQL_ATTR_ODBC_VERSION, ( SQLPOINTER ) SQL_OV_ODBC3, 0 ) ) ||
        !SQL_SUCCEEDED( SQLAllocHandle( SQL_HANDLE_DBC, context.environment, &context.connection ) ) )
        goto cleanup;
    if( !HBBindCheck( &context, "loginTimeoutConfigured", SQL_SUCCEEDED( SQLSetConnectAttr(
        context.connection, SQL_ATTR_LOGIN_TIMEOUT, ( SQLPOINTER ) ( uintptr_t ) 15, 0 ) ) ) )
        goto cleanup;
    if( !SQL_SUCCEEDED( SQLDriverConnectW( context.connection, NULL, wideConnection,
        ( SQLSMALLINT ) units, NULL, 0, NULL, SQL_DRIVER_NOPROMPT ) ) )
    {
        HBBindState( &context, SQL_HANDLE_DBC, context.connection, "connectionSQLState" );
        goto cleanup;
    }
    context.connected = HB_TRUE;
    available = HB_TRUE;
    HBBindCheck( &context, "connectionUtf16", HB_TRUE );
    if( SQL_SUCCEEDED( SQLGetInfoA( context.connection, SQL_DRIVER_NAME, information, sizeof( information ), &informationLength ) ) )
        HBBindString( context.report, "driverName", ( const char * ) information );
    if( SQL_SUCCEEDED( SQLGetInfoA( context.connection, SQL_DRIVER_VER, information, sizeof( information ), &informationLength ) ) )
        HBBindString( context.report, "driverVersion", ( const char * ) information );
    if( SQL_SUCCEEDED( SQLGetInfoA( context.connection, SQL_DBMS_NAME, information, sizeof( information ), &informationLength ) ) )
        HBBindString( context.report, "backend", ( const char * ) information );
    if( SQL_SUCCEEDED( SQLGetInfoA( context.connection, SQL_DBMS_VER, information, sizeof( information ), &informationLength ) ) )
        HBBindString( context.report, "backendVersion", ( const char * ) information );
    HBBindCases( &context );
    HBBindDeclaredCases( &context );

cleanup:
    if( wideConnection != NULL )
    {
        SecureZeroMemory( wideConnection, ( units + 1 ) * sizeof( SQLWCHAR ) );
        hb_xfree( wideConnection );
    }
    HBBindReleaseStatement( &context );
    HBBindCheck( &context, "allStatementsReleased", context.allocatedStatements == context.releasedStatements &&
        context.statementReleaseFailures == 0 && context.statement == SQL_NULL_HSTMT );
    if( context.connected )
        HBBindCheck( &context, "connectionDisconnected", SQL_SUCCEEDED( SQLDisconnect( context.connection ) ) );
    if( context.connection != SQL_NULL_HDBC )
        HBBindCheck( &context, "connectionReleased", SQL_SUCCEEDED( SQLFreeHandle( SQL_HANDLE_DBC, context.connection ) ) );
    if( context.environment != SQL_NULL_HENV )
        HBBindCheck( &context, "environmentReleased", SQL_SUCCEEDED( SQLFreeHandle( SQL_HANDLE_ENV, context.environment ) ) );
    HBBindLogical( context.report, "success", available && context.failureCount == 0 );
    HBBindInteger( context.report, "checkCount", context.checkCount );
    HBBindInteger( context.report, "failureCount", context.failureCount );
    HBBindHash( context.report, "checks", context.checks );
    HBBindHash( context.report, "capabilities", context.capabilities );
    hb_itemRelease( context.capabilities );
    hb_itemRelease( context.checks );
    hb_itemReturnRelease( context.report );
}
