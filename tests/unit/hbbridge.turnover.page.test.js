// Released to Public Domain. Run with Node.js; no browser or network is required.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

class Element {
    constructor(tag = "") {
        this.tag = tag;
        this.children = [];
        this.style = {};
        this.handlers = {};
        this.textContent = "";
        this.disabled = false;
    }
    append(...items) { this.children.push(...items); }
    replaceChildren() { this.children = []; this.textContent = ""; }
    addEventListener(name, fn) { this.handlers[name] = fn; }
    get childElementCount() { return this.children.length; }
    click() { this.handlers.click(); }
}
const elements = Object.fromEntries(["hbb-title", "hbb-description", "hbb-note", "hbb-path", "hbb-back", "hbb-cards", "hbb-bars", "hbb-trends", "hbb-children", "hbb-employee"]
    .map(name => [name, new Element()]));
const document = {
    getElementById: id => elements[id],
    createElement: tag => new Element(tag),
    addEventListener: (event, fn) => { if (event === "DOMContentLoaded") fn(); }
};
const node = (children = {}, details = undefined) => ({initial:1, active:2, admissions:1, dismissals:0,
    transferIn:1, transferOut:0, turnoverPercent:50, children, details});
const details = {employeeName:"<img src=x onerror=1>", admissionDate:"2026-10-05", dismissalDate:null,
    transfers:{"1":{date:"2026-10-10", direction:"in", fromBranch:"02", toBranch:"01", fromCostCenter:"B", toCostCenter:"A"}}};
const payload = node({"202610":node({"99":node({"":node({"A":node({"J1":node({"001":node({}, details)})})})})})});
const source = fs.readFileSync(path.join(__dirname, "../../src/tlpp/tests/protheus/hbbridge.turnover.test/hbbridge.turnover.example.tlpp"), "utf8");
const match = source.match(/<script>\s*([\s\S]*?)\s*<\/script>/);
assert.ok(match, "turnover script exists");
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(payload)), {document});
const grid = container => elements[container].children[0];
const body = table => table.children[1];
const text = node => [node.textContent, ...node.children.flatMap(child => text(child))].filter(Boolean);
assert.equal(elements["hbb-back"].disabled, true);
assert.equal(elements["hbb-cards"].children.length, 4);
assert.equal(elements["hbb-bars"].children.length, 3);
assert.equal(elements["hbb-trends"].children.length, 2, "monthly chart shows the fixture period");
assert.ok(text(elements["hbb-trends"]).includes("202610 | Initial: 1 | Final: 2 | Turnover: 50%"));
for (let level = 0; level < 6; level++) {
    assert.equal(grid("hbb-children").tag, "table", "each hierarchy level has a detail grid");
    const firstRow = body(grid("hbb-children")).children[0];
    assert.equal(firstRow.children.length, 8, "grid includes measures and transfer counts");
    firstRow.children[0].children[0].click();
}
assert.match(elements["hbb-path"].textContent, /001$/);
assert.equal(elements["hbb-employee"].children.length, 2, "employee facts and transfers have separate grids");
const employeeValues = text(elements["hbb-employee"]);
assert.ok(employeeValues.includes("<img src=x onerror=1>"), "employee text stays literal");
assert.ok(employeeValues.includes("2026-10-05") && employeeValues.includes("Not supplied"), "dates and NULL are visible");
assert.ok(employeeValues.includes("2026-10-10") && employeeValues.includes("02") && employeeValues.includes("01"), "transfer origin and destination are visible");
elements["hbb-back"].click();
assert.match(elements["hbb-path"].textContent, /J1$/);
assert.equal(elements["hbb-employee"].children.length, 0, "employee details are cleared after Back");
const selectedLeaf = payload.children["202610"].children["99"].children[""].children["A"].children["J1"].children["001"];
selectedLeaf.details = null;
selectedLeaf.transferIn = null;
selectedLeaf.transferOut = null;
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(payload)), {document});
for (let level = 0; level < 6; level++) body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.equal(elements["hbb-employee"].textContent, "Employee details were not supplied by the source.");
elements["hbb-back"].click();
assert.ok(text(grid("hbb-children")).includes("Not supplied"), "unknown transfers are not presented as zero");
const multiple = node({"202609":node({}, null), "202610":node({}, null)});
multiple.children["202609"].transferIn = null;
multiple.children["202609"].transferOut = null;
multiple.children["202610"].admissions = 2;
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(multiple)), {document});
assert.equal(elements["hbb-trends"].children.length, 3, "monthly chart contains both periods");
assert.ok(text(elements["hbb-cards"]).includes("Active employee-months"), "cross-month total has an explicit unit");
assert.ok(text(elements["hbb-cards"]).includes("See monthly values"), "cross-month turnover is not presented as a period rate");
const missingTransfer = elements["hbb-trends"].children[1].children[3];
assert.equal(missingTransfer.children[2].textContent, "Not supplied", "unknown movement stays unknown");
assert.equal(missingTransfer.children[1].children[0].style.width, "0%", "unknown movement does not draw a full bar");
assert.equal(elements["hbb-trends"].children[1].children[1].children[1].children[0].style.width, "50%", "monthly bars share the same scale");
assert.equal(elements["hbb-trends"].children[2].children[1].children[1].children[0].style.width, "100%");
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.equal(elements["hbb-trends"].children.length, 0, "monthly chart is limited to the period overview");
const report = {definition:"source-monthly-turnover-v1", periods:{"202501":{
    initial:"1234567890123456", active:"10", admissions:"2", dismissals:"1", final:"9",
    transferIn:"3", transferOut:"2", turnoverPercent:"18.7500", dismissalPercent:"6.2500"}}};
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(report)), {document});
assert.equal(elements["hbb-title"].textContent, "Turnover: monthly source report");
assert.equal(elements["hbb-path"].textContent, "Monthly report", "source report does not claim employee-month totals");
assert.ok(text(elements["hbb-cards"]).includes("Monthly report"), "report overview does not invent totals");
assert.ok(text(elements["hbb-trends"]).includes("202501 | Initial: 1234567890123456 | Final: 9 | Turnover: 18.7500%"),
    "report displays exact source values");
assert.equal(elements["hbb-trends"].children[1].children[1].children[1].children[0].style.width,
    (100 * 2 / 3) + "%", "numeric strings contribute to chart scale");
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.equal(elements["hbb-children"].textContent, "Detailed levels are not supplied by this monthly source.");
assert.ok(text(elements["hbb-cards"]).includes("18.7500"), "selected month preserves exact decimal text");
elements["hbb-back"].click();
assert.ok(text(elements["hbb-cards"]).includes("Monthly report"));
const branchReport = {definition:"source-monthly-turnover-v1", company:"99", periods:report.periods,
    branches:{"202501":{"01":{active:"6", initial:"5", admissions:"2", dismissals:"1", transferIn:"3", transferOut:"2", turnoverPercent:"30.00"},
        "02":{active:"4", initial:"4", admissions:"0", dismissals:"0", transferIn:"0", transferOut:"0", turnoverPercent:"0.00"}}}};
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(branchReport)), {document});
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.ok(text(grid("hbb-children")).includes("Company"), "the selected month shows the company level");
assert.equal(body(grid("hbb-children")).children.length, 1);
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.ok(text(grid("hbb-children")).includes("Branch"), "the company grid identifies the branch level");
assert.equal(body(grid("hbb-children")).children.length, 2, "each source branch has its own row");
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.match(elements["hbb-path"].textContent, /202501 \/ 99 \/ 01$/);
assert.ok(text(elements["hbb-cards"]).includes("30.00"), "branch percentage comes from its own query");
assert.equal(elements["hbb-children"].textContent, "No further detail is supplied for this level.");
elements["hbb-back"].click();
assert.equal(body(grid("hbb-children")).children.length, 2, "Back restores the branch grid");
let costReceiver, costRequest;
const bridge = {
    onAdvplToJs: handler => { costReceiver = handler; },
    send: (type, body) => { costRequest = {type, body:JSON.parse(body)}; return true; }
};
const dynamicReport = {...branchReport, costCenterAvailable:true};
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(dynamicReport)),
    {document, window:{FWWebEx:{TWebChannel:bridge}}, setTimeout, clearTimeout});
for (let level = 0; level < 3; level++) body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.equal(costRequest.type, "HBBRIDGE_TURNOVER_COST_REQUEST");
assert.equal(costRequest.body.period, "202501");
assert.equal(costRequest.body.branch, "01");
assert.equal(elements["hbb-children"].textContent, "Loading cost centers...");
const costRow = {PERIODO:"202501", RA_FILIAL:"01", RA_CC:"100", CTT_DESC01:"Sales",
    TFUNIMES:5, TFUNMES:6, TFUNADMMES:2, TFUNDEMMES:1, TFUNFMES:5, TTRFENT:3, TTRFSAI:2, TURNOVER:"30.00", TURNMOVF:"10.00"};
costReceiver("HBBRIDGE_TURNOVER_COST_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":costRow}}));
assert.ok(text(grid("hbb-children")).includes("Cost center"));
assert.ok(text(grid("hbb-children")).includes("100 - Sales"));
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.equal(costRequest.type, "HBBRIDGE_TURNOVER_JOB_REQUEST");
assert.equal(costRequest.body.period, "202501");
assert.equal(costRequest.body.branch, "01");
assert.equal(costRequest.body.cost, "100");
assert.equal(elements["hbb-children"].textContent, "Loading jobs...");
const jobRow = {...costRow, RA_CODFUNC:"J1", RJ_DESC:"Analyst", TURNOVER:"12.50"};
costReceiver("HBBRIDGE_TURNOVER_JOB_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":jobRow}}));
assert.ok(text(grid("hbb-children")).includes("Job"));
assert.ok(text(grid("hbb-children")).includes("J1 - Analyst"));
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.equal(costRequest.type, "HBBRIDGE_TURNOVER_EMPLOYEE_REQUEST");
assert.equal(costRequest.body.period, "202501");
assert.equal(costRequest.body.branch, "01");
assert.equal(costRequest.body.cost, "100");
assert.equal(costRequest.body.job, "J1");
const employeeRow = {...jobRow, RA_MAT:"001", SRARECNO:"12", RA_NOME:"Alex Example",
    RA_ADMISSA:"20220110", RA_DEMISSA:""};
const sourceEvent = {SRARECNO:"12", EVENTRECNO:"43", RE_DATA:"20250115", RE_EMPP:"99", RE_FILIALP:"02",
    RE_MATP:"007", RE_CCP:"200", RE_EMPD:"99", RE_FILIALD:"01", RE_MATD:"001", RE_CCD:"100", MATCHOUT:1, MATCHIN:0};
costReceiver("HBBRIDGE_TURNOVER_EMPLOYEE_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":employeeRow}, transferStatus:"matched", transferRows:{"1":sourceEvent}}));
assert.ok(text(grid("hbb-children")).includes("Employee"));
assert.ok(text(grid("hbb-children")).includes("001 - Alex Example"));
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.ok(text(elements["hbb-cards"]).includes("12.50"));
assert.ok(text(elements["hbb-employee"]).includes("20220110"));
assert.ok(text(elements["hbb-employee"]).includes("20250115"));
assert.ok(text(elements["hbb-employee"]).includes("Cost center P"));
assert.ok(text(elements["hbb-employee"]).some(item => item.includes("coverage may be partial")));
assert.ok(text(elements["hbb-employee"]).includes("2"), "model transfer counts remain independent of event rows");
elements["hbb-back"].click();
assert.ok(text(grid("hbb-children")).includes("001 - Alex Example"));
elements["hbb-back"].click();
assert.ok(text(grid("hbb-children")).includes("J1 - Analyst"), "Back restores the loaded jobs");
elements["hbb-back"].click();
assert.ok(text(grid("hbb-children")).includes("100 - Sales"), "Back restores the loaded cost centers");
elements["hbb-back"].click();
const previousRequest = costRequest;
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.equal(costRequest, previousRequest, "revisiting a branch does not repeat its completed SQL batch");
elements["hbb-back"].click();
body(grid("hbb-children")).children[1].children[0].children[0].click();
assert.equal(costRequest.body.branch, "02");
costReceiver("HBBRIDGE_TURNOVER_COST_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":costRow}}));
assert.match(elements["hbb-children"].textContent, /failed or its outcome is unknown/,
    "a result from another branch is rejected");
const failedRequest = costRequest;
elements["hbb-back"].click();
body(grid("hbb-children")).children[1].children[0].children[0].click();
assert.equal(costRequest, failedRequest, "a failed or uncertain request is not retried automatically");
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(dynamicReport)),
    {document, window:{FWWebEx:{TWebChannel:bridge}}, setTimeout, clearTimeout});
for (let level = 0; level < 3; level++) body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_COST_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":costRow}}));
body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_JOB_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":{...jobRow,RA_CC:"200"}}}));
assert.match(elements["hbb-children"].textContent, /failed or its outcome is unknown/,
    "jobs from another cost center are rejected");
const failedJobRequest = costRequest;
elements["hbb-back"].click();
body(grid("hbb-children")).children[0].children[0].children[0].click();
assert.equal(costRequest, failedJobRequest, "an uncertain job request is not retried automatically");
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(dynamicReport)),
    {document, window:{FWWebEx:{TWebChannel:bridge}}, setTimeout, clearTimeout});
for (let level = 0; level < 3; level++) body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_COST_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":costRow}}));
body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_JOB_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":jobRow}}));
body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_EMPLOYEE_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":{...employeeRow,RA_CODFUNC:"J2"}}}));
assert.match(elements["hbb-children"].textContent, /failed or its outcome is unknown/,
    "employees from another job are rejected");
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(dynamicReport)),
    {document, window:{FWWebEx:{TWebChannel:bridge}}, setTimeout, clearTimeout});
for (let level = 0; level < 3; level++) body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_COST_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":costRow}}));
body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_JOB_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":jobRow}}));
body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_EMPLOYEE_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":employeeRow}, transferStatus:"matched", transferRows:{"1":{...sourceEvent,SRARECNO:"999"}}}));
assert.match(elements["hbb-children"].textContent, /failed or its outcome is unknown/,
    "transfer evidence cannot be attributed to another employee");
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify(dynamicReport)),
    {document, window:{FWWebEx:{TWebChannel:bridge}}, setTimeout, clearTimeout});
for (let level = 0; level < 3; level++) body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_COST_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":costRow}}));
body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_JOB_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":jobRow}}));
body(grid("hbb-children")).children[0].children[0].children[0].click();
costReceiver("HBBRIDGE_TURNOVER_EMPLOYEE_RESPONSE", JSON.stringify({requestID:costRequest.body.requestID, success:true,
    rowCount:1, rows:{"1":employeeRow}, transferStatus:"matched", transferRows:{"1":{...sourceEvent,RE_CCD:"999"}}}));
assert.match(elements["hbb-children"].textContent, /failed or its outcome is unknown/,
    "transfer evidence outside the selected assignment is rejected");
vm.runInNewContext(match[1].replace("@@DATA@@", JSON.stringify({definition:"source-monthly-turnover-v1",periods:{}})), {document});
assert.equal(elements["hbb-children"].textContent, "No rows at this level.", "an empty report is not described as missing drill-down");
console.log("Turnover page: monthly chart, level grids, employee facts, transfers, literal text and Back passed.");
