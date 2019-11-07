;;; -*- Mode: LISP; Syntax: Common-Lisp; Package: Ideal;  Base: 10 -*-

(in-package :ideal)



;;;;********************************************************
;;;;  Copyright (c) 1989, 1992 Rockwell International -- All rights reserved.
;;;;  Rockwell International Science Center Palo Alto Lab
;;;;********************************************************


;;;;;;;;;;;;;;;;;;;;;;;; Sampath ;;;;;;;;;;;;;;;;;;;;



(export '(SET-UP-FOR-SIMULATION-INFER
	   SIMULATION-INFER))

;--------------------------------------------------------

(defun set-up-for-simulation-infer (belief-net)
  (let (logically-constrained-node)
    (cond
      ((not (consistent-p (unlink-all-dummy-nodes belief-net)))
       (error "The input diagram is not consistent"))
      ((not (belief-net-p belief-net))
       (error "The input diagram is not a belief net"))
      ((setq logically-constrained-node
	     (find-if-not #'strictly-positive-node-distribution-p belief-net))
       (error "The node ~A has a zero probability in its distribution. SIMULATION-INFER ~
             cannot handle such distributions." logically-constrained-node))
      ( t (prog1 (mapc #'set-up-node-for-simulation-infer belief-net)
		 (set-diagram-initialization belief-net :algorithm-type :SIMULATION))))))

(defun set-up-node-for-simulation-infer (node)
  ; Find the markov blanket of the node
  (setf (markov-blanket node)(find-markov-blanket node))
  ; Make an array for transition probabilities
  (setf (transition-array node)(make-transition-array node))
  ; Make a template for markov-blanket-cases (see fn markov-blanket-case-template)
  (setf (markov-blanket-case-template node)(make-markov-blanket-case-template node))
  ; Make an array to store beliefs
  (setf (node-bel node)(make-probability-array node :initial-element 0))
  ; the random state is set to the evidence, if present, or to some arbritrary state
  (setf (random-state-of node)(or (simulation-evidence-state-of node)
				  (first (state-labels node))))
  ; Initialize the transition probability array
  (initialize-transition-probabilities node))

(defun initialize-transition-probabilities (node)
  (let ((product-node-list (cons node (node-successors node)))(overall-case nil))
    (for-all-cond-cases (markov-case (markov-blanket node))
      (let ((total 0))
	(for-all-cond-cases (node-case node)
	  (setq overall-case (combine-cond-cases node-case markov-case))
	  (incf total 
		(setf (transition-prob-of node-case markov-case)
		      (product-over (n product-node-list)
			(prob-of (list (find n overall-case :key #'car)) overall-case)))))
	(for-all-cond-cases (node-case node)
	  (setf (transition-prob-of node-case markov-case)
		(/ (transition-prob-of node-case markov-case) total))))))
  (values node))


(defun simulation-infer (belief-net &optional (iterations 1000))
  (when (initialized-diagram belief-net :algorithm-type :SIMULATION)
    (dotimes (index iterations)
      (ideal-debug-msg "~% Iteration: ~A" index)
      (simulate-belief-net belief-net))
    (ideal-debug-msg "~%Normalizing node beliefs")
    (simulation-normalize-beliefs belief-net)))

; This function had a depth first order of firing of nodes before. Any
; old order will do actually. Now it just fires the nodes in sequence.

(defun simulate-belief-net (belief-net)
  (ideal-debug-msg "~% Triggering:")
  (mapc #'trigger belief-net))

; Explanation of hack: (the hack is in the fn trigger).

; Due to round-off errors it may happen that the cumulative-prob is
; slightly less than 1 even after all node-cases's are accounted for. If
; random-cumulative-prob happens to be greater than cumulative-prob, in
; such a case, the 'if' statement will not recognize that the last state
; is the one that it should be choosing. If this happens the hack
; remedies the situation.

(defun trigger (node)
  (when (not (simulation-evidence-node-p node))
    (let ((markov-blanket-case (generate-markov-blanket-case node))
	  (random-cumulative-prob (generate-random-probability))
	  (cumulative-prob 0)  trans-prob last-state new-random-state)
      (for-all-cond-cases (node-case node)
	(setq trans-prob (transition-prob-of node-case markov-blanket-case))
	(incf (belief-of node-case) trans-prob)
	(if (and (null new-random-state)
		 (<= random-cumulative-prob (incf cumulative-prob trans-prob)))
	    (setq new-random-state (state-in node-case)))
	(setq last-state (state-in node-case)))
	; This is a hack. See note above
      (setf (random-state-of node)(or new-random-state last-state))))
  (ideal-debug-msg " ~A=~A" (node-name node)(label-name (random-state-of node)))
  (values))






