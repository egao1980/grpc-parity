(in-package #:grpc-parity)

(defun print-matrix ()
  (format t "~&grpc-parity matrix~%")
  (format t "  peers: grpcio=~a~%"
          (if (python-available-p) "yes" "no"))
  (format t "  Lisp → grpcio: unary Ping / server-stream Watch / interleaved bidi Chat~%")
  (format t "  gaps: grpc-go peer, Lisp gRPC server, compressed-frame canary~%")
  (values))
