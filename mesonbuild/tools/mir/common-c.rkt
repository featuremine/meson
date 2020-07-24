#lang racket
(require racket/provide-syntax)
(require "core.rkt")
(require "utils.rkt")
(provide
    get-include-directory-name
    get-include-directory-name-full
    get-include-filename
    get-include-filename-full
    type-dict
    get-c-type-name
    get-c-type-name-from-string
    get-c-callable-directory-name
    get-c-callable-directory-name-full
    get-c-callable-inc-filename
    get-c-callable-inc-filename-full
    collect-callable-defs
    get-origin-alias-type
    get-copyright-header
    )

;'char 'void 'string 'int8 'int16 'int32 'int64 'uint8 'uint16 'uint32 'uint64 'double
(define type-dict '#hash(
    ("char" . "char") 
    ("string" . "char*") 
    ("int8" . "int8_t") 
    ("int16" . "int16_t") 
    ("int32" . "int32_t") 
    ("int64" . "int64_t") 
    ("uint8" . "uint8_t") 
    ("uint16" . "uint16_t") 
    ("uint32" . "uint32_t") 
    ("uint64" . "uint64_t") 
    ("double" . "double") 
    ("bool" . "bool") 
    ("pointer" . "void*") 
    ("none" . "void")))

;return copytifght header block as string
(define (get-copyright-header module)
  (apply string-append (map (lambda (l)( format "~a\n" l)) (list 
  "/******************************************************************************"
  "\t\tCOPYRIGHT (c) 2020 by Featuremine Corporation."
  "\t\tThis software has been provided pursuant to a License Agreement"
  "\t\tcontaining restrictions on its use.  This software contains"
  "\t\tvaluable trade secrets and proprietary information of"
  "\t\tFeatureMine LLC and is protected by law.  It may not be"
  "\t\tcopied or distributed in any form or medium, disclosed to third"
  "\t\tparties, reverse engineered or used in any manner not provided"
  "\t\tfor in said License Agreement except with the prior written"
  "\t\tauthorization Featuremine Corporation."
  "*****************************************************************************/"))))

;return relative path to directory of module
(define (get-include-directory-name module)
    (apply build-path (append (list "include"  (path-only (get-module-relative-path module))) )))

;return full path to directory of module
(define (get-include-directory-name-full module)
    (build-path (get-destination-folder-name) (get-include-directory-name module) ))

;return .h relative path with filename of module
(define (get-include-filename module)
    (apply build-path (list (get-include-directory-name module)  (path-replace-extension (file-name-from-path (get-module-relative-path module)) ".h"))))

;return .h relative path with filename of module
(define (get-include-filename-full module)
    (build-path (get-destination-folder-name)  (get-include-filename module)))


(define (get-c-callable-directory-name module)
    (build-path "include"  "_callables"))

(define (get-c-callable-directory-name-full module)
  (build-path (get-destination-folder-name) (get-c-callable-directory-name module)))

(define (get-c-callable-inc-filename callable module)
  (apply build-path (list(get-c-callable-directory-name module) (format "~a.h"(type-def-name callable)))))

(define (get-c-callable-inc-filename-full callable module)
  (build-path (get-destination-folder-name) (get-c-callable-inc-filename  callable module)))

;return c representation of mir defined name
(define (get-c-type-name-from-string id)
 (string-replace  id "." "_")) 

;return low lewel origin type of alias
(define (get-origin-alias-type type)
  (cond [(alias-def? type)
          (let ([type (alias-def-type type)])
            (if (alias-def? type) (get-origin-alias-type type) type))] 
          [else type]))

;collect all defenitions which used in callable
(define (collect-callable-defs callable m) 
  (let ([proc (lambda (val map) 
          (begin
            (cond
              [(callable-def? val) (collect-callable-defs val map) ]
              [(default-def? val) void ]
              [else  (hash-set! map (type-def-name val) val)])
            map))]
      [args  (callable-def-args callable)])
    (hash-set! m (type-def-name callable) callable)
    (map (lambda (val)
      (proc (arg-def-type val) m))
      args)
    (proc (return-def-type (callable-def-return callable)) m)
    m))

;get c type name
(define (get-c-type-name type mod)
    (begin 
        
        (cond 
            [(default-def? type)
                (hash-ref type-dict (type-def-name type))]
            [(python-type-def? type)
                (type-def-name type)]
            [else  
            (let ([env (module-def-env mod)]
                    [id  (type-def-name type)])
                (let ([ref (hash-ref env id #f)])
                    (if ref 
                        (get-c-type-name-from-string  id ) 
                        (error 
                            (format "id ~a not found" id)))))])))