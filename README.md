# grpc-parity

Interop canary: **[`grpc-backend-http2`](https://github.com/egao1980/grpc-backend-http2)** vs **grpcio** (Python) and **grpc-go**, plus a Lisp TLS accept loop.

Lisp owns the harness and assertions. Peers are the SUT, not a refresh script.
**CI-only — not published to GHCR.**

```
Lisp unary / Watch / Chat  →  grpcio Echo
Lisp unary / Watch / Chat  →  grpc-go Echo
grpcio client              →  Lisp grpc-serve Echo
```

Windows is a required OS for the **client** path (portable http2 vs `grpc-backend-native`). The Lisp accept loop needs `http2/server/threaded` (may skip on Windows grovel).

## Run

```bash
cd peers/python && uv sync
export GRPC_PARITY_PEERS=1
export HTTP_ASYNC_EVENT_BACKEND=libuv
ros -l scripts/run.lisp
```

Skip live peers (load/smoke only):

```bash
export GRPC_PARITY_PEERS=0
ros -l scripts/run.lisp
```

Go peer needs a `go` toolchain (`peers/go`).

## Matrix

See [MATRIX.md](MATRIX.md).

## Env

| Variable | Default | Meaning |
|----------|---------|---------|
| `GRPC_PARITY_PEERS` | on in CI | `0` skips live peers |
| `GRPC_PARITY_PYTHON` | first `python` with grpcio | interpreter for `peers/python/` |
| `GRPC_PARITY_GO` | `go` on PATH | grpc-go peer |
| `HTTP_ASYNC_EVENT_BACKEND` | `libuv` | event backend for H2 client |

## License

MIT. Peers are [grpcio](https://grpc.io/) / [grpc-go](https://github.com/grpc/grpc-go) (Apache-2.0). Localhost TLS pair is test-only.
