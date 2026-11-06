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
    TurnoverPeriodTests( hRegistry, hContext, @nFailures, @nChecks )
    TurnoverReportTests( hRegistry, hContext, @nFailures, @nChecks )
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

/* This controlled source exercises monthly eligibility, not historical SRE/SR7 reconstruction. */
STATIC PROCEDURE TurnoverPeriodTests( hRegistry, hContext, nFailures, nChecks )

    LOCAL cSQL

    LOCAL hParams, hResult, hOctober, hNovember

    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "CREATE TABLE turnover_dates (COMPANY TEXT, EMPLOYEE TEXT, ADMITTED TEXT, DISMISSED TEXT)" }, hContext )
    M1Assert( hResult[ "success" ], "turnover monthly date fixture is created", @nFailures, @nChecks )
    IF ! hResult[ "success" ]
        RETURN
    ENDIF
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "INSERT INTO turnover_dates VALUES " + ;
        "('99','001','20250101',''),('99','002','20261001','20261031')," + ;
        "('99','003','20261031',''),('99','004','20260901','20261001')," + ;
        "('99','005','20261101',''),('99','006','20260901','20260930')," + ;
        "('98','007','20261001','20261031')" }, hContext )
    M1Assert( hResult[ "success" ], "turnover monthly date fixture is populated", @nFailures, @nChecks )
    IF ! hResult[ "success" ]
        RETURN
    ENDIF
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "CREATE TABLE turnover_months (PERIOD TEXT, COMPANY TEXT, BRANCH TEXT, COST_CENTER TEXT, " + ;
        "JOB TEXT, EMPLOYEE TEXT, ACTIVE INTEGER, ADMISSION INTEGER, DISMISSAL INTEGER)" }, hContext )
    M1Assert( hResult[ "success" ], "turnover monthly source has declared types", @nFailures, @nChecks )
    IF ! hResult[ "success" ]
        RETURN
    ENDIF
    cSQL := "INSERT INTO turnover_months SELECT P.PERIOD, E.COMPANY, '01', 'A', 'J1', " + ;
        "E.EMPLOYEE, 1 AS ACTIVE, CASE WHEN SUBSTR(E.ADMITTED,1,6)=P.PERIOD THEN 1 ELSE 0 END AS ADMISSION, " + ;
        "CASE WHEN SUBSTR(E.DISMISSED,1,6)=P.PERIOD THEN 1 ELSE 0 END AS DISMISSAL " + ;
        "FROM turnover_dates E CROSS JOIN (SELECT '202610' AS PERIOD UNION ALL SELECT '202611') P " + ;
        "WHERE SUBSTR(E.ADMITTED,1,6)<=P.PERIOD AND " + ;
        "(E.DISMISSED='' OR (SUBSTR(E.ADMITTED,1,6)<=SUBSTR(E.DISMISSED,1,6) " + ;
        "AND SUBSTR(E.DISMISSED,1,6)>=P.PERIOD))"
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => cSQL }, hContext )
    M1Assert( hResult[ "success" ], "turnover materializes eligible employee-months", @nFailures, @nChecks )
    IF ! hResult[ "success" ]
        RETURN
    ENDIF
    cSQL := "SELECT PERIOD, COMPANY, BRANCH, COST_CENTER, JOB, EMPLOYEE, ACTIVE, ADMISSION, DISMISSAL " + ;
        "FROM turnover_months WHERE COMPANY = ? ORDER BY PERIOD, EMPLOYEE"
    hParams := { "profile" => "sample", "sql" => cSQL, ;
        "bindings" => { "1" => { "type" => "text", "isNull" => .F., "value" => "99" } } }
    hResult := TurnoverTestCall( hRegistry, hContext, hParams )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 7, ;
        "turnover selects eligible employee-months across boundaries", @nFailures, @nChecks )
    IF hResult[ "success" ] .AND. hResult[ "rowCount" ] == 7
        hOctober := hResult[ "result" ][ "children" ][ "202610" ][ "children" ][ "99" ]
        hNovember := hResult[ "result" ][ "children" ][ "202611" ][ "children" ][ "99" ]
        M1Assert( hOctober[ "active" ] == 4 .AND. hOctober[ "admissions" ] == 2 .AND. ;
            hOctober[ "dismissals" ] == 2 .AND. hOctober[ "initial" ] == 2 .AND. ;
            hOctober[ "turnoverPercent" ] == 100 .AND. hOctober[ "dismissalPercent" ] == 50, ;
            "turnover includes same-month admission and dismissal", @nFailures, @nChecks )
        M1Assert( hNovember[ "active" ] == 3 .AND. hNovember[ "admissions" ] == 1 .AND. ;
            hNovember[ "dismissals" ] == 0 .AND. hNovember[ "initial" ] == 2 .AND. ;
            hNovember[ "turnoverPercent" ] == 25, ;
            "turnover excludes earlier dismissals and includes subsequent admissions", @nFailures, @nChecks )
    ENDIF
    hParams[ "bindings" ][ "1" ][ "value" ] := "98"
    hResult := TurnoverTestCall( hRegistry, hContext, hParams )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 1 .AND. ;
        hResult[ "result" ][ "initial" ] == 0 .AND. hResult[ "result" ][ "turnoverPercent" ] == 0 .AND. ;
        hResult[ "result" ][ "dismissalPercent" ] == 0, ;
        "turnover preserves the zero denominator rule", @nFailures, @nChecks )
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

/* The fixture represents already-aggregated report rows, not employee records. */
STATIC PROCEDURE TurnoverReportTests( hRegistry, hContext, nFailures, nChecks )

    LOCAL cBranchSQL, cSQL

    LOCAL hParams, hResult, hDenied

    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "CREATE TABLE turnover_report (COMPANY TEXT, RA_FILIAL TEXT, PERIODO TEXT, TTRFSAI INTEGER, TTRFENT INTEGER, " + ;
        "TFUNIMES INTEGER, TFUNADMMES INTEGER, TFUNMES INTEGER, TFUNDEMMES INTEGER, TFUNFMES INTEGER, " + ;
        "TURNOVER TEXT, TURNMOVF TEXT)" }, hContext )
    M1Assert( hResult[ "success" ], "monthly report fixture has declared types", @nFailures, @nChecks )
    IF ! hResult[ "success" ]
        RETURN
    ENDIF
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "INSERT INTO turnover_report VALUES " + ;
        "('99','01','202610',2,3,8,2,10,1,9,'18.7500','6.2500')," + ;
        "('99','01','202611',0,1,9,1,10,0,10,'5.5556','0.0000')" }, hContext )
    M1Assert( hResult[ "success" ], "monthly report fixture has independent aggregates", @nFailures, @nChecks )
    IF ! hResult[ "success" ]
        RETURN
    ENDIF
    cSQL := "SELECT PERIODO,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF " + ;
        "FROM turnover_report WHERE COMPANY = ? ORDER BY PERIODO"
    hParams := { "profile" => "sample", "sql" => cSQL, ;
        "bindings" => { "1" => { "type" => "text", "isNull" => .F., "value" => "99" } } }
    hResult := TurnoverReportTestCall( hRegistry, hContext, hParams )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 2, ;
        "monthly report action returns each period", @nFailures, @nChecks )
    IF hResult[ "success" ]
        M1Assert( TurnoverReportTestNumber( hResult[ "periods" ][ "202610" ][ "active" ] ) == 10 .AND. ;
            TurnoverReportTestNumber( hResult[ "periods" ][ "202610" ][ "transferOut" ] ) == 2 .AND. ;
            TurnoverReportTestNumber( hResult[ "periods" ][ "202610" ][ "transferIn" ] ) == 3 .AND. ;
            TurnoverReportTestNumber( hResult[ "periods" ][ "202610" ][ "final" ] ) == 9, ;
            "monthly report maps source aggregates without summing levels", @nFailures, @nChecks )
        M1Assert( HB_ISSTRING( hResult[ "periods" ][ "202610" ][ "turnoverPercent" ] ) .AND. ;
            HB_ISSTRING( hResult[ "periods" ][ "202611" ][ "turnoverPercent" ] ) .AND. ;
            hResult[ "periods" ][ "202610" ][ "turnoverPercent" ] == "18.7500" .AND. ;
            hResult[ "periods" ][ "202611" ][ "turnoverPercent" ] == "5.5556", ;
            "monthly report preserves supplied exact decimal strings", @nFailures, @nChecks )
    ENDIF
    cBranchSQL := "SELECT PERIODO,RA_FILIAL,TTRFSAI,TTRFENT,TFUNIMES," + ;
        "TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF FROM turnover_report WHERE COMPANY = ?"
    hParams[ "branchSql" ] := cBranchSQL
    hParams[ "branchBindings" ] := { "1" => { "type" => "text", "isNull" => .F., "value" => "99" } }
    hResult := TurnoverReportTestCall( hRegistry, hContext, hParams )
    M1Assert( hResult[ "success" ] .AND. hResult[ "branchRowCount" ] == 2 .AND. ;
        hResult[ "branches" ][ "202610" ][ "01" ][ "turnoverPercent" ] == "18.7500", ;
        "monthly report includes independent branch measures", @nFailures, @nChecks )
    hParams[ "branchSql" ] := cBranchSQL + " UNION ALL " + cBranchSQL
    hParams[ "branchBindings" ][ "2" ] := { "type" => "text", "isNull" => .F., "value" => "99" }
    hResult := TurnoverReportTestCall( hRegistry, hContext, hParams )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "DUPLICATE_BRANCH", ;
        "monthly report rejects duplicate period and branch keys", @nFailures, @nChecks )
    hParams[ "sql" ] := StrTran( cSQL, " ORDER BY PERIODO", " AND PERIODO='202611' ORDER BY PERIODO" )
    hParams[ "branchSql" ] := cBranchSQL + " AND PERIODO='202610'"
    hb_HDel( hParams[ "branchBindings" ], "2" )
    hResult := TurnoverReportTestCall( hRegistry, hContext, hParams )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "UNMATCHED_PERIOD", ;
        "monthly report rejects branch periods absent from the company source", @nFailures, @nChecks )
    hParams[ "sql" ] := cSQL
    hb_HDel( hParams, "branchSql" )
    hb_HDel( hParams, "branchBindings" )
    hDenied := HBBridgeContext( "restricted" )
    hDenied[ "permissions" ] := { "addon.execute" }
    hResult := TurnoverReportTestCall( hRegistry, hDenied, hParams )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "FORBIDDEN", ;
        "monthly report inherits query authorization", @nFailures, @nChecks )
    hParams[ "sql" ] := "SELECT PERIODO FROM turnover_report WHERE COMPANY = ?"
    hResult := TurnoverReportTestCall( hRegistry, hContext, hParams )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "INVALID_SOURCE", ;
        "monthly report requires all source measures", @nFailures, @nChecks )
    hParams[ "sql" ] := cSQL
    HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "INSERT INTO turnover_report SELECT * FROM turnover_report WHERE PERIODO='202610'" }, hContext )
    hResult := TurnoverReportTestCall( hRegistry, hContext, hParams )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "DUPLICATE_PERIOD", ;
        "monthly report rejects duplicate periods", @nFailures, @nChecks )
    HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "DELETE FROM turnover_report WHERE PERIODO='202610'" }, hContext )
    HBBridgeDispatch( hRegistry, "RPCRDD.Execute", ;
        { "requestVersion" => 1, "alias" => "sample", "sql" => ;
        "UPDATE turnover_report SET TURNOVER='invalid' WHERE PERIODO='202611'" }, hContext )
    hResult := TurnoverReportTestCall( hRegistry, hContext, hParams )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "INVALID_SOURCE", ;
        "monthly report rejects nonnumeric measures", @nFailures, @nChecks )
RETURN

STATIC FUNCTION TurnoverReportTestCall( hRegistry, hContext, hParams )
RETURN HBBridgeDispatch( hRegistry, "ADDON.Execute", ;
    { "module" => "hbbridgeaddons.hrb", "params" => { "action" => "turnoverReport", "params" => hParams } }, hContext )

STATIC FUNCTION TurnoverReportTestNumber( xValue )
    IF HB_ISSTRING( xValue )
        RETURN Val( xValue )
    ENDIF
RETURN xValue
