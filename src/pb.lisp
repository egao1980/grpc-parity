(in-package #:grpc-parity)

;;; Tiny proto3 echo.Msg { bytes body = 1; } — field tag 0x0a.

(defun pb-varint (n)
  (let ((out (make-array 0 :element-type '(unsigned-byte 8)
                         :adjustable t :fill-pointer 0)))
    (loop
      (let ((b (logand n #x7f)))
        (setf n (ash n -7))
        (vector-push-extend (if (plusp n) (logior b #x80) b) out)
        (when (zerop n)
          (return out))))))

(defun read-varint (octets start)
  (let ((n 0)
        (shift 0)
        (pos start))
    (loop
      (when (>= pos (length octets))
        (error "short protobuf varint"))
      (let ((b (aref octets pos)))
        (incf pos)
        (setf n (logior n (ash (logand b #x7f) shift)))
        (when (zerop (logand b #x80))
          (return (values n pos)))
        (incf shift 7)))))

(defun pb-encode-bytes (octets)
  (let ((payload (coerce octets '(vector (unsigned-byte 8)))))
    (concatenate '(vector (unsigned-byte 8))
                 #(#x0a)
                 (pb-varint (length payload))
                 payload)))

(defun pb-decode-bytes (octets)
  (when (zerop (length octets))
    (return-from pb-decode-bytes
      (make-array 0 :element-type '(unsigned-byte 8))))
  (unless (= #x0a (aref octets 0))
    (error "expected echo.Msg field 1"))
  (multiple-value-bind (len pos)
      (read-varint octets 1)
    (subseq octets pos (+ pos len))))
