;;; -*- Mode: LISP; Syntax: Common-Lisp; Package: Ideal;  Base: 10 -*-

(in-package :ideal)



;;;;********************************************************
;;;;  Copyright (c) 1989, 1992 Rockwell International -- All rights reserved.
;;;;  Rockwell International Science Center Palo Alto Lab
;;;;********************************************************


;;;;;;;;;;;;;;;;;;;;;;;; Sampath ;;;;;;;;;;;;;;;;;;;;


(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(NODE-TYPE RELATION-TYPE STATE-LABELS NODE-PREDECESSORS
            NODE-SUCCESSORS NUMBER-OF-STATES PRODUCT-OVER)))

;-----------------------------------------------------------------------

; We need the following capability: When some particular fields of a
; node structure or a discrete-dist structure are changed the changed-p
; field of the associated node must be set to t.  This is achieved by
; calling the actual field in the structure something else and then
; defining a setf for the field-name we really want. This setf sets the
; changed-p flag to t and also sets the actual field of the structure.


;*************** Redefined fields of node structure ****************** 
; All the fields that end with -* have a "wrapped" setf method defined
; for them.   The setf method is not defined directly coz doing it that
; way causes a compiler bug  on TI Exploders.

(defun node-type (node)(node-type-* node))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (proclaim '(inline node-type)))

(defun set-node-type (node value)
  (while-setting-change-flag-of (node)
    (setf (node-type-* node) value)))

(defsetf node-type set-node-type)

;-----------

(defun node-predecessors (node)(node-predecessors-* node))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (proclaim '(inline node-predecessors)))

(defun set-node-predecessors (node value)
  (while-setting-change-flag-of (node)
    (setf (node-predecessors-* node) value)))

(defsetf node-predecessors set-node-predecessors)

;------------

(defun node-successors (node)(node-successors-* node))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (proclaim '(inline node-successors)))

(defun set-node-successors (node value)
  (while-setting-change-flag-of (node)
    (setf (node-successors-* node) value)))

(defsetf node-successors set-node-successors)

; ****************** Redefined field of discrete-dist structure ***********

; Returns relation-type of node (:det, :prob)

(defun relation-type (node)
  (discrete-dist-relation-type-* (node-distribution node)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (proclaim '(inline relation-type)))

(defun set-relation-type (node value)
  (while-setting-change-flag-of (node)
    (setf (discrete-dist-relation-type-* (node-distribution node)) value)))

(defsetf relation-type set-relation-type)

;-------------------
; Returns list of State-Label (structures) of the node

(defun state-labels (node)
  (discrete-dist-state-labels-* (node-distribution node)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (proclaim '(inline state-labels)))

(defun set-state-labels (node list)
  (while-setting-change-flag-of (node)
    (setf (discrete-dist-state-labels-* (node-distribution node)) list)))

(defsetf state-labels set-state-labels)
;-------------------
; Setting and getting number-of-states of a discrete node

(defun number-of-states (node)
  (discrete-dist-number-of-states-* (node-distribution node)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (proclaim '(inline number-of-states)))

(defun set-number-of-states (node number)
  (while-setting-change-flag-of (node)
    (setf (discrete-dist-number-of-states-* (node-distribution node)) number)))

(defsetf number-of-states set-number-of-states)

;-------------------

; Executes body with index-var bound to each element in list and returns
; product of all these executions. Returns 1 if list is nil. This macro
; is here coz it is used in the immediately following file.

; If the product becomes zero at some point the macro returns
; immediately. So the body is not guaranteed to execute for each member
; of the input list. It should therefore not be side effecting.

(defmacro product-over ((index-var list) &body body)
  (let ((list-var (gentemp "list-var")) (ans-var (gentemp "ans-var")))
    `(let ((,list-var ,list)
	   (,ans-var 1)
	   ,index-var)
       (loop
	 (if (or (null ,list-var)(zerop ,ans-var))(return ,ans-var))
	 (setq ,index-var (pop ,list-var))
	 (setq ,ans-var (* ,ans-var ,@body))))))

(defmacro sum-over ((index-var list) &body body)
  (let ((list-var (gentemp "list-var"))(ans-var (gentemp "ans-var")))
    `(let ((,list-var ,list)
	   (,ans-var 0)
	   ,index-var)
       (loop
	 (if (null ,list-var)(return ,ans-var))
	 (setq ,index-var (pop ,list-var))
	 (incf ,ans-var ,@body)))))

; Generalization of product-over, can iterate over multiple variables.
; example of syntax:
; (multiply-over ((a list-a)(b list-b)(c list-c))(fn a b c))

(defmacro multiply-over (vars &body body)
  (let ((vars-and-variables			
	  (mapcar #'(lambda (v)(list (first v)(second v)
				     (gentemp))) vars))
	(product-var (gentemp "product")))
    `(let ((,product-var 1)
	   ,@(mapcan #'(lambda (v1)
			 `(,(first v1) (,(third v1) ,(second v1)))) vars-and-variables))
       (loop
	 (if (zerop ,product-var)(return))
	 ,@(mapcar #'(lambda (v1)
		       `(if (null ,(third v1))(return)
			    (setq ,(first v1) (pop ,(third v1))))) vars-and-variables)
	 (setq ,product-var
	       (* ,product-var ,@body)))
       (values ,product-var))))
