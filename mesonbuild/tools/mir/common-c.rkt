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
    define-callable-struct-three-maybe
    define-callable-struct-three
    get-c-callable-type
    get-callable-decl-c
    get-c-callable-arg
    function-representation 
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

;collect all definitions which used in callable
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

;get struct word if struct as string
(define (get-if-struct type)
  (if (or (struct-def? type) (class-def? type) (python-type-def? type)) "struct " ""))

;generate c function representation
(define (function-representation ret ret-ref args module prefix name [name-addition ""])
  (string-append
      (format "~a~a~a (*~a)("
        (get-if-struct ret) 
        (if (callable-def? ret)  
          (get-c-callable-type ret (format "~a_~a" prefix name ))
          (get-c-type-name ret module))
        (if ret-ref "*" "")
        (format "~a~a" name name-addition))

    
    (string-join  
        (append
          (map 
            (lambda (inp)
              (if (callable-def? (arg-def-type inp))  
                (get-c-callable-arg inp module (arg-def-name inp))
                (string-append
                  (format "~a~a " (get-if-struct (arg-def-type inp)) (get-c-type-name (arg-def-type inp) module))
                  (if (arg-def-ref inp) "*" "")
                  (arg-def-name inp))))
            args)
            (list "void *c"))
          ",")
          
    ");\n"))

(define (define-callable-struct-three-maybe memb module name )
  (if (and (callable-def? memb) (callable-def? (return-def-type (callable-def-return memb))))
    ((return-def-type (callable-def-return memb)) module name )
    ""))

;generate define callable struct
(define (define-callable-struct-three memb module name )
  (letrec(
    [args (callable-def-args memb)]
    [return-type (return-def-type (callable-def-return memb))]
    [ret-name (if (callable-def? return-type) 
                     (get-c-callable-type memb (format "~a_ret" name) )
                     (get-c-type-name (return-def-type (callable-def-return memb)) module))])
  (string-append
    ;define childrens
    (if (callable-def? return-type) 
      (define-callable-struct-three return-type module (format "~a_ret" name))
      "")
    (apply  string-append
      (map 
        (lambda (inp)
          (if (and (callable-def? (arg-def-type inp)) (return-def-type (callable-def-return (arg-def-type inp))))
            (define-callable-struct-three (return-def-type (callable-def-return (arg-def-type inp)))
                                          module 
                                          (format "~a_arg_~a_ret" name  (arg-def-name inp))
                                          )
            ""))
        args))
      ;define current struct
      
      (string-append
        "typedef struct {\n"
          (format "\t~a~a~a (*func)("
            (get-if-struct (return-def-type(callable-def-return memb)))
            ret-name
            (if (return-def-ref (callable-def-return memb)) "*" "")) 

        (string-join  
            (append
              (map 
                (lambda (inp)
                (letrec ([arg-type (arg-def-type inp)]
                          [arg-name (if (callable-def? arg-type) 
                          (get-c-callable-type memb (format "~a_arg_~a" name (arg-def-name inp)))
                          (arg-def-name inp))])
                  (string-append
                    (format "~a~a " (get-if-struct (arg-def-type inp)) (get-c-type-name (arg-def-type inp) module))
                    (if (arg-def-ref inp) "*" "")
                    arg-name
                    )))
                args)
                (list "void *c"))
              ",")
              
        ");\n"
        "\tvoid *closure;\n"
        (format "}~a;\n" (get-c-callable-type memb name ))))))

;generate callable c return type name
(define (get-c-callable-type memb name)
  (letrec(
    [args (callable-def-args memb)]
    [return-type (return-def-type (callable-def-return memb))]
    [ret-name (format "~a_ret" name )])
        ret-name))

;generate c callable argument
(define (get-c-callable-arg memb module name prefix [arg? #t])
  (letrec(
    [args (callable-def-args memb)]
    [return-type (return-def-type (callable-def-return memb))]
    [real-return-type (get-origin-alias-type return-type)])
  (string-append
    (format "CALLABLE_ARG(~a,~a~a~a"
      name
      (get-if-struct return-type) 
      (if (callable-def? return-type)
        (get-c-callable-type return-type (format "~a_~a~a" prefix (if arg? "arg_" "")name))
        (get-c-type-name return-type module))
      (if (return-def-ref (callable-def-return memb)) "*" ""))

    (if(>(length args)0) "," "")
    (string-join  
          (map 
            (lambda (inp)
              (if (callable-def? (arg-def-type inp) )
                (get-c-callable-arg (arg-def-type inp) module name (format "~a_~a" prefix name))
                (string-append
                  (format "~a~a " (get-if-struct (arg-def-type inp)) (get-c-type-name (arg-def-type inp) module))
                  (if (arg-def-ref inp) "*" "")
                  (arg-def-name inp))))
            (callable-def-args memb))
          ",")
          
    ")")))


;generate callable decl
(define (get-callable-decl-c memb module name)
  (string-append
    (comment (format "structure which represents ~a callable\n" name))
    "typedef struct {\n"
    (if (callable-def-return memb) 
      (string-append (comment "allows to call stored callback with arguments\n")
        (format "\t~a~a~a (*func)("
          (get-if-struct (return-def-type(callable-def-return memb))) 
          (get-c-type-name (return-def-type (callable-def-return memb)) module)
          (if (return-def-ref (callable-def-return memb)) "*" ""))) 
      "void")
    
    (string-join  
        (append
          (map 
            (lambda (inp)
              (string-append
                (format "~a~a " (get-if-struct (arg-def-type inp)) (get-c-type-name (arg-def-type inp) module))
                (if (arg-def-ref inp) "*" "")
                (arg-def-name inp)
                ))
            (callable-def-args memb))
            (list "void *c"))
          ",")
          
    ");\n"
    (comment "closure pointer on closure\n")
    "\tvoid *closure;\n"
    (format "}~a;\n" name)))

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