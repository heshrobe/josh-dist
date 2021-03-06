;;; -*- Mode: LISP; Base: 10; Syntax: Common-lisp; Package: joshua-internals -*-

(in-package :ji)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; I'll keep the trivial encapsulations here, but put any with real
;;; code dependencies in the file with the function they encapsulate.

;;; Encapsulate the generic functions for ask, tell, n-t-v-c, justify,  and unjustify

(define-joshua-encapsulation (encaps-ask-internal ask-internal t '(:ask))
    :body-wrapper ((trace-ask predication :truth-value truth-value)
                   (let ((original-rule-depth *rule-depth*)
                         (original-continuation continuation))
                     (flet ((my-continuation (just)
                              (let ((*rule-depth* original-rule-depth))
                                (trace-ask-success predication :truth-value truth-value :justification just))
                              (funcall original-continuation just)))
                       (setf continuation #'my-continuation)
                       (with-another-rule
                         (call-next))))))




(define-joshua-encapsulation (encaps-tell-internal  tell-internal t '(:tell))
  :before-body
  (trace-tell predication :truth-value truth-value :justification justification))

(define-joshua-encapsulation (encaps-untell untell t '(:untell))
  :before-body
  (trace-untell database-predication))

(define-joshua-encapsulation (encaps-notice-truth-value-change notice-truth-value-change t '(:notice-truth-value-change))
  :before-body
  (trace-notice-truth-value-change database-predication
       :truth-value (predication-truth-value database-predication)
       :old-truth-value old-truth-value))

(define-joshua-encapsulation (encaps-act-on-truth-value-change act-on-truth-value-change t '(:act-on-truth-value-change))
  :before-body
  (trace-act-on-truth-value-change database-predication
				    :truth-value (predication-truth-value database-predication)
				    :old-truth-value old-truth-value
				    :old-state old-state))

(define-joshua-encapsulation (encaps-justify justify t '(:justify))
    :before-body
  (trace-justify conclusion
		 :truth-value truth-value
		 :justification (list mnemonic true-support false-support unknown-support))
  )

(define-joshua-encapsulation (encaps-unjustify unjustify t '(:unjustify))
    :arglist (predication &optional justification)
    :before-body
    (trace-unjustify predication :truth-value (predication-truth-value predication)))

;;;; Encapsulation stuff that couldn't come earlier


;;; As these aren't protocol functions we can't really encapsulate the generic.
;;; The logic here is very dependent on the TMS functions they encapsulate.
(define-joshua-encapsulation (encaps-bring-in-with-truth-value ltms::bring-in-with-truth-value t '(:bring-in))
  :arglist (predication new-clause truth-value)
  :before-body
  (when (= (predication-truth-value predication) +unknown+)
     (trace-bring-in predication
                     :truth-value truth-value
                     :old-truth-value (predication-truth-value predication)
                     :justification new-clause
                     )))

(define-joshua-encapsulation (encaps-propagate ltms::propagate t '(:contradiction))
    :arglist (clause &optional cause)
    :before-body
    (when cause
      (when (listp cause) (setf cause (car cause)))
      (when (zerop (ltms::clause-number-of-satisfiable-literals clause))
	(trace-contradiction cause
			     :truth-value (if (= (predication-truth-value cause) +true+) +false+ +true+)
			     :old-truth-value (predication-truth-value cause)
			     :justification clause))))

(define-joshua-encapsulation  (encaps-update-predication-to-reflect-retraction
				ltms::update-predication-to-reflect-retraction t
				'(:retract))
    :arglist (predication previous-truth-value)
  :before-body
  (let ((old-truth-value (predication-truth-value predication)))
       (when (not (= 0 (logand previous-truth-value old-truth-value)))
	 (trace-retract predication
                        :truth-value old-truth-value
			:justification (ltms::predication-supporting-clause predication)))))

;;; This encapsulation is no longer used and is probably a little out of data
;(define-joshua-encapsulation (encaps-rete-network-match-predication
;			       rete-network-match-predication
;			       nil
;			       '(:try-match :succeed-match :fail-match))
;  :before-body
;  `(let ((node (first arglist))
;	 (predication (second arglist)))
;     (cond ((eql (rete-match-node-truth-value node) (predication-truth-value predication))
;	    (incf *match-count*)
;	    (trace-try-match node :match-predication predication
;			     :match-pattern (match-id-pattern
;					      (car (Rete-match-node-match-ids node))) )
;	    (multiple-value-bind (match-env has-logic-variables)
;		(cond ((predication-logic-variable-free-p predication)
;		       (incf *semi-match-count*)
;		       (funcall (Rete-node-semi-unification-code Node) predication))
;		      (t
;			(funcall (Rete-node-code Node) predication)))
;	      (cond (match-env
;		     (trace-succeed-match node
;					  :match-predication predication
;					  :match-pattern
;					  (match-id-pattern
;					    (car (Rete-match-node-match-ids node)))
;					  :environment match-env)
;		     (incf *successful-match-count*)
;		     (let ((state-entry (make-rete-internal-state
;					  :environment match-env
;					  :predications (list predication)
;					  :has-logic-variables (if has-logic-variables 1 0)
;					  :my-nodes (list node))))
;		       (push state-entry (predication-rete-states predication))
;		       (rete-proceed-to-next-node state-entry node)))
;		    (t (trace-fail-match node :match-predication predication
;					 :match-pattern
;					 (match-id-pattern
;					    (car (Rete-match-node-match-ids node))))))))
;	   (t (push node (predication-stimulate-list predication))))))

;;;; Here's the encapsulation for the merging.
;(define-joshua-encapsulation (encaps-Rete-network-merge-environments
;			       Rete-network-merge-environments
;			       nil
;			       '(:try-merge :succeed-merge :fail-merge))
;  :before-body
;  `(destructuring-bind (node side first-state second-state)
;       arglist
;       (cond ((not (zerop (rete-internal-state-inactive second-state)))
;	      ;; the other state is inactive, we shouldn't do the merge now
;	      (when (zerop (rete-internal-state-dead second-state))
;		;; but he hasn't been killed.  Flip the value of side for his
;		;; entry.
;		(push (list node (if (eql side 'left) 'right 'left) first-state)
;		      (rete-internal-state-stimulate-list second-state))))
;	     (t
;	      (let ((left-state first-state) (right-state second-state))
;		(when (eql side 'right) (rotatef left-state right-state))
;		(let ((left-predications (rete-internal-state-predications left-state))
;		      (right-predication (car (rete-internal-state-predications right-state)))
;		      (left-env (rete-internal-state-environment left-state))
;		      (right-env (rete-internal-state-environment right-state)))
;		  (incf *merge-count*)
;		  (trace-try-merge node :merge-left left-state :merge-right right-state)
;		  (multiple-value-bind (merge-env has-logic-variables)
;		      (cond ((and
;			       (zerop (rete-internal-state-has-logic-variables left-state))
;			       (zerop (rete-internal-state-has-logic-variables right-state)))
;			     ;; both environments are variable-free, so
;			     ;; semi-unification will work
;			     (incf *semi-merge-count*)
;			     (funcall (Rete-node-semi-unification-code Node)
;				      left-env right-env))
;			    (t
;			      ;; full unification required (but what if just 1 has variables?)
;			      (funcall (Rete-node-code node) left-env right-env)))
;		    (cond (merge-env
;			 (trace-succeed-merge node :merge-left left-state
;					      :merge-right right-state
;					      :environment merge-env)
;			 ;; merge succeeded
;			 (incf *successful-merge-count*)
;			 (let ((new-state-entry
;				 (make-rete-internal-state
;				   :environment merge-env
;				   :predications (cons right-predication left-predications)
;				   :has-logic-variables (if has-logic-variables 1 0)
;				   :parent-states (list left-state right-state)
;				   :my-nodes (list node))))
;			   (push new-state-entry (rete-internal-state-children left-state))
;			   (push new-state-entry (rete-internal-state-children right-state))
;			   (rete-proceed-to-next-node new-state-entry node)))
;			(t (trace-fail-merge node :merge-left left-state
;					     :merge-right right-state))))))))))



(define-joshua-encapsulation (encaps-run-backward-queue run-backward-queue nil '(:enqueue-backward-rule))
  :before-body
  (loop with key
	   with entry
	   with something-there
	   do
       (multiple-value-setq (entry key something-there) (heap-remove queue))
       (when (and something-there (backward-trigger-p entry))
	 (trace-dequeue-backward-rule (backward-trigger-rule entry)
                                      :predication nil
                                      :truth-value nil
                                      :importance key)
	 (funcall function entry))
       (when (not something-there)(return nil))))


(define-joshua-encapsulation (encaps-enqueue-backward enqueue-backward t '(:enqueue-backward-rule))
  :before-body
  (when (backward-trigger-p entry)
       (trace-enqueue-backward-rule (backward-trigger-rule entry)
				    :predication nil
                                    :truth-value nil
				    :importance (number-from-importance importance))))


(define-joshua-encapsulation (encaps-trigger-backward-rule
                              trigger-backward-rule
                              nil
                              '(:fire-backward-rule :exit-backward-rule :succeed-backward-rule :retry-backward-rule)
                              t)
  :before-body
  (progn
     (incf *backward-fire-count*)
     (when (zerop *rule-depth*) (reset-tracing-state *joshua-debugger*))
     (trace-fire-backward-rule rule :predication predication :truth-value truth-value :importance -1)
     (let ((old-rule-depth *rule-depth*))
       (with-another-rule
         ;; we're now 1 deeper in rules.
         (funcall rule predication truth-value
                  #'(lambda (&rest args)
                      (declare (dynamic-extent args))
                      (let ((*rule-depth* old-rule-depth))
                        (trace-succeed-backward-rule rule :predication predication :truth-value truth-value :importance -1))
                      (apply continuation args)
                      (let ((*rule-depth* old-rule-depth))
                        (trace-retry-backward-rule rule :predication predication :truth-value truth-value :importance -1)))
                  do-questions)))
     (trace-exit-backward-rule rule :predication predication :truth-value truth-value :importance -1)
     ))

(define-joshua-encapsulation (encaps-run-forward-queue run-forward-queue nil '(:dequeue-forward-rule))
  :before-body
  (loop for entry = (heap-remove *forward-priority-queue*)
	 when (heap-empty-p *forward-priority-queue*)
	   do (setq *something-in-fwrd-q* nil)
	 while entry
	 doing (trace-dequeue-forward-rule (rete-terminal-entry-rule-name (cadr entry))
		 :triggers (rete-internal-state-predications (car entry))
		 :env (rete-internal-state-environment (car entry))
		 :importance (number-from-importance (Rete-terminal-entry-importance (cadr entry))))
	       ;; note that the heap-elements iteration path is the wrong thing for this.
	       ;; have to go through run-rule, 'cause the truth-values might have changed.
	 doing (execute-forward-rule (car entry) (cadr entry))))

(define-joshua-encapsulation (encaps-run-forward-rule
			       run-forward-rule
			       nil
			       '(:enqueue-forward-rule))
  :before-body
  (let ((importance (Rete-terminal-entry-importance child-entry)))
       (cond (importance
	      ;; this rule has a importance, so queue it
	      (cond
		((zerop (rete-internal-state-inactive state-entry))
		 ;; state is alive, so queue it now
		 (trace-enqueue-forward-rule (rete-terminal-entry-rule-name child-entry)
					     :triggers (reverse (rete-internal-state-predications state-entry))
					     :env (rete-internal-state-environment state-entry)
					     :importance (number-from-importance importance))
		 ;; mark that there might be something in the forward queue.
		 (setq *something-in-fwrd-q* t)
		 (enqueue-forward-rule state-entry child-entry importance))
		(t (push child-entry (rete-internal-state-stimulate-list state-entry)))))
	     (t (execute-forward-rule state-entry child-entry)))))

(define-joshua-encapsulation (encaps-execute-forward-rule
			       execute-forward-rule
			       nil
			       '(:fire-forward-rule :exit-forward-rule)
			       t)
  :before-body
  (cond
       ((zerop (rete-internal-state-inactive state-entry))
	;; state is alive, do it now.
	;;reset tracing if we're at 0 rule-depth
	(when (zerop *rule-depth*)(reset-tracing-state *joshua-debugger*))
	(trace-fire-forward-rule (rete-terminal-entry-rule-name child-entry)
				 :triggers (reverse (rete-internal-state-predications state-entry))
				 :env (rete-internal-state-environment state-entry)
				 :importance (number-from-importance (Rete-terminal-entry-importance child-entry)))
	(incf *forward-fire-count*)
	(with-another-rule
	  ;; we're now 1 deeper in rules.
	  (loop with rule-name = (rete-terminal-entry-rule-name child-entry)
		for supporter in (rete-internal-state-predications state-entry)
		for truth-value = (predication-truth-value supporter)
		if (= truth-value +true+) collect supporter into true-support
		else if (= truth-value +false+) collect supporter into false-support
		else if (= truth-value +unknown+) collect supporter into unknown-support
		else do (error "Contradictory truth-value of ~S in *support*: ~S" supporter *support*)
		finally (with-stack-list (justification rule-name true-support false-support unknown-support)
			  (funcall rule-name
				   (rete-terminal-entry-function child-entry)
				   (rete-internal-state-environment state-entry)
				   justification))))
	(trace-exit-forward-rule (rete-terminal-entry-rule-name child-entry)
				 :triggers (reverse (rete-internal-state-predications state-entry))
				 :env (rete-internal-state-environment state-entry)
				 :importance (number-from-importance (Rete-terminal-entry-importance child-entry))))
       (t (push child-entry (rete-internal-state-stimulate-list state-entry)))))
