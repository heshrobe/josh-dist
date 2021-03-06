;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Package: CLIM-ENV; Base: 10; Lowercase: Yes -*-

;;; Copyright (c) 1994-2000, Scott McKay.
;;; Copyright (c) 2001-2003, Scott McKay and Howard Shrobe.
;;; All rights reserved.  No warranty is expressed or implied.
;;; See COPYRIGHT for full copyright and terms of use.

(in-package :clim-env)

;;; Useful presentation types

;; Class name
(define-presentation-type class ()
  :history t)

#+Genera
(define-presentation-method accept
    ((type clos:class) stream (view textual-view) &key)
  (values
    (completing-from-suggestions (stream :partial-completers '(#\-))
      (map nil #'(lambda (x) 
		   (if (listp x)
		     (suggest (first x) (find-class (second x)))
		     (suggest (symbol-name x) (find-class x))))
	   clos-internals:*all-class-names-aarray*))))

#+(or Lispworks Allegro)
(progn
(defvar *class-names-aarray* nil)
(defvar *class-names-aarray-tick* nil)

(define-presentation-method accept
    ((type class) stream (view textual-view) &key)
  (let* ((all-classes #+Lispworks clos::*class-table*
		      #+Allegro (excl::list-all-classes))
	 (n-classes #+Lispworks (hash-table-size all-classes)
		    #+Allegro (length all-classes)))
    (unless (eql *class-names-aarray-tick* n-classes)
      (let ((names nil))
	#+Lispworks
	(maphash #'(lambda (name class)
		     (push (cons name class) names))
		 all-classes)
	#+Allegro
	(map () #'(lambda (class)
		    (unless (consp (class-name class))
		      (push (cons (class-name class) class) names)))
	     all-classes)
	(setq *class-names-aarray* (sort names #'string-lessp :key #'car))
	(setq *class-names-aarray-tick* n-classes))))
  (multiple-value-bind (class success string)
      (completing-from-suggestions (stream :partial-completers '(#\- #\space)
					   :allow-any-input t)
        (map nil #'(lambda (x) 
		     (suggest (symbol-name (car x)) (cdr x)))
	     *class-names-aarray*))
    (declare (ignore success))
    (unless class
      (ignore-errors
        (setq class (find-class (read-from-string string) :errorp nil)))
      (unless class
	(simple-parse-error "~A is not the name of a class" string)))
    class))
)	;#+(or Lispworks Allegro)

#-(or Genera Lispworks Allegro)
(define-presentation-method accept
    ((type class) stream (view textual-view) &key default)
  (let* ((class-name (accept 'symbol :stream stream :view view
				     :default (and default (class-name default))
				     :prompt nil))
	 (class (find-class class-name nil)))
    (unless class
      (input-not-of-required-type class-name type))
    class))

(define-presentation-method present
    (class (type class) stream (view textual-view) &key)
  (if (typep class 'class)
    (prin1 (class-name class) stream)
    (prin1 class stream)))

#+Genera (pushnew '(clos:class clos:class)
		  clim-internals::*dw-type-to-clim-type-alist* :key #'first)


;; Generic function name
#-Lispworks	;Lispworks doesn't want to do this
(define-presentation-type generic-function ()
  :history t)

#+Lispworks	;we still want a presentation type history for this
(progn
(defvar *generic-function-type-history*
	(make-presentation-type-history 'clos:generic-function 
                                        :history-name "generic function"))

(define-presentation-method presentation-type-history
    ((type clos:generic-function))
  *generic-function-type-history*)
)	;#+Lispworks

#+Genera
(define-presentation-method accept
    ((type clos:generic-function) stream (view textual-view) &key)
  (values
    (completing-from-suggestions (stream :partial-completers '(#\-))
      (map nil #'(lambda (x) 
		   (if (listp x)
		     (when (fboundp (second x))
		       (suggest (first x) (fdefinition (second x))))
		     (when (fboundp x)
		       (suggest (symbol-name x) (fdefinition x)))))
	   clos-internals::*all-generic-function-names-aarray*))))

#+Allegro
(progn
(defvar *generic-function-names-aarray* nil)
(defvar *generic-function-names-aarray-tick* nil)

(define-presentation-method accept
    ((type generic-function) stream (view textual-view) &key)
  (let* ((all-gfs #+Allegro (excl::list-all-generic-functions))
	 (n-gfs #+Allegro (length all-gfs)))
    (unless (eql *generic-function-names-aarray-tick* n-gfs)
      (let ((names nil))
	#+Allegro
	(map () #'(lambda (gf)
		    (unless (consp (generic-function-name gf))
		      (push (cons (generic-function-name gf) gf) names)))
	     all-gfs)
	(setq *generic-function-names-aarray* (sort names #'string-lessp :key #'car))
	(setq *generic-function-names-aarray-tick* n-gfs))))
  (multiple-value-bind (gf success string)
      (completing-from-suggestions (stream :partial-completers '(#\-)
					   :allow-any-input t)
        (map nil #'(lambda (x) 
		     (suggest (symbol-name (car x)) (cdr x)))
	     *generic-function-names-aarray*))
    (declare (ignore success))
    (unless gf
      (ignore-errors
        (setq gf (and (fboundp (read-from-string string))
		      (fdefinition (read-from-string string)))))
      (unless gf
	(simple-parse-error "~A is not the name of a generic function" string)))
    gf))
)	;#+Allegro

#-(or Genera Allegro)
(define-presentation-method accept
    ((type generic-function) stream (view textual-view) &key default)
  ;;--- Extend CLIM's COMPLETE-SYMBOL-NAME to look in the packages
  ;;--- and then make this use it only on generic functions
  (let* ((gf-name (accept #---ignore 'symbol
			  #+++ignore '((expression) :auto-activate t)
			  :stream stream :view view
			  :default (and default (generic-function-name default))
			  :prompt nil))
	 (gf (and (fboundp gf-name) (fdefinition gf-name))))
    (unless (typep gf 'aisl-clos:generic-function)
      (input-not-of-required-type gf-name type))
    gf))

(define-presentation-method present
    (gf (type generic-function) stream (view textual-view) &key)
  (if (typep gf 'generic-function)
    (prin1 (generic-function-name gf) stream)
    (prin1 gf stream)))

#+Genera (pushnew '(clos:generic-function clos:generic-function)
		  clim-internals::*dw-type-to-clim-type-alist* :key #'first)


;; Method
(define-presentation-type method ()
  :history t)

(define-presentation-method present
    (method (type method) stream (view textual-view) &key)
  (prin1 #+Genera (clos-internals::function-spec-object method)
	 #+Allegro (function-name method)
	 #+Lispworks (sys::function-name (method-function method))
	 #-(or Genera Allegro Lispworks)
	 (generic-function-name (method-function method))
	 stream))


;; Package
(define-presentation-type package ()
  :inherit-from t
  :history t)

(define-presentation-method accept
    ((type package) stream (view textual-view) &key)
  (values
    (let ((packages (sort (copy-list (list-all-packages)) #'string-lessp
			  :key #'package-name)))
      (completing-from-suggestions (stream :partial-completers '(#\-))
	(map nil #'(lambda (package)
		     (suggest (package-name package) package)
		     (loop for nickname in (package-nicknames package)
			 do (suggest nickname package))
		     )
	     packages)))))

(define-presentation-method present
    (package (type package) stream (view textual-view) &key)
  (write-string (package-name package) stream))

(define-presentation-method presentation-typep (object (type package))
  (typep object 'clim-lisp::package))

#+Genera (pushnew '(package package)
		  clim-internals::*dw-type-to-clim-type-alist* :key #'first)


;; General function spec
(define-presentation-type function-spec (&key (defined-p nil))
  :history t)

#+Genera
;;--- Use different views to implement support for multiple languages
(define-presentation-method accept
    ((type function-spec) stream (view textual-view) &key)
  (multiple-value-bind (object success string)
      (completing-from-suggestions (stream :partial-completers '(#\-)
					   :allow-any-input t)
	(map nil #'(lambda (x) 
		     (if (listp x)
		       (suggest (first x) (second x))
		       (suggest (symbol-name x) (fdefinition x))))
	     zwei:*zmacs-completion-aarray*))
    (declare (ignore success))
    (unless object
      (setq object (ignore-errors (read-from-string string))))
    (cond (defined-p
	   (if (fboundp object)
	     object
	     (input-not-of-required-type object type)))
	  (t object))))

#-Genera
(define-presentation-method accept
    ((type function-spec) stream (view textual-view) &key default)
  (let ((fspec (accept #---ignore 'symbol
		       #+++ignore '((expression) :auto-activate t)
		       :stream stream :view view
		       :default default
		       :prompt nil)))
    ;;--- Extend CLIM's COMPLETE-SYMBOL-NAME to look in the packages
    ;;--- and then make this use it
    (cond (defined-p
	   (if (fboundp fspec)
	     fspec
	     (input-not-of-required-type fspec type)))
	  (t fspec))))

;;--- Use different views to implement support for multiple languages
(define-presentation-method present
    (fspec (type function-spec) stream (view textual-view) &key)
  (prin1 fspec stream))

(define-presentation-method presentation-typep (object (type function-spec))
  (and (or (symbolp object)
	   (and (listp object)
		(or (eql (car object) 'setf)
		    #+Genera (eql (car object) 'sys:locf))))
       (or (not defined-p)
	   (fboundp object))))
		
#+Genera (pushnew '(sys:function-spec function-spec (:partial-completers :abbreviate-p))
		  clim-internals::*dw-type-to-clim-type-alist* :key #'first)


;; System name
(define-presentation-type system ()
  :inherit-from t
  :history t)


#+Genera
(define-presentation-method accept
    ((type system) stream (view textual-view) &key)
  (values
   (completing-from-suggestions (stream :partial-completers '(#\- #\space))
      (map nil #'(lambda (x) 
		   (suggest (car x) (cdr x)))
	   sct:*subsystems-aarray*))))

#+allegro
(define-presentation-method accept
    ((type system) stream (view textual-view) &key)
  (values 
   (with-delimiter-gestures (#\,)
     (completing-from-suggestions (stream :partial-completers '(#\- #\space))
				  (map nil #'(lambda (x) 
					       (suggest (defsys:pretty-name x) x))
				       (defsys:list-all-systems))
				  (loop for (nil . system) being the hash-values of asdf/find-system:*defined-systems*
				      do (suggest (asdf/find-system:primary-system-name system) system))
				  ))))

#-(or Genera Allegro)
(define-presentation-method accept
    ((type system) stream (view textual-view) &key)
  (values
    (let ((systems (sort (copy-list clim-defsys::*systems*) #'string-lessp
			 :key #'clim-defsys::system-name)))
      (completing-from-suggestions (stream :partial-completers '(#\- #\space))
	(map nil #'(lambda (system) 
		     (suggest (string (clim-defsys::system-name system)) system))
	     systems)))))

(define-presentation-method present
    (system (type system) stream (view textual-view) &key)
  #+Genera (princ (sct:system-pretty-name system) stream)
   #+Allegro (if (typep system 'asdf/system:system)
		 (princ (asdf/find-system:primary-system-name system) stream)
	       (princ (defsys:pretty-name system) stream))
  #-(or Genera Allegro) (princ (clim-defsys::system-name system) stream))

(define-presentation-method presentation-typep (object (type system))
  #+Genera (typep object 'sct:basic-system)
   #+Allegro (or (typep object 'defsys::defsystem-base-class)
		 (typep object 'asdf/system:system))
  #-(or Genera Allegro) (typep object 'clim-defsys::system))

#+Genera (pushnew '(sct:system system)
		  clim-internals::*dw-type-to-clim-type-alist* :key #'first)
#+Genera (pushnew '(sct:subsystem system)
		  clim-internals::*dw-type-to-clim-type-alist* :key #'first)


(define-presentation-type universal-time (&key (pastp t))
  :history t)

(define-presentation-method accept
    ((type universal-time) stream (view textual-view) &key)
  (handler-bind (#-Genera (time-parser-error
			    #'(lambda (error)
			        (apply #'simple-parse-error
                                       (parse-error-format-string error)
                                       (parse-error-format-arguments error)))))
    (let* ((buffer-start (stream-scan-pointer stream))
	   (time (read-token stream))
	   (utime #+Genera (time:parse-universal-time time :pastp pastp)
		  #-Genera (parse-universal-time time)))
      (unless (stream-rescanning-p stream)
        (presentation-replace-input stream utime type view
				    :buffer-start buffer-start))
      utime)))

(define-presentation-method present
    (time (type universal-time) stream (view textual-view) &key)
  #+Genera (time:print-universal-time time stream)
  #-Genera (print-universal-time time :stream stream))

(define-presentation-method presentation-typep (object (type universal-time))
  (integerp object))


;; Command table name
(define-presentation-type command-table ()
  :history t)

(define-presentation-method accept
    ((type command-table) stream (view textual-view) &key)
  (values
    (let ((command-tables 
	    (let ((comtabs nil))
	      (maphash #'(lambda (key comtab)
			   (declare (ignore key))
			   (pushnew comtab comtabs))
		       clim-internals::*all-command-tables*)
	      (sort comtabs #'string-lessp
		    :key #'(lambda (comtab) (string (command-table-name comtab)))))))
      (completing-from-suggestions (stream :partial-completers '(#\-))
	(map nil #'(lambda (comtab) 
		     (suggest (string (command-table-name comtab)) comtab))
	     command-tables)))))

(define-presentation-method present
    (comtab (type command-table) stream (view textual-view) &key)
  (princ (command-table-name comtab) stream))


;; Process name

;; Command table name
(define-presentation-type process ()
  :history t)

(define-presentation-method accept
    ((type process) stream (view textual-view) &key)
  (values
    (completing-from-suggestions (stream :partial-completers '(#\- #\space))
      (map nil #'(lambda (process) 
		   (suggest (string (clim-sys:process-name process)) process))
	   (clim-sys:all-processes)))))

(define-presentation-method present
    (process (type process) stream (view textual-view) &key)
  (princ (clim-sys:process-name process) stream))

(define-presentation-method presentation-typep (object (type process))
  (clim-sys:processp object))


;; Printer

(defparameter *printer-name-alist* ())

(define-presentation-type printer ())

(define-presentation-method accept
    ((type printer) stream (view textual-view) &key)
  (multiple-value-bind (object success string)
      (completing-from-suggestions (stream :partial-completers '(#\- #\space)
                                           #-Genera :allow-any-input #-Genera t)
        (dolist (printer *printer-name-alist*)
          (suggest (cdr printer) (car printer))))
    (declare (ignore success #+Genera string))
    #-Genera (when (null object)
               (setq object string)
               (pushnew (cons object object) *printer-name-alist*
                        :key #'first :test #'string-equal))
    object))

(define-presentation-method present
    (printer (type printer) stream (view textual-view) &key acceptably)
  (let ((entry (assoc printer *printer-name-alist*
                      #-Genera :test #-Genera #'string-equal)))
    (when entry
      (write-token (cdr entry) stream :acceptably acceptably))))

(define-presentation-method presentation-typep (object (type printer))
  #+Genera (not (null (assoc object *printer-name-alist*)))
  #-Genera (and (stringp object)
                (not (null (assoc object *printer-name-alist*
				  :test #'string-equal)))))

#+Genera
(scl:add-initialization "Local printers"
   '(let ((site net:*local-site*))
      (setq *printer-name-alist*
	    (mapcar #'(lambda (printer)
			(cons printer (scl:send printer :pretty-name)))
		    (net:find-objects-from-property-list ':printer ':site site))))
   '(:now) 'neti:commonly-used-property-lists)

