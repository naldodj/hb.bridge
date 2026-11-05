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
const elements = Object.fromEntries(["hbb-path", "hbb-back", "hbb-cards", "hbb-bars", "hbb-children", "hbb-employee"]
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
console.log("Turnover page: level grids, employee facts, transfers, literal text and Back passed.");
