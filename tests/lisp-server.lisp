(in-package #:grpc-parity/tests)

(deftest grpcio-client-lisp-server
  "grpcio client → Lisp gRPC accept loop (unary + Watch + Chat)."
  (cond
    ((not (peers-enabled-p))
     (skip "GRPC_PARITY_PEERS unset/off"))
    ((not (python-client-available-p))
     (skip "python client + grpcio + TLS pair missing"))
    ((not (lisp-server-available-p))
     (skip "http2/server VANILLA-SERVER-CONNECTION missing (openssl grovel / Windows)"))
    (t
     (with-lisp-echo-server (port)
       (handler-case
           (multiple-value-bind (ok out)
               (grpc-parity::run-grpcio-client port)
             (ok ok (format nil "grpcio → Lisp: ~A" out)))
         (error (e)
           (ok nil (format nil "grpcio → Lisp: ~A" e))))))))

(deftest lisp-client-lisp-server
  "Lisp client → Lisp accept loop (same Echo RPCs)."
  (cond
    ((not (peers-enabled-p))
     (skip "GRPC_PARITY_PEERS unset/off"))
    ((not (lisp-server-available-p))
     (skip "http2/server VANILLA-SERVER-CONNECTION missing (openssl grovel / Windows)"))
    ((not (and (find-package :http-backend-async)
               (find-package :event-backend-libuv)))
     (skip "http-backend-async/event-backend-libuv not loaded"))
    ((not (grpc-parity::http2-ready-p))
     (skip "http2/client not loadable"))
    (t
     (with-lisp-echo-server (port)
       (multiple-value-bind (http) (bind-async-http)
         (let ((ch (open-parity-channel port http)))
           (unwind-protect
                (handler-case
                    (let ((got (exercise-echo ch)))
                      (ok (equalp #(9 8 7) (getf got :ping)))
                      (ok (equalp '(#(9 0) #(9 1) #(9 2) :eof) (getf got :watch)))
                      (ok (equalp '(#(65) #(66) :eof) (getf got :chat))))
                  (error (e)
                    (ok nil (format nil "Lisp → Lisp: ~A" e))))
             (ignore-errors (grpc-protocol:grpc-close ch)))))))))
