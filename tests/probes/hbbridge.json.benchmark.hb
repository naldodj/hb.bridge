/* Released to Public Domain. */
#include "set.ch"

REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE Main( cRows, cEncodes, cBatches, cWarmup )

    LOCAL cBaseline, cOptimized

    LOCAL hFixture, hReport, hSamples

    LOCAL lEqual := .T., lOptimized

    LOCAL nRows := Val( cRows ), nEncodes := Val( cEncodes )
    LOCAL nBatches := Val( cBatches ), nWarmup := Val( cWarmup )
    LOCAL nBatch, nIndex, nStarted, nElapsed, nDecimals, nFixed

    hb_cdpSelect( "UTF8EX" )
    hFixture := JSONBenchmarkFixture( nRows )
    hSamples := { "baseline" => {=>}, "optimized" => {=>} }
    hReport := { "schemaVersion" => 1, "fixture" => "json.m08.scalar.v1", ;
        "rows" => nRows, "encodesPerBatch" => nEncodes, "batches" => nBatches, ;
        "warmupEncodesPerVariant" => nWarmup, "clock" => "HBBridgeMonotonicMs", ;
        "scope" => "in-memory encoding only; fixture construction and comparisons excluded", ;
        "runtime" => Version(), "platform" => OS(), "samples" => hSamples }

    // Compare the two implementations under the supported presentation SET matrix.
    FOR nDecimals := 2 TO 18 STEP 16
        Set( _SET_DECIMALS, nDecimals )
        FOR nFixed := 0 TO 1
            Set( _SET_FIXED, nFixed == 1 )
            cBaseline := HBBridgeJSONEncodeBaseline( hFixture )
            cOptimized := HBBridgeJSONEncodeOptimized( hFixture )
            lEqual := lEqual .AND. HB_ISSTRING( cBaseline ) .AND. cBaseline == cOptimized
        NEXT
    NEXT
    Set( _SET_DECIMALS, 2 )
    Set( _SET_FIXED, .F. )
    cBaseline := HBBridgeJSONEncodeBaseline( hFixture )
    cOptimized := HBBridgeJSONEncodeOptimized( hFixture )
    lEqual := lEqual .AND. cBaseline == cOptimized
    hReport[ "byteIdentical" ] := lEqual
    hReport[ "payloadBytes" ] := Len( cBaseline )
    hReport[ "fixtureWritten" ] := hb_MemoWrit( "baseline.json", cBaseline ) .AND. ;
        hb_MemoWrit( "optimized.json", cOptimized )

    FOR nIndex := 1 TO nWarmup
        cBaseline := HBBridgeJSONEncodeBaseline( hFixture )
        cOptimized := HBBridgeJSONEncodeOptimized( hFixture )
    NEXT
    FOR nBatch := 1 TO nBatches
        // Reverse the two variants on alternate batches to reduce order bias.
        FOR nIndex := 1 TO 2
            lOptimized := ( nBatch % 2 == 1 .AND. nIndex == 2 ) .OR. ;
                ( nBatch % 2 == 0 .AND. nIndex == 1 )
            nStarted := HBBridgeMonotonicMs()
            JSONBenchmarkBatch( hFixture, nEncodes, lOptimized, @cOptimized )
            nElapsed := HBBridgeMonotonicMs() - nStarted
            hSamples[ iif( lOptimized, "optimized", "baseline" ) ][ hb_ntos( nBatch ) ] := nElapsed
            lEqual := lEqual .AND. cBaseline == cOptimized
        NEXT
    NEXT
    hReport[ "byteIdentical" ] := lEqual
    hReport[ "success" ] := lEqual .AND. hReport[ "fixtureWritten" ]
    hb_MemoWrit( "result.json", hb_jsonEncode( hReport, .T. ) )
    OutStd( "JSON encoding benchmark: " + iif( hReport[ "success" ], "OK", "FAILED" ) + hb_eol() )
    ErrorLevel( iif( hReport[ "success" ], 0, 1 ) )

RETURN

STATIC FUNCTION JSONBenchmarkFixture( nRows )

    LOCAL hRows := {=>}

    LOCAL nRow

    FOR nRow := 1 TO nRows
        hRows[ hb_ntos( nRow ) ] := { "ID" => nRow, "NAME" => "hbbridge-" + hb_ntos( nRow ), ;
            "AMOUNT" => nRow * 0.25 }
    NEXT

RETURN { "success" => .T., "rowCount" => nRows, "rows" => hRows, ;
    "columns" => { "ID" => { "type" => "N", "length" => 10, "decimals" => 0 }, ;
        "NAME" => { "type" => "C", "length" => 32, "decimals" => 0 }, ;
        "AMOUNT" => { "type" => "N", "length" => 15, "decimals" => 2 } } }

STATIC FUNCTION JSONBenchmarkBatch( hFixture, nEncodes, lOptimized, cJSON )

    LOCAL nIndex

    IF lOptimized
        FOR nIndex := 1 TO nEncodes
            cJSON := HBBridgeJSONEncodeOptimized( hFixture )
        NEXT
    ELSE
        FOR nIndex := 1 TO nEncodes
            cJSON := HBBridgeJSONEncodeBaseline( hFixture )
        NEXT
    ENDIF

RETURN NIL
