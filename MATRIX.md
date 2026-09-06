# grpc-parity matrix

Status: `have` · `missing` · `skip`

| RPC | Lisp → grpcio | Lisp → go | grpcio → Lisp | Notes |
|-----|---------------|-----------|---------------|-------|
| unary `Echo/Ping` | have | have | have | length-prefixed proto `Msg.body` |
| server-stream `Echo/Watch` | have | have | have | 3 replies then EOF |
| interleaved bidi `Echo/Chat` | have | have | have | send/recv/send/recv/half-close |
| client-stream | skip | skip | skip | same send loop as bidi; no dedicated peer RPC |
| compressed frames (gzip/deflate) | skip | skip | skip | covered in `grpc-backend-http2` unit tests |
| grpc-go peer | have | have | — | `peers/go/server.go` (TLS) |
| Lisp gRPC server | — | — | have | `grpc-backend-http2` TLS accept loop |

Portable path is **grpc-backend-http2** over **http-server-backend-http2** (TLS). No h2c / `:insecure`. Do not claim Windows-portable native C-core.

Lisp accept on Windows is `skip` when `http2/server/threaded` fails to load (grovel). Lisp → go / Lisp → grpcio still run on windows-latest via the H2 client.
