/* Released to Public Domain. The fixture contains no ERP data. */
PROCEDURE TurnoverAddonTests( hRegistry, hContext, nFailures, nChecks )

    LOCAL cSQL

    LOCAL hParams, hResult, hCompany, hEmpty, hDenied

    cSQL := "SELECT PERIOD, COMPANY, BRANCH, COST_CENTER, JOB, EMPLOYEE, ACTIVE, ADMISSION, DISMISSAL " + ;
        "FROM turnover_fixture WHERE COMPANY = ? ORDER BY EMPLOYEE"
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "CREATE TABLE turnover_fixture (PERIOD TEXT, COMPANY TEXT, BRANCH TEXT, COST_CENTER TEXT, " + ;
        "JOB TEXT, EMPLOYEE TEXT, ACTIVE INTEGER, ADMISSION INTEGER, DISMISSAL INTEGER)" }, hContext )
    M1Assert( hResult[ "success" ], "turnover fixture creates an isolated table", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "INSERT INTO turnover_fixture VALUES " + ;
        "('202610','99','01','A','J1','001',1,0,0)," + ;
        "('202610','99','01','A','J1','002',1,1,0)," + ;
        "('202610','99','02','B','J2','003',1,0,1)" }, hContext )
    M1Assert( hResult[ "success" ], "turnover fixture inserts three controlled records", @nFailures, @nChecks )
    hParams := { "profile" => "sample", "sql" => cSQL, ;
        "bindings" => { "1" => { "type" => "text", "isNull" => .F., "value" => "99" } } }
    hResult := TurnoverTestCall( hRegistry, hContext, hParams )
    M1Assert( hb_HGetDef( hResult, "success", .F. ), "turnover addon queries and calculates", @nFailures, @nChecks )
    IF hb_HGetDef( hResult, "success", .F. )
        hCompany := hResult[ "result" ][ "children" ][ "202610" ][ "children" ][ "99" ]
        M1Assert( hResult[ "rowCount" ] == 3 .AND. hCompany[ "active" ] == 3 .AND. ;
            hCompany[ "initial" ] == 2 .AND. hCompany[ "admissions" ] == 1 .AND. ;
            hCompany[ "dismissals" ] == 1 .AND. hCompany[ "turnoverPercent" ] == 50 .AND. ;
            hCompany[ "dismissalPercent" ] == 25, "turnover company formula and totals", @nFailures, @nChecks )
        M1Assert( hCompany[ "children" ][ "01" ][ "active" ] == 2 .AND. ;
            hCompany[ "children" ][ "02" ][ "dismissals" ] == 1, ;
            "turnover branch groups are independent", @nFailures, @nChecks )
        M1Assert( hCompany[ "children" ][ "01" ][ "children" ][ "A" ][ "children" ][ "J1" ] ;
            [ "children" ][ "002" ][ "admissions" ] == 1, ;
            "turnover supports drill down to the employee", @nFailures, @nChecks )
    ENDIF
    TurnoverDetailTests( hRegistry, hContext, hParams, @nFailures, @nChecks )
    hEmpty := hb_HClone( hParams )
    hEmpty[ "bindings" ] := { "1" => { "type" => "text", "isNull" => .F., "value" => "no-company" } }
    hResult := TurnoverTestCall( hRegistry, hContext, hEmpty )
    M1Assert( hb_HGetDef( hResult, "success", .F. ) .AND. hResult[ "rowCount" ] == 0 .AND. ;
        hResult[ "result" ][ "turnoverPercent" ] == 0, "turnover handles an empty query", @nFailures, @nChecks )
    hEmpty := hb_HClone( hParams )
    hEmpty[ "sql" ] := "SELECT PERIOD FROM turnover_fixture WHERE COMPANY = ?"
    hResult := TurnoverTestCall( hRegistry, hContext, hEmpty )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "INVALID_SOURCE", ;
        "turnover rejects missing required columns", @nFailures, @nChecks )
    hEmpty[ "sql" ] := "SELECT PERIOD FROM absent_turnover_table WHERE COMPANY = ?"
    hResult := TurnoverTestCall( hRegistry, hContext, hEmpty )
    M1Assert( ! hResult[ "success" ], "turnover propagates query failures", @nFailures, @nChecks )
    hResult := TurnoverTestCall( hRegistry, hContext, hParams )
    M1Assert( hb_HGetDef( hResult, "success", .F. ), "turnover recovers after a failed query", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "INSERT INTO turnover_fixture (PERIOD, COMPANY, BRANCH, COST_CENTER, JOB, EMPLOYEE, ACTIVE, ADMISSION, DISMISSAL) VALUES ('202610','99','','','J1','004',1,0,0)" }, hContext )
    M1Assert( hResult[ "success" ], "turnover shared branch fixture is prepared", @nFailures, @nChecks )
    hResult := TurnoverTestCall( hRegistry, hContext, hParams )
    M1Assert( hb_HGetDef( hResult, "success", .F. ) .AND. ;
        hResult[ "result" ][ "children" ][ "202610" ][ "children" ][ "99" ][ "children" ][ "" ][ "active" ] == 1, ;
        "turnover preserves blank shared branch and cost center", @nFailures, @nChecks )
    HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "DELETE FROM turnover_fixture WHERE EMPLOYEE = '004'" }, hContext )
    hDenied := HBBridgeContext( "restricted" )
    hDenied[ "permissions" ] := { "addon.execute" }
    hResult := TurnoverTestCall( hRegistry, hDenied, hParams )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "FORBIDDEN", ;
        "turnover query inherits caller permissions", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "INSERT INTO turnover_fixture (PERIOD, COMPANY, BRANCH, COST_CENTER, JOB, EMPLOYEE, ACTIVE, ADMISSION, DISMISSAL) VALUES ('202613','99','01','A','J1','004',1,0,0)" }, hContext )
    M1Assert( hResult[ "success" ], "turnover invalid period fixture is prepared", @nFailures, @nChecks )
    hResult := TurnoverTestCall( hRegistry, hContext, hParams )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "INVALID_SOURCE", ;
        "turnover rejects invalid calendar months", @nFailures, @nChecks )
    HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "DELETE FROM turnover_fixture WHERE EMPLOYEE = '004'" }, hContext )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "INSERT INTO turnover_fixture SELECT * FROM turnover_fixture WHERE EMPLOYEE = '001'" }, hContext )
    M1Assert( hResult[ "success" ], "turnover duplicate fixture is prepared", @nFailures, @nChecks )
    hResult := TurnoverTestCall( hRegistry, hContext, hParams )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "DUPLICATE_EMPLOYEE", ;
        "turnover rejects duplicate employee periods", @nFailures, @nChecks )
RETURN

STATIC PROCEDURE TurnoverDetailTests( hRegistry, hContext, hParams, nFailures, nChecks )

    LOCAL cDetails, cSQL

    LOCAL hDetail, hEvents, hResult, hRequest, hRoot, hLeaf

    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "ALTER TABLE turnover_fixture ADD COLUMN DETAILS_JSON TEXT" }, hContext )
    M1Assert( hResult[ "success" ], "turnover detail column is created", @nFailures, @nChecks )
    hEvents := { "1" => { "date" => "2026-10-10", "direction" => "in", ;
        "fromBranch" => "02", "toBranch" => "01", "fromCostCenter" => "B", "toCostCenter" => "A" }, ;
        "2" => { "date" => "2026-09-10", "direction" => "out", ;
        "fromBranch" => "01", "toBranch" => "02", "fromCostCenter" => "A", "toCostCenter" => "B" } }
    hDetail := { "employeeName" => "Alex Example", "admissionDate" => "2022-04-12", ;
        "dismissalDate" => NIL, "transfers" => hEvents }
    cDetails := HBBridgeJSONEncode( hDetail )
    cSQL := "UPDATE turnover_fixture SET DETAILS_JSON='" + StrTran( cDetails, "'", "''" ) + "' WHERE EMPLOYEE='001'"
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => cSQL }, hContext )
    M1Assert( hResult[ "success" ], "turnover employee details are saved", @nFailures, @nChecks )
    hDetail := { "employeeName" => "Blair Example", "admissionDate" => "2026-10-05", ;
        "dismissalDate" => NIL, "transfers" => {=>} }
    cSQL := "UPDATE turnover_fixture SET DETAILS_JSON='" + ;
        StrTran( HBBridgeJSONEncode( hDetail ), "'", "''" ) + "' WHERE EMPLOYEE='002'"
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => cSQL }, hContext )
    M1Assert( hResult[ "success" ], "turnover empty transfer history is saved", @nFailures, @nChecks )
    hRequest := hb_HClone( hParams )
    hRequest[ "sql" ] := "SELECT PERIOD, COMPANY, BRANCH, COST_CENTER, JOB, EMPLOYEE, " + ;
        "ACTIVE, ADMISSION, DISMISSAL, DETAILS_JSON FROM turnover_fixture WHERE COMPANY = ? ORDER BY EMPLOYEE"
    hResult := TurnoverTestCall( hRegistry, hContext, hRequest )
    M1Assert( hResult[ "success" ], "turnover accepts partial detail availability", @nFailures, @nChecks )
    IF hResult[ "success" ]
        hRoot := hResult[ "result" ]
        hLeaf := hRoot[ "children" ][ "202610" ][ "children" ][ "99" ][ "children" ][ "01" ]
        M1Assert( hRoot[ "transferIn" ] == NIL .AND. ! hRoot[ "transferEvidenceComplete" ], ;
            "turnover does not report partial transfer totals as complete", @nFailures, @nChecks )
        M1Assert( hLeaf[ "transferIn" ] == 1 .AND. hLeaf[ "transferOut" ] == 0 .AND. ;
            hLeaf[ "transferEvidenceComplete" ], "turnover counts only events in the requested month", @nFailures, @nChecks )
        M1Assert( hLeaf[ "children" ][ "A" ][ "children" ][ "J1" ][ "children" ][ "002" ][ "transferIn" ] == 0, ;
            "turnover distinguishes an explicitly empty history", @nFailures, @nChecks )
        hLeaf := hLeaf[ "children" ][ "A" ][ "children" ][ "J1" ][ "children" ][ "001" ]
        M1Assert( hLeaf[ "details" ][ "admissionDate" ] == "2022-04-12" .AND. ;
            hLeaf[ "details" ][ "transfers" ][ "1" ][ "toBranch" ] == "01" .AND. ;
            hLeaf[ "transferIn" ] == 1, "turnover preserves employee dates and transfer evidence", @nFailures, @nChecks )
    ENDIF
    hDetail := { "employeeName" => "Casey Example", "admissionDate" => "2021-03-01", ;
        "dismissalDate" => "2026-10-18", "transfers" => ;
        { "1" => { "date" => "2026-10-08", "direction" => "out", "fromBranch" => "02", ;
            "toBranch" => "01", "fromCostCenter" => "B", "toCostCenter" => "A" } } }
    cSQL := "UPDATE turnover_fixture SET DETAILS_JSON='" + ;
        StrTran( HBBridgeJSONEncode( hDetail ), "'", "''" ) + "' WHERE EMPLOYEE='003'"
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => cSQL }, hContext )
    M1Assert( hResult[ "success" ], "turnover dismissal and transfer details are saved", @nFailures, @nChecks )
    hResult := TurnoverTestCall( hRegistry, hContext, hRequest )
    M1Assert( hResult[ "success" ] .AND. hResult[ "result" ][ "transferIn" ] == 1 .AND. ;
        hResult[ "result" ][ "transferOut" ] == 1 .AND. hResult[ "result" ][ "transferEvidenceComplete" ], ;
        "turnover totals include complete transfer evidence across branches", @nFailures, @nChecks )
    IF hResult[ "success" ]
        hLeaf := hResult[ "result" ][ "children" ][ "202610" ][ "children" ][ "99" ][ "children" ][ "02" ]
        hLeaf := hLeaf[ "children" ][ "B" ][ "children" ][ "J2" ][ "children" ][ "003" ]
        M1Assert( hLeaf[ "dismissals" ] == 1 .AND. hLeaf[ "details" ][ "dismissalDate" ] == "2026-10-18" .AND. ;
            hLeaf[ "transferOut" ] == 1 .AND. hLeaf[ "details" ][ "transfers" ][ "1" ][ "fromBranch" ] == "02", ;
            "turnover preserves dismissal and outgoing transfer details", @nFailures, @nChecks )
    ENDIF
    hDetail[ "dismissalDate" ] := "2026-02-30"
    cSQL := "UPDATE turnover_fixture SET DETAILS_JSON='" + ;
        StrTran( HBBridgeJSONEncode( hDetail ), "'", "''" ) + "' WHERE EMPLOYEE='003'"
    HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => cSQL }, hContext )
    hResult := TurnoverTestCall( hRegistry, hContext, hRequest )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "INVALID_SOURCE", ;
        "turnover rejects invalid employee dates", @nFailures, @nChecks )
RETURN
STATIC FUNCTION TurnoverTestCall( hRegistry, hContext, hParams )
RETURN HBBridgeDispatch( hRegistry, "ADDON.Execute", ;
    { "module" => "hbbridgeaddons.hrb", "params" => { "action" => "turnover", "params" => hParams } }, hContext )
