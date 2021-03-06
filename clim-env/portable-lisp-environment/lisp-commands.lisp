;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Package: CLIM-ENV; Base: 10; Lowercase: Yes -*-

;;; Copyright (c) 1994-2000, Scott McKay.
;;; Copyright (c) 2001-2003, Scott McKay and Howard Shrobe.
;;; All rights reserved.  No warranty is expressed or implied.
;;; See COPYRIGHT for full copyright and terms of use.

(in-package :clim-env)

;;; Evaluation context commands

(define-command (com-set-base :command-table lisp :name t)
    ((base '((integer) :base 10)
	   :default *read-base*))
  (setq *print-base* base
	*read-base* base)
  (with-frame-standard-output (stream)
    (fresh-line stream)
    (format stream "Print and read base set to ~D(10)." base)))

(define-command (com-set-package :command-table lisp :name t)
    ((package 'package
	      :default *package*))
  (setq *package* package)
  (with-frame-standard-output (stream)
    (fresh-line stream)
    (format stream "Package set to ~A." package)))

(define-command (com-show-macro-expansion :command-table lisp :name t)
    ((form '((form) :auto-activate t))
     &key
     (all 'boolean
          :prompt "expand all levels"
          :default nil :mentioned-default t
          :documentation "Fully macroexpand the form"))
  (with-frame-standard-output (stream)
    (let ((expansion (if all
                       (macroexpand form)
		       (macroexpand-1 form))))
      (pprint expansion stream)))) 


;;; General inspection commands

;;; Glue that connects the various utilities together by their objects
(define-command (com-invoke-inspector :command-table inspection :name t)
    ((object '((expression) :auto-activate t)
	     :gesture nil))
  (make-clim-environment-application 
    (find-navigator :framem (frame-manager *application-frame*)) 'inspector-frame
    :object object
    :width 700 :height 650))

(define-command (com-invoke-class-browser :command-table inspection :name t)
    ((object '(or expression class) :gesture nil))
  (make-clim-environment-application 
    (find-navigator :framem (frame-manager *application-frame*)) 'class-browser
    :class (if (typep object 'class) object (class-of object))
    :width 700 :height 650))

(define-command (com-invoke-generic-function-browser :command-table inspection :name t)
    ((object '(or expression generic-function)))
  (let ((gf (typecase object
	      (generic-function object)
              (method (method-generic-function object))
	      (otherwise nil))))
    (when gf
      (make-clim-environment-application 
	(find-navigator :framem (frame-manager *application-frame*)) 'generic-function-browser
	:generic-function gf
	:width 700 :height 650))))

(define-presentation-to-command-translator invoke-generic-function-browser
    ((or expression generic-function) com-invoke-generic-function-browser inspection
     :gesture nil
     :tester ((object)
	      (typep object '(or generic-function method))))
    (object)
  (list object))

(define-command (com-invoke-function-browser :command-table inspection :name t)
    ((object '(or expression function-spec)))
  (let ((function (cond ((and (symbolp object)
			      (fboundp object))
			 (fdefinition object))
			((and (listp object)
			      (listp (cdr object))
			      (null (cddr object))
			      (eql (car object) 'setf)
			      (fboundp object))
			  (fdefinition object))
			((functionp object)
			 object))))
    (when function
      (make-clim-environment-application 
	(find-navigator :framem (frame-manager *application-frame*)) 'function-browser
	:function function
	:width 700 :height 650))))

(define-presentation-to-command-translator invoke-function-browser
    ((or expression function-spec) com-invoke-function-browser inspection
     :gesture nil
     :tester ((object)
	      (or (and (symbolp object)
		       (fboundp object))
		  (and (listp object)
		       (listp (cdr object))
		       (null (cddr object))
		       (eql (car object) 'setf)
		       (fboundp object))
		  (functionp object))))
    (object)
  (list object))

(define-command (com-invoke-package-browser :command-table inspection :name t)
    ((object '(or expression package) :gesture nil))
  (make-clim-environment-application 
    (find-navigator :framem (frame-manager *application-frame*)) 'package-browser
    :package (typecase object
	       (symbol (symbol-package object))
	       (package object)
	       (t nil))
    :width 700 :height 650)) 


;;; Callers and callees

(define-command (com-show-callers :command-table callers :name t)
    ((function 'function-spec
	       :provide-default t)
     &key 
     (called-how '(token-or-type (:any)
		   (subset :variable :constant :function :macro :slot))
		 :default :any
		 :documentation "List only callers which call in the specified way")
     (package '(null-or-type package)
	      :default nil
	      :documentation "List only callers in the specified package")
     (system '(null-or-type system)
	     :default nil
	     :documentation "List only callers in the specified system "))
  (with-frame-standard-output (stream)
    (show-callers function
		  :called-how called-how
		  :package package :system system
		  :stream stream)))


(defun show-callers (symbol &key called-how package system (stream *standard-output*)
				 #+(or MCL Allegro) &aux #+(or MCL allegro) system-files)
  #-Genera (declare (ignore called-how))
   #+Genera (cond ((eql called-how :any)
		   (setq called-how nil))
		  (t (setq called-how (substitute :instance-variable :slot called-how))))
    #+allegro (when system (setq system-files (all-files-in-system system)))
     (labels ((thing-in-package (thing &optional ignore)
		(declare (ignore ignore))
		(cond ((symbolp thing)
		       ;; If we have a symbol, just use its package
		       (eql (symbol-package thing) package))
		      ((listp thing)
		       ;; If it's an internal function, etc., find the parent
		       (thing-in-package (second thing)))
		      (t t)))
	      (thing-in-system (thing &optional ignore)
		(declare (ignore ignore))
		#+Genera
		 (let* ((pathname (get-source-file-name-that-works thing nil t))
			(sys (when pathname (scl:send pathname :get 'sct:system))))
		   (or (eql sys system)
		       (and (not (typep system 'sct:subsystem))
			    (typep sys 'sct:subsystem)
			    (eql system (sct:subsystem-parent-system sys)))))
		 ;;---*** Here's a hack!
		 ;;---*** Maybe use a hashtable if you want to apply this to big systems and many callers -- JCMa 12/14/2001.
		 #+MCL
		  (flet ((physical-pathname (p)
			   (typecase p
			     (logical-pathname (translate-logical-pathname p))
			     (t p))))
		    (declare (inline physical-pathname))
		    (multiple-value-bind (files)
			(ccl::edit-definition-p thing) ; values: (files name type specializers qualifiers)
		      (and files
			   (intersection
			    (mapcan #'(lambda (x) 
					(when (member (car x) '(ccl::function ccl::method))
					  (list (physical-pathname (pathname (cdr x))))))
				     files)
			    (or system-files
				(prog2 (clim-defsystem::system-map-files
					system
					#'(lambda (p) (push (physical-pathname p) system-files)) 
					:file-type :source :include-components nil) 
				    system-files)) 
			    :test #'equal))))
		  #+Allegro 
		   (loop for (nil nil pathname nil) in (excl::find-source-file thing)
		       when (member pathname system-files :test #'equal)
		       return t)
		   #-(or Genera MCL Allegro) 
		    t)
	      #+Genera
	      (get-source-file-name-that-works (fspec &optional type chase-parents)
		(when (zwei:flavor-method-has-no-source-code fspec)
		  (setq fspec (flavor:method-flavor fspec))) ;instance variable accessor
		(si:get-source-file-name fspec type chase-parents))
	      (thing-in-package-and-system (thing &optional ignore)
		(declare (ignore ignore))
		(and (thing-in-package thing)
		     (thing-in-system thing))))
       (declare (dynamic-extent #'thing-in-package #'thing-in-system #'thing-in-package-and-system
				 #+Genera #'get-source-file-name-that-works))
       #+Genera
	(si:map-over-callers
	 symbol
	 #'(lambda (caller how)
	     (fresh-line stream)
	     (format stream "~/presentation/~@?."
		     (list caller 'function-spec)
		     (or (cadr (assoc how si:*who-calls-how-alist*))
			 " uses ~S in an unknown way") symbol))
	 :called-how called-how
	 :eliminate-duplicates nil
	 :filter (cond ((and system package) #'thing-in-package-and-system)
		       (system #'thing-in-system)
		       (package #'thing-in-package)
		       (t nil)))
	#+(or Lispworks Allegro MCL) 
	 (dolist (caller (who-calls symbol))
	   (when (cond ((and system package)
			(thing-in-package-and-system caller))
		       (system
			(thing-in-system caller))
		       (package
			(thing-in-package caller))
		       (t t))
	     (fresh-line stream)
	     (present caller 'function-spec :stream stream)
	     ;; (with-text-face (stream :italic) (format stream " uses ~/presentation/." (list symbol 'function-spec)))
	     ))))

#+(or Genera Lispworks Allegro)
(define-command (com-show-callees :command-table callers :name t)
    ((function 'function-spec :provide-default t)
     &key 
     (package '(null-or-type package)
	      :default nil
	      :documentation "List only callers in the specified package")
     (system '(null-or-type system)
	     :default nil
	     :documentation "List only callers in the specified system "))
  (with-frame-standard-output (stream)
    (show-callees function
		  :package package :system system
		  :stream stream)))

;; MCL 4.3 doesn't know how to do this

#+Genera
(defun show-callees (function-spec
		     &key package system
			  (stream *standard-output*))
  (let ((function (and (fboundp function-spec)
		       (fdefinition function-spec))))
    (unless (and function (compiled-function-p function))
      (fresh-line stream)
      (format stream "~S is not a compiled function" function-spec)
      (return-from show-callees))
    (let ((printed nil))
      (si:map-over-compiled-function-callees
	function
	#'(lambda (caller callee how)
	    (declare (ignore caller))
	    (when (and (or (null package)
			   (not (symbolp callee))
			   (eql (symbol-package callee) package)))
	      (unless printed
		(fresh-line stream)
		(format stream "~S calls" function-spec)
		(setq printed t))
	      (case how
		((:function :generic-function)
		 (fresh-line stream)
		 (format stream "  ~/presentation/ as a function" (list callee 'function-spec)))
		(:variable
		 (fresh-line stream)
		 (format stream "  ~/presentation/ as a variable" (list callee 'form))))))
	:external-references t))))

#+(or Lispworks Allegro)
(defun show-callees (function
		     &key package system
			  (stream *standard-output*))
  (declare (ignore system))
  (let ((printed nil))
    (dolist (callee (calls-who function))
      (when (and (or (null package)
		     (not (symbolp callee))
		     (eql (symbol-package callee) package)))
	(unless printed
	  (fresh-line stream)
	  (format stream "~S calls" function)
	  (setq printed t))
	(fresh-line stream)
	(write-string "  " stream)
	(present callee 'function-spec :stream stream)))))
