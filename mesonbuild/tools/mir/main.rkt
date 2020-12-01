;; COPYRIGHT (c) 2020 by Featuremine Corporation.
;; This software has been provided pursuant to a License Agreement
;; containing restrictions on its use.  This software contains
;; valuable trade secrets and proprietary information of
;; Featuremine Corporation and is protected by law.  It may not be
;; copied or distributed in any form or medium, disclosed to third
;; parties, reverse engineered or used in any manner not provided
;; for in said License Agreement except with the prior written
;; authorization from Featuremine Corporation.

#lang racket
(require "c-generator.rkt")
(require "python-generator.rkt")
(require "core.rkt")
(require "utils.rkt")
(require (for-syntax racket/base syntax/parse))
(require racket/runtime-path)


(print-graph #t)

(define (p val)(display val))

(define last-location null);
(define (set-last-location data) (set! last-location data));
;imported modules
(define imported-modules (make-hash))

;last
(define last-processed null)

;prepare-to-import modules
(define prepare-to-import (make-hash))

;list of default types
(define default-types (list 'char 'pointer 'none 'string 'int8 'int16 'int32 'int64 'uint8 'uint16 'uint32 'uint64 'bool 'double))

;hash of operator symbols
(define operator-dict-python '#hash(
  (+ . "add") 
  (- . "substract") 
  (/ . "divide") 
  (* . "multiply") 
  (+= . "inplace_add") 
  (-= . "inplace_substract") 
  (/= . "inplace_divide") 
  (*= . "inplace_multiply") 
  (< . "less") 
  (== . "equal") 
  (&& . "and") 
  (|| . "or")))

(define (get-operator symb)
   (hash-ref operator-dict-python symb #f))

;return formatted string location from syntax object
(define (get-location-string stx)
  (format "~a:~a:~a" (syntax-source stx)(syntax-line stx)(syntax-column stx)))

;default env
(define (default-env)
  (let ([hash (make-hash)])
    (for ([id default-types])
    (hash-set! hash (symbol->string id) (default-def (symbol->string id) #'id)))
    hash))

;create module definition
(define (make-module-def name stx brief doc ns requires)
  (module-def name stx brief doc ns requires (list) (default-env)))

;get syntax data
(define (get-syntax obj)
  (cond 
    [(type-def? obj) (type-def-stx obj)] 
    [(variable-def?  obj) (variable-def-stx obj)] 
    [(const-def?  obj) (const-def-stx obj)] 
    ))

;extend module environment by loaded env
(define (extend-module-env module env)
  ;iterate over all in env
  (let([curr-env (module-def-env module)])
    (hash-map env (lambda (k v)
      (if (not (or (default-def? v) (python-type-def? v)))
        (let ([var (id-find module (string->symbol k))])
          (if (not var)
            ;insert defenition
            (hash-set! curr-env k v)
            (if (or (callable-def? var) (equal? (syntax-source (get-syntax v)) (syntax-source (get-syntax var))))
              void
              (error (format "redefenition of ~a in module ~a" k (module-def-name module) )))))
        void)))))

;check syntax symbol
(define-syntax (get-symbol stx)
  (syntax-parse stx
    [(_ m:id) 
      (begin
        (if 
          (equal? (substring  (symbol->string (syntax-e  #'m)) 0 1 ) "~")
          #'m
          #''m))]
    [(_ m) #'m]))


;make require
(define (make-requires module)
  (begin
  ;import modules id requires > 0
  (if(> (length (module-def-requires module)) 0)
  (map (lambda (path)
  (begin
  ;check if module already imported
  (if (not (hash-has-key? imported-modules path ))
    ;check if module not prepare to import
    (if (not (hash-has-key? prepare-to-import path ))
      (begin
        (hash-set! prepare-to-import path path)
        (dynamic-require (find-relative-path (current-directory) path) #f)
        (extend-module-env module (module-def-env last-processed))
        (hash-set! imported-modules path last-processed)
        (hash-remove! prepare-to-import path))
      (error (format "cycle dependency in module ~a : ~a" (module-def-name module) path ))
    )
    (extend-module-env module (module-def-env (hash-ref imported-modules path)))
  )))
  (module-def-requires module))
  void)))

;bind unbounded member
(define (bind-unbounded-member obj mod)(
  let ([env (module-def-env mod)]
        [ref (member-def-ref obj)]
        [type (member-def-type obj)]
    )(cond
      [(unbound-id? type)(
        if ref (
          if (hash-has-key? env (unbound-id-sym type))
            (set-member-def-type! obj (hash-ref env (unbound-id-sym type)))
            (error (format "~a\nunbound identifier ~a \n" (get-location-string (member-def-stx obj))(unbound-id-sym type))))
          (error (format "~a\nunbound value can't be non referenced ~a \n" (get-location-string (member-def-stx obj)) (unbound-id-sym type)))
        )]
      [else  void])))

;bind unbounded in struct
(define (bind-unbounded-struct obj mod)(
  let ([defs (struct-def-members obj)]
       [env (module-def-env mod)]
    )
    (for ([def defs])
      (cond
        [(member-def? def)(bind-unbounded-member def mod)]
        [(method-def? def)(bind-unbounded-method def (type-def-name obj) mod)]
        [else  (error (format "unprocessable entity ~a \n"  def))]))))

;bind unbounded in class
(define (bind-unbounded-class obj mod)(
  let ([defs (class-def-members obj)]
      [env (module-def-env mod)]
    )
    (for ([def defs])
      (cond
        [(member-def? def)(bind-unbounded-member def mod)]
        [(method-def? def)(bind-unbounded-method def (type-def-name obj) mod)]
        [else  (error (format "unprocessable entity ~a \n"  def))]))))

;bind unbounded alias
(define (bind-unbounded-alias obj mod)(
  let ([env (module-def-env mod)]
        [ref (alias-def-ref obj)]
        [type (alias-def-type obj)]
    )(cond
      [(unbound-id? type)(
        if ref (
          if (hash-has-key? env  (unbound-id-sym type))
            (set-alias-def-type! obj (hash-ref env (unbound-id-sym type)))
            (error (format "~a\nunbounded identifier ~a \n"  (get-location-string  (type-def-stx obj))  (unbound-id-sym type))))
          (error (format "~a\nunbounded value can't be non referenced ~a \n" (get-location-string  (type-def-stx obj))  (unbound-id-sym type)))
        )]
      [else  void])))

;bind unbounded variable
(define (bind-unbounded-variable obj mod)(
  let ([env (module-def-env mod)]
        [ref (variable-def-ref obj)]
        [type (variable-def-type obj)]
    )(cond
      [(unbound-id? type)(
        if ref (
          if (hash-has-key? env (unbound-id-sym type))
            (set-variable-def-type! obj (hash-ref env (unbound-id-sym type)))
            (error (format "a\nunbounded identifier ~a \n" (get-location-string  (variable-def-stx obj))  (unbound-id-sym type))))
          (error (format "a\nunbounded value can't be non referenced ~a \n" (get-location-string  (variable-def-stx obj)) (unbound-id-sym type)))
        )]
      [else  void])))

;bind unbounded const
(define (bind-unbounded-const obj mod)(
  let ([env (module-def-env mod)]
        [ref (const-def-ref obj)]
        [type (const-def-type obj)]
    )(cond
      [(unbound-id? type)(
        if ref (
          if (hash-has-key? env (unbound-id-sym type))
            (set-const-def-type! obj (hash-ref env (unbound-id-sym type)))
            (error (format "~a\nunbounded identifier ~a \n"(get-location-string  (const-def-stx obj)) (unbound-id-sym type))))
          (error (format "~a\nunbounded value can't be non referenced ~a \n"(get-location-string  (const-def-stx obj)) (unbound-id-sym type)))
        )]
      [else  void])))

;check unbounded type
(define (check-unbounded-type type ref env stx)
    (cond
      [(unbound-id? type)
        (let ([sym (unbound-id-sym type)])
          (if ref 
            (if (hash-has-key? env sym)
                #t
                (error (format "~a\nunbound identifier ~a \n"  (get-location-string  stx) sym)))
            (error (format "~a\nunbound value can't be non referenced ~a \n"  (get-location-string  stx)  sym))))]
      [else #f]))

;bind unbounded arg
(define (bind-unbounded-arg obj mod)(
  let ([env (module-def-env obj)]
        [ref (arg-def-ref obj)]
        [type (arg-def-type obj)]
    )(cond
      [(unbound-id? type)(
        if ref (
          if (hash-has-key? env (unbound-id-sym type))
            (set-member-def-type! obj (hash-ref env (unbound-id-sym type)))
            (error (format "unbound identifier ~a \n" (unbound-id-sym type))))
          (error (format "unbound value can't be non referenced ~a \n" (unbound-id-sym type)))
        )]
      [else  void])))

;bind unbounded callable
(define (bind-unbounded-callable obj mod)(
  let ([args (callable-def-args obj)]
      [return (callable-def-return obj)]
      [env (module-def-env mod)]
    )
    (begin
      (for ([arg args])

        (cond [(check-unbounded-type (arg-def-type arg) (arg-def-ref arg) env (arg-def-stx arg))
                      (set-arg-def-type! arg (hash-ref env (unbound-id-sym (arg-def-type arg))))]))
      (cond [(check-unbounded-type (return-def-type return) (return-def-ref return) env (return-def-stx return))
            (set-return-def-type! return (hash-ref env (unbound-id-sym (return-def-type return))))]))))


;bind unbounded method
(define (bind-unbounded-method def name mod)(
  let ([args (method-def-args def)]
      [return (method-def-return def)]
      [env (module-def-env mod)]
    )
    (begin
      (for ([arg args])
        (cond 
          [ (and (unbound-id? (arg-def-type arg)) (equal? (unbound-id-sym (arg-def-type arg)) name))
              (set-arg-def-type! arg (hash-ref env (unbound-id-sym (arg-def-type arg))))]
          [(check-unbounded-type (arg-def-type arg) (arg-def-ref arg) env (arg-def-stx arg))
              (set-arg-def-type! arg (hash-ref env (unbound-id-sym (arg-def-type arg))))]))
      (cond 
        [ (and (unbound-id? (return-def-type return)) (equal? (unbound-id-sym (return-def-type return)) name))
          (set-return-def-type! return (hash-ref env (unbound-id-sym (return-def-type return))))]
        [(check-unbounded-type (return-def-type return) (return-def-ref return) env (return-def-stx return))
          (set-return-def-type! return (hash-ref env (unbound-id-sym (return-def-type return))))]))))

;bind unbounded in module
(define (bind-unbounded-module mod)
(let ([defs (module-def-defs mod)])
  (for ([def defs])
    (cond
      [(struct-def? def)(bind-unbounded-struct def mod)]
      [(alias-def? def)(bind-unbounded-alias def mod)]
      [(variable-def? def)(bind-unbounded-variable def mod)]
      [(const-def? def)(bind-unbounded-const def mod)]
      [(callable-def? def)(bind-unbounded-callable def mod)]
      [(class-def? def)(bind-unbounded-class def mod)]
      [(enum-def? def) void]
      [(python-type-def? def) void]
      [(template-def? def) ""]
      [else  (error (format "unprocessable entity ~a \n" def))]))))


;process module stx and reverse defs
;we should recheck unbounded values
(define (process-module-stx mod)
  ; first we reverse the definition list to be in correct order
  (let ([defs (module-def-defs mod)])
      (set-module-def-defs! mod (reverse defs)))
      (bind-unbounded-module mod)
      (set! last-processed mod)
      )

;generate source files from input parameters and destination
(define (generate-source sources common?) 
  (let 
    ([main-module (module-def "main-module" #f "main-module" "main-module" (list) sources (list) (make-hash)) ])
      (set! last-processed main-module)
      (make-requires main-module)
      (let ([mod   (car (hash-values imported-modules))])
        (set-module-def-ns! main-module (list (car (module-def-ns mod))))  
        (set-module-def-name! main-module (car (module-def-ns mod)))) 
      
      ;generate source files
      (generate-c-source main-module imported-modules common?)
      (generate-python-source main-module imported-modules common?)))
     

;return source files which will be generated
(define (get-source-info sources source-info? mir-info? common?) 
  (let 
    ([main-module (module-def "main-module" #f "main-module" "main-module" (list) sources (list) (make-hash)) ])
      (set! last-processed main-module)
      (make-requires main-module)
      (let ([mod   (car (hash-values imported-modules))])
        (set-module-def-ns! main-module (list (car (module-def-ns mod))))  
        (set-module-def-name! main-module (car (module-def-ns mod)))) 
     
      (string-join 
        (append
          (if source-info?
            (map 
              (lambda (name)
                (format "~a" name))
              (append 
                (get-python-source-info main-module imported-modules common?)
                (get-c-source-info main-module imported-modules common?)))
            (list))
          (if mir-info?
            (let ([start-set (mutable-set)]
                  [ret-list (list)])
              (for ([it sources])   
                (set-add! start-set it))
              (map 
                (lambda (name)
                  (if (not (set-member? start-set name))
                    (set! ret-list (append ret-list (list (format "~a" name))))
                    ""))
                (hash-keys imported-modules))
              ret-list
              )
            (list))
            
            )
        ", ")))

;get full name include namespace
(define (get-full-name mod id)
  (format "~a.~a" (string-join (module-def-ns mod) ".") id))

;access to module environment as hash table and find out selected id
(define (id-find mod id)
  (let ([env (module-def-env mod)])
    (let ([ref (hash-ref env (symbol->string id) #f)])
      (if ref ref (hash-ref env (format "~a.~a" (string-join (module-def-ns mod) ".") id) #f)))))

; callable which adds def to module
(define (def-add! mod def)
    (let ([defs (module-def-defs mod)])
      (set-module-def-defs! mod (cons def defs))))

; get env hash-table / add def to module / add def to env table
(define (id-add! mod id def)
  (let ([env (module-def-env mod)])
    (def-add! mod def)
    (hash-set! env id def)))

; try to find id and return unbound id if not
(define (maybe-unbound-id mod id)
  (let ([found-id (id-find mod id)])
    (if found-id found-id (unbound-id  (get-full-name mod id)))))

(provide def-module
         def-struct
         def-member
         def-alias
         def-variable
         def-const
         def-callable
         def-arg
         def-return
         def-method
         def-operator
         def-constructor
         def-class
         def-template
         def-enum
         def-enum-value
         def-python-type
         generate-source
         get-source-info
         last
         (except-out (all-from-out racket) #%module-begin)
         (rename-out [module-begin #%module-begin]))

;; ============================================================
;; Overall module:

;define rule for module syntax (first should be def-module after that list of member defenitions)
;we process module syntax using module defenition rule
(define-syntax-rule
 (module-begin (def-module name prop ...)
  def ...)
 (#%module-begin
   (process-module-stx (let ([module (def-module name prop ...)])
                       (make-requires module)
                       (list (def module) ...)
                       module))))


(define-syntax-rule (def-rule (name data ...) (body ...)) 
  (define-syntax name
      (lambda (stx)
          (with-handlers 
            ([(lambda (v) #t) 
              (lambda (v) 
                (display(format "~a:~a\n~a" (syntax-source stx) (syntax-line stx) (exn-message v))))])
          (syntax-case stx ()
              [(name data ...)  
                  (with-syntax 
                    ([set-loc 
                      (datum->syntax #'lex 
                          (srcloc 
                            (syntax-source  stx)
                            (syntax-line  stx)
                            (syntax-column stx)
                            (syntax-position  stx)
                            (syntax-span  stx)))])
                  #'(let ([l set-loc]) (body ...)))])))))

;define rule for module defenition:
;make module defenition using make-module-def callable
(define-syntax-rule (def-module name
                     [brief brief-txt]
                     [doc doc-txt]
                     [namespace path ...]
                     [require-api file ...])
  (begin
  (make-module-def (symbol->string 'name)
              #'name
              brief-txt
              doc-txt
              (map (lambda (id) (symbol->string id))
                  (list 'path ...))
              (map (lambda (f) (get-module-absolute-path f))
                (list file ...)))))

;define rule for struct:
;build struct defenition and add it to the module members
;first we check id in module defenition second we add

;member syntax with optional reference
(define-syntax def-struct
  (syntax-rules ()
    [(def-struct id
                 [brief brief-txt]
                 [doc doc-txt] 
                 [repr]
                 member ...)
    (def-struct-full id
                 [brief brief-txt]
                 [doc doc-txt] 
                 #t
                 member ...)]
    [(def-struct id
                 [brief brief-txt]
                 [doc doc-txt] 
                 member ...)
    (def-struct-full id
                 [brief brief-txt]
                 [doc doc-txt] 
                 #f
                 member ...)]))

(define-syntax-rule (def-struct-full id
                     [brief brief-txt]
                     [doc doc-txt]
                     repr
                     member ...)
                    (lambda (mod)
                      (if (id-find mod 'id)
                          (error "duplicate definition of" 'id)
                          (let ([ctx (mutable-set)]
                                [name (get-full-name mod (symbol->string 'id))])
                          (id-add! mod name (struct-def name
                                                       #'id
                                                       brief-txt
                                                       doc-txt
                                                       repr
                                                       (list (member mod ctx) ...)))))))

;member syntax with reference
(define-syntax def-member-full
  (syntax-rules ()

  [(def-member-full id-data [brief brief-txt] [type template-id-data(type-id-data)] ref)
    (lambda (mod ctx) 
      (let ([id  (get-symbol id-data)]
            [template-id  (get-symbol template-id-data)]
            [type-id (get-symbol type-id-data)])
              (if (set-member? ctx id) (error (format "duplicate member name: ~a\n" 'id)) (set-add! ctx id ) )
                    (member-def 
                        (symbol->string id)
                        #'id-data
                        brief-txt
                        (get-template-type-id template-id type-id mod)
                        ref)))]

  [(def-member-full id-data [brief brief-txt] [type (type-id ...)] ref)
    (lambda (mod ctx) 
      (let ([id  (get-symbol id-data)])
              (if (set-member? ctx id) (error (format "duplicate member name: ~a\n" id)) (set-add! ctx id ) )
                (let ([arg-id  ((type-id ...) mod) ])
                    (member-def 
                        (symbol->string id)
                        #'id-data
                        brief-txt
                        (maybe-unbound-id mod arg-id)
                        ref
                        ))))]
                    
  [(def-member-full id-data [brief brief-txt] [type type-id-data] ref )
    (lambda (mod ctx)
     (let ([id  (get-symbol id-data)]
          [type-id (get-symbol type-id-data)])
            (if (set-member? ctx id) (error (format "duplicate member name: ~a\n" id)) (set-add! ctx id ) )
            (member-def 
                          (symbol->string id)
                          #'id-data
                          brief-txt
                          (maybe-unbound-id mod type-id)
                          ref
                          )))]))

;member syntax with optional reference
(define-syntax def-member
  (syntax-rules ()
    [(def-member id ... #:ref)
    (def-member-full id ... #t)]
    [(def-member id ...)
    (def-member-full id ... #f)]))

;alias syntax with reference
(define-syntax def-alias-full
  (syntax-rules ()

    [(def-alias-full id-data [brief brief-txt] [doc doc-txt] [type-data template-id-data(type-id-data)] ref)
      (lambda (mod)
        (let ([id  (get-symbol id-data)]
              [template-id  (get-symbol template-id-data)]
              [type-id (get-symbol type-id-data)])
                (if (id-find mod id)
                    (error "duplicate definition of" id)
                    (let (
                      [name (get-full-name mod (symbol->string id))])
                      (id-add! mod name (alias-def name
                                                  #'id
                                                  brief-txt
                                                  doc-txt
                                                  (get-template-type-id template-id type-id mod)
                                                  ref))))))]

    [(def-alias-full id-data [brief brief-txt] [doc doc-txt] [type (type-id ...)] ref)
      (lambda (mod)
        (let ([id  (get-symbol id-data)])
          (if (id-find mod id)
              (error "duplicate definition of" id)
              (let (
                [name (get-full-name mod (symbol->string id))]
                [arg-id  ((type-id ...) mod) ])
                (id-add! mod name (alias-def name
                                            #'id-data
                                            brief-txt
                                            doc-txt
                                            (maybe-unbound-id mod arg-id)
                                            ref))))))]

   [(def-alias-full id-data [brief brief-txt] [doc doc-txt] [type type-id-data] ref)
      (lambda (mod)
        (let ([id  (get-symbol id-data)]
              [type-id (get-symbol type-id-data)])
          (if (id-find mod id)
              (error "duplicate definition of" id)
      
              (let (
                [name (get-full-name mod (symbol->string id))])
                (id-add! mod name (alias-def name
                                            #'id-data
                                            brief-txt
                                            doc-txt
                                            (maybe-unbound-id mod type-id)
                                            ref))))))]))

;alias syntax with optional reference
(define-syntax def-alias
  (syntax-rules ()
    [(def-alias id ... #:ref)
      (def-alias-full id ... #t)]
    [(def-alias id ...)
      (def-alias-full id ... #f)]))

;variable syntax with reference
(define-syntax-rule
  (def-variable-full id [brief brief-txt] [doc doc-txt] [type type-id] ref)
  (lambda (mod)
  (if (id-find mod 'id)
      (error "duplicate definition of" 'id)
      (let ([name (get-full-name mod (symbol->string 'id))])
        (id-add! mod name (variable-def name
                                    #'id
                                    brief-txt
                                    doc-txt
                                    (maybe-unbound-id mod 'type-id)
                                    ref))))))

;variable syntax with optional reference
(define-syntax def-variable
  (syntax-rules ()
    [(def-variable id ... #:ref)
      (def-variable-full id ... #t)]
    [(def-variable id ...)
      (def-variable-full id ... #f)]))

;const syntax with reference
(define-syntax def-const-full
  (syntax-rules ()
    [(def-const-full id-data [brief brief-txt] [doc doc-txt] [type template-id-data(type-id-data)] [val val-data] ref)
      (lambda (mod)
        (let ([id  (get-symbol id-data)]
                [template-id  (get-symbol template-id-data)]
                [type-id (get-symbol type-id-data)])
          (if (id-find mod id)
              (error "duplicate definition of" id)
              (let (
                [name (get-full-name mod (symbol->string id))])
                (id-add! mod name (const-def name
                                            #'id-data
                                            brief-txt
                                            doc-txt
                                            (get-template-type-id template-id type-id mod)
                                            (format "~a" val-data)
                                            ref))))))]



    [(def-const-full id-data [brief brief-txt] [doc doc-txt] [type (type-id ...)] [val val-data] ref)
      (lambda (mod)
        (let ([id  (get-symbol id-data)])
          (if (id-find mod id)
              (error "duplicate definition of" id)
              (let (
                [name (get-full-name mod (symbol->string id))]
                [arg-id  ((type-id ...) mod) ])
                    (id-add! mod name (const-def name
                                            #'id-data
                                            brief-txt
                                            doc-txt
                                            (maybe-unbound-id mod arg-id)
                                            (format "~a" val-data)
                                            ref))))))]

    [(def-const-full id-data [brief brief-txt] [doc doc-txt] [type type-id-data] [val val-data] ref)
      (lambda (mod)
        (let ([id  (get-symbol id-data)]
                [type-id (get-symbol type-id-data)])
          (if (id-find mod id)
              (error "duplicate definition of" id)
              (let (
                [name (get-full-name mod (symbol->string id))])
                (id-add! mod name (const-def name
                                            #'id-data
                                            brief-txt
                                            doc-txt
                                            (maybe-unbound-id mod type-id)
                                            (format "~a" val-data)
                                            ref))))))]))

;const syntax with optional reference
(define-syntax def-const
  (syntax-rules ()
    [(def-const id ... #:ref)
      (def-const-full id ... #t)]
    [(def-const id ...)
      (def-const-full id ... #f)]))

;return name of callable
(define (get-callable-name  ret args ) 
    (let 
      ([tn (lambda (name)(if (unbound-id? name) (string-replace (unbound-id-sym name) "." "_") (string-replace (type-def-name name) "." "_")  ))  ])
      (string-join     
        (append (list (format "r~a_~a" (if (return-def-ref ret) "l" "") (tn (return-def-type ret))) )
          (map (lambda (arg)
            (format "a~a_~a" (if (arg-def-ref arg) "l" "") (tn (arg-def-type arg))))
            args))           
       "_"))) 

;define rule for callable:
;build callable defenition and add it to the module members
;first we check id in module defenition second we add it to module
(define-syntax def-callable
  (syntax-rules ()
    [(def-callable
      [def-arg in-data [brief message] others ...]...
      [def-return [brief-ret message-ret ] others-ret  ...])
        (lambda (mod)
          (let ([ctx (mutable-set)])
            (let ([args (list ((def-arg in-data [brief message] others  ...)  mod ctx) ...)]
                  [ret ((def-return [brief-ret message-ret ] others-ret ...) mod)])
              (let ([name  (get-callable-name ret args) ])
                    (if (id-find mod (string->symbol name)) 
                        (string->symbol name )
                        (begin
                          (id-add! mod  name (callable-def name
                                                        #'def-callable
                                                        args
                                                        ret))
                            (string->symbol name )))))))]
                   
    [(def-callable
      [def-arg in-data [brief message] others ...]...)
        (lambda (mod)
          (let ([ctx (mutable-set)])
            (let ([args (list ((def-arg in-data [brief message] others ...)  mod ctx) ...)]
                  [ret (return-def
                          #'stx
                          "No return Value"
                          (maybe-unbound-id mod (string->symbol "none"))
                          false)])
              (let ([name  (get-callable-name ret args) ])
                    (if (id-find mod (string->symbol name)) 
                        (string->symbol name )
                        (begin
                          (id-add! mod  name (callable-def name
                                                        #'def-callable
                                                        args
                                                        ret))
                            (string->symbol name )))))))]))
;get template id                           
(define (get-template-type-id template-id type-id mod)
  (let ([template (id-find mod template-id)])
    (if template 
      (letrec ([template-symbol (string->symbol(format "~a~a"  (symbol->string type-id) (car (reverse (string-split (symbol->string template-id) ".")))))]
              [template-callback (template-def-callback template)]
              [template-type (id-find mod template-symbol)])
         (if template-type 
            template-type
            (template-callback mod template-symbol type-id))
      (id-find mod template-symbol))
      (error (format "template type not found: ~a\n" template-id)))))

;define rule for class:
;build template defenition and add it to the module members
(define-syntax-rule (def-template id-data
                    callback)
                    (lambda (mod)
                      (let ([id  (get-symbol id-data)])
                        (if (id-find mod id)
                            (error "duplicate definition of" id)
                            (let ([ctx (mutable-set)]
                              [name (get-full-name mod (symbol->string id))])
                              (id-add! mod name (template-def id
                                                          #'id-data
                                                          callback)))))))


;arg syntax with reference
(define-syntax def-arg-full
  (syntax-rules ()
  [(def-arg-full id-data [brief brief-txt] [type template-id-data(type-id-data)] ref)
    (lambda (mod ctx) 
      (let ([id  (get-symbol id-data)]
            [template-id  (get-symbol template-id-data)]
            [type-id (get-symbol type-id-data)])
              (if (set-member? ctx id) (error (format "duplicate member name: ~a\n" id)) (set-add! ctx id ) )
              (arg-def
                    (symbol->string id)
                    #'id-data
                    brief-txt
                    (get-template-type-id template-id type-id mod)
                    ref)
                  ))]

    [(def-arg-full id-data [brief brief-txt] [type (type-id ...)] ref)
      (lambda (mod ctx)
        (let ([id  (get-symbol id-data)]
              [arg-id  ((type-id ...) mod) ])
              (if (set-member? ctx id) (error (format "duplicate arg name: ~a\n" id)) (set-add! ctx id ) )
              (arg-def
                    (symbol->string id)
                    #'id-data
                    brief-txt
                    (maybe-unbound-id mod arg-id)
                    ref)
                ))]

    [(def-arg-full id-data [brief brief-txt] [type type-id-data] ref)
      (lambda (mod ctx)
        (let ([id  (get-symbol id-data)]
          [type-id (get-symbol type-id-data)])
          (if (set-member? ctx id) (error (format "duplicate arg name: ~a\n" id)) (set-add! ctx id ) )
          (arg-def
              (symbol->string id)
              #'id-data
              brief-txt
              (maybe-unbound-id mod type-id)
              ref)))]))

;arg syntax with optional reference
(define-syntax def-arg
  (syntax-rules ()
    [(def-arg  id ... #:ref)
    (def-arg-full id ... #t)]
    [(def-arg id ...)
    (def-arg-full id ... #f)]))

;return syntax with reference
(define-syntax def-return-full
  (syntax-rules ()
  [(def-return-full [brief brief-txt] [type template-id-data(type-id-data)] ref)
      (lambda (mod)
       (let ([template-id  (get-symbol template-id-data)]
            [type-id (get-symbol type-id-data)])
        (return-def
            #'brief
            brief-txt
            (get-template-type-id template-id type-id mod)
            ref)))]
   
    [(def-return-full [brief brief-txt] [type (type-id ...)] ref)
      (lambda (mod)
       (let ([arg-id  ((type-id ...) mod) ])
        (return-def
            #'brief
            brief-txt
            (maybe-unbound-id mod arg-id)
            ref)
          ))]
    [(def-return-full [brief brief-txt] [type type-id-data] ref)
      (lambda (mod)
        (let ([type-id (get-symbol type-id-data)])
          (return-def
              #'brief
              brief-txt
              (maybe-unbound-id mod type-id)
              ref)))]))

;return syntax with optional reference
(define-syntax def-return
  (syntax-rules ()
    [(def-return  id ... #:ref)
      (def-return-full id ... #t)]
    [(def-return id ...)
      (def-return-full id ... #f)]))

;define rule for constructor:
;build constructor defenition
(define-syntax-rule (def-constructor
                    [def-arg in-data ...]...)
                    (lambda (mod)
                          (constructor-def  #'def-constructor
                          (list ((def-arg in-data ...)  mod (mutable-set)) ...))))

;define rule for class:
;build class defenition and add it to the module members
(define-syntax-rule (def-class id-data
                    [brief brief-txt]
                    [doc doc-txt]
                    [constructor ...]
                    [member ...] ...)
                    (lambda (mod)
                      (let ([id  (get-symbol id-data)])
                        (if (id-find mod id)
                            (error "duplicate definition of" id)
                            (let ([ctx (mutable-set)]
                              [name (get-full-name mod (symbol->string id))])
                              (id-add! mod name (class-def name
                                                          #'id-data
                                                          brief-txt
                                                          doc-txt
                                                          ((constructor ...)  mod)
                                                          (list ((member ...) mod ctx) ...))))))))

;define rule for callable:
;build callable defenition and add it to the module members
;first we check id in module defenition second we add it to module
(define-syntax-rule (def-method id-data
                    [brief brief-txt]
                    [doc doc-txt]
                    [def-arg in-data ...]...
                    [def-return out-data ...])
                    (lambda (mod ctx)
                        (let ([id  (get-symbol id-data)])
                          (if (set-member? ctx id) (error (format "duplicate method name: ~a\n" id)) (set-add! ctx id ) )
                            (method-def (symbol->string id)
                                                        #'id-data
                                                        brief-txt
                                                        doc-txt
                                                        (list ((def-arg in-data ...)  mod (mutable-set)) ...)
                                                        ((def-return out-data ...) mod)))))

;define rule for operator
;build operator defenition and add it to the module members
;first we check id in module defenition second we add it to module
(define-syntax-rule (def-operator id-data
                    [brief brief-txt]
                    [doc doc-txt]
                    [def-arg in-data ...]...
                    [def-return out-data ...])
                    (lambda (mod ctx)
                        (letrec ([orig-symbol (get-symbol id-data)]
                                [op (get-operator orig-symbol)]
                                [id  (if op  (string->symbol(string-append "operator_" op)) (error (format "invalid operator ~a" orig-symbol)))])      
                            (if (set-member? ctx id) (error (format "duplicate method name: ~a\n" id)) (set-add! ctx id))
                              (operator-def (symbol->string id)
                                                          #'id-data
                                                          brief-txt
                                                          doc-txt
                                                          (list ((def-arg in-data ...)  mod (mutable-set)) ...)
                                                          ((def-return out-data ...) mod)
                                                          (symbol->string orig-symbol)))))

;full enum value syntax
(define-syntax def-enum-value-full
  (syntax-rules ()
  [(def-enum-value-full id-data [brief brief-txt] val)
    (lambda (mod ctx) 
      (let ([id  (get-symbol id-data)])
              (if (set-member? ctx id) (error (format "duplicate member name: ~a\n" id)) (set-add! ctx id ) )
              (enum-value-def
                    (symbol->string id)
                    #'id-data
                    brief-txt
                    val)
                  ))]       
            ))

;enum value syntax
(define-syntax def-enum-value
  (syntax-rules ()
    [(def-enum-value  id [brief brief-txt] val)
    (def-enum-value-full id [brief brief-txt]  val)]
    [(def-enum-value id [brief brief-txt] )
    (def-enum-value-full id [brief brief-txt]  #f)]))

;enum syntax with reference
(define-syntax def-enum
  (syntax-rules ()
    [(def-enum id-data [brief brief-txt] [doc doc-txt] member ...)
      (lambda (mod)
        (let ([id  (get-symbol id-data)]
              [ctx (mutable-set)])
                (if (id-find mod id)
                    (error "duplicate definition of" id)
                    (let (
                      [name (get-full-name mod (symbol->string id))])
                      (id-add! mod name (enum-def name
                                                  #'id-data
                                                  brief-txt
                                                  doc-txt
                                                  (list (member mod ctx) ...)
                                                  ))))))]))

;def-python-type syntax
(define-syntax def-python-type
  (syntax-rules ()
    [(def-python-type id-data real-name-data)
      (lambda (mod)
        (let ([id  (get-symbol id-data)]
              [real-name-id (get-symbol real-name-data)])
              (letrec (
                [name  (symbol->string id )])
                  (if (id-find mod id) 
                    id
                    (begin
                      (id-add! mod  name (python-type-def name
                                                    #'id-data
                                                    real-name-id))
                        id)))))]))
                                                  
