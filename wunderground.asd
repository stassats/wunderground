;;; -*- Mode: Lisp -*-

(defsystem wunderground
  :serial t
  :depends-on (drakma cxml cxml-stp cl-ppcre)
  :components ((:file "packages")
               (:file "wunderground")))
