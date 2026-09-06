(in-package #:grpc-parity)

(defun echo-handlers ()
  "Echo service matching peers/python/server.py and peers/go."
  (list
   (grpc-protocol:make-grpc-method-handler
    "/echo.Echo/Ping"
    (lambda (request stream)
      (declare (ignore stream))
      request)
    :kind :unary)
   (grpc-protocol:make-grpc-method-handler
    "/echo.Echo/Watch"
    (lambda (request stream)
      (let ((body (pb-decode-bytes request)))
        (dotimes (i 3)
          (grpc-protocol:grpc-send
           stream
           (pb-encode-bytes
            (concatenate '(vector (unsigned-byte 8))
                         body
                         (vector i)))))))
    :kind :server-stream)
   (grpc-protocol:make-grpc-method-handler
    "/echo.Echo/Chat"
    (lambda (stream)
      (loop for msg = (grpc-protocol:grpc-recv stream)
            until (eq msg :eof)
            do (grpc-protocol:grpc-send stream msg)))
    :kind :bidi)))

(defun tls-cert ()
  (merge-pathnames "tls/cert.pem" *peer-root*))

(defun tls-key ()
  (merge-pathnames "tls/key.pem" *peer-root*))

(defun %http2-vanilla-connection-class ()
  (loop for pkg-name in '(:http2/server :http2/server/shared)
        for pkg = (find-package pkg-name)
        for sym = (and pkg (find-symbol "VANILLA-SERVER-CONNECTION" pkg))
        when (and sym (find-class sym nil))
          return sym))

(defun lisp-server-available-p ()
  "True when TLS fixtures exist and http2/server actually defined its connection class.
   Loading the system is not enough — a failed openssl grovel can leave the package empty."
  (and (peers-enabled-p)
       (probe-file (tls-cert))
       (probe-file (tls-key))
       (find-package :http-server-backend-http2)
       (let ((fn (find-symbol "HTTP2-SERVER-AVAILABLE-P" :http-server-backend-http2)))
         (and fn (fboundp fn) (ignore-errors (funcall fn))))
       (%http2-vanilla-connection-class)))

(defun start-lisp-echo-server (&key (host "127.0.0.1") (port (%free-port)))
  (let ((server (grpc-protocol:grpc-serve
                 (echo-handlers)
                 :host host
                 :port port
                 :credentials (list :ssl :cert (tls-cert) :key (tls-key)))))
    (values server (or (grpc-protocol:grpc-server-port server) port))))

(defun stop-lisp-echo-server (server)
  (when server
    (ignore-errors (grpc-protocol:grpc-stop server))))
