(defsystem "grpc-parity"
  :version "0.2.0"
  :description "Interop canary: grpc-backend-http2 vs grpcio and grpc-go (client + Lisp serve)"
  :author "egao1980"
  :license "MIT"
  :depends-on ((:version "grpc-protocol" "0.2.0")
               (:version "grpc-backend-http2" "0.4.0")
               "http-protocol"
               "http-backend-async"
               "event-backend-libuv"
               "http-server-protocol"
               "http-server-backend-http2"
               "cl-stack-ssl"
               "bordeaux-threads"
               "uiop"
               "usocket"
               "rove")
  :properties (:cl-repo (:ci (:with ("dissect" "http2" "http2/client" "http2/server"))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "pb")
               (:file "peers")
               (:file "echo")
               (:file "harness")
               (:file "report"))
  :in-order-to ((test-op (test-op "grpc-parity/tests"))))

(defsystem "grpc-parity/tests"
  :depends-on ("grpc-parity" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "grpcio")
               (:file "go")
               (:file "lisp-server"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "grpc-parity tests failed"))))
