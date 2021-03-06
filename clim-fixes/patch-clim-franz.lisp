(in-package :clim-internals)
;;;; -------------------------------------------------------------------------------------
;;;; FRANZ seem to have left these out of their implementation:

(defmethod command-menu-enabled (command-table (frame standard-application-frame))
  (with-slots (disabled-commands) frame
    (or *assume-all-commands-enabled*
	(let ((comtab (if (command-table-p command-table)
			  command-table
			  (find-command-table command-table :errorp nil))))
	  (not (member comtab disabled-commands))))))

(defmethod (setf command-menu-enabled)
	   (enabled command-table (frame standard-application-frame))
  (with-slots (disabled-commands) frame
    (let* ((comtab (if (command-table-p command-table)
		       command-table
		       (find-command-table command-table :errorp nil)))
	   (name (command-table-name comtab)))
      ;;--- NOTE-COMMAND-ENABLED/DISABLED doesn't manage to increment the
      ;;--- command table tick when we are using the non-gadget frame manager
      (cond (enabled
	     (setf disabled-commands (delete comtab disabled-commands))
	     (note-command-enabled (frame-manager frame) frame name))
	    (t
	     (pushnew comtab disabled-commands)
	     (note-command-disabled (frame-manager frame) frame name)))
      enabled)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(command-menu-enabled) :clim-internals))
(eval-when (:compile-toplevel :load-toplevel :execute)
  (import '(clim-internals:command-menu-enabled) :clim))
(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(command-menu-enabled) :clim))

;;;; -------------------------------------------------------------------------------------
;;;; Franz seem to have not gotten this far ...

;; The :radio-box and :check-box types are a bit odd:
;;  (add-menu-item-to-command-table
;;    <command-table> <symbol> :radio-box	;or :check-box
;;    '(:items (("True" t) ("False" nil))
;;      :callback (lambda (x) (format *trace-output* "Value changed to ~S" x))))
#|
(defun add-menu-item-to-command-table (command-table string type value
				       &key documentation (after ':end) 
					    keystroke mnemonic
					    text-style (errorp t))
  (check-type type (member :command :function :menu :divider
                           ;; Some ports allow radio/check-boxes in menus
                           :radio-box :check-box))
  (if (member type '(:divider :radio-box :check-box))
      (check-type string (or string symbol null))
      (check-type string (or string null)))
  (when keystroke
    (assert (keyboard-gesture-spec-p keystroke) (keystroke)
	    "~S is not a keyboard gesture spec" keystroke)
    (multiple-value-bind (keysym modifiers)
	(decode-gesture-spec keystroke)
      #+Genera (when (and (characterp keysym)
			  (not (zerop (si:char-bits keysym))))
		 (error "The keystroke ~S is no longer legal" keysym))
      (setq keystroke (cons keysym modifiers))))
  (check-type documentation (or string null))
  (setq command-table (find-command-table command-table))
  (let ((old-item (and string (find-menu-item string command-table :errorp nil))))
    (when old-item
      (when errorp
	(cerror "Remove the menu item and proceed"
		'command-already-present
		:format-string "Menu item ~S already present in ~S"
		:format-args (list string command-table)))
      (remove-menu-item-from-command-table command-table string)))
  (when (eq type ':command)
    ;; Canonicalize command name to a command with the right number of
    ;; unsupplied argument markers.
    (unless (listp value)
      (setq value (list value)))
    (let ((n-required (get (first value) 'n-required))
	  (n-supplied (1- (length value))))
      (when (and n-required
		 (not (zerop n-required))
		 (< n-supplied n-required))
	(setq value (append value 
			    (make-list (- n-required n-supplied)
				       :initial-element *unsupplied-argument-marker*))))))
  (with-slots (menu menu-tick commands keystrokes) command-table
    (incf menu-tick)
    (setq keystrokes nil)
    (let* ((item `(,type ,value 
		   ,@(and documentation `(:documentation ,documentation))
		   ,@(and text-style `(:text-style ,text-style))
		   ,@(and mnemonic `(:mnemonic ,mnemonic))))
	   ;; Entries are of the form (MENU-NAME KEYSTROKE MENU-ITEM)
	   (entry (list string keystroke item)))
      (when (null menu)
	(setq menu (make-array *command-table-size*
			       :fill-pointer 0 :adjustable t)))
      (case after
	((:start)
	 (vector-push-extend nil menu)		;extend the vector by 1
	 (replace menu menu :start1 1 :start2 0)
	 (setf (aref menu 0) entry))
	((:end nil)
	 (vector-push-extend entry menu))
	((:sort)
	 (vector-push-extend entry menu)
	 (flet ((menu-name-lessp (x y)
		  (cond ((null x) t)
			((null y) nil)
			(t (string-lessp x y)))))
	   (setq menu (sort menu #'menu-name-lessp :key #'first))))
	(otherwise
	  (if (stringp after)
	      (let ((index (position after menu
				     :test #'menu-name-equal :key #'first)))
		(if index
		    (cond ((= index (1- (fill-pointer menu)))
			   ;; Just add at end
			   (vector-push-extend entry menu))
			  (t (vector-push-extend nil menu)
			     (replace menu menu :start1 (+ index 2) :start2 (+ index 1))
			     (setf (aref menu (+ index 1)) entry)))
		  (error 'command-not-present
			 :format-string "Menu item ~S not present in ~S for :AFTER"
			 :format-args (list after command-table))))
	    (error "The value for :AFTER is not a string, :START, :END, or :SORT"))))
      ;; Now that the command is accessible via a menu (or keystroke),
      ;; make sure that we've really imported it
      (when (eq type ':command)
	(let ((old-name (gethash (first value) commands)))
	  (setf (gethash (first value) commands) (or old-name t))))
      entry)))
|#

;;;; -------------------------------------------------------------------------------------
;;;; OOPS missed out on some more ...

(eval-when (:compile-toplevel :load-toplevel :execute)
  (setf (excl:package-definition-lock (find-package :clim-internals)) nil))

(defmethod frame-document-highlighted-presentation-1
           ((frame standard-application-frame) presentation input-context window x y stream)
  (let ((modifier-state (port-modifier-state (port window))))
    (declare (type fixnum modifier-state))
    (multiple-value-bind (left   left-presentation   left-context
			  middle middle-presentation middle-context
			  right  right-presentation  right-context)
	(find-applicable-translators-for-documentation presentation input-context
						       frame window x y modifier-state)
      (let* ((*print-length* 3)
	     (*print-level* 2)
	     (*print-circle* nil)
	     (*print-array* nil)
	     (*print-readably* nil)
	     (*print-pretty* nil))
	(flet ((document-translator (translator presentation context-type
				     button-name separator)
		 ;; Assumes 5 modifier keys and the reverse ordering of *MODIFIER-KEYS*
		 (let ((bit #o20)
		       (shift-name '("h-" "s-" "m-" "c-" "sh-")))
		   (declare (type fixnum bit))
		   (repeat 5			;length of shift-name
		     (unless (zerop (logand bit modifier-state))
		       (write-string (car shift-name) stream))
		     (pop shift-name)
		     (setq bit (the fixnum (ash bit -1)))))
		 (write-string button-name stream)
		 (document-presentation-translator translator presentation context-type
						   frame nil window x y
						   :stream stream
						   :documentation-type :pointer)
		 (write-string separator stream)))
	  (declare (dynamic-extent #'document-translator))
	  ;;--- The button names should be hard-wired in.  Consider 1-button
	  ;;--- Macs and 2-button PCs...
	  (when left
	    (let ((button-name (cond ((and (eq left middle)
					   (eq left right))
				      (setq middle nil
					    right nil)
				      "L,M,R: ")
				     ((eq left middle) 
				      (setq middle nil)
				      "L,M: ")
				     (t "L: "))))
	      (document-translator left left-presentation left-context
				   button-name (if (or middle right) "; " "."))))
	  (when middle
	    (let ((button-name (cond ((eq middle right)
				      (setq right nil)
				      "M,R: ")
				     (t "M: "))))
	      (document-translator middle middle-presentation middle-context
				   button-name (if right "; " "."))))
	  (when right
	    (document-translator right right-presentation right-context
				 "R: " "."))
	  ;; Return non-NIL if any pointer documentation was produced
	  (or left middle right))))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (setf (excl:package-definition-lock (find-package :clim-internals)) t))
