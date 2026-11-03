#!/usr/bin/env python3
"""Check a read-only MSSQL LEFT JOIN fixture through the hbBridge TCP service."""

import argparse
import gzip
import json
import socket


SQL = (
    "SELECT E.[ID] AS [EMPLOYEE_RECORD],R.[ID] AS [RELATED_RECORD] "
    "FROM (SELECT CAST(1 AS BIGINT) AS [ID] UNION ALL SELECT CAST(2 AS BIGINT)) E "
    "LEFT JOIN (SELECT CAST(1 AS BIGINT) AS [OWNER],CAST(10 AS BIGINT) AS [ID] "
    "UNION ALL SELECT CAST(1 AS BIGINT),CAST(11 AS BIGINT)) R "
    "ON E.[ID]=R.[OWNER]"
)


def query(host, port, profile, page):
    request = {
        "service": "RPCRDD.QueryTyped",
        "params": {
            "requestVersion": 1,
            "alias": profile,
            "sql": SQL,
            "bindings": {},
            "page": {
                "number": page,
                "size": 2,
                "orderBy": "EMPLOYEE_RECORD ASC,RELATED_RECORD ASC",
            },
        },
    }
    payload = json.dumps(request, separators=(",", ":")).encode("utf-8")
    frame = b"HBBRIDGE/1|JSON|" + str(len(payload)).encode("ascii") + b"\n" + payload
    chunks = []
    with socket.create_connection((host, port), timeout=30) as connection:
        connection.settimeout(30)
        connection.sendall(gzip.compress(frame))
        while True:
            chunk = connection.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
    response = b"".join(chunks)
    if response.startswith(b"\x1f\x8b"):
        response = gzip.decompress(response)
    if response.startswith(b"HBBRIDGE/1|"):
        header, response = response.split(b"\n", 1)
        signature, encoding, length = header.split(b"|")
        if signature != b"HBBRIDGE/1" or encoding != b"JSON" or int(length) != len(response):
            raise ValueError("Invalid response frame")
    return json.loads(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", required=True, help="Configured MSSQL profile key")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=1512)
    args = parser.parse_args()
    expected = (
        [("1", "10"), ("1", "11")],
        [("2", None)],
    )
    for index, rows in enumerate(expected, start=1):
        response = query(args.host, args.port, args.profile, index)
        if response.get("success") is not True:
            raise RuntimeError("Query failed: " + str(response.get("code", "unknown")))
        page = response.get("page", {})
        header = response.get("header", {})
        actual_rows = response.get("rows", {})
        actual = [
            (actual_rows[str(row)]["EMPLOYEE_RECORD"], actual_rows[str(row)]["RELATED_RECORD"])
            for row in range(1, len(rows) + 1)
        ]
        if (
            actual != rows
            or response.get("rowCount") != len(rows)
            or response.get("totalRows") != 3
            or response.get("totalPages") != 2
            or page.get("number") != index
            or page.get("hasNext") != (index == 1)
            or header.get("EMPLOYEE_RECORD", {}).get("wire", {}).get("kind") != "int64"
            or header.get("RELATED_RECORD", {}).get("wire", {}).get("kind") != "int64"
        ):
            raise AssertionError("Synthetic LEFT JOIN page verification failed")
        print(f"Synthetic LEFT JOIN page {index}: PASS")
    print("Synthetic MSSQL LEFT JOIN, exact int64 and unmatched NULL: OK")


if __name__ == "__main__":
    main()
