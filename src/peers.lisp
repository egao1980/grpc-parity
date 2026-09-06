(in-package #:grpc-parity)

(defparameter *peer-root*
  (asdf:system-relative-pathname "grpc-parity" "peers/")
  "Directory containing python/ and tls/.")

(defun %env-on-p (name)
  (let ((v (uiop:getenv name)))
    (and v (not (member (string-downcase v)
                        '("" "0" "false" "no" "off")
                        :test #'string=)))))

(defun %env-off-p (name)
  (member (uiop:getenv name) '("0" "false" "no" "off") :test #'string-equal))

(defun peers-enabled-p ()
  (not (%env-off-p "GRPC_PARITY_PEERS")))

(defun python-bin ()
  (or (uiop:getenv "GRPC_PARITY_PYTHON")
      (loop for cmd in '("python3" "python")
            when (zerop (nth-value 2 (uiop:run-program
                                      (list cmd "-c" "import grpc, grpc_tools")
                                      :ignore-error-status t
                                      :output nil
                                      :error-output nil)))
              return cmd)))

(defun python-available-p ()
  (and (peers-enabled-p)
       (python-bin)
       (probe-file (merge-pathnames "python/server.py" *peer-root*))
       (probe-file (merge-pathnames "tls/cert.pem" *peer-root*))
       (probe-file (merge-pathnames "tls/key.pem" *peer-root*))))

(defun python-client-available-p ()
  (and (python-available-p)
       (probe-file (merge-pathnames "python/client.py" *peer-root*))))

(defun go-bin ()
  (or (uiop:getenv "GRPC_PARITY_GO")
      (loop for cmd in '("go")
            when (zerop (nth-value 2 (uiop:run-program
                                      (list cmd "version")
                                      :ignore-error-status t
                                      :output nil
                                      :error-output nil)))
              return cmd)))

(defun go-available-p ()
  (and (peers-enabled-p)
       (go-bin)
       (probe-file (merge-pathnames "go/server.go" *peer-root*))
       (probe-file (merge-pathnames "go/go.mod" *peer-root*))
       (probe-file (merge-pathnames "tls/cert.pem" *peer-root*))
       (probe-file (merge-pathnames "tls/key.pem" *peer-root*))))

(defun %free-port ()
  (let* ((sock (usocket:socket-listen "127.0.0.1" 0 :reuseaddress t))
         (port (usocket:get-local-port sock)))
    (usocket:socket-close sock)
    port))

(defun %read-listen-line (proc)
  (let ((out (uiop:process-info-output proc))
        (deadline (+ (get-internal-real-time)
                     (* 15 internal-time-units-per-second))))
    (loop
      (when (> (get-internal-real-time) deadline)
        (return nil))
      (when (listen out)
        (let ((line (read-line out nil nil)))
          (when (and line (search "LISTEN" line))
            (return line))))
      (unless (uiop:process-alive-p proc)
        (return nil))
      (sleep 0.05))))

(defun start-grpcio-server (&key (port (%free-port)))
  (let* ((script (merge-pathnames "python/server.py" *peer-root*))
         (cert (merge-pathnames "tls/cert.pem" *peer-root*))
         (key (merge-pathnames "tls/key.pem" *peer-root*))
         (proc (uiop:launch-program
                (list (python-bin)
                      (uiop:native-namestring script)
                      (princ-to-string port)
                      (uiop:native-namestring cert)
                      (uiop:native-namestring key))
                :output :stream
                :error-output :stream)))
    (unless (%read-listen-line proc)
      (ignore-errors (uiop:terminate-process proc :urgent t))
      (error "grpcio server failed to start on ~A" port))
    (values proc port)))

(defun stop-grpcio-server (proc)
  (when proc
    (ignore-errors (uiop:terminate-process proc :urgent t))
    (ignore-errors (uiop:wait-process proc))))

(defun start-go-server (&key (port (%free-port)))
  (let* ((script (merge-pathnames "go/server.go" *peer-root*))
         (cert (merge-pathnames "tls/cert.pem" *peer-root*))
         (key (merge-pathnames "tls/key.pem" *peer-root*))
         (proc (uiop:launch-program
                (list (go-bin) "run"
                      (uiop:native-namestring script)
                      (princ-to-string port)
                      (uiop:native-namestring cert)
                      (uiop:native-namestring key))
                :directory (uiop:native-namestring
                            (merge-pathnames "go/" *peer-root*))
                :output :stream
                :error-output :stream)))
    (unless (%read-listen-line proc)
      (ignore-errors (uiop:terminate-process proc :urgent t))
      (error "grpc-go server failed to start on ~A" port))
    (values proc port)))

(defun stop-go-server (proc)
  (stop-grpcio-server proc))

(defun run-grpcio-client (port)
  "Drive peers/python/client.py against PORT. → T on all OK."
  (let* ((script (merge-pathnames "python/client.py" *peer-root*))
         (cert (merge-pathnames "tls/cert.pem" *peer-root*)))
    (multiple-value-bind (out err code)
        (uiop:run-program
         (list (python-bin)
               (uiop:native-namestring script)
               (princ-to-string port)
               (uiop:native-namestring cert))
         :output '(:string :stripped t)
         :error-output '(:string :stripped t)
         :ignore-error-status t)
      (declare (ignore err))
      (values (zerop code) out))))
