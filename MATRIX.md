# grpc-parity matrix

Status: `have` · `missing` · `skip`

| RPC | Lisp → grpcio | Notes |
|-----|---------------|-------|
| unary `Echo/Ping` | have | length-prefixed proto `Msg.body` |
| server-stream `Echo/Watch` | have | 3 replies then EOF |
| interleaved bidi `Echo/Chat` | have | send/recv/send/recv/half-close |
| client-stream | skip | same send loop as bidi; no dedicated peer RPC |
| compressed frames (gzip/deflate) | skip | covered in `grpc-backend-http2` unit tests |
| grpc-go peer | missing | grpcio is the wave-1 canary |
| Lisp gRPC server | missing | no first-party gRPC accept loop yet |

Do not claim Windows-portable gRPC unless the `grpcio` job is green on `windows-latest`.
