;;; -*- Mode: LISP; Package: COMMON-LISP-USER; Lowercase: T; Base: 10 -*-
;;; Created 10/10/01 10:01:54 by HES

;;; Copyright 2001, Symbolics, Inc.  All Rights Reserved.

(in-package :cl-user)

#-Genera
(eval-when (:load-toplevel :execute)
  (let* ((loading-file *load-truename*)
         (host (pathname-host loading-file))
         (device (pathname-device loading-file))
         (loading-dir (pathname-directory loading-file))
         (wildcard-dir (append loading-dir (list :wild-inferiors))))
    (let ((home (make-pathname :directory loading-dir :host host :device device))
	  (wildcard (make-pathname :directory wildcard-dir :host host :device device)))
      (setf (logical-pathname-translations "aisl-clos")
	    `(("source;*.*" ,home)
	      ("**;*.*" ,wildcard))))))

#|

#+allegro
(eval-when (:compile-toplevel :load-top-level :execute)
  (defclass separate-destination-module (defsys:lisp-module)
    ())

  (defmethod defsys:product-pathname ((module separate-destination-module))
    (let ((source-pathname (ds:source-pathname module)))
      (let* ((my-directory (append (butlast (pathname-directory source-pathname)) 
				   (list (format nil "~a-binaries"
						 #+(and unix solaris2) 'solaris
						 #+(and unix macosx) 'macosx
						 #+(and unix (not macosx) (not solaris2)) 'linux
						#+MSWindows 'windows))))
	     (full-pathname (make-pathname :directory my-directory
					   :host (pathname-host source-pathname)
					   :device (pathname-device source-pathname)
					   :name (pathname-name source-pathname)
					   )))
	(ensure-directories-exist full-pathname)
	full-pathname))))

|#

#+allegro
(defsystem aisl-clos
    (:default-pathname "AISL-clos:source;"
     :default-module-class separate-destination-module
     )
  (:serial
    "aisl-clos-pkg"
    "mop"))

#+mcl
(clim-defsys:defsystem AISL-CLOS
    (:default-pathname "AISL-CLOS:source;"
     :default-binary-pathname (format NIL "AISL-CLOS:~A-binaries;"
				      #+MCL "MCL"
				      #+Allegro "ALLEGRO"
				      #+Lispworks "LISPWORKS"))
  ("aisl-clos-pkg" :language :lisp-unix)
  ("mop" :language :lisp-unix))

#+Genera
(sct:defsystem aisl-clos
    (:default-pathname "AISL-clos:source;"
     :journal-directory "aisl-clos:genera;patch;"
     :default-destination-pathname "aisl-clos:genera;")
  (:serial
   "aisl-clos-pkg"
   "mop"))
