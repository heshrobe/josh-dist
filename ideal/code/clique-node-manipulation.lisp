;;; -*- Mode: LISP; Syntax: Common-Lisp; Package: Ideal;  Base: 10 -*-

(in-package :ideal)


;;;;********************************************************
;;;;  Copyright (c) 1989, 1992 Rockwell International -- All rights reserved.
;;;;  Rockwell International Science Center Palo Alto Lab
;;;;********************************************************

;;;;;;;;;;;;;;;;;;;;;;;; Sampath ;;;;;;;;;;;;;;;;;;;;


(export '( CLIQUE-PROB-OF
	  CLIQUE-PI-OF
	  CLIQUE-PI-MSG-OF
	  CLIQUE-LAMBDA-OF
	  CLIQUE-LAMBDA-MSG-OF
	  INITIALIZE-FOR-CLUSTERING))

;--------------------------------------------------------

;;********************** Utilities

(defun get-clique-dist-array-key (clique-node clique-node-case pred-node-case)
  (let ((residual-key
	  (get-key-for-conditioning-case clique-node-case
					 (clique-node-residual-nodes clique-node)))
	(seperator-key
	  (get-key-for-conditioning-case clique-node-case
					 (clique-node-seperator-nodes clique-node))))
    (cond
      ((cond-cases-match-on
	 (clique-node-seperator-nodes clique-node) clique-node-case pred-node-case)
       (+ (* (clique-node-number-of-residual-states clique-node) seperator-key)
	  residual-key))
      (t :ZERO-LOCATION))))

(defun make-clique-dist-array (c-node)
  ; The fact that the elements are initialized to zero is important.
  ; See set-up-clique-prob-dists-2
  (make-vanilla-clique-array c-node :initial-element 0))

(defun make-vanilla-clique-array (c-node &key (initial-element 0))
  (make-probability-array (clique-node-component-nodes c-node)
		      :initial-element initial-element))


;************************ Access functions

; Probabilities in the distribution of clique nodes

(defun clique-prob-of (clique-node node-case pred-case)
  (let ((array-key (get-clique-dist-array-key clique-node node-case pred-case)))
    (cond
      ((eq array-key :ZERO-LOCATION) 0)
      ( t (aref (distribution-repn clique-node) array-key)))))

(defsetf clique-prob-of (clique-node node-case pred-case)(value)
  (let ((array-key-var (gentemp "array-key-var")) (clique-node-var (gentemp "clique-node"))
	(node-case-var (gentemp "node-case"))(pred-case-var (gentemp "pred-case")))
    `(let* ((,clique-node-var ,clique-node)(,node-case-var ,node-case)
	    (,pred-case-var ,pred-case)
	    (,array-key-var
	     (get-clique-dist-array-key ,clique-node-var ,node-case-var ,pred-case-var)))
       (cond
	 ((eq ,array-key-var :ZERO-LOCATION)
	  (error "The location clique-prob-of[~A] for[ ~A /~A] is not settable.~
                  When queried for this probability is always returned as 0."
		 ,clique-node-var ,node-case-var ,pred-case-var))
	 (t (setf (aref (distribution-repn ,clique-node-var) ,array-key-var) ,value))))))

; The operations performed in the following access fn are required in all the following
; top-level access functions and therefore it has been coded as a seperate accesss fn.

(defun clique-array-location-of (case node-whose-comps-are-reqd assoc-list assoc-key-node
				 &optional (array nil))
  (read-probability-array
    (or array (locate-array-in-assoc-list assoc-key-node assoc-list))
    case (clique-node-component-nodes node-whose-comps-are-reqd)))

(defsetf clique-array-location-of (case node-whose-comps-are-reqd assoc-list assoc-key-node
					&optional array) (value)
  `(write-probability-array
     (or ,array (locate-array-in-assoc-list ,assoc-key-node ,assoc-list))
     ,case (clique-node-component-nodes  ,node-whose-comps-are-reqd) ,value))



; Clique psi is stored in the node-bel field

(defun clique-psi-of (c-node case)
  (clique-array-location-of case c-node nil nil (clique-node-bel c-node)))

(defsetf clique-psi-of (c-node case)(value)
  (let ((node-var (gentemp "node-var")))
    `(let ((,node-var ,c-node))
       (setf  (clique-array-location-of ,case ,node-var nil nil (clique-node-bel ,node-var))
	      ,value))))

; Clique node overall pies

(defun clique-pi-of (c-node case)
  (clique-array-location-of case c-node (clique-node-pi-msg c-node) c-node ))

(defsetf clique-pi-of (c-node case)(value)
  (let ((node-var (gentemp "node-var")))
    `(let ((,node-var ,c-node))
       (setf
	 (clique-array-location-of ,case ,node-var (clique-node-pi-msg ,node-var) ,node-var)
	     ,value))))

; Clique node pi msgs

(defun clique-pi-msg-of (c-node parent-case)
  (clique-array-location-of parent-case (parent c-node)
			    (clique-node-pi-msg (parent c-node)) c-node))

(defsetf clique-pi-msg-of (c-node parent-case)(value)
  (let ((node-var (gentemp "node-var")))
    `(let ((,node-var ,c-node))
       (setf (clique-array-location-of ,parent-case (parent ,node-var)
				       (clique-node-pi-msg (parent ,node-var)) ,node-var)
	     ,value))))

; Clique node overall lambdas

(defun clique-lambda-of (c-node case)
  (clique-array-location-of case c-node (clique-node-lambda-msg c-node) c-node))

(defsetf clique-lambda-of (c-node case)(value)
  (let ((node-var (gentemp "node-var")))
    `(let ((,node-var ,c-node))
       (setf (clique-array-location-of ,case ,node-var
				       (clique-node-lambda-msg ,node-var) ,node-var)
	     ,value))))

; Clique node lambda msgs

(defun clique-lambda-msg-of (c-node case child-node)
  (clique-array-location-of case c-node (clique-node-lambda-msg child-node) c-node))

(defsetf clique-lambda-msg-of (c-node case child-node)(value)
  (let ((c-node-var (gentemp "c-node")))
    `(let ((,c-node-var ,c-node))
       (setf (clique-array-location-of ,case ,c-node-var
				       (clique-node-lambda-msg ,child-node) ,c-node-var)
	     ,value))))

; The evidence-list so far for a dummy node. This access fn uses the
; component nodes field coz this field is not used anyway in the case of
; a dummy node.

(defun dummy-clique-node-evidence-list (dummy-c-node)
  (cond
    ((not (dummy-clique-node-p dummy-c-node))
     (error "~A is not a dummy clique node" dummy-c-node))
    (t (clique-node-component-nodes dummy-c-node))))

(defsetf dummy-clique-node-evidence-list (dummy-c-node)(value)
  `(cond
     ((not (dummy-clique-node-p ,dummy-c-node))
      (error "~A is not a dummy clique node " ,dummy-c-node))
     ( t (setf (clique-node-component-nodes ,dummy-c-node) ,value))))

;************** HIGHER LEVEL FUNCTIONS

;***** Creating clique node diagrams


(defun make-clique-node-for-clique (clique id-number)
  (let ((c-node (make-clique-node)))
    (setf (clique-node-name c-node)
	  (intern (string-upcase
		    (format nil "~{~A*~}" (mapcar #'node-name clique))))
	  (clique-node-id-number c-node) id-number
	  (clique-node-type c-node) :CHANCE
	  (clique-node-distribution c-node)(make-discrete-dist)
	  (clique-node-component-nodes c-node) clique)
    (setf (relation-type c-node) :PROB)
    (values c-node)))

;****** Setting up clique diagram data structures

(defun set-up-clique-diagram-data-structures (join-tree)
  (mapc #'set-up-clique-node-data-structures join-tree))

(defun set-up-clique-node-data-structures (c-node)
  (let ((component-inf-nodes
	  (clique-node-component-nodes c-node))
	(preds-component-inf-nodes
	  (when (parent c-node)(clique-node-component-nodes (parent c-node)))))
    (setf (clique-node-residual-nodes c-node)
	  (copy-list (set-difference component-inf-nodes preds-component-inf-nodes)))
    (setf (clique-node-number-of-residual-states c-node)
	  (product-over (n (clique-node-residual-nodes c-node))(number-of-states n)))
    (setf (clique-node-seperator-nodes c-node)
	  (copy-list (intersection component-inf-nodes preds-component-inf-nodes)))
    (setf (distribution-repn c-node)
	  (make-clique-dist-array c-node))
    (setf (number-of-states c-node)
	  (product-over (comp-node (clique-node-component-nodes c-node))
	    (number-of-states comp-node)))
    (setf (clique-node-bel c-node)
	  (make-vanilla-clique-array c-node))
    ; The overall lambda msg of c-node and the lambda msg that the parent will
    ; get from c-node (which has the parent's dimensions)
    (setf (clique-node-lambda-msg c-node)
	  (mapcar #'(lambda (c-n)(cons c-n (make-vanilla-clique-array c-n)))
		  (cons c-node (clique-node-predecessors c-node))))
    ; The overall pi msg of c-node and the pi msgs for each of the kids each of
    ; which has c-node's dimensions.
    (setf (clique-node-pi-msg c-node)
	  (mapcar #'(lambda (c-n)(cons c-n (make-vanilla-clique-array c-node)))
		  (cons c-node (clique-node-successors c-node))))))


(defun set-up-clique-prob-dists (c-diagram)
  (when (ordered-p c-diagram :reverse t)
    (set-up-clique-prob-dists-2 c-diagram)
    (ideal-debug-msg "~% Done setting up clique prob dists")
    (values c-diagram)))


; This function ends with -2 coz it is a complete re-coding. The old
; code for this fn (in reap protected file number 49) has the version
; number 1.


; New version 6 Nov 89

(defun set-up-clique-prob-dists-2 (ordered-clique-diagram)
  (dolist (clique-node ordered-clique-diagram)
    (initialize-psi-distribution clique-node))
  (dolist (clique-node ordered-clique-diagram)
    (ideal-debug-msg "~% Setting distribution of ~A" clique-node)
    (for-all-cond-cases (seperator-case (clique-node-seperator-nodes clique-node))
      (let ((marginal-of-psi-over-residuals
	      (marginalize-psi-over-residuals clique-node seperator-case)))
	(propogate-marginal-into-parent-cliques-psi-distribution
	  clique-node seperator-case marginal-of-psi-over-residuals)
	; Noting that the clique-prob-of array is initialized with 0's this
	; zerop check is equivalent to a 0/0 = 0 definition
	(when (not (zerop marginal-of-psi-over-residuals))
	  (for-all-cond-cases (residual-case (clique-node-residual-nodes clique-node))
	    (let ((clique-node-case (combine-cond-cases seperator-case residual-case)))
	      (setf (clique-prob-of clique-node clique-node-case seperator-case)
		    (/ (clique-psi-of clique-node clique-node-case)
		       marginal-of-psi-over-residuals)))))))))


(defun initialize-psi-distribution (clique-node)
  (ideal-debug-msg "~% Initializing psi-fn of ~A" clique-node)
  (let ((psi-function-members (get-psi-function-members clique-node)))
    (for-all-clique-node-cases (clique-node-case clique-node)
      (setf (clique-psi-of clique-node clique-node-case)
	    (product-over (node-case (get-psi-function-members-cases
				       psi-function-members clique-node-case))
	      (prob-of node-case clique-node-case))))))

(defun get-psi-function-members (c-node)
  (remove-if-not #'(lambda (comp-node)(member-of-psi-function comp-node c-node))
		 (clique-node-component-nodes c-node)))
  
(defun member-of-psi-function (comp-node c-node)
  (and (includable-in-psi comp-node c-node)
       (not (includable-in-psi comp-node (parent c-node)))))

(defun includable-in-psi (node c-node)
  (and (not (null c-node))
       (member node (clique-node-component-nodes c-node)); this membership check is redundant.
       (subsetp (node-predecessors node)(clique-node-component-nodes c-node))))

; Returns a list of node cases; each node case is for one of the member nodes.
; The state in the node case is the state found for the member node in clique-node-case.

(defun get-psi-function-members-cases (member-nodes clique-node-case)
  (mapcar #'(lambda (m-node)
	      (list (find m-node clique-node-case :key #'car))) member-nodes))

(defun marginalize-psi-over-residuals (clique-node seperator-case)
  (let ((marginal 0))
    (for-all-cond-cases (residual-case (clique-node-residual-nodes clique-node))
      (incf marginal
	    (clique-psi-of clique-node (combine-cond-cases seperator-case residual-case))))
    (values marginal)))

(defun propogate-marginal-into-parent-cliques-psi-distribution (c-node sep-case marginal)
  (let ((parent (parent c-node)))
    (when parent
      (for-all-cond-cases (rest-case (set-difference
				       (clique-node-component-nodes parent)
				       (clique-node-seperator-nodes c-node)))
	(let ((parent-case (combine-cond-cases sep-case rest-case)))
	  (setf (clique-psi-of parent parent-case)
		(* (clique-psi-of parent parent-case) marginal))))
      (values))))

;***** Initializing clique diagrams

; Initializes the belief-net (data structures etc) and also the clique-diagram.

(defun initialize-clique-diagram (clique-diagram)
  (unlink-all-dummy-clique-nodes clique-diagram)
  (mapc #'initialize-clique-node-beliefs&msgs (order clique-diagram))
  (values clique-diagram))

; Initializes both the clique diagram and the belief net

(defun initialize-for-clustering (belief-net clique-diagram)
  (initialize-belnet-for-clustering-algorithm belief-net)
  (initialize-clique-diagram clique-diagram)
  (set-diagram-initialization belief-net :algorithm-type :CLUSTERING))

(defun initialize-belnet-for-clustering-algorithm (belnet)
  (cond
    ((not (consistent-p (unlink-all-dummy-nodes belnet)))
     (error "The belief net is not consistent"))
    ((not (belief-net-p belnet))
     (error  "The input diagram is not a belief net"))
    (t  (dolist (node belnet)
	  (reset-node-evidence node)
	  (setf  (node-bel node)(make-probability-array node)))
	(values belnet))))

(defun unlink-all-dummy-clique-nodes (clique-diagram)
  (map nil #'unlink-dummy-clique-nodes-attached-to-node clique-diagram))

(defun unlink-dummy-clique-nodes-attached-to-node (node)
  (map nil #'(lambda (pred)
	       (when (dummy-clique-node-p pred)(delete-link node pred)))
       (node-predecessors node))
  (map nil #'(lambda (succ)
	       (when (dummy-clique-node-p succ)(delete-link succ node)))
       (node-successors node)))

(defun initialize-clique-node-beliefs&msgs (c-node)
  (initialize-clique-node-beliefs&pi-msgs c-node)
  (initialize-clique-node-lambda-msgs c-node))


; Sets c-node's initial belief vector, initial over all pi vector and the
; pi msg vectors for all the children

(defun initialize-clique-node-beliefs&pi-msgs (c-node)
  (ideal-debug-msg "~% Initializing beliefs and pi messages of ~A" c-node)
  (for-all-clique-node-cases (case c-node)
    (let ((initial-belief (calculate-initial-belief-of c-node case)))
      (setf (clique-pi-of c-node case) initial-belief)
      (dolist (child (clique-node-successors c-node))
	(setf (clique-pi-msg-of child case) initial-belief)))))

(defun initialize-clique-node-lambda-msgs (c-node)
  (ideal-debug-msg "~% Initializing lambda messages of ~A" c-node)
  (for-all-clique-node-cases (node-case c-node)
    (setf (clique-lambda-of c-node node-case) 1))
  (when (parent c-node)
    (for-all-clique-node-cases (parent-case (parent c-node))
      (setf (clique-lambda-msg-of (parent c-node) parent-case c-node) 1))))


(defun calculate-initial-belief-of (c-node case)
  (let ((parent-node (parent c-node)))
    (cond
      ((null parent-node) (clique-prob-of c-node case nil))
      (t (let ((total 0))
	   (for-all-clique-node-cases (parent-case parent-node)
	     (incf total (* (clique-prob-of c-node case parent-case)
			    (clique-pi-of parent-node parent-case))))
	   (values total))))))









