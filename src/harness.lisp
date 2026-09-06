(in-package #:grpc-parity)

(defun bind-async-http ()
  "Wire http-backend-async + libuv + H2. → (values http-backend event-backend)."
  (unless (and (find-package :http-backend-async)
               (find-package :event-backend-libuv))
    (return-from bind-async-http nil))
  (let* ((maker (find-symbol "MAKE-LIBUV-BACKEND" :event-backend-libuv))
         (ensure (find-symbol "ENSURE-TLS" :http-backend-async))
         (eb (funcall maker)))
    (when (and ensure (fboundp ensure))
      (funcall ensure))
    (let ((ensure-h2 (find-symbol "ENSURE-HTTP2" :http-backend-async)))
      (when (and ensure-h2 (fboundp ensure-h2))
        (funcall ensure-h2)))
    (setf (symbol-value (find-symbol "*EVENT-BACKEND-MAKER*" :http-backend-async))
          (lambda () eb))
    (values (funcall (find-symbol "MAKE-ASYNC-BACKEND" :http-backend-async))
            eb)))

(defun http2-ready-p ()
  (let ((eh (find-symbol "ENSURE-HTTP2" :http-backend-async)))
    (and eh (fboundp eh) (funcall eh))))

(defun call-timeout (seconds thunk)
  (let ((done nil)
        (val nil)
        (err nil))
    (let ((th (make-thread
               (lambda ()
                 (handler-case (setf val (funcall thunk) done t)
                   (error (e) (setf err e done t))))
               :name "grpc-parity-timeout")))
      (loop repeat (max 1 (round (* seconds 20)))
            until done
            do (sleep 0.05))
      (unless done
        (ignore-errors (destroy-thread th))
        (error "grpcio parity timed out after ~A s" seconds))
      (when err (error err))
      val)))

(defun open-parity-channel (port http)
  (let ((client (http-protocol:make-http-client
                 http :http-version :http/2 :verify nil)))
    (grpc-protocol:grpc-connect
     (format nil "localhost:~D" port)
     :credentials :ssl
     :metadata (list :http-backend http
                     :http-client client))))

(defmacro with-peer-server ((channel-var starter stopper) &body body)
  (let ((proc (gensym "PROC"))
        (port (gensym "PORT"))
        (http (gensym "HTTP"))
        (ch (gensym "CH")))
    `(multiple-value-bind (,http) (bind-async-http)
       (unless ,http
         (error "http-backend-async / event-backend-libuv not loaded"))
       (multiple-value-bind (,proc ,port)
           (funcall ,starter)
         (let ((,ch (open-parity-channel ,port ,http)))
           (unwind-protect
                (let ((,channel-var ,ch))
                  ,@body)
             (ignore-errors (grpc-protocol:grpc-close ,ch))
             (funcall ,stopper ,proc)))))))

(defmacro with-grpcio-server ((channel-var) &body body)
  `(with-peer-server (,channel-var #'start-grpcio-server #'stop-grpcio-server)
     ,@body))

(defmacro with-go-server ((channel-var) &body body)
  `(with-peer-server (,channel-var #'start-go-server #'stop-go-server)
     ,@body))

(defun exercise-echo (ch)
  "Run unary Ping, Watch, Chat on CH. → plist of decoded bodies / :eof."
  (list
   :ping
   (pb-decode-bytes
    (call-timeout
     15
     (lambda ()
       (grpc-protocol:grpc-call ch "/echo.Echo/Ping"
                                (pb-encode-bytes #(9 8 7))
                                :timeout 5))))
   :watch
   (call-timeout
    20
    (lambda ()
      (let ((s (grpc-protocol:grpc-stream ch "/echo.Echo/Watch")))
        (unwind-protect
             (progn
               (grpc-protocol:grpc-send s (pb-encode-bytes #(9)) :end t)
               (list (pb-decode-bytes (grpc-protocol:grpc-recv s))
                     (pb-decode-bytes (grpc-protocol:grpc-recv s))
                     (pb-decode-bytes (grpc-protocol:grpc-recv s))
                     (grpc-protocol:grpc-recv s)))
          (grpc-protocol:grpc-close s)))))
   :chat
   (call-timeout
    20
    (lambda ()
      (let ((s (grpc-protocol:grpc-stream ch "/echo.Echo/Chat")))
        (unwind-protect
             (progn
               (grpc-protocol:grpc-send s (pb-encode-bytes #(65)))
               (let ((a (grpc-protocol:grpc-recv s)))
                 (grpc-protocol:grpc-send s (pb-encode-bytes #(66)))
                 (let ((b (grpc-protocol:grpc-recv s)))
                   (grpc-protocol:grpc-send s nil :end t)
                   (list (pb-decode-bytes a)
                         (pb-decode-bytes b)
                         (grpc-protocol:grpc-recv s)))))
          (grpc-protocol:grpc-close s)))))))

(defmacro with-lisp-echo-server ((port-var) &body body)
  (let ((server (gensym "SERVER")))
    `(multiple-value-bind (,server ,port-var)
         (start-lisp-echo-server)
       (unwind-protect
            (progn ,@body)
         (stop-lisp-echo-server ,server)))))
