;;; -*- Mode: LISP; Syntax: Common-Lisp; Base: 10; Package: COMMON-LISP-USER -*-(in-package :user);;;;********************************************************;;;;  Copyright (c) 1989, 1992 Rockwell International -- All rights reserved.;;;;  Rockwell International Science Center Palo Alto Lab;;;;********************************************************#|File:      ideal-genera-sysdcl.lispDescription:  System file for IDEAL - genera systemsNotes:|#; Package Setup for IDEAL-EDIT(unless (find-package :ideal-edit)  (make-package "IDEAL-EDIT" :use '(:clim-lisp :clim));;  (shadowing-import '(clim:interactive-stream-p clim:truename clim:pathname))  );;; if this package definition is changed, also change the definition in ideal's ;;;   genera sysdcl file (unless (find-package :ideal)  (make-package :ideal :use '(lisp) :nicknames '())  );;;(when (not (find-package "IDEAL-EDIT"));;;  (make-package "IDEAL-EDIT");;;  (cl::in-package "IDEAL-EDIT");;;  (shadowing-import '(clim:truename clim:close clim:input-stream-p clim:pathname;;;                                    clim:stream-element-type clim:streamp;;;                                    clim:output-stream-p));;;  (use-package "CLIM");;;  (shadowing-import '(clos:setf clos:documentation));;;  (use-package "CLOS");;;  (shadowing-import '(conditions:ctypecase conditions:etypecase conditions:check-type;;;                                           conditions:error conditions:assert conditions:break;;;                                           conditions:ccase conditions:ecase conditions:cerror;;;                                           conditions:warn));;;  (use-package "CONDITIONS"))(defsystem ideal-edit    (:default-package "IDEAL-EDIT"     :default-pathname "ideal-edit:code;"     :distribute-binaries t     :patchable t     :initial-status :experimental)  (:module id ideal (:type :system))  (:module interface ("interface"))  (:module nodes ("nodes"))  (:module layer1 ("node-internals" "graph-editor"))  (:module layer2 ("graph-edit" "display" "file-io" "solutions" "node-edit"))  (:module layer3 ("node-tables" "id-commands" ; "noisy-or-nodes"		   ))  (:serial id   interface   nodes   layer1   layer2   layer3))