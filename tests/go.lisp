(in-package #:grpc-parity/tests)

(defun %go-client-ready-p ()
  (cond
    ((not (peers-enabled-p))
     (skip "GRPC_PARITY_PEERS unset/off")
     nil)
    ((not (go-available-p))
     (skip "go toolchain or peers/go/server.go or TLS pair missing")
     nil)
    ((not (and (find-package :http-backend-async)
               (find-package :event-backend-libuv)))
     (skip "http-backend-async/event-backend-libuv not loaded")
     nil)
    ((not (grpc-parity::http2-ready-p))
     (skip "http2/client not loadable")
     nil)
    (t t)))

(deftest go-unary-ping
  "Lisp unary Ping vs grpc-go."
  (when (%go-client-ready-p)
    (with-go-server (ch)
      (handler-case
          (let ((out (call-timeout
                      15
                      (lambda ()
                        (grpc-protocol:grpc-call
                         ch "/echo.Echo/Ping"
                         (pb-encode-bytes #(9 8 7))
                         :timeout 5)))))
            (ok (equalp #(9 8 7) (pb-decode-bytes out))))
        (error (e)
          (ok nil (format nil "Lisp → go Ping: ~A" e)))))))

(deftest go-watch-and-chat
  "Lisp Watch + interleaved Chat vs grpc-go."
  (when (%go-client-ready-p)
    (with-go-server (ch)
      (handler-case
          (let ((got (exercise-echo ch)))
            (ok (equalp #(9 8 7) (getf got :ping)))
            (ok (equalp '(#(9 0) #(9 1) #(9 2) :eof) (getf got :watch)))
            (ok (equalp '(#(65) #(66) :eof) (getf got :chat))))
        (error (e)
          (ok nil (format nil "Lisp → go streams: ~A" e)))))))
