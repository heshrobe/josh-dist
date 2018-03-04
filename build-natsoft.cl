;;; -*- Mode: Common-lisp; Package: common-lisp-user -*-

(in-package :common-lisp-user)

;;; This seems to cause trouble in Allegro 10.0
(eval-when (:compile-toplevel :execute :load-toplevel)
  (proclaim '(optimize (debug 3) (safety 3) (speed 1) (space 1))))

(load "~/josh-dist/find-lisp-listener")

(require :climxm)

(require :xml-rpc)

(load "~/josh-dist/driver.lisp")

(handler-bind ((fasl-casemode-mismatch #'(lambda (c) (invoke-restart 'excl::fasl-casemode-mismatch-continue)))) 
  (build-it)

  (load "~/josh-dist/xml-parser/xml-parser-defsystem.lisp")
  (load-system 'xml-parser)

  (load "~/josh-dist/ideal/load-ideal.lisp")
  (load-system 'ideal)

  (push "~/my-logical-pathnames.lisp"
	(logical-pathname-translations-database-pathnames))

  ;; I don't think I have a need for this anymore
  ;; (load "test-eli.fasl")

  (load-system 'sample-xml-rpc-server)

  ;; (load "~/research-projects/natural-software/code/defsystem.lisp")
  ;; (load-system 'natsoft)

  )

(setq *read-init-files* t)

(setq *restart-init-function* 'clim-env:start-clim-environment)

(dumplisp :name "sys:clim-env-josh.dxl")




		      