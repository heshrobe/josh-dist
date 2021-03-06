;;; -*- Mode: LISP; Syntax: Common-Lisp; Package: Ideal;  Base: 10 -*-

(in-package :ideal)


;;;;********************************************************
;;;;  Copyright (c) 1989, 1992 Rockwell International -- All rights reserved.
;;;;  Rockwell International Science Center Palo Alto Lab
;;;;********************************************************

;;;;;;;;;;;;;;;;;;;;;;;; Sampath ;;;;;;;;;;;;;;;;;;;;

(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(JENSEN-INFER)))

;--------------------------------------------------------

;---- Top level ---

; Use fn create-jensen-join-tree to create a join tree for input to
; jensen-infer.

(defun jensen-infer (join-tree belief-net)
  (when (initialized-diagram belief-net :algorithm-type :JENSEN)
    (revert-potentials join-tree)
    (reset-activations join-tree)
    (ideal-debug-msg "~% Entering evidence -------~%")
    (enter-evidence belief-net join-tree)
    (ideal-debug-msg "~% Beginning Propagation ------ ~%")
    (jensen-propagate join-tree)
    (ideal-debug-msg "~% Setting beliefs.--------- ~%")
    (set-beliefs belief-net join-tree)
    (values belief-net)))

(defun jensen-propagate (join-tree)
  (when (jensen-join-tree-root-univ join-tree)
    (ideal-debug-msg "~% Collecting evidence.-------- ~% Absorbing into:")
    (collect-evidence (jensen-join-tree-root-univ join-tree))
    (ideal-debug-msg "~% Distributing evidence.---------- ~% Absorbing into:")
    (distribute-evidence (jensen-join-tree-root-univ join-tree))))

; These versions are used to check the estimators.
;
;(defun jensen-infer (join-tree belief-net)
;  (LET((A *OPERATION-COUNT*))
;    (set-diagram-initialization belief-net :algorithm-type :JENSEN)
;    (revert-potentials join-tree)
;    (reset-activations join-tree)
;    (ideal-debug-msg "~% Entering evidence -------~%")
;    (enter-evidence belief-net join-tree)
;    (FORMAT T "~% EVIDENCE: ~A" (- (- A (SETQ A *OPERATION-COUNT*))))
;    (ideal-debug-msg "~% Beginning Propagation ------ ~%")
;    (jensen-propagate join-tree)
;    (SETQ A *OPERATION-COUNT*)
;    (ideal-debug-msg "~% Setting beliefs.--------- ~%")
;    (set-beliefs belief-net join-tree)
;    (FORMAT T "~% BELS: ~A" (- (- A (SETQ A *OPERATION-COUNT*))))
;    (values belief-net)))
;
;(defun jensen-propagate (join-tree)
;  (when (jensen-join-tree-root-univ join-tree)
;    (ideal-debug-msg "~% Collecting evidence.-------- ~% Absorbing into:")
;    (LET((A *OPERATION-COUNT*))
;      (collect-evidence (jensen-join-tree-root-univ join-tree))
;      (FORMAT T "~% COLLECTE: ~A" (- (- A (SETQ A *OPERATION-COUNT*))))
;      (ideal-debug-msg "~% Distributing evidence.---------- ~% Absorbing into:")
;      (distribute-evidence (jensen-join-tree-root-univ join-tree))
;      (FORMAT T "~% DISTRIBUTE: ~A" (- (- A (SETQ A *OPERATION-COUNT*)))))))

;---- Entering evidence -----

(defun enter-evidence (belief-net jensen-jt &key (mode :ACTUAL))
  (let ((containing-univ nil))
    (dolist (n (get-evidence-nodes belief-net))
      (setf containing-univ (find-containing-univ n jensen-jt))
      (setf (univ-evidence-univ-p containing-univ) t)
      (when (not (eq mode :SIMULATE))
	(enter-univ-evidence n containing-univ)))
	; Note that any of the evidence-univs can be the arg to the choose root fn.
	; The last containing-univ will do just as well
    (setf (jensen-join-tree-root-univ jensen-jt)
	  (choose-root-univ-for-evidence containing-univ))))

; Note that the jensen-join-tree-univs are ordered by cardinality and so
; this fn finds the smallest univ containing n.

(defun find-containing-univ (n jensen-jt)
  (or (find n (jensen-join-tree-univs jensen-jt) :key #'univ-component-nodes :test #'member)
      (error "Couldnt find node ~A in any univ of jensen join tree ~A" n jensen-jt)))

(defun enter-univ-evidence (n univ)
  (ideal-debug-msg "~%Entering ~A's evidence into Univ ~A" n univ)
  (for-all-cond-cases (univ-case (univ-component-nodes univ))
    (if (not (matches-evidence n univ-case))
	(setf (univ-potential-of univ univ-case) 0))))

(defun matches-evidence (n univ-case)
  (eq (node-state n)(cdr (find n univ-case :key #'car))))

;---- Collect and distribute evidence -------

; Is smart:  Updates only where necessary

(defun collect-evidence (univ &optional (activating-sepset nil))
  (let ((changed-sepsets nil))
    (dolist (s (remove activating-sepset (univ-sepset-neighbours univ)))
      (collect-evidence (sepsets-other-univ s univ) s)
      (if (sepset-changed-p s)
	  (push s changed-sepsets)))
    (absorb-from-neighbours univ changed-sepsets)
    (when (and (or changed-sepsets (univ-evidence-univ-p univ)) activating-sepset)
      (setf (sepset-changed-p activating-sepset) t))))

; Is Dumb: Updates everything. Used when setting up the join tree

(defun complete-collect-evidence (univ &optional (activating-sepset nil))
  (let ((other-sepsets (remove activating-sepset (univ-sepset-neighbours univ))))
    (when other-sepsets
      (dolist (s other-sepsets)
	(complete-collect-evidence (sepsets-other-univ s univ) s))
      (absorb-from-neighbours univ other-sepsets))))

(defun distribute-evidence (univ &optional (activating-sepset nil))
  (when (not (null activating-sepset))
    (absorb-from-neighbours univ (list activating-sepset)))
  (dolist (s (remove activating-sepset (univ-sepset-neighbours univ)))
    (distribute-evidence (sepsets-other-univ s univ) s)))


;---- Absorption operation ------

; Absorbs from the sepsets in the argument <sepsets>

(defun absorb-from-neighbours (univ sepsets)
  (when sepsets
    (ideal-debug-msg "~% ~A" univ)
    (dolist (s sepsets)(update-sepset s univ))
    (for-all-cond-cases (univ-case (univ-component-nodes univ))
      (setf (univ-potential-of univ univ-case)
	    (* (univ-potential-of univ univ-case)
	       (product-over (s sepsets)(sepset-transmission-potential-of s univ-case)))))))

(defun update-sepset (s univ)
  (let* ((other-univ (sepsets-other-univ s univ)) 
	 (other-univ/sepset (set-difference (univ-component-nodes other-univ)
					    (sepset-component-nodes s)))
	 new-potential)
    (for-all-cond-cases (s-case (sepset-component-nodes s))
      (setf new-potential
	    (marginalize-univ-potential other-univ other-univ/sepset s-case))
      (setf (sepset-transmission-potential-of s s-case)
	    (cond
	      ((zerop new-potential) 0)
	      (t (/ new-potential (sepset-potential-of s s-case)))))
      (setf (sepset-potential-of s s-case) new-potential))))

(defun marginalize-univ-potential (univ nodes-to-marginalize-over rest-nodes-case)
  (let ((marginal 0))
    (for-all-cond-cases (marg-case nodes-to-marginalize-over)
      (incf marginal
	    (univ-potential-of univ (combine-cond-cases marg-case rest-nodes-case))))
    (values marginal)))


; --- Belief Marginalization

; Note that the jensen-join-tree-univs are sorted in increasing order of
; univ cardinality and the fn set-n-beliefs is passed this list.

(defun set-beliefs (belief-net join-tree)
  (dolist (node belief-net)
    (setf (node-bel node)(make-probability-array node))
    (set-n-beliefs node (jensen-join-tree-univs join-tree))))

(defun set-n-beliefs (node sorted-univ-list)
  (let* ((smallest-univ
	   (find node sorted-univ-list :key #'univ-component-nodes :test #'member))
	 (other-nodes
	   (remove node (univ-component-nodes smallest-univ)))
	 (marginal-belief
	   0))
    (ideal-debug-msg "~%Node ~A  from univ ~A" node smallest-univ)
    (for-all-cond-cases (node-case node)
      (incf marginal-belief
	    (setf (belief-of node-case)
		  (marginalize-univ-potential smallest-univ other-nodes node-case))))
    (when (zerop marginal-belief)
      (error "The marginal belief of ~A is zero. ~
              The evidence declared is  therefore impossible" node))
    (for-all-cond-cases (node-case node)
      (setf (belief-of node-case)
	    (/ (belief-of node-case) marginal-belief)))))

;---- Choosing appropriate root univ

; To minimize complexity of collect evidence it is best to choose a
; root-node which is not a leaf node in the evidence subtree (i.e an
; evidence node see below) AND has maximum cardinality. If no such
; candidate exists then the subtree consists solely of evidence univs.
; Then any old evidence univ can be used as the root univ. If there is
; no evidence input arg to the fn is nil and nil is returned.

(defun choose-root-univ-for-evidence (containing-univ)
  (cond
    ((null containing-univ) nil)
    (t (let* ((sub-tree (mark-and-get-evidence-sub-tree containing-univ))
	      (non-leaf-univs (remove-if #'univ-ev-subtree-leaf-p sub-tree)))
	 (or (and (not (null non-leaf-univs))
		  (find-max non-leaf-univs :key #'univ-cardinality))
	     (first sub-tree))))))

; MARK-AND-GET-EVIDENCE-SUB-TREE returns a list of univs contained in
; the smallest subtree of the join-tree containing all the evidence
; univs and the argument univ. Therefore, If the argument univ is an
; evidence univ it returns the smallest sub-tree containing all evidence
; univs.  As a side effect all the nodes in the evidence subtree are
; marked and an additional mark is put on the leaf univs in the subtree.
; These marks are made use of by the run time estimator fn for collect
; evidence (i.e by collect-evidence-est)

; Note that the base case (i.e the fn being called on a leaf univ with
; the activator-univ being the parent) is automatically handled by the
; argument to the mapcan being nil when the base case appears.


(defun mark-and-get-evidence-sub-tree (member-univ)
  (setf (univ-ev-subtree-leaf-p member-univ) t)
  (mark-and-get-1 member-univ))

(defun mark-and-get-1 (member-univ &optional activator-univ)
  (let ((rest-sub-tree
	  (mapcan #'(lambda (n-u)(mark-and-get-1 n-u member-univ))
		  (delete activator-univ (univ-neighbours member-univ)))))
    (cond
      (rest-sub-tree
       (setf (univ-ev-subtree-member-p member-univ) t)
       (cons member-univ rest-sub-tree))
      ((univ-evidence-univ-p member-univ)
       (setf (univ-ev-subtree-member-p member-univ) t
	     (univ-ev-subtree-leaf-p member-univ) t)
       (list member-univ))
      (t nil))))

(defun univ-neighbours (u)
  (mapcar #'(lambda (s)(sepsets-other-univ s u)) (univ-sepset-neighbours u)))

; This fn just chooses the non-leaf univ with min cardinality or if
; there is no such univ, any univ. Is used to choose root univ for
; propagation during set up of join tree.

; Note that the univ list in the join tree is ordered in increasing
; order of univ cardinality and so it gives the required result.

(defun choose-root-univ (jensen-join-tree)
  (labels ((leaf-univ-p (u)(null (cdr (univ-sepset-neighbours u)))))
    (or (find-if-not #'leaf-univ-p (jensen-join-tree-univs jensen-join-tree) :from-end t)
	(first (jensen-join-tree-univs jensen-join-tree)))))

