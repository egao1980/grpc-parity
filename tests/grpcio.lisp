(in-package #:grpc-parity/tests)

(deftest grpcio-unary-server-stream-bidi
  "Lisp unary / server-stream / interleaved bidi vs grpcio. GRPC_PARITY_PEERS=1."
  (cond
    ((not (peers-enabled-p))
     (skip "GRPC_PARITY_PEERS unset/off"))
    ((not (python-available-p))
     (skip "python + grpcio + grpcio-tools or TLS pair missing"))
    ((not (and (find-package :http-backend-async)
               (find-package :event-backend-libuv)))
     (skip "http-backend-async/event-backend-libuv not loaded"))
    ((not (grpc-parity::http2-ready-p))
     (skip "http2/client not loadable"))
    (t
     (with-grpcio-server (ch)
       (testing "unary Ping"
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
             (ok nil (format nil "unary Ping: ~A" e)))))
       (testing "server-stream Watch"
         (handler-case
             (let ((msgs (call-timeout
                          20
                          (lambda ()
                            (let ((s (grpc-protocol:grpc-stream
                                      ch "/echo.Echo/Watch")))
                              (unwind-protect
                                   (progn
                                     (grpc-protocol:grpc-send
                                      s (pb-encode-bytes #(9)) :end t)
                                     (list (grpc-protocol:grpc-recv s)
                                           (grpc-protocol:grpc-recv s)
                                           (grpc-protocol:grpc-recv s)
                                           (grpc-protocol:grpc-recv s)))
                                (grpc-protocol:grpc-close s)))))))
               (ok (equalp #(9 0) (pb-decode-bytes (first msgs))))
               (ok (equalp #(9 1) (pb-decode-bytes (second msgs))))
               (ok (equalp #(9 2) (pb-decode-bytes (third msgs))))
               (ok (eq :eof (fourth msgs))))
           (error (e)
             (ok nil (format nil "Watch: ~A" e)))))
       (testing "interleaved bidi Chat"
         (handler-case
             (let ((msgs (call-timeout
                          20
                          (lambda ()
                            (let ((s (grpc-protocol:grpc-stream
                                      ch "/echo.Echo/Chat")))
                              (unwind-protect
                                   (progn
                                     (grpc-protocol:grpc-send
                                      s (pb-encode-bytes #(65)))
                                     (let ((a (grpc-protocol:grpc-recv s)))
                                       (grpc-protocol:grpc-send
                                        s (pb-encode-bytes #(66)))
                                       (let ((b (grpc-protocol:grpc-recv s)))
                                         (grpc-protocol:grpc-send s nil :end t)
                                         (list a b (grpc-protocol:grpc-recv s)))))
                                (grpc-protocol:grpc-close s)))))))
               (ok (equalp #(65) (pb-decode-bytes (first msgs))))
               (ok (equalp #(66) (pb-decode-bytes (second msgs))))
               (ok (eq :eof (third msgs))))
           (error (e)
             (ok nil (format nil "Chat: ~A" e)))))))))
