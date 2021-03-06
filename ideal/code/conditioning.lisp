;;; -*- Mode: LISP; Syntax: Common-Lisp; Package: Ideal;  Base: 10 -*-

(in-package :ideal)


;;;;********************************************************
;;;;  Copyright (c) 1989, 1992 Rockwell International -- All rights reserved.
;;;;  Rockwell International Science Center Palo Alto Lab
;;;;********************************************************

;;;;;;;;;;;;;;;;;;;;;;;; Sampath ;;;;;;;;;;;;;;;;;;;;



(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(CONDITIONING-INFER)))

;--------------------------------------------------------
 

(defun conditioning-infer ( &optional (belnet *diagram*))
  (let ((cutset+evidence (set-up-for-conditioning-1 belnet)))
    (my-print "~%")
    (prop-every-case-1 cutset+evidence belnet 1))
  (normalize-beliefs belnet))

(defun prop-every-case-1 (cutset+evidence belnet mix-wt &optional (tab 1))
  (cond
    ((null cutset+evidence)
     (my-print " Mix wt: ~14,8,2E" mix-wt)
     (increment-bels belnet mix-wt))
    (t
     (dolist (node-case.belief (get-belief-list (first cutset+evidence)))
       (let ((node-case (car node-case.belief))(belief (cdr node-case.belief)))
	;----
	 (my-actions (move-tab tab))
	 (my-print " ~A" (prob-string-of-cond-case node-case))
	;-----
	 (cond
	   ((zerop belief)
	    (my-print " ZERO !" (prob-string-of-cond-case node-case)))
	   (t (propagate-evidence node-case belnet)
	      (prop-every-case-1 (rest cutset+evidence) belnet (* belief mix-wt) (+ 1 tab))))))
     (retract-evidence (first cutset+evidence) belnet))))


(defun get-belief-list (node)
  (cond
    ((is-ev-node-p node)
     (let ((node-case (get-evidence-case node)))
       (list (cons node-case (calc-belief-of node-case)))))
    ((is-cs-node-p node)
     ; Cutset nodes are not updated during actual propagation.
     (update-msgs node)
     (let ((ans nil))
       (for-all-cond-cases (node-case node)
	 (push (cons (copy-conditioning-case node-case) (calc-belief-of node-case)) ans))
       (nreverse ans)))
    (t (error "Node ~A is neither a cutset node nor an evidence node" node))))


(defun get-evidence-case (node)
  (list (cons node (node-state node))))

(defun increment-bels (belnet mix-wt)
  (dolist (n belnet)
    (let ((total 0))
      (for-all-cond-cases (node-case n)
	(incf total (calc-bel-of node-case)))
      (for-all-cond-cases (node-case n)
	(incf (belief-of node-case)(/ (* (calc-bel-of node-case) mix-wt) total))))))

(defun calc-bel-of (node-case)
  (* (lambda-of node-case)(pi-of node-case)))

(defun calc-belief-of (node-case)
  (let ((normalization-constant 0))
    (for-all-cond-cases (n-case (node-in node-case))
      (incf normalization-constant (* (lambda-of n-case)(pi-of n-case))))
    (values (/ (* (lambda-of node-case)(pi-of node-case)) normalization-constant))))

(defun normalize-beliefs (belnet)
  (dolist (n belnet)
    (let ((marginal 0))
      (for-all-cond-cases (node-case n)
	(incf marginal (belief-of node-case)))
      (ideal-debug-msg "~% Node: ~A P(e): ~A" n marginal)
      (for-all-cond-cases (node-case n)
	(setf (belief-of node-case)(/ (belief-of node-case) marginal)))))
  (values belnet))

;-------  Propagation ----------------------------------------------------------

(defun propagate-evidence (node-case belnet)
  (ideal-debug-msg "~% Propagating evidence: ~A ~% Firing node: "
		   (prob-string-of-cond-case node-case))
  (let ((node (node-in node-case)))
	; Set up dummy node.
    (set-up-dummy-inf-node-for-evidence (first node-case))
	; Update messages of evidence or cutset node once.
    (update-msgs node)
	; For every neighbour ...
    (dolist (neighbour (neighbours node))
      (ideal-debug-msg "~% Activating thru neighbour ~A. Firing node: ~%"
		       (node-name neighbour))
	; Initialize belnet ..
      (dolist (n belnet) (mark-node-as-unvisited n))
	; Mark the evidence node as visited ...
      (mark-node-as-visited node)
	; Send out messages thru the neighbour ...
      (propagate-thru-net (list neighbour)))))

(defun retract-evidence (node belnet)
  (propagate-evidence (list (cons node nil)) belnet))
	
(defun propagate-thru-net (queue)
  (loop
    (if (null queue)(return))
    (setq queue (nconc (update-node (pop queue)) queue))))

(defun update-node (n)
  (when (not (or (is-cs-node-p n)(node-has-been-visited-p n)))
    (update-msgs n)
    (mark-node-as-visited n)
    (values (neighbours n))))

(defun update-msgs (n)
  (ideal-debug-msg " ~A" (node-name n))
  (update-overall-lambda n)
  (update-overall-pi n)
  (update-lambda-messages n)
  (update-pi-messages n))

(defun deactivate-node (n)
  (setf (node-activating-node n) nil))


;-------- Extra data structures ---------------------------------------------

(defstruct cond-ds
  ev-node-p
  cs-node-p
  visited-p
  order-number
  parent
  children
  local-evidence
  activated-p)

(defun is-ev-node-p (n)(cond-ds-ev-node-p (node-actual-bel n)))

(defsetf is-ev-node-p (n)(v)
  `(setf (cond-ds-ev-node-p (node-actual-bel ,n)) ,v))

(defun is-cs-node-p (n)(cond-ds-cs-node-p (node-actual-bel n)))

(defsetf is-cs-node-p (n)(v)
  `(setf (cond-ds-cs-node-p (node-actual-bel ,n)) ,v))

(defun node-has-been-visited-p (n)(cond-ds-visited-p (node-actual-bel n)))

(defsetf node-has-been-visited-p (n)(v)
  `(setf (cond-ds-visited-p (node-actual-bel ,n)) ,v))

(defun node-order (n)
  (cond-ds-order-number (node-actual-bel n)))

(defsetf node-order (n)(value)
  `(setf (cond-ds-order-number (node-actual-bel ,n)) ,value))

(defun local-evidence (n)(cond-ds-local-evidence (node-actual-bel n)))

(defsetf local-evidence (n)(v)
  `(setf (cond-ds-local-evidence (node-actual-bel ,n)) ,v))

(defun activated-p (n)
  (cond-ds-activated-p (node-actual-bel n)))

(defsetf activated-p (n)(v)
  `(setf (cond-ds-activated-p (node-actual-bel ,n)) ,v))

(defun set-up-cond-ds (node)
  (setf (node-actual-bel node)
	(make-cond-ds))
  (setf (node-bel node)
	(make-probability-array node))
  (setf (node-lambda-msg node)
	(mapcar #'(lambda (pred)
		    (cons pred (make-vanilla-msg-array pred :initial-element 1)))
		(cons node (node-predecessors node))))
  (setf (node-pi-msg node)
	(mapcar #'(lambda (succ)
		    (cons succ (make-vanilla-msg-array node)))
		(cons node (node-successors node))))
  (values))


(defun mark-node-as-visited (n)
  (setf (node-has-been-visited-p n) t))

(defun mark-node-as-unvisited (n)
  (setf (node-has-been-visited-p n) nil))


(defun node-order-parent (n)(cond-ds-parent (node-actual-bel n)))

(defsetf node-order-parent (n)(v)
  `(setf (cond-ds-parent (node-actual-bel ,n)) ,v))

(defun node-order-children (n)(cond-ds-children (node-actual-bel n)))

(defsetf node-order-children (n)(v)
  `(setf (cond-ds-children (node-actual-bel ,n)) ,v))

;------ Set up --------------------------------------------------------------------

(defun set-up-for-conditioning-1 (belnet)
  (unlink-all-dummy-nodes belnet)
  (set-diagram-initialization belnet :algorithm-type :CONDITIONING)
  (ideal-debug-msg "~% Beginning Set up .... ")
  (let* ((ordered-belnet (order belnet))
	 (cutset (get-cycle-cutset belnet))
	 (evidence (get-evidence-nodes ordered-belnet))
	 (cutset+evidence (union cutset evidence)))
    (ideal-debug-msg "~% cutset   ~A ~% evidence ~A" (node-names cutset)
		     (node-names evidence))
    (dolist (n ordered-belnet)(set-up-cond-ds n))
    (mark-node-order ordered-belnet)
    (dolist (c cutset)(setf (is-cs-node-p c) t))
    (dolist (e evidence)(setf (is-ev-node-p e) t))
    (initialize-all-pi-msgs ordered-belnet)
    (ideal-debug-msg "~% .....  End Set up ")
    (values (sort cutset+evidence #'< :key #'node-order))))

(defun initialize-all-pi-msgs (ordered-belnet)
  (ideal-debug-msg "~% Initializing pi msgs ")
  (dolist (n ordered-belnet)
    (update-overall-pi n)
    (for-all-cond-cases (n-case n)
      (dolist (s (node-successors n))
	(setf (pi-msg-of s n-case) (pi-of n-case))))))


(defun mark-node-order (ordered-belnet)
  (let ((order-number 0))
    (dolist (n ordered-belnet)
      (setf (node-order n)(incf order-number)))))
