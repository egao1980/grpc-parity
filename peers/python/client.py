#!/usr/bin/env python3
"""grpcio client against a TLS Echo peer (Lisp or otherwise). Prints OK/FAIL."""

from __future__ import annotations

import sys

import grpc

_PROTO = """
syntax = "proto3";
package echo;
service Echo {
  rpc Ping (Msg) returns (Msg);
  rpc Watch (Msg) returns (stream Msg);
  rpc Chat (stream Msg) returns (stream Msg);
}
message Msg { bytes body = 1; }
"""


def _load():
    import importlib.util
    import os
    import tempfile

    from grpc_tools import protoc

    work = tempfile.mkdtemp()
    proto = os.path.join(work, "echo.proto")
    with open(proto, "w", encoding="utf-8") as fh:
        fh.write(_PROTO)
    protoc.main(["", f"-I{work}", f"--python_out={work}", f"--grpc_python_out={work}", proto])
    sys.path.insert(0, work)
    spec = importlib.util.spec_from_file_location("echo_pb2", os.path.join(work, "echo_pb2.py"))
    pb2 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pb2)
    spec2 = importlib.util.spec_from_file_location(
        "echo_pb2_grpc", os.path.join(work, "echo_pb2_grpc.py")
    )
    grpc_mod = importlib.util.module_from_spec(spec2)
    spec2.loader.exec_module(grpc_mod)
    return pb2, grpc_mod


def main() -> int:
    port = int(sys.argv[1])
    cert = sys.argv[2]
    pb2, grpc_mod = _load()
    with open(cert, "rb") as cf:
        creds = grpc.ssl_channel_credentials(cf.read())
    target = f"127.0.0.1:{port}"
    options = (("grpc.ssl_target_name_override", "localhost"),)
    failed = 0
    with grpc.secure_channel(target, creds, options=options) as channel:
        stub = grpc_mod.EchoStub(channel)
        ping = stub.Ping(pb2.Msg(body=bytes([9, 8, 7])), timeout=5)
        if ping.body != bytes([9, 8, 7]):
            print("FAIL Ping", ping.body, flush=True)
            failed += 1
        else:
            print("OK Ping", flush=True)
        watch = list(stub.Watch(pb2.Msg(body=bytes([9])), timeout=10))
        got = [m.body for m in watch]
        if got != [bytes([9, 0]), bytes([9, 1]), bytes([9, 2])]:
            print("FAIL Watch", got, flush=True)
            failed += 1
        else:
            print("OK Watch", flush=True)

        def chat_reqs():
            yield pb2.Msg(body=bytes([65]))
            yield pb2.Msg(body=bytes([66]))

        chat = list(stub.Chat(chat_reqs(), timeout=10))
        gotc = [m.body for m in chat]
        if gotc != [bytes([65]), bytes([66])]:
            print("FAIL Chat", gotc, flush=True)
            failed += 1
        else:
            print("OK Chat", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
