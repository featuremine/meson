;; COPYRIGHT (c) 2020 by Featuremine Corporation.
;; This software has been provided pursuant to a License Agreement
;; containing restrictions on its use.  This software contains
;; valuable trade secrets and proprietary information of
;; FeatureMine LLC and is protected by law.  It may not be
;; copied or distributed in any form or medium, disclosed to third
;; parties, reverse engineered or used in any manner not provided
;; for in said License Agreement except with the prior written
;; authorization from FeatureMine LLC.

#lang racket
(require racket/provide-syntax)
(provide
  (struct-out unbound-id)
  (struct-out module-def)
  (struct-out type-def)
  (struct-out default-def)
  (struct-out struct-def)
  (struct-out member-def)
  (struct-out alias-def)
  (struct-out variable-def)
  (struct-out const-def)
  (struct-out callable-def)
  (struct-out arg-def)
  (struct-out return-def)
  (struct-out class-def)
  (struct-out constructor-def)
  (struct-out method-def)
  (struct-out operator-def)
  (struct-out namespace-def)
  (struct-out template-def)
  (struct-out enum-def)
  (struct-out enum-value-def)
  get-destination-folder-name
  set-destination-folder-name
  set-base-root-dir
  get-base-root-dir
  get-module-path
  set-include-dirs
  get-include-dirs
  )
  
(struct unbound-id (sym) #:transparent)

(struct module-def ([name #:mutable] stx brief doc [ns #:mutable] requires
                        ; definitions are in reverse order when building
                        [defs #:mutable]
                        [env #:mutable])
#:transparent)

(struct type-def (name stx) #:transparent)
(struct default-def () #:super struct:type-def  #:transparent)
(struct struct-def (brief doc members)  #:super struct:type-def  #:transparent)
(struct member-def (name stx  brief [type #:mutable] ref ) #:transparent)
(struct alias-def (brief doc [type #:mutable] ref) #:super struct:type-def #:transparent)
(struct variable-def (name stx brief doc [type #:mutable] ref) #:transparent)
(struct const-def (name stx brief doc [type #:mutable] val ref) #:transparent)
(struct callable-def (args return)  #:super struct:type-def #:transparent)
(struct arg-def (name stx brief [type #:mutable] ref) #:transparent)
(struct return-def (stx brief [type #:mutable] ref) #:transparent)
(struct class-def (brief doc constructor members)  #:super struct:type-def  #:transparent)
(struct constructor-def (stx args) #:transparent)
(struct method-def (name stx brief doc args return) #:transparent)
(struct operator-def (num-name) #:super struct:method-def  #:transparent)
(struct enum-def (brief doc members) #:super struct:type-def #:transparent)
(struct enum-value-def (name stx brief value) #:transparent)

(struct template-def (callback) #:super struct:type-def  #:transparent)

;represents namespace
(struct namespace-def ([brief #:mutable] [doc #:mutable] namespaces members [child-nss #:mutable]))

(define base-folder-def "api-gen")
(define (set-destination-folder-name name) (set! base-folder-def name))
(define (get-destination-folder-name) base-folder-def)

(define base-root-dir #f)
(define (set-base-root-dir dir) (set! base-root-dir dir))
(define (get-base-root-dir) base-root-dir)

(define include-dirs (list))
(define (set-include-dirs dir) (set! include-dirs dir))
(define (get-include-dirs) include-dirs)

(define (get-module-path module)
      (syntax-source (module-def-stx module)))

