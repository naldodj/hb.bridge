/* Released to Public Domain. Included by the managed SDDSQLITE3 patch. */
#include <limits.h>
#include <math.h>
#include <string.h>

typedef struct
{
    PHB_ITEM name;
    int kind;
} SQLiteTypedColumn;

enum
{
    SQLiteTypedUnsupported = 0,
    SQLiteTypedText,
    SQLiteTypedInteger,
    SQLiteTypedNumber
};

static HB_BOOL SQLiteTypedIntegerFitsDouble( sqlite3_int64 nValue )
{
    int nBits = 0;

    sqlite3_uint64 nMagnitude = nValue < 0 ?
        ( sqlite3_uint64 ) ( -( nValue + 1 ) ) + 1 : ( sqlite3_uint64 ) nValue;
    sqlite3_uint64 nScan = nMagnitude;

    while( nScan != 0 )
    {
        ++nBits;
        nScan >>= 1;
    }
    return nBits <= 53 ||
        ( nMagnitude & ( ( ( ( sqlite3_uint64 ) 1 ) << ( nBits - 53 ) ) - 1 ) ) == 0;
}

static int SQLiteTypedDeclaration( const char * cDeclaration )
{
    char * cBase;

    HB_SIZE nBase, nLength;

    int nKind = SQLiteTypedUnsupported;

    if( cDeclaration == NULL )
        return nKind;
    nLength = strlen( cDeclaration );
    while( nLength != 0 && ( cDeclaration[ nLength - 1 ] == ' ' || cDeclaration[ nLength - 1 ] == '\t' ) )
        --nLength;
    while( nLength != 0 && ( *cDeclaration == ' ' || *cDeclaration == '\t' ) )
    {
        ++cDeclaration;
        --nLength;
    }
    nBase = 0;
    while( nBase < nLength && cDeclaration[ nBase ] != '(' )
        ++nBase;
    while( nBase != 0 && ( cDeclaration[ nBase - 1 ] == ' ' || cDeclaration[ nBase - 1 ] == '\t' ) )
        --nBase;
    cBase = hb_strndup( cDeclaration, nBase );
    hb_strUpper( cBase, nBase );

    /* Only known declared families are candidates. SQLite's arbitrary type names
     * and numeric affinity do not establish a version 2 result mapping. */
    if( strcmp( cBase, "INT" ) == 0 || strcmp( cBase, "INTEGER" ) == 0 ||
        strcmp( cBase, "TINYINT" ) == 0 || strcmp( cBase, "SMALLINT" ) == 0 ||
        strcmp( cBase, "MEDIUMINT" ) == 0 || strcmp( cBase, "BIGINT" ) == 0 ||
        strcmp( cBase, "INT2" ) == 0 || strcmp( cBase, "INT8" ) == 0 )
        nKind = SQLiteTypedInteger;
    else if( strcmp( cBase, "TEXT" ) == 0 || strcmp( cBase, "CHAR" ) == 0 ||
        strcmp( cBase, "CHARACTER" ) == 0 || strcmp( cBase, "VARCHAR" ) == 0 ||
        strcmp( cBase, "VARYING CHARACTER" ) == 0 || strcmp( cBase, "NCHAR" ) == 0 ||
        strcmp( cBase, "NATIVE CHARACTER" ) == 0 || strcmp( cBase, "NVARCHAR" ) == 0 ||
        strcmp( cBase, "CLOB" ) == 0 )
        nKind = SQLiteTypedText;
    else if( strcmp( cBase, "REAL" ) == 0 || strcmp( cBase, "FLOAT" ) == 0 ||
        strcmp( cBase, "DOUBLE" ) == 0 || strcmp( cBase, "DOUBLE PRECISION" ) == 0 )
        nKind = SQLiteTypedNumber;
    hb_xfree( cBase );

    return nKind;
}

static PHB_ITEM SQLiteTypedMetadata( sqlite3_stmt * pStatement, int nColumn, int nPosition, int nKind )
{
    const char * cDeclaration = sqlite3_column_decltype( pStatement, nColumn );
    const char * cKind = nKind == SQLiteTypedText ? "text" :
        ( nKind == SQLiteTypedInteger ? "int64" : "number" );

    PHB_ITEM pField = hb_hashNew( NULL );
    PHB_ITEM pRDD = hb_hashNew( NULL );
    PHB_ITEM pSource = hb_hashNew( NULL );
    PHB_ITEM pWire = hb_hashNew( NULL );

    HBBridgeTypedPutN( pField, "position", nPosition );
    HBBridgeTypedPutNil( pRDD, "type" );
    HBBridgeTypedPutNil( pRDD, "length" );
    HBBridgeTypedPutNil( pRDD, "decimals" );
    HBBridgeTypedPutNil( pSource, "typeCode" );
    HBBridgeTypedPutC( pSource, "typeName", cDeclaration );
    HBBridgeTypedPutNil( pSource, "precision" );
    HBBridgeTypedPutNil( pSource, "precisionRadix" );
    HBBridgeTypedPutNil( pSource, "scale" );
    HBBridgeTypedPutNil( pSource, "characterLength" );
    HBBridgeTypedPutNil( pSource, "octetLength" );
    HBBridgeTypedPutNil( pSource, "nullable" );
    HBBridgeTypedPutNil( pSource, "catalog" );
    HBBridgeTypedPutNil( pSource, "schema" );
    HBBridgeTypedPutNil( pSource, "table" );
    HBBridgeTypedPutNil( pSource, "column" );
    HBBridgeTypedPutNil( pSource, "collation" );
#if defined( SQLITE_ENABLE_COLUMN_METADATA )
    {
        const char * cCatalog = sqlite3_column_database_name( pStatement, nColumn );
        const char * cTable = sqlite3_column_table_name( pStatement, nColumn );
        const char * cColumn = sqlite3_column_origin_name( pStatement, nColumn );

        if( cCatalog != NULL )
            HBBridgeTypedPutC( pSource, "catalog", cCatalog );
        if( cTable != NULL )
            HBBridgeTypedPutC( pSource, "table", cTable );
        if( cColumn != NULL )
            HBBridgeTypedPutC( pSource, "column", cColumn );
    }
#endif
    HBBridgeTypedPutC( pWire, "kind", cKind );
    HBBridgeTypedPutC( pWire, "jsonType", nKind == SQLiteTypedNumber ? "number" : "string" );
    if( nKind == SQLiteTypedNumber )
        HBBridgeTypedPutNil( pWire, "encoding" );
    else
        HBBridgeTypedPutC( pWire, "encoding", "UTF-8" );
    HBBridgeTypedPut( pField, "rdd", pRDD );
    HBBridgeTypedPut( pField, "source", pSource );
    HBBridgeTypedPut( pField, "wire", pWire );
    hb_itemRelease( pRDD );
    hb_itemRelease( pSource );
    hb_itemRelease( pWire );

    return pField;
}

static HB_BOOL SQLiteTypedBind( sqlite3_stmt * pStatement, int nIndex, PHB_ITEM pDescriptor,
    const char ** cError, const char ** cMessage )
{
    const char * cType;

    double dValue;

    HB_MAXINT nInteger;

    HB_SIZE nLength;

    int nStatus;

    PHB_ITEM pNull = HBBridgeTypedGet( pDescriptor, "isNull" );
    PHB_ITEM pType = HBBridgeTypedGet( pDescriptor, "type" );
    PHB_ITEM pValue = HBBridgeTypedGet( pDescriptor, "value" );

    if( ! HB_IS_HASH( pDescriptor ) || pType == NULL || ! HB_IS_STRING( pType ) ||
        pNull == NULL || ! HB_IS_LOGICAL( pNull ) )
    {
        *cError = "INVALID_BINDINGS";
        *cMessage = "Typed parameter descriptors are malformed.";
        return HB_FALSE;
    }
    cType = hb_itemGetCPtr( pType );
    if( hb_itemGetCLen( pType ) != strlen( cType ) )
    {
        *cError = "INVALID_BINDINGS";
        *cMessage = "Typed parameter names must not contain NUL.";
        return HB_FALSE;
    }
    if( strcmp( cType, "decimal" ) == 0 )
    {
        *cError = "UNSUPPORTED_BINDING_TYPE";
        *cMessage = "SQLite fixed decimal binding is unsupported.";
        return HB_FALSE;
    }
    if( strcmp( cType, "text" ) != 0 && strcmp( cType, "integer" ) != 0 &&
        strcmp( cType, "int64" ) != 0 && strcmp( cType, "number" ) != 0 &&
        strcmp( cType, "boolean" ) != 0 && strcmp( cType, "date" ) != 0 )
    {
        *cError = "UNSUPPORTED_BINDING_TYPE";
        *cMessage = "The requested SQLite binding type is unsupported.";
        return HB_FALSE;
    }
    *cError = "BINDING_RANGE_ERROR";
    *cMessage = "A typed parameter does not fit its declared input mapping.";
    if( hb_itemGetL( pNull ) )
    {
        if( pValue != NULL )
            return HB_FALSE;
        nStatus = sqlite3_bind_null( pStatement, nIndex );
    }
    else
    {
        if( pValue == NULL )
            return HB_FALSE;
        if( strcmp( cType, "text" ) == 0 || strcmp( cType, "date" ) == 0 )
        {
            const char * cValue;

            if( ! HB_IS_STRING( pValue ) )
                return HB_FALSE;
            cValue = hb_itemGetCPtr( pValue );
            nLength = hb_itemGetCLen( pValue );
            if( nLength > INT_MAX || ! HBBridgeTypedValidUTF8( cValue, nLength ) ||
                ( strcmp( cType, "date" ) == 0 && ! HBBridgeTypedDateISOValid( cValue, nLength ) ) )
                return HB_FALSE;
            nStatus = sqlite3_bind_text( pStatement, nIndex, cValue, ( int ) nLength, SQLITE_TRANSIENT );
        }
        else if( strcmp( cType, "int64" ) == 0 )
        {
            if( ! HB_IS_STRING( pValue ) || ! HBBridgeTypedParseInt64( hb_itemGetCPtr( pValue ),
                hb_itemGetCLen( pValue ), &nInteger ) )
                return HB_FALSE;
            nStatus = sqlite3_bind_int64( pStatement, nIndex, ( sqlite3_int64 ) nInteger );
        }
        else if( strcmp( cType, "boolean" ) == 0 )
        {
            if( ! HB_IS_LOGICAL( pValue ) )
                return HB_FALSE;
            nStatus = sqlite3_bind_int( pStatement, nIndex, hb_itemGetL( pValue ) ? 1 : 0 );
        }
        else
        {
            if( ! HB_IS_NUMERIC( pValue ) )
                return HB_FALSE;
            dValue = hb_itemGetND( pValue );
            if( ! isfinite( dValue ) )
                return HB_FALSE;
            if( strcmp( cType, "integer" ) == 0 )
            {
                if( dValue < -9007199254740991.0 || dValue > 9007199254740991.0 || floor( dValue ) != dValue )
                    return HB_FALSE;
                nStatus = sqlite3_bind_int64( pStatement, nIndex, ( sqlite3_int64 ) dValue );
            }
            else
                nStatus = sqlite3_bind_double( pStatement, nIndex, dValue );
        }
    }
    if( nStatus != SQLITE_OK )
    {
        *cError = "STATEMENT_BIND_FAILED";
        *cMessage = "Unable to bind a typed SQLite parameter.";
        return HB_FALSE;
    }

    return HB_TRUE;
}

static HB_BOOL HBBridgeSQLiteTypedExecute( sqlite3 * pDatabase, PHB_ITEM pRequest )
{
    const char * cError = "INVALID_TYPED_REQUEST";
    const char * cMessage = "The internal typed SQLite request is malformed.";
    const char * cSQL, * cTail = NULL;

    double dLimit, dSkip;

    HB_BOOL lCountMode = HB_FALSE;
    HB_BOOL lHasNext = HB_FALSE;
    HB_BOOL lSuccess = HB_FALSE;

    HB_MAXINT nRows = 0, nLimit;

    HB_SIZE nSQLLength;

    int nColumn, nColumns = 0, nIndex, nParameters, nSkip, nStatus;

    PHB_ITEM pBindings, pHeader = NULL, pLimit, pOutput = NULL, pRow = NULL;
    PHB_ITEM pRows = NULL, pSkip, pSQL;

    sqlite3_stmt * pStatement = NULL;
    sqlite3_stmt * pExtra = NULL;

    SQLiteTypedColumn * pColumns = NULL;

    if( pDatabase == NULL || ! HBBridgeTypedIsRequest( pRequest ) )
        goto Cleanup;
    lCountMode = strcmp( hb_itemGetCPtr( HBBridgeTypedGet( pRequest, "operation" ) ),
        "hbbridge.querytyped.count.v1" ) == 0;
    pSQL = HBBridgeTypedGet( pRequest, "sql" );
    pBindings = HBBridgeTypedGet( pRequest, "bindings" );
    pSkip = HBBridgeTypedGet( pRequest, "skipColumns" );
    pLimit = HBBridgeTypedGet( pRequest, "rowLimit" );
    if( pSQL == NULL || ! HB_IS_STRING( pSQL ) || pBindings == NULL || ! HB_IS_HASH( pBindings ) ||
        pSkip == NULL || ! HB_IS_NUMERIC( pSkip ) || pLimit == NULL || ! HB_IS_NUMERIC( pLimit ) )
        goto Cleanup;
    cSQL = hb_itemGetCPtr( pSQL );
    nSQLLength = hb_itemGetCLen( pSQL );
    dSkip = hb_itemGetND( pSkip );
    dLimit = hb_itemGetND( pLimit );
    if( nSQLLength == 0 || nSQLLength > INT_MAX || memchr( cSQL, 0, nSQLLength ) != NULL ||
        ! HBBridgeTypedValidUTF8( cSQL, nSQLLength ) || ! HBBridgeTypedSQLSingle( cSQL, nSQLLength ) ||
        ! isfinite( dSkip ) || ! isfinite( dLimit ) ||
        dSkip < 0 || dSkip > INT_MAX || floor( dSkip ) != dSkip ||
        dLimit < 0 || dLimit > 9007199254740991.0 || floor( dLimit ) != dLimit )
        goto Cleanup;
    nSkip = ( int ) dSkip;
    nLimit = ( HB_MAXINT ) dLimit;
    if( lCountMode && ( nSkip != 0 || nLimit != 0 ) )
        goto Cleanup;
    cError = "STATEMENT_PREPARE_FAILED";
    cMessage = "Unable to prepare the typed SQLite query.";
    nStatus = sqlite3_prepare_v2( pDatabase, cSQL, ( int ) nSQLLength, &pStatement, &cTail );
    if( nStatus != SQLITE_OK || pStatement == NULL )
        goto Cleanup;
    if( cTail != NULL && cTail < cSQL + nSQLLength )
    {
        nStatus = sqlite3_prepare_v2( pDatabase, cTail, ( int ) ( cSQL + nSQLLength - cTail ), &pExtra, NULL );
        if( nStatus != SQLITE_OK || pExtra != NULL )
        {
            cError = "INVALID_TYPED_REQUEST";
            cMessage = "Typed SQLite queries must contain a single statement.";
            goto Cleanup;
        }
    }
    nColumns = sqlite3_column_count( pStatement );
    if( sqlite3_stmt_readonly( pStatement ) == 0 || nColumns <= nSkip )
    {
        cError = "UNSUPPORTED_RESULT_TYPE";
        cMessage = "Typed SQLite queries require a read-only row-returning statement.";
        goto Cleanup;
    }
    nParameters = sqlite3_bind_parameter_count( pStatement );
    if( hb_hashLen( pBindings ) != ( HB_SIZE ) nParameters )
    {
        cError = "INVALID_BINDINGS";
        cMessage = "Typed SQLite parameter count does not match the prepared statement.";
        goto Cleanup;
    }
    for( nIndex = 1; nIndex <= nParameters; ++nIndex )
    {
        char cKey[ 24 ];

        PHB_ITEM pDescriptor;

        hb_snprintf( cKey, sizeof( cKey ), "%d", nIndex );
        pDescriptor = HBBridgeTypedGet( pBindings, cKey );
        if( sqlite3_bind_parameter_name( pStatement, nIndex ) != NULL || pDescriptor == NULL )
        {
            cError = "INVALID_BINDINGS";
            cMessage = "Typed SQLite queries require contiguous anonymous parameters.";
            goto Cleanup;
        }
        if( ! SQLiteTypedBind( pStatement, nIndex, pDescriptor, &cError, &cMessage ) )
            goto Cleanup;
    }
    if( lCountMode )
    {
        const char * cName = nColumns == 1 ? sqlite3_column_name( pStatement, 0 ) : NULL;

        sqlite3_int64 nCount;

        cError = "UNSUPPORTED_RESULT_TYPE";
        cMessage = "The internal SQLite count must return its single reserved projection.";
        if( cName == NULL || hb_stricmp( cName, "__HBBRIDGE_COUNT" ) != 0 )
            goto Cleanup;
        cError = "STATEMENT_FETCH_FAILED";
        cMessage = "Unable to fetch the internal SQLite count.";
        if( sqlite3_step( pStatement ) != SQLITE_ROW || sqlite3_column_type( pStatement, 0 ) != SQLITE_INTEGER )
            goto Cleanup;
        nCount = sqlite3_column_int64( pStatement, 0 );
        if( nCount < 0 || nCount > ( sqlite3_int64 ) 9007199254740991LL )
        {
            cError = "RESULT_RANGE_ERROR";
            cMessage = "The internal SQLite count exceeds the exact JSON integer range.";
            goto Cleanup;
        }
        nRows = ( HB_MAXINT ) nCount;
        if( sqlite3_step( pStatement ) != SQLITE_DONE )
            goto Cleanup;
        lSuccess = HB_TRUE;
        goto Cleanup;
    }
    pHeader = hb_hashNew( NULL );
    pRows = hb_hashNew( NULL );
    pColumns = ( SQLiteTypedColumn * ) hb_xgrabz( ( HB_SIZE ) nColumns * sizeof( SQLiteTypedColumn ) );
    for( nColumn = nSkip; nColumn < nColumns; ++nColumn )
    {
        const char * cName = sqlite3_column_name( pStatement, nColumn );
        const char * cDeclaration = sqlite3_column_decltype( pStatement, nColumn );

        PHB_ITEM pField;

        cError = "UNSUPPORTED_RESULT_TYPE";
        cMessage = "A typed SQLite result column has no supported declared mapping.";
        pColumns[ nColumn ].kind = SQLiteTypedDeclaration( cDeclaration );
        if( cName == NULL || pColumns[ nColumn ].kind == SQLiteTypedUnsupported ||
            ! HBBridgeTypedValidUTF8( cName, strlen( cName ) ) || cDeclaration == NULL ||
            ! HBBridgeTypedValidUTF8( cDeclaration, strlen( cDeclaration ) ) )
            goto Cleanup;
        pColumns[ nColumn ].name = HBBridgeTypedName( cName, strlen( cName ) );
        if( pColumns[ nColumn ].name == NULL || ! HB_IS_STRING( pColumns[ nColumn ].name ) ||
            hb_itemGetCLen( pColumns[ nColumn ].name ) == 0 ||
            hb_hashGetItemPtr( pHeader, pColumns[ nColumn ].name, 0 ) != NULL ||
            ( nSkip > 0 && ( strchr( hb_itemGetCPtr( pColumns[ nColumn ].name ), ':' ) != NULL ||
                strncmp( hb_itemGetCPtr( pColumns[ nColumn ].name ), "__HBBRIDGE_ROWNO", 16 ) == 0 ) ) )
        {
            /* Derived projections may rename duplicate X columns to X:1.
             * Preserve the ordinary paged reader's ambiguity protection.
             */
            cMessage = "Typed SQLite projection names must be nonempty and unique after normalization.";
            goto Cleanup;
        }
        pField = SQLiteTypedMetadata( pStatement, nColumn, nColumn - nSkip + 1, pColumns[ nColumn ].kind );
        hb_hashAdd( pHeader, pColumns[ nColumn ].name, pField );
        hb_itemRelease( pField );
    }
    while( ( nStatus = sqlite3_step( pStatement ) ) == SQLITE_ROW )
    {
        if( nLimit != 0 && nRows == nLimit )
        {
            lHasNext = HB_TRUE;
            break;
        }
        if( nRows == ( HB_MAXINT ) 9007199254740991LL )
        {
            cError = "RESULT_RANGE_ERROR";
            cMessage = "The typed SQLite row count exceeds the exact JSON integer range.";
            goto Cleanup;
        }
        pRow = hb_hashNew( NULL );
        for( nColumn = nSkip; nColumn < nColumns; ++nColumn )
        {
            const char * cText;

            double dValue;

            int nBytes, nType = sqlite3_column_type( pStatement, nColumn );

            PHB_ITEM pValue = NULL;

            sqlite3_int64 nInteger;

            cError = "UNSUPPORTED_RESULT_TYPE";
            cMessage = "A SQLite storage class does not fit the fixed result mapping.";
            if( nType == SQLITE_NULL )
                pValue = hb_itemNew( NULL );
            else if( pColumns[ nColumn ].kind == SQLiteTypedText )
            {
                if( nType != SQLITE_TEXT )
                    goto Cleanup;
                cText = ( const char * ) sqlite3_column_text( pStatement, nColumn );
                nBytes = sqlite3_column_bytes( pStatement, nColumn );
                if( cText == NULL || nBytes < 0 )
                {
                    cError = "STATEMENT_FETCH_FAILED";
                    cMessage = "Unable to retrieve typed SQLite text bytes.";
                    goto Cleanup;
                }
                if( ! HBBridgeTypedValidUTF8( cText, ( HB_SIZE ) nBytes ) )
                {
                    cError = "RESULT_RANGE_ERROR";
                    cMessage = "Typed SQLite text is not valid UTF-8.";
                    goto Cleanup;
                }
                pValue = hb_itemPutCL( NULL, cText, ( HB_SIZE ) nBytes );
            }
            else if( pColumns[ nColumn ].kind == SQLiteTypedInteger )
            {
                if( nType != SQLITE_INTEGER )
                    goto Cleanup;
                pValue = HBBridgeTypedIntegerText( ( HB_MAXINT ) sqlite3_column_int64( pStatement, nColumn ) );
            }
            else
            {
                if( nType != SQLITE_FLOAT && nType != SQLITE_INTEGER )
                    goto Cleanup;
                if( nType == SQLITE_INTEGER )
                {
                    nInteger = sqlite3_column_int64( pStatement, nColumn );
                    if( ! SQLiteTypedIntegerFitsDouble( nInteger ) )
                    {
                        cError = "RESULT_RANGE_ERROR";
                        cMessage = "A SQLite integer cannot fit the fixed number mapping exactly.";
                        goto Cleanup;
                    }
                }
                dValue = sqlite3_column_double( pStatement, nColumn );
                if( ! isfinite( dValue ) )
                {
                    cError = "RESULT_RANGE_ERROR";
                    cMessage = "A typed SQLite number is not finite.";
                    goto Cleanup;
                }
                pValue = hb_itemPutND( NULL, dValue );
            }
            hb_hashAdd( pRow, pColumns[ nColumn ].name, pValue );
            hb_itemRelease( pValue );
        }
        {
            PHB_ITEM pKey = HBBridgeTypedIntegerText( ++nRows );

            hb_hashAdd( pRows, pKey, pRow );
            hb_itemRelease( pKey );
            hb_itemRelease( pRow );
            pRow = NULL;
        }
    }
    if( nStatus != SQLITE_DONE && ! lHasNext )
    {
        cError = "STATEMENT_FETCH_FAILED";
        cMessage = "Unable to fetch the typed SQLite query result.";
        goto Cleanup;
    }
    lSuccess = HB_TRUE;

Cleanup:
    if( pExtra != NULL )
        sqlite3_finalize( pExtra );
    if( pStatement != NULL && sqlite3_finalize( pStatement ) != SQLITE_OK && lSuccess )
    {
        lSuccess = HB_FALSE;
        cError = "STATEMENT_FETCH_FAILED";
        cMessage = "Unable to finalize the typed SQLite query statement.";
    }
    if( pColumns != NULL )
    {
        for( nColumn = 0; nColumn < nColumns; ++nColumn )
        {
            if( pColumns[ nColumn ].name != NULL )
                hb_itemRelease( pColumns[ nColumn ].name );
        }
        hb_xfree( pColumns );
    }
    if( pRow != NULL )
        hb_itemRelease( pRow );
    if( lSuccess )
    {
        pOutput = hb_hashNew( NULL );
        HBBridgeTypedPutL( pOutput, "success", HB_TRUE );
        if( lCountMode )
            HBBridgeTypedPutN( pOutput, "totalRows", nRows );
        else
        {
            HBBridgeTypedPut( pOutput, "header", pHeader );
            HBBridgeTypedPut( pOutput, "rows", pRows );
            HBBridgeTypedPutN( pOutput, "rowCount", nRows );
            HBBridgeTypedPutL( pOutput, "hasNext", lHasNext );
        }
        HBBridgeTypedPut( pRequest, "output", pOutput );
        hb_itemRelease( pOutput );
    }
    if( pHeader != NULL )
        hb_itemRelease( pHeader );
    if( pRows != NULL )
        hb_itemRelease( pRows );

    return lSuccess ? HB_TRUE : HBBridgeTypedError( pRequest, cError, cMessage );
}
