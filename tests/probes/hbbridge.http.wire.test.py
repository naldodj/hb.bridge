"""Read-only MSSQL M08 wire comparison; no installed configuration is changed."""
import argparse
import gzip
import hashlib
import http.client
import json
import pathlib

arguments = argparse.ArgumentParser(description=__doc__)
arguments.add_argument("--endpoints", required=True, type=pathlib.Path)
arguments.add_argument("--output", required=True, type=pathlib.Path)
options = arguments.parse_args()
endpoint = json.loads(options.endpoints.read_text(encoding="utf-8"))
digits = "(VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9))"
sql = ("SELECT ID, CAST('hbbridge-' + CAST(ID AS VARCHAR(10)) AS VARCHAR(32)) AS NAME, "
       "CAST(ID * 0.25 AS DECIMAL(15,2)) AS AMOUNT FROM (SELECT 1 + A.N + 10 * B.N + "
       "100 * C.N + 1000 * D.N + 10000 * E.N AS ID FROM " + digits + " A(N) CROSS JOIN " +
       digits + " B(N) CROSS JOIN " + digits + " C(N) CROSS JOIN " + digits +
       " D(N) CROSS JOIN " + digits + " E(N)) F WHERE ID <= 10000")
request = json.dumps({"service": "RPCRDD.Query", "params": {
    "alias": endpoint["profile"], "sql": sql,
    "page": {"number": 1, "size": 10000, "orderBy": "ID ASC"}}}, separators=(",", ":"))
observations = []
decoded = []
request_bytes = request.encode("utf-8")
for encoding in ("identity", "gzip"):
    connection = http.client.HTTPConnection(endpoint["host"], endpoint["httpPort"], timeout=30)
    try:
        connection.request("POST", "/api/v1/rpc", body=request_bytes, headers={
            "Content-Type": "application/json", "Accept-Encoding": encoding,
            "Connection": "close", "Authorization": "Bearer " + endpoint["token"]})
        response = connection.getresponse()
        wire = response.read()
        assert response.status == 200
        assert int(response.getheader("Content-Length")) == len(wire)
        assert response.getheader("Content-Encoding", "identity") == encoding
        plain = gzip.decompress(wire) if response.getheader("Content-Encoding") == "gzip" else wire
        result = json.loads(plain)
        assert result["success"] and result["rowCount"] == 10000
        assert result["rows"]["1"]["ID"] == 1 and result["rows"]["10000"]["ID"] == 10000
        decoded.append(plain)
        observations.append({"requestedEncoding": encoding, "contentEncoding": response.getheader("Content-Encoding"),
                             "wireBytes": len(wire), "decodedBytes": len(plain),
                             "decodedSHA256": hashlib.sha256(plain).hexdigest().upper(), "success": True})
    finally:
        connection.close()
assert decoded[0] == decoded[1]
options.output.parent.mkdir(parents=True, exist_ok=True)
options.output.write_text(json.dumps(observations, indent=2), encoding="utf-8")
print(json.dumps(observations))
