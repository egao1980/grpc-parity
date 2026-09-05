(asdf:load-system "grpc-parity")
(grpc-parity:print-matrix)
(asdf:test-system "grpc-parity")
(uiop:quit 0)
