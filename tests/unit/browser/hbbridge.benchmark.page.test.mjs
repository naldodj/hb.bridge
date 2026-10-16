/* Released to Public Domain. */
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {existsSync, mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import test from 'node:test';

const ProjectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const PageSource = join(ProjectRoot, 'src/tlpp/tests/protheus/hbbridge.benchmark.test/hbbridge.benchmark.page.tlpp');
const Match = readFileSync(PageSource, 'utf8').match(/beginContent\s+var\s+cHTML\s*\r?\n([\s\S]*?)\r?\n\s*endContent/i);
assert.ok(Match, 'The browser test must extract the actual TLPP HTML template.');
const Template = Match[1];
const Candidates = [
    process.env.HBBRIDGE_TEST_BROWSER,
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome'
].filter(Boolean);
const Browser = Candidates.find(candidate => existsSync(candidate));
const ArtifactRoot = join(ProjectRoot, 'tmp', 'benchmark-browser-' + process.pid);
mkdirSync(ArtifactRoot, {recursive: true});

function JSONForHTML(value) {
    return JSON.stringify(value).replace(/</g, '\\u003c').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
}

function Defaults(instance = 'browser-test', profile = 'MSSQL/pData') {
    return {instance, profile, rows: 1000, pageSize: 100, iterations: 5, warmup: 2, timeoutSeconds: 30};
}

function Document(component, before = '', after = '') {
    return '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
        '<meta name="viewport" content="width=device-width,initial-scale=1"><title>hbBridge benchmark browser verification</title>' +
        '</head><body>' + before + component + after + '</body></html>';
}

function RunBrowser(path) {
    assert.ok(Browser, 'A local Chromium browser is required. Set HBBRIDGE_TEST_BROWSER to its executable path.');
    return execFileSync(Browser, [
        '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
        '--disable-background-networking', '--disable-extensions',
        '--user-data-dir=' + join(ArtifactRoot, 'profile-' + Date.now()),
        '--virtual-time-budget=10000', '--dump-dom', pathToFileURL(path).href
    ], {encoding: 'utf8', maxBuffer: 24 * 1024 * 1024, timeout: 60000, windowsHide: true,
        stdio: ['ignore', 'pipe', 'pipe']});
}

const Bootstrap = `<script>
    window.HBBTest = {calls: [], mode: 'ok', receiver: null, unsubscribed: 0, timers: new Map(), blobs: []};
    window.__HBBridgeBenchmarkTestHook = api => { window.HBBTest.api = api; };
    const HBBNativeTimeout = window.setTimeout.bind(window);
    const HBBNativeClear = window.clearTimeout.bind(window);
    let HBBTimerSequence = 1000000;
    window.setTimeout = (callback, delay, ...args) => {
        if (delay === 30000) {
            const token = ++HBBTimerSequence;
            HBBTest.timers.set(token, () => callback(...args));
            return token;
        }
        return HBBNativeTimeout(callback, delay, ...args);
    };
    window.clearTimeout = token => {
        if (!HBBTest.timers.delete(token)) HBBNativeClear(token);
    };
    URL.createObjectURL = blob => { HBBTest.blobs.push(blob); return 'blob:hbbridge-test'; };
    URL.revokeObjectURL = () => {};
    HTMLAnchorElement.prototype.click = function () {};
    window.FWWebEx = {TWebChannel: {
        onAdvplToJs(receiver) {
            HBBTest.receiver = receiver;
            return () => { HBBTest.unsubscribed++; };
        },
        send(type, content) {
            HBBTest.calls.push({type, content: JSON.parse(content)});
            if (HBBTest.mode === 'false') return false;
            if (HBBTest.mode === 'reject') return Promise.reject(new Error('Private native detail must not reach the UI.'));
            if (HBBTest.mode === 'throw') throw new Error('Private native detail must not reach the UI.');
            return Promise.resolve(true);
        }
    }};
</script>`;

// Test observations run against Chromium's actual DOM and the extracted component.
const Assertions = `<script>
(async () => {
    const passed = [];
    const failures = [];
    const E = name => document.getElementById('hbb-' + name);
    const A = (condition, name) => { if (!condition) throw new Error(name); passed.push(name); };
    const Tick = async () => { await Promise.resolve(); await Promise.resolve(); await Promise.resolve(); };
    const Submit = () => E('form').dispatchEvent(new Event('submit', {cancelable: true}));
    const Reply = report => HBBTest.receiver('HBBRIDGE_BENCHMARK_RESPONSE', JSON.stringify({
        instance: 'browser-test', requestID: HBBTest.api.State.pending, report
    }));
    const Sample = (elapsedMs, success = true) => ({elapsedMs, success, failureCategory: success ? '' : 'QUERY_FAILED',
        rowsRead: success ? 1000 : 0, pagesRead: success ? 10 : 0, rpcCalls: success ? 10 : 1});
    const Series = () => ({success: true, completedIterations: 5, warmupCompleted: 2,
        totalMs: 5000, minMs: 800, maxMs: 1200, avgMs: 1000, measuredCalls: 50, measuredRows: 5000,
        samples: {'1': Sample(800), '2': Sample(900), '3': Sample(1000), '4': Sample(1100), '5': Sample(1200)},
        warmupSamples: {'1': Sample(1300), '2': Sample(1100)}, failureCategory: ''});
    const Report = () => ({schemaVersion: 1, runID: 'BROWSER-TEST-ONLY', fixture: 'm08.constant.v1', profile: 'MSSQL/pData',
        rowsPerIteration: 1000, pageSize: 100, iterations: 5, warmupIterations: 2, concurrency: 1,
        transportOrder: 'TCP,HTTP', startedLocal: 'synthetic browser verification', success: true, failureCategory: '',
        memory: {status: 'UNAVAILABLE'}, runElapsedMs: 14887, tcp: Series(), http: Series()});
    try {
        const api = HBBTest.api;
        A(!!api && !E('run').disabled, 'Live channel enables the run button.');
        A(E('profile').textContent.includes('</script><img'), 'A closing-tag alias remains literal text.');
        A(E('profile').querySelector('img') === null && !window.HBBInjected, 'Profile data cannot inject markup or a script.');
        A(document.querySelectorAll('#hbb-form input').length === 5, 'Only the five numeric parameters are editable.');
        Submit();
        const firstID = api.State.pending;
        A(api.State.busy && E('run').disabled, 'Submitting disables the button and records one outstanding run.');
        A(HBBTest.calls.length === 1 && HBBTest.calls[0].type === 'HBBRIDGE_BENCHMARK_REQUEST', 'The expected request type is sent.');
        A(Object.keys(HBBTest.calls[0].content.params).join(',') === 'rows,pageSize,iterations,warmup,timeoutSeconds', 'The request has numeric parameters only.');
        A(!/token|password|host|url|port|profile/i.test(JSON.stringify(HBBTest.calls[0].content.params)), 'No endpoint, alias or credential is submitted by the browser.');
        Submit();
        A(HBBTest.calls.length === 1, 'A second click cannot submit an outstanding run again.');
        HBBTest.timers.get(api.State.notice)();
        A(api.State.busy && E('run').disabled && E('status').textContent.includes('no cancellation'), 'The wait notice retains the run guard and makes no SQL cancellation claim.');
        HBBTest.receiver('HBBRIDGE_BENCHMARK_RESPONSE', '{broken');
        HBBTest.receiver('OTHER', '{}');
        HBBTest.receiver('HBBRIDGE_BENCHMARK_RESPONSE', {instance: 'stale', requestID: firstID, report: Report()});
        HBBTest.receiver('HBBRIDGE_BENCHMARK_RESPONSE', {instance: 'browser-test', requestID: 'stale', report: Report()});
        A(api.State.busy && api.State.pending === firstID, 'Malformed and unrelated responses do not release the pending request.');
        Reply(Report());
        A(!api.State.busy && !E('run').disabled && HBBTest.timers.size === 0, 'A matching response releases the guard and wait timer.');
        A(E('result-state').textContent === 'PASSED' && E('status').dataset.state === 'passed', 'Both successful transports display PASSED.');
        A(E('stats-body').children.length === 2 && E('warmup-body').children.length === 4, 'Measured statistics and warmup observations are separate.');
        A(E('average-chart').querySelectorAll('rect').length === 2 && E('sample-chart').querySelectorAll('path').length === 2, 'Both SVG charts render actual transport series.');
        A(E('memory').textContent.includes('unavailable') && E('memory').textContent.includes('not inferred'), 'Unavailable memory and physical pooling limits remain visible.');
        E('export-json').click();
        E('export-html').click();
        const exportedJSON = await HBBTest.blobs[0].text();
        const exportedHTML = await HBBTest.blobs[1].text();
        A(JSON.parse(exportedJSON).tcp.avgMs === 1000, 'JSON export retains the measured report.');
        A(exportedHTML.includes('<svg') && exportedHTML.includes('Benchmark report'), 'HTML export retains charts and a standalone title.');
        A(!/<script|<form|<input|FWWebEx|HBBRIDGE_BENCHMARK_REQUEST|onerror=/i.test(exportedHTML), 'HTML export contains no form, script, channel or event handler.');
        Submit();
        HBBTest.receiver('HBBRIDGE_BENCHMARK_RESPONSE', {instance: 'browser-test', requestID: firstID, report: Report()});
        A(api.State.busy && E('results').hidden, 'A new run clears old results and ignores the old response ID.');
        HBBTest.receiver('HBBRIDGE_BENCHMARK_RESPONSE', {instance: 'browser-test', requestID: api.State.pending, error: 'RUN_FAILED'});
        A(!api.State.busy && !E('run').disabled && E('status').textContent.includes('RUN_FAILED'), 'A correlated error permits a later run with a fixed category.');
        for (const mode of ['false', 'reject', 'throw']) {
            HBBTest.mode = mode;
            Submit();
            await Tick();
            A(!api.State.busy && !E('run').disabled && E('status').textContent.includes('CHANNEL_FAILED'), 'Channel ' + mode + ' is handled without exposing native detail.');
        }
        HBBTest.mode = 'ok';
        E('rows').value = '1e2';
        const beforeInvalid = HBBTest.calls.length;
        Submit();
        A(HBBTest.calls.length === beforeInvalid && E('status').dataset.state === 'failed', 'Noncanonical exponent input is rejected before sending.');
        E('rows').value = '100000';
        E('pageSize').value = '10000';
        E('iterations').value = '500';
        Submit();
        A(api.State.busy && HBBTest.calls.at(-1).content.params.rows === 100000 &&
            HBBTest.calls.at(-1).content.params.iterations === 500, 'The existing fixture range remains available without a new UI cap.');
        Reply({schemaVersion: 2, success: true});
        A(!api.State.busy && E('status').textContent.includes('RESPONSE_INVALID'), 'An unsupported response format is visible and releases the request.');
        E('rows').value = '1000';
        E('pageSize').value = '100';
        E('iterations').value = '5';
        Submit();
        const partial = Report();
        partial.success = false;
        partial.http.success = false;
        partial.http.avgMs = null;
        partial.http.samples = {'1': Sample(0), '2': null, '3': {...Sample(30020, false), serviceCode: 'IO_TIMEOUT', httpStatus: 0, failedPage: 7}, '4': Sample(1000), '5': Sample(1100)};
        Reply(partial);
        A(E('result-state').textContent.includes('FAILED') && E('status').dataset.state === 'failed', 'A failed run with partial statistics is never marked passed.');
        A(E('http-average').textContent === 'Unavailable', 'A null statistic is unavailable rather than zero.');
        const paths = E('sample-chart').querySelectorAll('path');
        A((paths[1].getAttribute('d').match(/M/g) || []).length === 2, 'Missing and failed iterations create line gaps.');
        A(E('sample-chart').querySelectorAll('circle').length === 8, 'A genuine zero sample is plotted; null and failed samples are omitted.');
        A(!E('failures-panel').hidden && E('failures-body').textContent.includes('IO_TIMEOUT') &&
            E('failures-body').textContent.includes('QUERY_FAILED'), 'Safe failure details identify the failed sample and service code.');
        Submit();
        Reply({schemaVersion: 1, success: false, failureCategory: 'INVALID_CONFIGURATION'});
        A(E('result-state').textContent.includes('FAILED') && E('failures-body').textContent.includes('INVALID_CONFIGURATION'), 'A failed report without transport objects retains its category.');
        const huge = Report();
        huge.iterations = 210001;
        huge.tcp.samples = {};
        huge.http.samples = {};
        const shared = Sample(1000);
        for (let index = 1; index <= 210001; index++) huge.tcp.samples[index] = shared;
        api.RenderReport(huge);
        A(E('sample-chart').querySelectorAll('circle').length <= 602 && E('chart-note').textContent.includes('600'), 'Over 200,000 samples are decimated without a function-argument overflow.');
        A(api.State.report.tcp.samples['210001'].elapsedMs === 1000, 'Chart decimation preserves the full report for export.');
        Submit();
        const pendingBeforeHide = api.State.pending;
        window.dispatchEvent(new Event('pagehide'));
        HBBTest.receiver('HBBRIDGE_BENCHMARK_RESPONSE', {instance: 'browser-test', requestID: pendingBeforeHide, report: Report()});
        const callsBeforeHide = HBBTest.calls.length;
        Submit();
        A(api.State.closed && HBBTest.unsubscribed === 1 && HBBTest.timers.size === 0 &&
            E('run').disabled && HBBTest.calls.length === callsBeforeHide, 'Closing the page unsubscribes, clears timers and blocks later requests.');
    } catch (error) {
        failures.push(error.message);
    }
    const result = document.createElement('pre');
    result.id = 'hbbridge-browser-verification';
    result.textContent = JSON.stringify({checks: passed.length, passed, failures});
    document.body.replaceChildren(result);
})();
</script>`;

test('Benchmark page: actual Chromium DOM, request lifecycle, charts and exports', () => {
    const defaults = Defaults('browser-test', '</script><img src=x onerror="window.HBBInjected=true">');
    const path = join(ArtifactRoot, 'live.html');
    writeFileSync(path, Document(Template.replace('@@HBBRIDGE_BENCH_CONFIG@@', JSONForHTML(defaults)), Bootstrap, Assertions));
    const output = RunBrowser(path);
    writeFileSync(join(ArtifactRoot, 'live-dom.html'), output);
    const match = output.match(/<pre id="hbbridge-browser-verification">([^<]*)<\/pre>/);
    assert.ok(match, 'Chromium must finish the complete verification script. Inspect ' + path);
    const result = JSON.parse(match[1].replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>'));
    writeFileSync(join(ArtifactRoot, 'result.json'), JSON.stringify(result, null, 4) + '\n');
    result.passed.forEach(message => console.log('PASS ' + message));
    assert.deepEqual(result.failures, [], JSON.stringify(result));
    assert.ok(result.checks >= 35, 'All lifecycle/chart/export observations must execute.');
    console.log('Browser evidence: ' + ArtifactRoot);
});

test('Benchmark page: standalone document cannot issue a request', () => {
    const path = join(ArtifactRoot, 'offline.html');
    writeFileSync(path, Document(Template.replace('@@HBBRIDGE_BENCH_CONFIG@@', JSONForHTML(Defaults()))));
    const output = RunBrowser(path);
    writeFileSync(join(ArtifactRoot, 'offline-dom.html'), output);
    assert.match(output, /id="hbb-run"[^>]*disabled/);
    assert.match(output, /This standalone page has no execution channel/);
    assert.doesNotMatch(output, /https?:\/\/[^"\s<]+\.(?:js|css)/i);
});
