/* Released to Public Domain. */
#include "hbsqlit3.ch"
#require "hbsqlit3"

REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE Main( cOutput )

    LOCAL cCodePage := hb_cdpSelect( "UTF8EX" )

    LOCAL hReport := { "schemaVersion" => 1, "probe" => "sqlite.native.binding.v1", ;
        "sqliteVersion" => sqlite3_libversion(), "sqliteVersionNumber" => sqlite3_libversion_number(), ;
        "checks" => { => }, "checkCount" => 0, "failureCount" => 0, "observations" => { => } }

    LOCAL oError

    LOCAL pDatabase := sqlite3_open( ":memory:", .T. )

    IF Empty( cOutput )
        cOutput := "result.json"
    ENDIF
    hReport[ "capabilities" ] := { ;
        "scope" => "standalone hbsqlit3 wrappers; no SQLMIX or hbBridge service integration", ;
        "text" => "explicit-length UTF-8 binding and retrieval including embedded NUL", ;
        "null" => "native SQLITE_NULL indicators; no first-row schema inference", ;
        "integer" => "checked canonical strings bind through native Harbour int64, including both signed endpoints", ;
        "decimal" => "unsupported: NUMERIC affinity does not preserve exact decimal digits or scale", ;
        "boolean" => "caller convention INTEGER 0 or 1; not a native SQLite logical type", ;
        "date" => "caller convention ISO date as TEXT; not a native SQLite date type", ;
        "metadata" => "declared type and per-row storage class are separate observations" }

    BEGIN SEQUENCE WITH {|oFailure| Break( oFailure ) }
        ProbeAssert( hReport, ! Empty( pDatabase ), "openMemoryDatabase" )
        IF ! Empty( pDatabase )
            ProbeMarkers( pDatabase, hReport )
            ProbeText( pDatabase, hReport )
            ProbeValues( pDatabase, hReport )
            ProbeInteger64( pDatabase, hReport )
            ProbeDecimal( pDatabase, hReport )
            ProbeMetadata( pDatabase, hReport )
            ProbeReuse( pDatabase, hReport )
        ENDIF
    RECOVER USING oError
        ProbeAssert( hReport, .F., "unexpectedRuntimeError" )
        hReport[ "runtimeError" ] := oError:Description
    END SEQUENCE

    pDatabase := NIL
    hb_gcAll( .T. )
    hb_cdpSelect( cCodePage )
    hReport[ "success" ] := hReport[ "failureCount" ] == 0
    IF ! hb_MemoWrit( cOutput, hb_jsonEncode( hReport, .T. ) + hb_eol() )
        ProbeAssert( hReport, .F., "writeReport" )
    ENDIF
    OutStd( "SQLite native binding checks=" + hb_ntos( hReport[ "checkCount" ] ) + ;
        "; failures=" + hb_ntos( hReport[ "failureCount" ] ) + hb_eol() )
    ErrorLevel( hReport[ "failureCount" ] )

RETURN

STATIC PROCEDURE ProbeMarkers( pDatabase, hReport )

    LOCAL cSQL := "SELECT ? AS bound_value, '?' AS literal_value, 'it''s ?' AS quoted_value /* ? */ -- ?" + ;
        hb_eol() + ", ? AS other_value"

    LOCAL pStatement := sqlite3_prepare( pDatabase, cSQL )

    ProbeAssert( hReport, ! Empty( pStatement ), "prepareAnonymousMarkers" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, sqlite3_bind_parameter_count( pStatement ) == 2, "nativeCountIgnoresLiteralAndCommentMarkers" )
    ProbeAssert( hReport, Empty( sqlite3_bind_parameter_name( pStatement, 1 ) ) .AND. ;
        Empty( sqlite3_bind_parameter_name( pStatement, 2 ) ), "anonymousMarkersHaveNoNames" )
    ProbeAssert( hReport, sqlite3_bind_parameter_count( pStatement ) != 1, "callerCanDetectParameterCountMismatch" )
    ProbeAssert( hReport, sqlite3_bind_int( pStatement, 0, 1 ) == SQLITE_RANGE, "zeroBindIndexIsRangeError" )
    ProbeAssert( hReport, sqlite3_bind_int( pStatement, 3, 1 ) == SQLITE_RANGE, "extraBindIndexIsRangeError" )
    ProbeAssert( hReport, sqlite3_bind_text( pStatement, 1, "bound" ) == SQLITE_OK, "anonymousTextBind" )
    ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_ROW, "underbindingNativeStepReturnsRow" )
    ProbeAssert( hReport, sqlite3_column_text( pStatement, 1 ) == "bound" .AND. ;
        sqlite3_column_text( pStatement, 2 ) == "?" .AND. ;
        sqlite3_column_text( pStatement, 3 ) == "it's ?", "literalAndBoundValuesStayDistinct" )
    ProbeAssert( hReport, sqlite3_column_type( pStatement, 4 ) == SQLITE_NULL, "unboundParameterBecomesNativeNull" )
    ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_DONE, "anonymousStatementCompletes" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "anonymousStatementFinalizes" )
    hReport[ "observations" ][ "underbinding" ] := ;
        "SQLite permits missing bindings as NULL; an application must reject count mismatches itself"

    pStatement := sqlite3_prepare( pDatabase, "SELECT :value, :value, @other, $last, ?5" )
    ProbeAssert( hReport, ! Empty( pStatement ), "prepareNamedAndNumberedMarkers" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, sqlite3_bind_parameter_count( pStatement ) == 5, "numberedCountUsesLargestSlot" )
    ProbeAssert( hReport, sqlite3_bind_parameter_name( pStatement, 1 ) == ":value" .AND. ;
        sqlite3_bind_parameter_name( pStatement, 2 ) == "@other" .AND. ;
        sqlite3_bind_parameter_name( pStatement, 3 ) == "$last" .AND. ;
        Empty( sqlite3_bind_parameter_name( pStatement, 4 ) ) .AND. ;
        sqlite3_bind_parameter_name( pStatement, 5 ) == "?5", "nativeNamesExposeNamedNumberedAndGapSlots" )
    ProbeAssert( hReport, sqlite3_bind_parameter_index( pStatement, ":value" ) == 1 .AND. ;
        sqlite3_bind_parameter_index( pStatement, "?5" ) == 5 .AND. ;
        sqlite3_bind_parameter_index( pStatement, ":missing" ) == 0, "nativeNameLookup" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "namedStatementFinalizes" )
    hReport[ "observations" ][ "markers" ] := ;
        "Native names distinguish named and ?N slots; counts describe slots, not SQL token occurrences"

RETURN

STATIC PROCEDURE ProbeText( pDatabase, hReport )

    LOCAL cNul := Chr( 0 )
    LOCAL cUnicode := "caf" + hb_utf8Chr( 233 ) + " " + hb_utf8Chr( 128640 )
    LOCAL cValue, cKey

    LOCAL hCases := { => }

    LOCAL nBytes

    LOCAL pStatement := sqlite3_prepare( pDatabase, "SELECT ?, typeof(?)" )

    hCases[ "unicode" ] := cUnicode
    hCases[ "middleNul" ] := cUnicode + cNul + "tail"
    hCases[ "leadingNul" ] := cNul + cUnicode
    hCases[ "trailingNul" ] := cUnicode + cNul
    hCases[ "onlyNul" ] := cNul
    hCases[ "empty" ] := ""
    ProbeAssert( hReport, ! Empty( pStatement ), "prepareTextRoundTrips" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    FOR EACH cValue IN hCases
        cKey := cValue:__enumKey()
        nBytes := hb_BLen( cValue )
        ProbeAssert( hReport, sqlite3_reset( pStatement ) == SQLITE_OK .AND. ;
            sqlite3_clear_bindings( pStatement ) == SQLITE_OK, cKey + "ResetAndClear" )
        ProbeAssert( hReport, sqlite3_bind_text( pStatement, 1, cValue ) == SQLITE_OK .AND. ;
            sqlite3_bind_text( pStatement, 2, cValue ) == SQLITE_OK, cKey + "ExplicitLengthBind" )
        ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_ROW, cKey + "Row" )
        ProbeAssert( hReport, sqlite3_column_type( pStatement, 1 ) == SQLITE_TEXT .AND. ;
            sqlite3_column_text( pStatement, 2 ) == "text", cKey + "TextStorage" )
        ProbeAssert( hReport, sqlite3_column_bytes( pStatement, 1 ) == nBytes .AND. ;
            hb_BLen( sqlite3_column_text( pStatement, 1 ) ) == nBytes .AND. ;
            sqlite3_column_text( pStatement, 1 ) == cValue, cKey + "ExactBytesAndLength" )
        ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_DONE, cKey + "Done" )
    NEXT
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "textStatementFinalizes" )

RETURN

STATIC PROCEDURE ProbeValues( pDatabase, hReport )

    LOCAL cDate := "2026-10-24"

    LOCAL nInteger64 := 9007199254740991
    LOCAL nDouble := 1 / 3

    LOCAL pStatement := sqlite3_prepare( pDatabase, "SELECT ?, ?, ?, ?, ?, ?, ?" )

    ProbeAssert( hReport, ! Empty( pStatement ), "prepareTypedValues" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, sqlite3_bind_null( pStatement, 1 ) == SQLITE_OK, "bindNativeNull" )
    ProbeAssert( hReport, sqlite3_bind_int( pStatement, 2, -2147483647 ) == SQLITE_OK, "bindSignedInteger" )
    ProbeAssert( hReport, sqlite3_bind_int64( pStatement, 3, nInteger64 ) == SQLITE_OK, "bindNumericInteger64" )
    ProbeAssert( hReport, sqlite3_bind_double( pStatement, 4, nDouble ) == SQLITE_OK, "bindDouble" )
    ProbeAssert( hReport, sqlite3_bind_int( pStatement, 5, 1 ) == SQLITE_OK .AND. ;
        sqlite3_bind_int( pStatement, 6, 0 ) == SQLITE_OK, "bindBooleanConventionAsInteger" )
    ProbeAssert( hReport, sqlite3_bind_text( pStatement, 7, cDate ) == SQLITE_OK, "bindDateConventionAsText" )
    ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_ROW, "typedValuesRow" )
    ProbeAssert( hReport, sqlite3_column_type( pStatement, 1 ) == SQLITE_NULL, "nativeNullIndicator" )
    ProbeAssert( hReport, sqlite3_column_type( pStatement, 2 ) == SQLITE_INTEGER .AND. ;
        sqlite3_column_int( pStatement, 2 ) == -2147483647, "signedIntegerRoundTrip" )
    ProbeAssert( hReport, sqlite3_column_type( pStatement, 3 ) == SQLITE_INTEGER .AND. ;
        sqlite3_column_int64( pStatement, 3 ) == nInteger64, "numericInteger64RoundTripWithinSafeRange" )
    ProbeAssert( hReport, sqlite3_column_type( pStatement, 4 ) == SQLITE_FLOAT .AND. ;
        sqlite3_column_double( pStatement, 4 ) == nDouble, "binary64RoundTrip" )
    ProbeAssert( hReport, sqlite3_column_type( pStatement, 5 ) == SQLITE_INTEGER .AND. ;
        sqlite3_column_int( pStatement, 5 ) == 1 .AND. ;
        sqlite3_column_type( pStatement, 6 ) == SQLITE_INTEGER .AND. ;
        sqlite3_column_int( pStatement, 6 ) == 0, "booleanConventionRemainsInteger" )
    ProbeAssert( hReport, sqlite3_column_type( pStatement, 7 ) == SQLITE_TEXT .AND. ;
        sqlite3_column_text( pStatement, 7 ) == cDate, "dateConventionRemainsText" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "typedStatementFinalizes" )

RETURN

STATIC PROCEDURE ProbeInteger64( pDatabase, hReport )

    LOCAL cCase, cValue

    LOCAL hCases := { "zero" => "0", "positiveOne" => "1", "negativeOne" => "-1", ;
        "positive32Boundary" => "2147483648", "negative32Boundary" => "-2147483649", ;
        "aboveBinary64ExactInteger" => "9007199254740993", ;
        "belowBinary64ExactInteger" => "-9007199254740993", ;
        "maximum" => "9223372036854775807", "beforeMaximum" => "9223372036854775806", ;
        "minimum" => "-9223372036854775808", "afterMinimum" => "-9223372036854775807" }
    LOCAL hInvalid := { "empty" => "", "plus" => "+1", "leadingZero" => "01", ;
        "negativeZero" => "-0", "negativeLeadingZero" => "-01", "signOnly" => "-", ;
        "leadingSpace" => " 1", "trailingSpace" => "1 ", "fraction" => "1.0", ;
        "exponent" => "1e3", "hexadecimal" => "0x10", "trailingText" => "1x", ;
        "embeddedNul" => "1" + Chr( 0 ) + "2", "unicodeDigit" => hb_utf8Chr( 1633 ), ;
        "positiveOverflow" => "9223372036854775808", "negativeOverflow" => "-9223372036854775809", ;
        "largeOverflow" => "99999999999999999999999999999999999999", ;
        "numericInput" => 1, "nullInput" => NIL, "logicalInput" => .T. }
    LOCAL hBound

    LOCAL xInvalid

    LOCAL pStatement := sqlite3_prepare( pDatabase, "SELECT ?, typeof(?)" )

    ProbeAssert( hReport, ! Empty( pStatement ), "prepareCanonicalInteger64" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, ProbeNativeInteger( Val( "9223372036854775807" ) ), "nativeValMaximumStaysInteger" )
    ProbeAssert( hReport, ! ProbeNativeInteger( Val( "-9223372036854775808" ) ), "nativeValMinimumRequiresCheckedAlternative" )
    FOR EACH cValue IN hCases
        cCase := "int64" + cValue:__enumKey()
        ProbeAssert( hReport, sqlite3_reset( pStatement ) == SQLITE_OK .AND. ;
            sqlite3_clear_bindings( pStatement ) == SQLITE_OK, cCase + "ResetAndClear" )
        hBound := ProbeBindInteger64( pStatement, 1, cValue )
        ProbeAssert( hReport, hBound[ "success" ] .AND. hBound[ "nativeStatus" ] == SQLITE_OK, ;
            cCase + "CheckedStringBind" )
        ProbeAssert( hReport, ProbeNativeInteger( hBound[ "value" ] ), cCase + "HasNoDoubleIntermediate" )
        hBound := ProbeBindInteger64( pStatement, 2, cValue )
        ProbeAssert( hReport, hBound[ "success" ] .AND. sqlite3_step( pStatement ) == SQLITE_ROW, cCase + "Row" )
        ProbeAssert( hReport, sqlite3_column_type( pStatement, 1 ) == SQLITE_INTEGER .AND. ;
            sqlite3_column_text( pStatement, 2 ) == "integer", cCase + "NativeIntegerStorage" )
        ProbeAssert( hReport, sqlite3_column_text( pStatement, 1 ) == cValue, cCase + "ExactNativeTextRetrieval" )
        ProbeAssert( hReport, ProbeNativeInteger( sqlite3_column_int64( pStatement, 1 ) ) .AND. ;
            hb_ntos( sqlite3_column_int64( pStatement, 1 ) ) == cValue, cCase + "ExactHarbourIntegerRetrieval" )
        ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_DONE, cCase + "Done" )
    NEXT
    ProbeAssert( hReport, sqlite3_reset( pStatement ) == SQLITE_OK .AND. ;
        sqlite3_clear_bindings( pStatement ) == SQLITE_OK .AND. ;
        sqlite3_bind_text( pStatement, 1, "unchanged" ) == SQLITE_OK, "invalidIntegerFixture" )
    FOR EACH xInvalid IN hInvalid
        cCase := "int64Reject" + xInvalid:__enumKey()
        hBound := ProbeBindInteger64( pStatement, 1, xInvalid )
        ProbeAssert( hReport, ! hBound[ "success" ] .AND. hBound[ "value" ] == NIL .AND. ;
            hBound[ "nativeStatus" ] == NIL .AND. hBound[ "code" ] == "BINDING_RANGE_ERROR", cCase )
    NEXT
    ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_ROW .AND. ;
        sqlite3_column_type( pStatement, 1 ) == SQLITE_TEXT .AND. ;
        sqlite3_column_text( pStatement, 1 ) == "unchanged", "invalidIntegerNeverReachesNativeBinding" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "integer64StatementFinalizes" )
    hReport[ "observations" ][ "int64" ] := { ;
        "input" => "probe-local canonical syntax and lexical range checks before Val", ;
        "minimum" => "-Val(positive signed maximum) - 1; direct Val(minimum) would pass through double", ;
        "nativeType" => "HB_IS_NUMINT checked before binding and after sqlite3_column_int64", ;
        "retrieval" => "sqlite3_column_text and hb_ntos(native int64) both equal the original canonical string", ;
        "integration" => "probe helper only; no QueryTyped or SQLMIX implementation" }

RETURN

STATIC FUNCTION ProbeBindInteger64( pStatement, nIndex, xValue )

    LOCAL hParsed := ProbeParseInteger64( xValue )

    IF hParsed[ "success" ]
        hParsed[ "nativeStatus" ] := sqlite3_bind_int64( pStatement, nIndex, hParsed[ "value" ] )
        hParsed[ "success" ] := hParsed[ "nativeStatus" ] == SQLITE_OK
        hParsed[ "code" ] := iif( hParsed[ "success" ], "", "NATIVE_BIND_ERROR" )
    ENDIF

RETURN hParsed

STATIC FUNCTION ProbeParseInteger64( xValue )

    LOCAL cDigits, cLimit

    LOCAL hParsed := { "success" => .F., "value" => NIL, ;
        "nativeStatus" => NIL, "code" => "BINDING_RANGE_ERROR" }

    LOCAL lNegative

    LOCAL nChar, nIndex, nLength, nValue

    IF ! HB_ISSTRING( xValue )
        RETURN hParsed
    ENDIF
    nLength := hb_BLen( xValue )
    IF nLength == 0 .OR. nLength > 20
        RETURN hParsed
    ENDIF
    lNegative := hb_BLeft( xValue, 1 ) == "-"
    cDigits := iif( lNegative, hb_BSubStr( xValue, 2 ), xValue )
    nLength := hb_BLen( cDigits )
    IF nLength == 0 .OR. nLength > 19 .OR. ;
        ( nLength > 1 .AND. hb_BLeft( cDigits, 1 ) == "0" ) .OR. ;
        ( lNegative .AND. cDigits == "0" )
        RETURN hParsed
    ENDIF
    FOR nIndex := 1 TO nLength
        nChar := Asc( hb_BSubStr( cDigits, nIndex, 1 ) )
        IF nChar < 48 .OR. nChar > 57
            RETURN hParsed
        ENDIF
    NEXT
    cLimit := iif( lNegative, "9223372036854775808", "9223372036854775807" )
    IF nLength == 19 .AND. cDigits > cLimit
        RETURN hParsed
    ENDIF
    IF lNegative .AND. cDigits == "9223372036854775808"
        // The pinned Val parses the positive magnitude first; keep this endpoint out of double.
        nValue := -Val( "9223372036854775807" ) - 1
    ELSE
        nValue := Val( cDigits )
        IF lNegative
            nValue := -nValue
        ENDIF
    ENDIF
    IF ! ProbeNativeInteger( nValue )
        RETURN hParsed
    ENDIF
    hParsed[ "value" ] := nValue
    hParsed[ "success" ] := .T.
    hParsed[ "code" ] := ""

RETURN hParsed

STATIC PROCEDURE ProbeDecimal( pDatabase, hReport )

    LOCAL cValue, cCase

    LOCAL hCases := { "excessDigits" => "12345678901234567890.123456789", ;
        "fractionalScale" => "1.2300", "integralScale" => "100.0000" }
    LOCAL hObserved := { => }

    LOCAL pStatement

    ProbeAssert( hReport, sqlite3_exec( pDatabase, ;
        "CREATE TABLE decimal_candidate (value DECIMAL(38,9))" ) == SQLITE_OK, "createDecimalCandidate" )
    FOR EACH cValue IN hCases
        cCase := "decimal" + cValue:__enumKey()
        ProbeAssert( hReport, sqlite3_exec( pDatabase, "DELETE FROM decimal_candidate" ) == SQLITE_OK, cCase + "Clear" )
        pStatement := sqlite3_prepare( pDatabase, "INSERT INTO decimal_candidate VALUES (?)" )
        ProbeAssert( hReport, ! Empty( pStatement ), cCase + "Prepare" )
        IF Empty( pStatement )
            RETURN
        ENDIF
        ProbeAssert( hReport, sqlite3_bind_text( pStatement, 1, cValue ) == SQLITE_OK .AND. ;
            sqlite3_step( pStatement ) == SQLITE_DONE, cCase + "BindExactInputString" )
        ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, cCase + "InsertFinalizes" )
        pStatement := sqlite3_prepare( pDatabase, "SELECT value FROM decimal_candidate" )
        ProbeAssert( hReport, ! Empty( pStatement ), cCase + "PrepareRead" )
        IF Empty( pStatement )
            RETURN
        ENDIF
        ProbeAssert( hReport, sqlite3_column_decltype( pStatement, 1 ) == "DECIMAL(38,9)" .AND. ;
            sqlite3_step( pStatement ) == SQLITE_ROW, cCase + "DeclarationDoesNotImplyExactStorage" )
        ProbeAssert( hReport, sqlite3_column_type( pStatement, 1 ) != SQLITE_TEXT .AND. ;
            sqlite3_column_text( pStatement, 1 ) != cValue, cCase + "NativeNumericAffinityLosesDigitsOrScale" )
        hObserved[ cValue:__enumKey() ] := { "input" => cValue, ;
            "storageClass" => sqlite3_column_type( pStatement, 1 ), ;
            "retrievedText" => sqlite3_column_text( pStatement, 1 ) }
        ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, cCase + "ReadFinalizes" )
    NEXT
    hReport[ "observations" ][ "decimal" ] := { "status" => "unsupported", ;
        "reason" => "SQLite has no fixed DECIMAL storage/bind type; NUMERIC affinity converts exact strings to INTEGER/REAL", ;
        "policy" => "do not emulate exact decimal binding with double, CAST or post-read rounding", ;
        "examples" => hObserved }

RETURN

STATIC PROCEDURE ProbeMetadata( pDatabase, hReport )

    LOCAL hFields := { "1" => "INTEGER", "2" => "DECIMAL(15,4)", "3" => "TEXT", ;
        "4" => "DATE", "5" => "BOOLEAN", "6" => "BLOB" }
    LOCAL hStorage := { => }

    LOCAL nColumn, nRows := 0, nStatus, nType

    LOCAL pStatement

    ProbeAssert( hReport, sqlite3_exec( pDatabase, ;
        "CREATE TABLE declared_values (id INTEGER, amount DECIMAL(15,4), text_value TEXT, " + ;
        "date_value DATE, flag BOOLEAN, payload BLOB)" ) == SQLITE_OK, "createDeclaredColumns" )
    pStatement := sqlite3_prepare( pDatabase, "SELECT * FROM declared_values WHERE 0" )
    ProbeAssert( hReport, ! Empty( pStatement ), "prepareEmptyDeclaredResult" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, sqlite3_column_count( pStatement ) == 6, "emptyResultColumnCount" )
    FOR nColumn := 1 TO 6
        ProbeAssert( hReport, sqlite3_column_decltype( pStatement, nColumn ) == hFields[ hb_ntos( nColumn ) ], ;
            "emptyDeclaredType" + hb_ntos( nColumn ) )
    NEXT
    ProbeAssert( hReport, sqlite3_column_name( pStatement, 2 ) == "amount", "emptyResultColumnName" )
    ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_DONE, "emptyResultHasNoRow" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "emptyDeclaredStatementFinalizes" )

    ProbeAssert( hReport, sqlite3_exec( pDatabase, ;
        "INSERT INTO declared_values (id) VALUES (1), (2)" ) == SQLITE_OK, "insertAllNullDeclaredValues" )
    pStatement := sqlite3_prepare( pDatabase, "SELECT amount FROM declared_values ORDER BY id" )
    ProbeAssert( hReport, ! Empty( pStatement ), "prepareAllNullDeclaredResult" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, sqlite3_column_decltype( pStatement, 1 ) == "DECIMAL(15,4)", "allNullDeclaredTypeBeforeRows" )
    nStatus := sqlite3_step( pStatement )
    DO WHILE nStatus == SQLITE_ROW
        nRows++
        ProbeAssert( hReport, sqlite3_column_type( pStatement, 1 ) == SQLITE_NULL .AND. ;
            sqlite3_column_decltype( pStatement, 1 ) == "DECIMAL(15,4)", "allNullRow" + hb_ntos( nRows ) )
        nStatus := sqlite3_step( pStatement )
    ENDDO
    ProbeAssert( hReport, nRows == 2 .AND. nStatus == SQLITE_DONE, "allNullResultCompletes" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "allNullStatementFinalizes" )

    pStatement := sqlite3_prepare( pDatabase, ;
        "SELECT 1 + 1 AS computed, CAST(NULL AS DECIMAL(15,4)) AS absent WHERE 0" )
    ProbeAssert( hReport, ! Empty( pStatement ), "prepareEmptyExpressions" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, sqlite3_column_count( pStatement ) == 2 .AND. ;
        sqlite3_column_name( pStatement, 1 ) == "computed" .AND. ;
        Empty( sqlite3_column_decltype( pStatement, 1 ) ) .AND. ;
        Empty( sqlite3_column_decltype( pStatement, 2 ) ), "expressionTypesRemainUnknownWithoutDeclaration" )
    ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_DONE, "emptyExpressionsHaveNoRow" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "expressionStatementFinalizes" )

    ProbeAssert( hReport, sqlite3_exec( pDatabase, "CREATE TABLE mixed_values (value, declared INTEGER)" ) == SQLITE_OK .AND. ;
        sqlite3_exec( pDatabase, "INSERT INTO mixed_values VALUES (NULL,NULL),(7,7),(1.25,1.25),('text','text')" ) == SQLITE_OK, ;
        "createMixedStorageFixture" )
    pStatement := sqlite3_prepare( pDatabase, "SELECT value, declared FROM mixed_values ORDER BY rowid" )
    ProbeAssert( hReport, ! Empty( pStatement ), "prepareMixedStorage" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, Empty( sqlite3_column_decltype( pStatement, 1 ) ) .AND. ;
        sqlite3_column_decltype( pStatement, 2 ) == "INTEGER", "mixedDeclaredAndUndeclaredTypesBeforeRows" )
    nRows := 0
    nStatus := sqlite3_step( pStatement )
    DO WHILE nStatus == SQLITE_ROW
        nRows++
        nType := sqlite3_column_type( pStatement, 1 )
        hStorage[ hb_ntos( nType ) ] := .T.
        ProbeAssert( hReport, sqlite3_column_type( pStatement, 2 ) == nType .AND. ;
            sqlite3_column_decltype( pStatement, 2 ) == "INTEGER", "mixedStorageRow" + hb_ntos( nRows ) )
        nStatus := sqlite3_step( pStatement )
    ENDDO
    ProbeAssert( hReport, nRows == 4 .AND. nStatus == SQLITE_DONE .AND. ;
        hb_HHasKey( hStorage, hb_ntos( SQLITE_NULL ) ) .AND. ;
        hb_HHasKey( hStorage, hb_ntos( SQLITE_INTEGER ) ) .AND. ;
        hb_HHasKey( hStorage, hb_ntos( SQLITE_FLOAT ) ) .AND. ;
        hb_HHasKey( hStorage, hb_ntos( SQLITE_TEXT ) ), "mixedStorageCannotDefineOneLogicalSchema" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "mixedStatementFinalizes" )
    hReport[ "observations" ][ "declaredColumns" ] := hFields
    hReport[ "observations" ][ "mixedStorageClasses" ] := hStorage
    hReport[ "observations" ][ "metadata" ] := ;
        "Empty and all-NULL direct columns retain declarations; expressions may have none; non-STRICT declared columns allow mixed storage"

RETURN

STATIC PROCEDURE ProbeReuse( pDatabase, hReport )

    LOCAL pStatement := sqlite3_prepare( pDatabase, "SELECT ?" )

    ProbeAssert( hReport, ! Empty( pStatement ), "prepareReusableStatement" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, sqlite3_bind_int( pStatement, 1, 7 ) == SQLITE_OK .AND. ;
        sqlite3_step( pStatement ) == SQLITE_ROW .AND. ;
        sqlite3_column_int( pStatement, 1 ) == 7, "initialReusableValue" )
    ProbeAssert( hReport, sqlite3_reset( pStatement ) == SQLITE_OK .AND. ;
        sqlite3_step( pStatement ) == SQLITE_ROW .AND. ;
        sqlite3_column_int( pStatement, 1 ) == 7, "resetRetainsBindings" )
    ProbeAssert( hReport, sqlite3_reset( pStatement ) == SQLITE_OK .AND. ;
        sqlite3_clear_bindings( pStatement ) == SQLITE_OK .AND. ;
        sqlite3_step( pStatement ) == SQLITE_ROW .AND. ;
        sqlite3_column_type( pStatement, 1 ) == SQLITE_NULL, "clearBindingsRestoresNull" )
    ProbeAssert( hReport, sqlite3_reset( pStatement ) == SQLITE_OK .AND. ;
        sqlite3_bind_text( pStatement, 1, "rebound" ) == SQLITE_OK .AND. ;
        sqlite3_step( pStatement ) == SQLITE_ROW .AND. ;
        sqlite3_column_text( pStatement, 1 ) == "rebound", "resetRebindChangesValueAndStorage" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "reusableStatementFinalizes" )
    pStatement := sqlite3_prepare( pDatabase, "SELEC malformed" )
    ProbeAssert( hReport, Empty( pStatement ) .AND. sqlite3_errcode( pDatabase ) == SQLITE_ERROR .AND. ;
        ! Empty( sqlite3_errmsg( pDatabase ) ), "malformedSqlHasNativeError" )
    pStatement := sqlite3_prepare( pDatabase, "SELECT 42" )
    ProbeAssert( hReport, ! Empty( pStatement ), "prepareAfterMalformedSql" )
    IF Empty( pStatement )
        RETURN
    ENDIF
    ProbeAssert( hReport, sqlite3_step( pStatement ) == SQLITE_ROW .AND. ;
        sqlite3_column_int( pStatement, 1 ) == 42 .AND. ;
        sqlite3_step( pStatement ) == SQLITE_DONE, "connectionRecoversAfterMalformedSql" )
    ProbeAssert( hReport, sqlite3_finalize( pStatement ) == SQLITE_OK, "recoveredStatementFinalizes" )

RETURN

STATIC PROCEDURE ProbeAssert( hReport, lSuccess, cName )

    hReport[ "checks" ][ cName ] := lSuccess
    hReport[ "checkCount" ]++
    IF ! lSuccess
        hReport[ "failureCount" ]++
    ENDIF
    OutStd( iif( lSuccess, "PASS ", "FAIL " ) + cName + hb_eol() )

RETURN

#pragma BEGINDUMP

#include "hbapi.h"

/* Observation only: make an otherwise invisible integer-to-double conversion fail the probe. */
HB_FUNC( PROBENATIVEINTEGER )
{
    PHB_ITEM pValue = hb_param( 1, HB_IT_ANY );

    hb_retl( pValue != NULL && HB_IS_NUMINT( pValue ) && sizeof( HB_MAXINT ) == 8 );
}

#pragma ENDDUMP
