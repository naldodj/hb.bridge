"""Recompute exported M08 benchmark statistics without executing companion HTML."""

import argparse
import hashlib
import json
import math
import pathlib
import statistics


ROUTES = (
    "tcp", "http", "protheusStartJob", "protheusRest",
    "hbbridgeAddon", "protheusServer",
)
RELATIVE_TOLERANCE = 1e-9
ABSOLUTE_TOLERANCE = 1e-5


def IsNumber(xValue):
    return (isinstance(xValue, (int, float)) and not isinstance(xValue, bool)
            and math.isfinite(xValue))


def Check(lCondition, cMessage, jValidation):
    jValidation["checks"] += 1
    if not lCondition:
        jValidation["failures"].append(cMessage)


def CheckNumber(xActual, nExpected, cMessage, jValidation):
    Check(IsNumber(xActual) and math.isclose(
        xActual, nExpected, rel_tol=RELATIVE_TOLERANCE,
        abs_tol=ABSOLUTE_TOLERANCE), cMessage, jValidation)


def AnalyzeSeries(cRoute, jSeries, jReport, jValidation):
    jSamples = jSeries.get("samples", {})
    jWarmups = jSeries.get("warmupSamples", {})
    Check(isinstance(jSamples, dict), cRoute + ": measured samples object", jValidation)
    Check(isinstance(jWarmups, dict), cRoute + ": warmup samples object", jValidation)
    if not isinstance(jSamples, dict) or not isinstance(jWarmups, dict):
        return {"success": False}

    aSamples = list(jSamples.values())
    aWarmups = list(jWarmups.values())
    aDurations = []
    nIterations = jReport["iterations"]
    nRows = jReport["rowsPerIteration"]
    nPages = math.ceil(nRows / jReport["pageSize"])
    nMeasuredRows = 0
    nMeasuredCalls = 0
    Check(jSeries.get("success") is True, cRoute + ": series success", jValidation)
    Check(len(aSamples) == nIterations, cRoute + ": measured sample count", jValidation)
    Check(len(aWarmups) == jReport["warmupIterations"],
          cRoute + ": warmup sample count", jValidation)

    for lMeasured, aItems in ((True, aSamples), (False, aWarmups)):
        for jSample in aItems:
            Check(isinstance(jSample, dict), cRoute + ": sample object", jValidation)
            if not isinstance(jSample, dict):
                continue
            Check(jSample.get("success") is True, cRoute + ": sample success", jValidation)
            for cField, nExpected in (("rowsRead", nRows), ("pagesRead", nPages),
                                      ("rpcCalls", nPages)):
                Check(jSample.get(cField) == nExpected,
                      cRoute + ": sample " + cField, jValidation)
            nDuration = jSample.get("elapsedMs")
            Check(IsNumber(nDuration) and nDuration >= 0,
                  cRoute + ": finite nonnegative duration", jValidation)
            if lMeasured and jSample.get("success") is True and IsNumber(nDuration):
                aDurations.append(nDuration)
                if IsNumber(jSample.get("rowsRead")):
                    nMeasuredRows += jSample["rowsRead"]
                if IsNumber(jSample.get("rpcCalls")):
                    nMeasuredCalls += jSample["rpcCalls"]

    nCount = len(aDurations)
    Check(nCount > 0, cRoute + ": successful measured samples", jValidation)
    Check(jSeries.get("completedIterations") == nCount,
          cRoute + ": completed iterations", jValidation)
    Check(jSeries.get("sampleCount") == nCount, cRoute + ": sampleCount", jValidation)
    Check(jSeries.get("warmupCompleted") == len(aWarmups),
          cRoute + ": completed warmups", jValidation)
    Check(jSeries.get("measuredRows") == nMeasuredRows,
          cRoute + ": measuredRows", jValidation)
    Check(jSeries.get("measuredCalls") == nMeasuredCalls,
          cRoute + ": measuredCalls", jValidation)
    if nCount == 0:
        return {"success": False}

    aSorted = sorted(aDurations)
    nTotal = math.fsum(aDurations)
    nAverage = statistics.mean(aDurations)
    nDeviation = statistics.pstdev(aDurations)
    jComputed = {
        "totalMs": nTotal,
        "minMs": min(aDurations),
        "maxMs": max(aDurations),
        "avgMs": nAverage,
        "medianMs": statistics.median(aDurations),
        "p95Ms": aSorted[math.ceil(0.95 * nCount) - 1],
        "stdDevMs": nDeviation,
        "cvPct": 100 * nDeviation / nAverage if nAverage else None,
        "throughputRowsSec": nMeasuredRows * 1000 / nTotal if nTotal else None,
        "throughputCallsSec": nMeasuredCalls * 1000 / nTotal if nTotal else None,
    }
    for cField, nExpected in jComputed.items():
        if nExpected is None:
            Check(jSeries.get(cField) is None, cRoute + ": " + cField, jValidation)
        else:
            CheckNumber(jSeries.get(cField), nExpected,
                        cRoute + ": " + cField, jValidation)

    jSummary = {
        "success": jSeries.get("success"),
        "measuredSamples": nCount,
        "warmupSamples": len(aWarmups),
        "measuredRows": nMeasuredRows,
        "measuredCalls": nMeasuredCalls,
        "recomputed": jComputed,
    }
    for cField in ("statisticsScope", "timingScope", "clock", "callElapsedMs",
                   "serverRunElapsedMs", "transport", "networkCalls", "workerCalls",
                   "returnedDatasetRows", "callTimingScope"):
        if cField in jSeries:
            jSummary[cField] = jSeries[cField]
    return jSummary


def AnalyzeReport(oPath):
    cContent = oPath.read_bytes()
    jReport = json.loads(cContent.decode("utf-8-sig"))
    jValidation = {"checks": 0, "failures": []}
    jSummary = {
        "file": oPath.name,
        "fileSHA256": hashlib.sha256(cContent).hexdigest().upper(),
        "settings": {},
        "routes": {},
        "validation": jValidation,
    }
    for cField in ("schemaVersion", "routeSelectionVersion", "runID", "startedLocal",
                   "fixture", "profile", "protheusEnvironment",
                   "rowsPerIteration", "pageSize", "iterations", "warmupIterations",
                   "concurrency", "selectedRoutes", "routeStates", "transportOrder",
                   "timeoutSeconds", "clock", "serverUnix", "timingScope",
                   "clientConstructionTimed", "warmupExcludedFromMeasuredStatistics",
                   "clientPolicy", "httpAcceptEncoding", "httpRequireGzip",
                   "comparisonScope", "comparisonBackend", "physicalPooling",
                   "memory", "runElapsedMs"):
        if cField in jReport:
            jSummary["settings"][cField] = jReport[cField]
    Check(jReport.get("success") is True, "report success", jValidation)
    for cField in ("rowsPerIteration", "pageSize", "iterations", "warmupIterations"):
        xValue = jReport.get(cField)
        Check(isinstance(xValue, int) and not isinstance(xValue, bool)
              and xValue >= (0 if cField == "warmupIterations" else 1),
              "positive integer setting " + cField, jValidation)
    if jValidation["failures"]:
        jSummary["success"] = False
        return jSummary

    jSelected = jReport.get("selectedRoutes", {})
    jStates = jReport.get("routeStates", {})
    Check(isinstance(jSelected, dict), "selectedRoutes object", jValidation)
    Check(isinstance(jStates, dict), "routeStates object", jValidation)
    if not isinstance(jSelected, dict) or not isinstance(jStates, dict):
        jSummary["success"] = False
        return jSummary
    for cRoute in ROUTES:
        lSelected = jSelected.get(cRoute) is True
        Check(jStates.get(cRoute) == ("completed" if lSelected else "skipped"),
              cRoute + ": selection state", jValidation)
        if lSelected:
            jSeries = jReport.get(cRoute)
            Check(isinstance(jSeries, dict), cRoute + ": series object", jValidation)
            if isinstance(jSeries, dict):
                jSummary["routes"][cRoute] = AnalyzeSeries(
                    cRoute, jSeries, jReport, jValidation)
    if jSelected.get("http") is True and jReport.get("httpRequireGzip") is True:
        Check(jReport.get("httpAcceptEncoding") == "gzip, identity;q=0",
              "mandatory gzip negotiation", jValidation)
    jSummary["success"] = not jValidation["failures"]
    return jSummary


def Main():
    oParser = argparse.ArgumentParser(description=__doc__)
    oParser.add_argument("--directory", type=pathlib.Path, required=True,
                         help="Directory containing hbbridge-benchmark-*.json exports")
    oParser.add_argument("--output", type=pathlib.Path,
                         help="Optional sanitized summary JSON; raw reports are unchanged")
    oOptions = oParser.parse_args()
    aPaths = sorted(oOptions.directory.glob("hbbridge-benchmark-*.json"))
    if not aPaths:
        oParser.error("No hbbridge-benchmark-*.json reports found in --directory")
    aRuns = []
    for oPath in aPaths:
        try:
            aRuns.append(AnalyzeReport(oPath))
        except (OSError, UnicodeError, ValueError, TypeError, KeyError) as oError:
            aRuns.append({"file": oPath.name, "success": False, "validation": {
                "checks": 0, "failures": ["Unable to analyze report: "
                                          + type(oError).__name__]}})
    jResult = {
        "schemaVersion": 1,
        "kind": "hbbridge.benchmark.export.validation",
        "success": all(jRun["success"] for jRun in aRuns),
        "method": "Recompute measured samples; median, P95 nearest rank, population SD; "
                  "check row/page/call totals. Companion HTML is never read or executed.",
        "tolerance": {"relative": RELATIVE_TOLERANCE, "absolute": ABSOLUTE_TOLERANCE},
        "reports": len(aRuns),
        "selectedSeries": sum(len(jRun.get("routes", {})) for jRun in aRuns),
        "measuredSamples": sum(jSeries.get("measuredSamples", 0) for jRun in aRuns
                               for jSeries in jRun.get("routes", {}).values()),
        "warmupSamples": sum(jSeries.get("warmupSamples", 0) for jRun in aRuns
                             for jSeries in jRun.get("routes", {}).values()),
        "checks": sum(jRun["validation"]["checks"] for jRun in aRuns),
        "failures": sum(len(jRun["validation"]["failures"]) for jRun in aRuns),
        "runs": aRuns,
        "limitations": [
            "A report is self-reported evidence, without deployed executable/RPO hashes.",
            "Compression policy fields do not independently capture response headers.",
            "Pooling, system load and route order may affect comparisons between runs.",
            "Server-local traversal samples and complete client traversals have distinct scopes.",
        ],
    }
    if oOptions.output:
        oResolved = oOptions.output.resolve()
        if oResolved in {oPath.resolve() for oPath in aPaths}:
            oParser.error("--output must not overwrite an input report")
        oResolved.parent.mkdir(parents=True, exist_ok=True)
        oResolved.write_text(json.dumps(jResult, indent=2, ensure_ascii=True) + "\n",
                             encoding="utf-8")
    print(json.dumps({cKey: jResult[cKey] for cKey in (
        "success", "reports", "selectedSeries", "measuredSamples", "warmupSamples",
        "checks", "failures")}))
    return 0 if jResult["success"] else 1


if __name__ == "__main__":
    raise SystemExit(Main())
