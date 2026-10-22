;;;; Body-pipe is http-protocol 0.3.9 — force that tag before ensure-deps walks names.

(format t "~&; ci: pre-install http-protocol:0.3.9~%")
(funcall (find-symbol "ENSURE-SYSTEMS" :cl-repo)
         "http-protocol" :version "0.3.9" :force t)
