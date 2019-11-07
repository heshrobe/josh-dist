;;; -*- Mode: LISP; Syntax: Common-Lisp; Package: Ideal;  Base: 10 -*-

(in-package :ideal)



;;;;********************************************************
;;;;  Copyright (c) 1989, 1992 Rockwell International -- All rights reserved.
;;;;  Rockwell International Science Center Palo Alto Lab
;;;;********************************************************


;;;;;;;;;;;;;;;;;;;;;;;; Sampath ;;;;;;;;;;;;;;;;;;;;


(export '( CONTENTS-OF DETERMINISTIC-STATE-OF PROB-OF DISTRIBUTION-REPN
	  CONTENTS-OF-DET-ARRAY-LOCATION CONTENTS-OF-DIST-ARRAY-LOCATION))

      
;********* ACCESS FUNCTIONS *********************************
; Accessing the distribution representation.

; This presently means you can get and set the distribution Array of a
; node by using (distribution-repn node) and (setf (distribution-repn
; node) ..) respectively.

(defun distribution-repn (node)
  (typecase (node-distribution node)
    (discrete-dist (discrete-dist-array (node-distribution node)))
    ( t (error "Non Discrete case enocuntered. No such case implemented"))))

(defsetf distribution-repn (node) (repn)
  `(typecase (node-distribution ,node)
     (discrete-dist (setf (discrete-dist-array (node-distribution ,node)) ,repn))
     (t (error "Non Discrete case enocuntered. No such case implemented"))))

; Access fns for disributions.

; In all the following distribution access functions the cond-case can
; contain redundant, or rather, irrelevant nodes. They are ignored. But
; the cond-case MUST contain the states that each of the predecessors
; nodes of the node of interest.

; Accesses the state of a value or decision node given the cond-case.
; Returns or is used to set the value in case of a value node and to
; access the decision given the state of the informational predecessors
; once the diagram has been solved and the policies are in place

(defun deterministic-state-of (node &optional cond-case)
  (read-node-array (make-dummy-node-case node) cond-case))

(defsetf deterministic-state-of (node cond-case) (quantity)
  `(write-node-array (make-dummy-node-case ,node) ,cond-case ,quantity))


; Accesses the probability P(node = state /cond-case). The (node =
; state) input has to in the format ((node . state)). It has been
; implemented this way coz this is the format generated by
; for-all-cond-cases.

(defun prob-of (node-case  &optional cond-case)
  (read-node-array node-case cond-case))

(defsetf prob-of write-node-array)

; This is exactly the same as prob-of. Aids clarity of code when
; accessing a general array [of a node of any type:  value, chance .. ]

(defun contents-of (node-case &optional cond-case)
  (read-node-array node-case cond-case))

(defsetf contents-of write-node-array)

; The low level array reading and writing

(defun read-node-array (node-case cond-case)
  (read-probability-array (distribution-repn (node-in node-case))
			  cond-case
			  (node-predecessors (node-in node-case))
			  :main-node-case node-case))


(defun write-node-array (node-case cond-case value)
  (while-setting-change-flag-of ((node-in node-case))
    (write-probability-array (distribution-repn (node-in node-case))
			     cond-case
			     (node-predecessors (node-in node-case))
			     value
			     :main-node-case node-case)))


; Direct manipulation of distribution arrays

; Whenever a distribution is updates the old distribution is still reqd
; to generate the new one. This allows direct manipulation of an array
; and is generally used to access an array which is no longer associated
; with a node (typically an old distribution).

; Returns contents of a value-array stored in location associated with
; cond-case.  Nodes reqd is a list of nodes that MUST be present in
; cond-case. Basically this means the node predecessors of the node the
; array came from. This check for presence of the node predecessors is
; automatically done when using deterministic-state-of, prob-of etc.

(defun contents-of-det-array-location (array cond-case reqd-nodes)
  (read-probability-array array cond-case reqd-nodes))

; Same as above but is for a prob dist array. The state (structure) of
; interest is also required as an input

(defun contents-of-dist-array-location (array node-case cond-case reqd-nodes)
  (read-probability-array array cond-case reqd-nodes :main-node-case node-case))









