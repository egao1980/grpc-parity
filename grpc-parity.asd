(defsystem "grpc-parity"
  :version "0.1.0"
  :description "Interop canary: grpc-backend-http2 vs grpcio (unary + server-stream + bidi)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("grpc-protocol"
               "grpc-backend-http2"
               "http-protocol"
               "http-backend-async"
               "event-backend-libuv"
               "cl-stack-ssl"
               "bordeaux-threads"
               "uiop"
               "usocket"
               "rove")
  :properties (:cl-repo (:ci (:with ("dissect" "http2" "http2/client"))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "pb")
               (:file "peers")
               (:file "harness")
               (:file "report"))
  :in-order-to ((test-op (test-op "grpc-parity/tests"))))

(defsystem "grpc-parity/tests"
  :depends-on ("grpc-parity" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "grpcio"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "grpc-parity tests failed"))))
