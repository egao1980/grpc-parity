(in-package #:grpc-parity)

(defun print-matrix ()
  (format t "~&grpc-parity matrix~%")
  (format t "  peers: grpcio=~a go=~a lisp-server=~a~%"
          (if (python-available-p) "yes" "no")
          (if (go-available-p) "yes" "no")
          (if (lisp-server-available-p) "yes" "no"))
  (format t "  Lisp → grpcio: unary Ping / server-stream Watch / interleaved bidi Chat~%")
  (format t "  Lisp → go:     unary Ping / server-stream Watch / interleaved bidi Chat~%")
  (format t "  grpcio → Lisp: unary Ping / server-stream Watch / bidi Chat~%")
  (format t "  gaps: compressed-frame canary; Windows Lisp accept if http2/server grovel fails~%")
  (values))
