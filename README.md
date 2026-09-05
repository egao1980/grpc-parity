# grpc-parity

Interop canary: **[`grpc-backend-http2`](https://github.com/egao1980/grpc-backend-http2)** vs **grpcio** (Python).

Lisp owns the harness and assertions. The grpcio peer is the SUT, not a refresh script.
**CI-only — not published to GHCR.**

```
Lisp unary          →  grpcio Echo/Ping
Lisp server-stream  →  grpcio Echo/Watch
Lisp interleaved bidi →  grpcio Echo/Chat
```

Windows is a required OS (this is the portable http2 path vs `grpc-backend-native`).

## Run

```bash
cd peers/python && uv sync
export GRPC_PARITY_PEERS=1
export HTTP_ASYNC_EVENT_BACKEND=libuv
ros -l scripts/run.lisp
```

Skip the live peer (load/smoke only):

```bash
export GRPC_PARITY_PEERS=0
ros -l scripts/run.lisp
```

## Matrix

See [MATRIX.md](MATRIX.md).

## Env

| Variable | Default | Meaning |
|----------|---------|---------|
| `GRPC_PARITY_PEERS` | on in CI | `0` skips the grpcio server |
| `GRPC_PARITY_PYTHON` | first `python` with grpcio | interpreter for `peers/python/server.py` |
| `HTTP_ASYNC_EVENT_BACKEND` | `libuv` | event backend for H2 client |

## License

MIT. Peer is [grpcio](https://grpc.io/) (Apache-2.0). Localhost TLS pair is test-only.
