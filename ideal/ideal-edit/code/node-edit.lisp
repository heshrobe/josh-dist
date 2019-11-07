;;; -*- Mode: LISP; Syntax: Common-Lisp; Base: 10; Package: IDEAL-EDIT -*-(in-package "IDEAL-EDIT");;;;********************************************************;;;;  Copyright (c) 1989, 1992 Rockwell International -- All rights reserved.;;;;  Rockwell International Science Center Palo Alto Lab;;;;********************************************************;;;----------------;;;   ooooooo                   NODE EDITOR;;;----------------;;; ;;; One of these is created per node, at the invocation of the user.;;; These mini-editors allow changes to the internal node structure,;;; principally the number and name of the states, and the distribution;;; or related data for computing its value.  There is also provision;;; for adding evidence for those node types which accept it.;;;----------------;;;   ooooooo             NODE EDITOR DESCRIPTION;;;----------------(define-application-frame node-editor ()    ((node :initarg :node)     (cond-cases :initarg :cond-cases)     (graph-editor :initarg :graph-editor)     (ne-proc :initform nil))  (:menu-bar nil)  (:panes    (table :accept-values	   :display-function '(accept-values-pane-displayer				:displayer ne-displayer				:resynchronize-every-pass t)	   :height :compute	   :width :compute	   :end-of-line-action :allow	   :scroll-bars :both)    (prompt :application	    :display-after-commands nil	    :initial-cursor-visibility :off	    :default-text-style '(:fix :roman :normal)	    :height '(3 :line)	    :scroll-bars :vertical)    (menu :command-menu	  :display-function '(display-command-menu :n-columns  3 :row-wise t)	  :default-text-style '(:sans-serif :bold :normal)	  :height :compute :width :compute	  :scroll-bars nil))  (:command-table (node-editor :inherit-from (accept-values-pane))))	      ;;;----------------;;;   ooooooo               NODE EDITOR CREATION;;;----------------(defmethod make-node-editor ((node graph-node) (graph-frame graph-editor))  (with-slots (node-editor) node    (setf node-editor	  (make-application-frame	   'node-editor	   :parent clim-user::*clim-root*	   :pretty-name NODE-EDITOR	   :left 200 :top 200 :width 500 :height 200	   :node node	   :cond-cases nil	   :graph-editor graph-frame))))(defun make-all-cond-cases (node)  (let ((cc-list nil))    (ideal:for-all-cond-cases (cc (ideal:node-predecessors node))      (push (ideal:copy-conditioning-case cc) cc-list))    cc-list))(defmethod get-cond-case ((editor node-editor))  (with-slots (cond-cases) editor    (car cond-cases)));;; the solved node may be different from the node itself (for decision nodes)(defmethod reset-cond-cases ((editor node-editor))  (with-slots (node cond-cases) editor    (setf cond-cases (make-all-cond-cases (or (and (typep node 'decision-node)						   (slot-value node 'solved-node))					      (slot-value node 'ideal-node))))))(defmethod next-cond-case ((editor node-editor))  (with-slots (cond-cases) editor    (setf cond-cases (append (cdr cond-cases) (list (car cond-cases))))));;; turn off commands that don't make sense for some node types;;; (it makes more since to do this on initialize-instance, but;;;  I couldn't figure out how to specialize on a keyword argument)(defmethod make-node-editor :after ((node value-node) graph-editor)  (declare (ignore graph-editor))  (setf (command-enabled 'com-add-state (slot-value node 'node-editor)) nil)  (setf (command-enabled  'com-delete-state (slot-value node 'node-editor)) nil))(defmethod make-node-editor :after (node graph-editor)  (declare (ignore graph-editor))  (if (not (or (typep node 'noisy-or-node)	       (typep node 'probability-node)	       (typep node 'deterministic-node)))    (setf (command-enabled 'com-change-type (slot-value node 'node-editor)) nil)))(defmethod frame-exit :after ((editor node-editor) #-genera &key)  (with-slots (node) editor    (if (typep node 'noisy-or-node)	(ideal:compile-noisy-or-distribution (slot-value node 'ideal-node)))));;;----------------;;;   ooooooo            PROCESS INTERACTION;;;----------------;;; note that if the multiprocessing feature does not exist,;;; then we will just run the node-editor as a subroutine,;;; and ne-proc will never be set to anything other than nil.(defmethod run-node-editor ((editor node-editor))  (with-slots (ne-proc) editor    (reset-cond-cases editor)    (cond (ne-proc	   ;; process already running -- move to top	   (window-expose editor))	  (t	   #+(and :ALLEGRO :multiprocessing)	   ;; no process running -- start a new process	   (setf ne-proc		 (mp:process-run-function 		  (symbol-name (gensym "node-editor"))		  #'run-frame-top-level editor))	   #-(and :ALLEGRO :multiprocessing)	   ;; if no multiprocessing, just run.	   (run-frame-top-level editor))))); This method doesnt do anything on non-allegro implementations.; Modification by Sam for non-allegro . Didnt want to screw with the basic; code structure and so I just left the method in there.(defmethod close-node-editor ((editor node-editor))  (with-slots (ne-proc) editor    (when ne-proc      ;; let's be paranoid here, and suppose that this could      ;; be called from ne-proc itself, even though it isn't.      (let ((temp ne-proc))	(setf ne-proc nil)	#+:ALLEGRO	(mp:process-interrupt temp #'frame-exit editor)        #-:ALLEGRO        temp))))(defmethod touch-node-editor ((editor node-editor))  ;; what we really need to do here is to poke the accepting values  ;; displayer into going through its loop again (thus redisplaying  ;; the table).  unfortunately, I can't think of a way to do that.  ());;;----------------;;;   ooooooo                 PROMPT WINDOW;;;----------------(defmethod graph-editor ((frame node-editor))  (slot-value frame 'graph-editor));;; the prompt window is where textual input is solicited.;;; all output to this window happens because of 'prompt';;; arguments to the accept function, or error output.(defun prompt-window ()  (get-frame-pane *application-frame* 'prompt));;; display a message in the prompt window(defmacro show-error (&rest arg-list)  `(progn    (beep)    (fresh-line (prompt-window))    (format (prompt-window) ,@arg-list)));;;----------------;;;   ooooooo                   MENU COMMANDS;;;----------------(define-node-editor-command (com-delete-state :menu t) ()  (let ((old-val nil) #+(or lucid mcl) hold)    (with-slots (node) *application-frame*      (with-slots (states ideal-node) node        ;; an error condition that ideal doesn't check for	(when (= (length states) 2)	  (show-error "Cannot have less than one state!")	  (return-from com-delete-state))	(setq old-val (menu-choose states :label "Choose State to Delete"				   ))	(when old-val	  (handler-case (ideal-delete-state node old-val)            (simple-error (c)	       #+(or lucid mcl) (setq hold t)	       (show-error "~a" c))	    #-(or lucid mcl)	    (:no-error (x)	       (declare (ignore x))	       (setf states (delete old-val states))))	  #+(or lucid mcl) (unless hold (setf states (delete old-val states)))	  )))));;;----------------(define-node-editor-command (com-next-case :menu t) ()    (next-cond-case *application-frame*))		       ;;;----------------(define-node-editor-command (com-add-state :menu t) ()  (let ((new-val nil) #+(or lucid mcl) hold)    (with-slots (node) *application-frame*      (with-slots (states ideal-node) node	(fresh-line (prompt-window))	(setq new-val (accept 'symbol			      :stream (prompt-window)			      :prompt "Enter State Name"			      :display-default nil			      :default nil))	(fresh-line (prompt-window)) 	(when new-val	  (handler-case (progn (ideal:add-state ideal-node new-val)			       (setf (ideal::node-bel ideal-node)				     (ideal::make-probability-array ideal-node)))	    (simple-error (c)	       #+(or lucid mcl) (setq hold t)	       (show-error "~a" c))	    #-(or lucid mcl)	    (:no-error (x)	       (declare (ignore x))	       (setf states (cons new-val states))	       ))	  #+(or lucid mcl) (unless hold (setf states (cons new-val states)))	  )))))			  (defun reset-node-beliefs (node)  (setf (ideal::node-bel node) nil));;;----------------;(define-node-editor-command (com-edit-states :menu t) ();  (let ((new-val nil));    (with-slots (node) *application-frame*;      (with-slots (states ideal-node) node;	(fresh-line (prompt-window));	(setq new-val (accept 'expression;			      :stream (prompt-window);			      :prompt "Enter New States";			      :default states));	(when (> (length new-val) 1);	  (ideal::edit-states ideal-node new-val);	  (setf states new-val))))));;;----------------;(define-node-editor-command (com-change-name :menu t) ();  (let ((new-name nil));    (with-slots (node graph-editor) *application-frame*;      (with-slots (name) node;	(fresh-line (prompt-window));	(setq new-name (accept 'symbol;			       :stream (prompt-window);			       :prompt "New Name";			       :display-default nil;			       :default nil));	(fresh-line (prompt-window));	(when new-name;	  (handler-case (change-node-name node new-name);	    (simple-error (c) ;	       (show-error "~a" c))))))));;; --- Convert Noisy-or to Standard Probability Node(define-node-editor-command (com-change-type :menu "Convert") ()  (with-slots (node) *application-frame*    (let ((ideal-node (slot-value node 'ideal-node)))      (typecase node	(noisy-or-node	  (ideal:compile-noisy-or-distribution ideal-node)	  (ideal:convert-noisy-or-node-to-chance-node ideal-node)	  (change-editor-node-type node 'probability-node))	(probability-node	  (ideal:convert-chance-node-to-noisy-or-node ideal-node)	  (change-editor-node-type node 'noisy-or-node))	(deterministic-node	  (ideal:convert-chance-node-to-noisy-or-node ideal-node)	  (change-editor-node-type node 'noisy-or-node))	))))(defun change-editor-node-type (node new-type)  (let ((new-node (make-instance new-type))	(old-x (slot-value node 'center-x))	(old-y (slot-value node 'center-y))	(frame (get-graph-editor)))    (with-slots (node-list) frame      ;;; now get rid of old node      (setf node-list (delete node node-list))      (with-unchanged-position ((display))	(undraw-self node))      (with-slots (link-list) frame	(mapc #'(lambda (l)		  (if (eq (from-node l) node)		      (setf (slot-value l 'from-node) new-node))		  (if (eq (to-node l) node)		      (setf (slot-value l 'to-node) new-node)))	      link-list))      ;;; Draw new node      (with-slots (center-x center-y name states ideal-node) new-node	(setf name (slot-value node 'name))	(setf ideal-node (slot-value node 'ideal-node))	(setf states (slot-value node 'states))	(setf center-x old-x	      center-y old-y)	(structure-changed)	(push new-node node-list)	(draw-self new-node))))  ;;; clean up  (setf (slot-value *application-frame* 'ne-proc) nil)  (frame-exit *application-frame*));;;----------------(define-node-editor-command (com-ne-refresh :menu "Refresh") ()  (window-refresh (get-frame-pane *application-frame* 'table)));;;----------------;;; This should be unecessary if the system is working properly;(define-node-editor-command (com-ne-exit2 :menu "ReCreate") ();  (with-slots (node) *application-frame*;    (with-slots (node-editor) node;      (setf node-editor nil);      (frame-exit *application-frame*))))	;;;----------------(define-node-editor-command (com-ne-exit :menu "Exit") ()  (setf (slot-value *application-frame* 'ne-proc) nil)  (frame-exit *application-frame*))