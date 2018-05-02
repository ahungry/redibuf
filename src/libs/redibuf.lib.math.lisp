;; redibuf - A project template generated by ahungry-fleece
;; Copyright (C) 2016 Your Name <redibuf@example.com>
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.
;;
;; You should have received a copy of the GNU Affero General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;;; redibuf.lib.math.lisp

(in-package #:cl-user)

(defpackage redibuf.lib.math
  (:use
   :cl
   :redis

   ;; cl-protobufs
   :protobufs
   )
  (:export
   ;; :math
   ))

(in-package #:redibuf.lib.math)

;; Generated code from cl-protobufs
(cl:eval-when (:execute :compile-toplevel :load-toplevel)
  (cl:unless (cl:find-package "TUTORIAL")
    (cl:defpackage TUTORIAL (:use))))
(cl:in-package "TUTORIAL")
(cl:eval-when (:execute :compile-toplevel :load-toplevel)
 (cl:export '(MATH
              BASE
              FACTORIAL
              DOUBLED
              TRIPLED)))

(proto:define-schema math
    (:package "tutorial"
     :lisp-package "tutorial")
  (proto:define-message math
      (:conc-name ""
                  :source-location (#P"~/src/lisp/redibuf/math.proto" 46 50))
    ((base 1) :type protobufs:int64)
    ((factorial 2) :type (common-lisp:or common-lisp:null protobufs:int64))
    ((doubled 3) :type (common-lisp:or common-lisp:null protobufs:int64))
    ((tripled 4) :type (common-lisp:or common-lisp:null protobufs:int64))
    ))
(cl:in-package :redibuf.lib.math)
;; End generated code from cl-protobufs

(defun schema-parse ()
  "Load up a cl-protobufs schema file."
  (protobufs:parse-schema-from-file
   "~/src/lisp/redibuf/math.proto"
   ;; :name 'math
   ;; :class 'math
   ;; :conc-name nil
   ))

(defun schema-to-string (protobuf-schema)
  "Given a cl-protobufs schema, write it to a string stream."
  (let ((schema (make-array '(0) :element-type 'base-char
                            :fill-pointer 0 :adjustable t)))
    (with-output-to-string (s schema)
      (proto:write-schema protobuf-schema :type :lisp :stream s))
    schema))

(defun schema-eval (spec)
  "Read/evaluate all the things in a string."
  (loop for (s-exp pos) = (multiple-value-list (read-from-string spec nil 'eof :start (or pos 0)))
     until (eq s-exp 'eof)
     do (progn
          ;; (print pos)
          (eval s-exp))))

(defun schema-boot ()
  "Load all the things."
  (schema-eval (schema-to-string (schema-parse)))
  (cl:in-package :redibuf.lib.math)
  (rename-package :tutorial :tutorial '(:nicknames :pbt)))

;; Could dynamically load code here, maybe..
;; (schema-boot)

(defun factorial (n)
  (cond ((< n 1) 1)
        (t (* n (factorial (1- n))))))

(defun doubled (n) (* 2 n))

(defmethod math-factorial ((obj tutorial:math))
  (setf (tutorial:factorial obj) (factorial (tutorial:base obj))))

(defmethod math-doubled ((obj tutorial:math))
  (setf (tutorial:doubled obj) (doubled (tutorial:base obj))))

;; Redis interactions.
(defun store-obj-on-redis (key obj)
  (with-connection (:host "localhost" :port 6379)
    ;; set
    (red:lpush
     key
     (flexi-streams:octets-to-string    ; string-to-octets to reverse
      (nth-value 1 (proto:serialize obj))
      ;; (proto:serialize-object-to-bytes obj 'blub-message)
      ))))

;; (eval-when (:compile-toplevel :load-toplevel :execute) )
(defun find-obj-on-redis (key)
  (with-connection (:host "localhost" :port 6379)
    (nth-value 0 (proto:deserialize-object-from-bytes
                  'tutorial:math (flexi-streams:string-to-octets
                                  ;; (red:get key)
                                  (car (red:lrange key 0 0))
                                  )))))

(defun merge-math-protobufs (obj-list)
  "Merge a set of Math objects into a single object."
  (let ((result (car obj-list)))
    (loop :for obj :in obj-list
       :do (progn
             (when (tutorial:factorial obj) (setf (tutorial:factorial result)
                                                  (tutorial:factorial obj)))
             (when (tutorial:doubled obj) (setf (tutorial:doubled result)
                                                (tutorial:doubled obj)))
             (when (tutorial:tripled obj) (setf (tutorial:tripled result)
                                                (tutorial:tripled obj)))
             ))
    result))

(defun find-obj-aggregate-on-redis (key)
  "Aggregate a set of objects from the list of protobufs."
  (with-connection (:host "localhost" :port 6379)
    (let ((obj-list (red:lrange key 0 -1)))
      (merge-math-protobufs
       (loop :for obj :in obj-list
          :collect
            (nth-value 0 (proto:deserialize-object-from-bytes
                          'tutorial:math
                          (flexi-streams:string-to-octets obj))))))))


;; Listeners and such
(defvar llog '())

(defun find-thread (name)
  (find name (bt:all-threads) :key #'bt:thread-name :test #'string=))

;; ("message" "calcs-needed" "id")
(defun listener-factorial ()
  "Listen for a publish that requests a factorial be computed."
  (when (find-thread "sub-factorial") (bt:destroy-thread (find-thread "sub-factorial")))
  (bt:make-thread
   (lambda ()
     (with-connection ()
       (red:subscribe "calcs-needed")
       (loop :for msg := (expect :anything) :do
            (progn
              (with-connection ()
                (let* ((key (caddr msg))
                       (obj (find-obj-on-redis key)))
                  ;; Now we have the instantiated object, yay.
                  (push (format nil "Key: ~a" key) llog)
                  (math-factorial obj)  ; Compute the factorial.
                  (store-obj-on-redis key obj)
                  (with-connection () (red:publish "calcs-done" key))
                  ))
              ))))
   :name "sub-factorial"))

(defun listener-doubled ()
  "Listen for a publish that requests a doubled be computed."
  (when (find-thread "sub-doubled") (bt:destroy-thread (find-thread "sub-doubled")))
  (bt:make-thread
   (lambda ()
     (with-connection ()
       (red:subscribe "calcs-needed")
       (loop :for msg := (expect :anything) :do
            (progn
              (with-connection ()
                (let* ((key (caddr msg))
                       (obj (find-obj-on-redis key)))
                  ;; Now we have the instantiated object, yay.
                  (push (format nil "Key: ~a" key) llog)
                  (math-doubled obj)  ; Compute the doubled.
                  (store-obj-on-redis key obj)
                  (with-connection () (red:publish "calcs-done" key))
                  ))
              ))))
   :name "sub-doubled"))

(defun publisher-factorial (key)
  "Triggers a request for calculations (factorial etc.)."
  (with-connection ()
    (red:publish "calcs-needed" key)))

(defun generate-math-object (base)
  "Make an object, send to the world to calculate other pieces, recombine and send."
  (unless (find-thread "sub-factorial") (listener-factorial))
  (unless (find-thread "sub-doubled") (listener-doubled))

  (let ((obj (make-instance 'tutorial:math :base base))
        (populators 3)
        (key (uuid:make-v4-uuid)))

    (with-connection () (red:del key))
    (store-obj-on-redis key obj)
    (publisher-factorial key)

    ;; Fire off a loop that will kill it for ourselves.
    ;; This ensures we don't sit here all day if a service fails.
    (bt:make-thread
     (lambda ()
       (sleep 0.5)
       (with-connection ()
         (dotimes (x populators)
           (red:publish "calcs-done" key)))))

    ;; Pause until we get N ping backs.
    (let ((x 0))
      (with-connection ()
        (red:subscribe "calcs-done")
        (loop
           :for msg := (expect :anything)
           ;; The first shows up with double quotes unless in format.
           :when (equal (format nil "~a" (caddr msg))
                        (format nil "~a" key))
           :do (incf x)
           :until (>= x populators))))

    ;; Just wait a tiny moment to test the concurrent method.
    ;; (sleep 0.05)

    (find-obj-aggregate-on-redis key)))

(defvar gmo-results '())
(defun generate-many-objects (n)
  "Repeatedly generate the objects, re-enter when no threads are left :)"
  (setf llog '())
  (setf gmo-results '())
  (dotimes (x n)
    (bt:make-thread
     (lambda ()
       (handler-case
           (push (generate-math-object 3) gmo-results)
         (error (err)
           (push err llog))))
     :name "gmo-thread"))

  (loop :for threads := (find-thread "gmo-thread")
     :until (equal threads nil))

  gmo-results)

;;; "redibuf.lib.math" goes here. Hacks and glory await!