;; COPYRIGHT (c) 2020 by Featuremine Corporation.
;; This software has been provided pursuant to a License Agreement
;; containing restrictions on its use.  This software contains
;; valuable trade secrets and proprietary information of
;; FeatureMine LLC and is protected by law.  It may not be
;; copied or distributed in any form or medium, disclosed to third
;; parties, reverse engineered or used in any manner not provided
;; for in said License Agreement except with the prior written
;; authorization from Featuremine Corporation.

#lang racket
(require racket/provide-syntax)
(require "core.rkt")
(require "utils.rkt")
(require "common-c.rkt")
(provide
  get-c-source-info
  generate-c-source)

;get struct word if struct as string
(define (get-if-struct type)
  (if (or (struct-def? type) (class-def? type) (python-type-def? type)) "struct " ""))

;access to module environment as hash table and find out selected id
(define (id-find mod id)
  (let ([env (module-def-env mod)])
    (let ([ref (hash-ref env (symbol->string id) #f)])
      (if ref ref (hash-ref env (format "~a.~a" (string-join (module-def-ns mod) ".") id) #f)))))
      
;save string data to .h file
(define (save-header data module )
    (begin
    (make-directory*  (get-include-directory-name-full module))
    (display-to-file	data  (get-include-filename-full module) #:exists 'replace)))


;return relative path to directory of module
(define (get-src-directory-name module)
    (apply build-path (append (list "src"  (path-only (get-module-relative-path module))) )))

;return full path to directory of module
(define (get-src-directory-name-full module)
    (build-path (get-destination-folder-name) (get-src-directory-name module) ))

;return .h relative path with filename of module
(define (get-src-filename module)
    (apply build-path (list (get-src-directory-name module)  (path-replace-extension (file-name-from-path (get-module-relative-path module)) ".c"))))

;return .h relative path with filename of module
(define (get-src-filename-full module)
    (build-path (get-destination-folder-name)  (get-src-filename module)))

;save string data to .c file
(define (save-src data module )
    (begin
    (make-directory*  (get-src-directory-name-full module))
    (display-to-file	data  (get-src-filename-full module) #:exists 'replace)))

;get callable c callable directory name
(define (get-c-callable-src-directory-name module)
    (build-path "src"  "_callables"))

(define (get-c-callable-src-directory-name-full module)
  (build-path (get-destination-folder-name) (get-c-callable-src-directory-name module)))

;get callable src file name
(define (get-c-callable-src-filename callable module)
  (apply build-path (list(get-c-callable-src-directory-name module) (format "~a.c"(type-def-name callable)))))

;get callable src full path
(define (get-c-callable-src-filename-full callable module)
  (build-path (get-destination-folder-name) (get-c-callable-src-filename  callable module)))

;save string data to src file
(define (save-callable-src data callable  module )
    (begin
    (make-directory*  (get-c-callable-src-directory-name-full module))
    (display-to-file	data  (get-c-callable-src-filename-full callable module) #:exists 'replace)))

;return guard name as string
(define (get-guard-name module)
  (format "H_~a" (string-upcase  (string-join(append (module-def-ns module) (list (module-def-name module))) "_"))))

;return guard block as string
(define (get-guard module)
  (let ([guard (get-guard-name module)])
    (format "#ifndef ~a\n#define ~a\n" guard guard)))

;return callable guard name as string
(define (get-callable-guard-name module)
  (format "H_~a" (string-upcase  (string-join(append (module-def-ns module) (list "Callable")) "_"))))

;return callable guard block as string
(define (get-callable-guard module)
  (let ([guard (get-callable-guard-name module)])
    (format "#ifndef ~a\n#define ~a\n" guard guard)))

;return includes block for module as string
(define (get-includes module module-map)
  (string-append
  "#include \"stdint.h\"\n" 
  "#include \"stdbool.h\"\n" 
  "#include \"mir/pythongen/common_c.h\"\n" 
  (apply string-append  (map (lambda (ns)( format "#include \"~a\"\n" (get-include-filename (hash-ref module-map ns) )))(module-def-requires module)))))

;return forward declaration block for module as string
(define (get-forward-declarations module)
  (apply 
    string-append
    (map (lambda (memb) 
            (cond
              [(class-def? memb) 
                (format "typedef struct ~a ~a;\n"  (get-c-type-name memb module) (get-c-type-name memb module))]
              [(struct-def? memb)  
                (format "typedef struct ~a ~a;\n"  (get-c-type-name memb module) (get-c-type-name memb module))]
              [(python-type-def? memb)
                  (format "typedef struct ~a ~a;\n"  (type-def-name memb ) (type-def-name memb ))]
              [else ""]))
      (module-def-defs module))))

;get member-def as string
(define (get-member-def memb module) 
  (string-append
  (comment (list (member-def-brief memb)))
  (format "~a~a " (get-if-struct (member-def-type memb)) (get-c-type-name (member-def-type memb) module))
  (if (member-def-ref memb) "* " " ")
  (format "~a;\n"  (member-def-name memb))))

;create members block as string
(define (get-members module )
  (apply 
    string-append
    (map (lambda (memb) 
            (cond
              [(alias-def? memb)  
                (string-append
                  (comment (list (alias-def-brief memb)  (alias-def-doc memb)))
                  (format "typedef ~a~a " (get-if-struct (alias-def-type memb)) (get-c-type-name (alias-def-type memb) module))
                  (if (alias-def-ref memb) "* " "")
                  (format "~a;\n\n" (get-c-type-name memb module)))]
              [(variable-def? memb)  
                (string-append
                  (comment (list (variable-def-brief memb) (variable-def-doc memb)))
                  (format "extern ~a~a" (get-if-struct (variable-def-type memb)) (get-c-type-name (variable-def-type memb) module))
                  (if (variable-def-ref memb) "* " " ")
                  (format "~a;\n\n"  (get-c-type-name-from-string (variable-def-name memb))))]
              [(enum-def? memb)  
               (let ([type-name (get-c-type-name memb module)])
                (string-append
                  (comment (list (enum-def-brief memb) (enum-def-doc memb)))
                  "typedef enum  {\n" 

                  (string-join  
                    (map 
                      (lambda (val)
                        (let([name (format "~a_~a" type-name (enum-value-def-name val))]
                             [value (enum-value-def-value val)])
                          (string-append   
                            (comment (enum-value-def-brief val))
                            (if value (format "~a=~a" name value) name))))
                      (enum-def-members memb))
                    ",\n") 
                  (format "\n} ~a;\n"(get-c-type-name memb module))))]
              [(const-def? memb)  
                (string-append
                  (comment (list (const-def-brief memb) (const-def-doc memb)))
                  (if (default-def? (const-def-type memb))
                    (format "#define ~a ~a\n\n" 
                      (get-c-type-name-from-string (const-def-name memb)) 
                      (const-def-val memb))
                    (format "~a * get_mir_const_~a();\n" (get-c-type-name (const-def-type memb) module) (get-c-type-name-from-string (const-def-name memb)))))]

              [(struct-def? memb)  
                (let ([type-name (get-c-type-name memb module)])
                  (string-append
                    (comment (list (struct-def-brief memb) (struct-def-doc memb)))
                    (format "struct ~a {\n" 
                      (get-c-type-name memb module))
                    (string-join  
                    (map 
                      (lambda (memb)
                        (get-member-def memb module))
                      (struct-def-members memb))
                    "")  
                    "};\n"
                      (comment (format "return type descriptor structure for ~a\n" type-name))
                      (format "mir_type_descr* ~a_get_descr();\n" type-name)
                      (comment (format "alloc memory function for ~a\n" type-name))
                      (format "~a * ~a_new_();\n" type-name type-name)
                    ))]
              [(class-def? memb)  
                (let ([c-type-name (get-c-type-name memb module)])
                  (string-append
                    (comment (list (class-def-brief memb) (class-def-doc memb)))
                    (format "typedef struct ~a_t ~a_t;\n" c-type-name c-type-name)
                    (format "struct ~a_t {\n" c-type-name)
                    (apply string-append  
                      (map 
                        (lambda (memb)
                          (cond 
                            [(member-def? memb)  
                            (get-member-def memb module)]
                            [else ""]
                            ))
                        (class-def-members memb)))  
                    
                      "};\n"
                    ;add constructors/destructors
                    (let ([type-name (get-c-type-name memb module)]
                          [members (class-def-members memb)])
                          (string-append
                            (comment (format "return type descriptor structure for ~a\n" type-name))
                            (format "mir_type_descr* ~a_get_descr();\n" type-name)
                            (comment (format "alloc memory function for ~a\n" type-name))
                            (format "~a * ~a_new_();\n" type-name type-name)
                            (comment (format "return data for ~a\n" type-name))
                            (format "~a_t * ~a_data_(~a* obj);\n" type-name type-name type-name)
                            (comment (format "destructor must be implement manually for ~a\n" type-name))
                            (format "void ~a_destructor(~a *self);\n" type-name type-name)
                            (comment (format "constructor must be implement manually for ~a\n" type-name))
                            (format "void ~a_constructor(" type-name)
                  
                            ( string-join
                              (append (list (format "~a* self" type-name)) 
                                (map 
                                  (lambda (arg)
                                    (format "~a~a ~a" (get-c-type-name (arg-def-type arg) module) (if (arg-def-ref arg)  "*" "") (arg-def-name arg))) 
                                (constructor-def-args (class-def-constructor memb))))
                            ", ")
                            ");\n"
                          ))

                    ;add property setters
                    (apply string-append  
                      (map 
                        (lambda (arg)
                          (cond 
                            [(member-def? arg)  
                              (letrec ([type (member-def-type arg)]
                                    [arg-name (member-def-name arg)]
                                    [arg-type-name (get-c-type-name type module)])
                                (string-append
                                  (comment (format "Set up property ~a of ~a\n" arg-name c-type-name))
                                  (format "void ~a_set_~a_(~a* self, ~a* ~a);\n"  c-type-name arg-name c-type-name arg-type-name arg-name)))]
                            [else ""]))
                        (class-def-members memb))) 

                    ;add methods of class  
                    (apply string-append  
                      (map 
                        (lambda (mthd)
                          (cond 
                            [(method-def? mthd)  
                              (let ([return-type (return-def-type (method-def-return mthd))]
                                    [c-type (get-c-type-name memb module)]
                                    [return-ref (return-def-ref (method-def-return mthd))]
                                    [return-c-type (get-c-type-name (return-def-type (method-def-return mthd)) module)])
                                (string-append
                                  (comment 
                                    (append
                                      (list
                                        (method-def-brief mthd) 
                                        (method-def-doc mthd))
                                      (list(format "@param ~a" (class-def-brief memb)))
                                      (map 
                                        (lambda (inp)
                                          (format "@param ~a" (arg-def-brief inp)))
                                        (method-def-args mthd))
                                      (list (format "@return ~a" (return-def-brief(method-def-return  mthd))))))
                                (if (method-def-return mthd)
                                  ;return value 
                                  (format  "~a~a~a"(get-if-struct return-type) return-c-type  (if return-ref "*" ""))
                                  "void")
                                (format " ~a_~a (struct ~a* self" c-type (method-def-name mthd) c-type)
                                (cond 
                                  [(> (length (method-def-args mthd)) 0)
                                    (string-append
                                      ", "
                                      (string-join  
                                        (map 
                                          (lambda (inp)
                                            (string-append
                                              (format "~a~a " (get-if-struct (arg-def-type inp)) (get-c-type-name (arg-def-type inp) module) )
                                              (if (arg-def-ref inp) "*" "")
                                                (arg-def-name inp)))
                                          (method-def-args mthd))
                                        ","))]
                                  [else ""])
                                ");\n"))]
                            [else ""]))
                        (class-def-members memb)))))]
              [else ""]))
      (module-def-defs module))))
  
;main function it generates c header file representation and save it to disk 
(define (generate-c-header module module-map)
  (let ([body ""]) 
    (save-header 
      (string-append
        ;add header
        (get-copyright-header module)
        "\n"
        ;add include guard
        (get-guard module)
        "\n"
        "#ifdef __cplusplus\n"
        "extern \"C\" {\n"
        "#endif\n"
        ;add include
        (apply string-append 
          (map (lambda (memb)
            (cond 
              [(callable-def? memb)
                (format "#include \"~a\"\n" (get-c-callable-inc-filename memb module ))]
              [else ""])) 
            (module-def-defs module)))
        (get-includes module module-map)
        "\n"
        ;add namespace
        ;(format "namespace ~a {\n" (string-join(append (module-def-ns module) (list (module-def-name module))) "::"))
        ;add declarations
        (get-forward-declarations module)
        "\n\n"
        ;add members
        (get-members module)
        "#ifdef __cplusplus\n"
        "}\n"
        "#endif\n"
        (format "#endif //~a\n" (get-guard-name module))
      )
      module)))

;generate type descriptor block
(define (get-c-type-description-structure type-name orig-type-name orig-type members module [mir-inc-ref "mir_inc_ref"] [mir-dec-ref "mir_dec_ref"])
  (string-append
    (if(equal? type-name orig-type-name)
      (string-append

        (comment (format "make copy inplace for ~a\n" type-name))


        (if (struct-def? orig-type)
          (format "void ~a_copy_inplace_(~a* dest, ~a* src ){\n" type-name type-name type-name)
          (string-append
            (format "void ~a_copy_inplace_(~a* pDest, ~a* pSrc ){\n" type-name type-name type-name)
            (if (>(length  (filter member-def? members))0)
              (string-append 
                (format "~a_t * src = ~a_data_(pSrc);\n" type-name type-name)
                (format "~a_t * dest = ~a_data_(pDest);\n" type-name type-name))
              "")))

        (apply string-append  
          (map 
            (lambda (memb)
              (cond 
                [(member-def? memb)  
                  (letrec ([type (get-origin-alias-type (member-def-type memb))]
                           [name (member-def-name memb)]
                           [type-name (get-c-type-name type module)]
                           [ref? (member-def-ref memb)])
                    (cond 
                      [(default-def? type) 
                            (format "\tdest->~a = src->~a;\n" name name)]
                      [(enum-def? type) 
                            (format "\tdest->~a = src->~a;\n" name name)]
                      [(python-type-def? type) 
                            (format "\tdest->~a = src->~a;\n" name name)]
                      [else
                            (if ref? 
                              (format "\tdest->~a =  ~a_get_descr()->copy_new_(src->~a);\n" name  type-name name)  
                              (format "~a_get_descr()->copy_inplace_(&dest->~a, &src->~a);\n" type-name name name))]))]
                [else ""]))
            members)) 
        "}\n"
      
        (comment (format "make new copy of ~a\n" type-name))
        (format "~a * ~a_copy_new_(~a* obj){\n" type-name type-name type-name)
        (format "\t~a* copy = (~a*) ~a_new_();\n" type-name type-name type-name)
        (format "\t~a_copy_inplace_ (copy, obj);\n" type-name)
        "\treturn copy;\n"
        "}\n"
        (comment (format "return size of ~a\n" type-name))
        (format "size_t ~a_size_()"type-name)
        (if (struct-def? orig-type)
          (string-append
            "{\n"
            (format "\treturn sizeof(~a);\n" type-name)
            "}\n")
          ";\n"))
      "")

    ;type descriptor structure
    (comment (format "type descriptor structure for ~a\n" type-name))
    (format "static mir_type_descr type_descr~a ={\n" type-name)
    (format "\t(void *(*)(void *))~a_copy_new_,\n" orig-type-name)
    (format "\t~a_size_,\n" orig-type-name)
    (format "\t(void (*)(void *, void *))~a_copy_inplace_,\n" orig-type-name)
    (format "\t(void *(*)())~a_new_,\n" orig-type-name)
    (format "\t~a,\n" mir-inc-ref)
    (format "\t~a\n" mir-dec-ref)
    "};\n"
    ;return type descriptor
    (comment (format "return type descriptor structure for ~a\n" type-name))  
    (format "mir_type_descr* ~a_get_descr(){\n" type-name)
    (format "\treturn &type_descr~a;\n" type-name)
    "}\n"))

;main function it generates c src file representation and save it to disk 
(define (generate-c-src module module-map)
  (let ([body ""]) 
    (save-src 
      (string-append
        ;add header
        (get-copyright-header module)
        "\n"
        ;add include
        "#include <stdlib.h>\n"
        "#include <string.h>\n"
        (format "#include \"~a\"\n" (get-include-filename module ))
        "#include \"mir/pythongen/utils.h\"\n" 
        "\n"
        ;add free/init functions
        (apply 
          string-append
          (map (lambda (memb) 
            (cond
              [(class-def? memb)  
                (let ([type-name (get-c-type-name memb module)]
                      [members (class-def-members memb)])
                  (string-append

                    ;add property setters
                    (apply string-append  
                      (map 
                        (lambda (arg)
                          (cond 
                            [(member-def? arg)  
                              (letrec ([type (member-def-type arg)]
                                      [arg-name (member-def-name arg)]
                                      [orig-type(get-origin-alias-type type)]
                                      [arg-ref (member-def-ref arg)]
                                      [ref-symb (if arg-ref "" "*")]
                                      [arg-type-name (get-c-type-name type module)]
                                      [orig-arg-type-name (get-c-type-name orig-type module)])
                                (string-append
                                  (comment (format "Set up property ~a of ~a\n" arg-name type-name))
                                  (format "void ~a_set_~a_(~a* pSelf, ~a* ~a){\n"  type-name arg-name type-name arg-type-name arg-name)
                                  (format "~a_t * self = ~a_data_(pSelf);\n" type-name type-name)
                                  (cond 
                                    [(or(callable-def? orig-type) (class-def? orig-type))
                                      (string-append 
                                        (format "~a_get_descr()->dec_ref_(~aself->~a);\n"orig-arg-type-name (if arg-ref "" "&") arg-name)
                                        (format "self->~a = ~a~a;\n" arg-name ref-symb  arg-name))]
                                    [(python-type-def? orig-type)
                                      (string-append 
                                        (format "mir_inc_ref(~aself->~a);\n" (if arg-ref "" "&") arg-name)
                                        (format "self->~a = ~a~a;\n" arg-name ref-symb  arg-name))]

                                    [else (format "self->~a = ~a~a;\n" arg-name ref-symb  arg-name)])
                                "}\n"))]
                            [else ""]))
                        (class-def-members memb))) 

                    (get-c-type-description-structure type-name type-name memb members module)
                   ))]
              [(struct-def? memb)  
                (let ([type-name (get-c-type-name memb module)]
                      [members (struct-def-members memb)])
                        (string-append
                          (comment (format "memory allocation function for ~a\n" type-name))
                          (format "~a * ~a_new_(){\n" type-name type-name)
                          
                          (format "\t~a* _obj =	malloc(sizeof(~a));\n" type-name type-name)
                          
                          "\treturn _obj;\n"
                          "}\n"
                          (get-c-type-description-structure type-name type-name memb members module "mir_inc_ref_struct" "mir_dec_ref_struct")))]
              [else ""]))
          (module-def-defs module))))
      module)))

;return callables declarations blok as string
(define (get-callables-def module )
  (apply 
    string-append
    (hash-map 
      (module-def-env module) 
      (lambda (key memb)
        (if (callable-def? memb)
          (format "typedef struct ~a ~a;\n" key key)
          "")))))

;return callables defenitions blok as string
(define (get-callables-decl module )
    (apply 
      string-append
      (hash-map 
        (module-def-env module) 
        (lambda (key memb)
          (if (callable-def? memb)
              (get-callable-decl memb module)
            "")))))

;return declaration block for callable
(define (get-callable-decl memb module)
  (let ([type-name (get-c-type-name memb module)])
  (string-append
    (comment "structure which represents callable\n")
    (format "typedef struct ~a_t ~a_t;\n" type-name type-name)
    (format "struct ~a_t {\n"  type-name)
    (if (callable-def-return memb) 
      (string-append (comment "allows to call stored callback wit arguments\n")
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
    "};\n" 
    (comment (format "create new ~a\n" type-name))
    (format "~a * ~a_new_();\n" type-name type-name )
    (comment (format "return data for ~a\n" type-name))
    (format "~a_t * ~a_data_(~a* obj);\n" type-name type-name type-name)
    (comment (format "return type descriptor structure for ~a\n" type-name))
    (format "mir_type_descr* ~a_get_descr();\n" type-name))))

;it generates h headers file representation and save it to disk 
(define (generate-callable module)
  (hash-map (module-def-env module) 
    (lambda(key val)
      (if (callable-def? val) 
        (begin
          (generate-callable-inc-file val module)
          (generate-callable-src-file val module)
        )
        void))))

;return callable include filename
(define (get-guard-callable-inc-name module callable)
  (format "H_~a" (string-upcase  (string-join(list (car(module-def-ns module)) (type-def-name callable)) "_"))))

;return guard section for callable .h file
(define (get-guard-callable-inc-header module callable)
  (let ([guard (get-guard-callable-inc-name module callable)])
    (format "#ifndef ~a\n#define ~a\n" guard guard)))

;save callable file to disk
(define (save-callable-inc-file data callable module)
  (begin
    (make-directory*  (get-c-callable-directory-name-full module))
    (display-to-file	data (get-c-callable-inc-filename-full  callable module) #:exists 'replace)))

(define (add-c-decl memb module)
      (cond
        [(python-type-def? memb)
              (format "typedef struct ~a ~a;\n" (get-c-type-name memb module) (get-c-type-name memb module))]
        [(alias-def? memb)
            (string-append
              (add-c-decl (alias-def-type memb) module)
              (format "typedef ~a ~a;\n" (get-c-type-name (alias-def-type memb) module) (get-c-type-name memb module) ))]
        [(or (class-def? memb) (struct-def? memb) (callable-def? memb))  
          (format "typedef struct ~a ~a;\n"  (get-c-type-name memb module) (get-c-type-name memb module))]
        [else ""]))

;generate .h file for callable
(define (generate-callable-inc-file callable module)
  (begin
    ;generate callable header file
    (save-callable-inc-file
     (string-append
        ; add header
        (get-copyright-header module)
        "\n"
        ;add include guard
        (get-guard-callable-inc-header module callable)
        "#ifdef __cplusplus\n"
        "extern \"C\" {\n"
        "#endif\n"
        "#include \"stdint.h\"\n" 
        "#include \"stdbool.h\"\n" 
        "#include \"mir/pythongen/utils.h\"\n" 
        "#include \"mir/pythongen/common_c.h\"\n" 
        ;add declarations
        (apply string-append
          (hash-map (collect-callable-defs callable (make-hash)) 
            (lambda(key memb)
              (add-c-decl memb module))))
   
        ;add members
        (get-callable-decl callable module)

        "#ifdef __cplusplus\n"
        "}\n"
        "#endif\n"
        ;clouse guard
        (format "#endif //~a\n" (get-guard-callable-inc-name module callable))
      )
      callable module)
  ))

;generate .c file for callable
(define (generate-callable-src-file callable module)
  (let([type-name (get-c-type-name callable module)])
    ;generate callable header file
    (save-callable-src
     (string-append
        ; add header
        (get-copyright-header module)
        "\n"
        ;add include guard
        (format "#include \"~a\"\n" (get-c-callable-inc-filename callable module))


        (comment (format "make copy inplace for ~a\n" type-name))
        (format "void ~a_copy_inplace_(~a* pDest, ~a* pSrc ){\n" type-name type-name type-name)
        (format "~a_t * src = ~a_data_(pSrc);\n" type-name type-name)
        (format "~a_t * dest = ~a_data_(pDest);\n" type-name type-name)
        "dest->func=src->func;\n"
        "dest->closure=src->closure;\n"
        "}\n"
         
        (comment (format "make new copy of ~a\n" type-name))
        (format "~a * ~a_copy_new_(~a* obj){\n" type-name type-name type-name)
        (format "\t~a* copy = (~a*) ~a_new_();\n" type-name type-name type-name)
        (format "\t~a_copy_inplace_ (copy, obj);\n" type-name)
        "\treturn copy;\n"
        "}\n"
        (comment (format "return size of ~a\n" type-name))
        (format "size_t ~a_size_();"type-name)

        (comment (format "return size of ~a\n" type-name))
        (format "size_t ~a_size_();\n" type-name)
        ;type descriptor structure
        (comment (format "type descriptor structure for ~a\n" type-name))
        (format "static mir_type_descr type_descr~a ={\n" type-name)
        (format "\t(void *(*)(void *))~a_copy_new_,\n" type-name)
        (format "\t~a_size_,\n" type-name)
        (format "\t(void (*)(void *, void *))~a_copy_inplace_,\n" type-name)
        (format "\t(void *(*)())~a_new_,\n" type-name)
        "\tmir_inc_ref,\n"
        "\tmir_dec_ref\n"
        "};\n"
        ;return type descriptor
        (comment (format "return type descriptor structure for ~a\n" type-name))  
        (format "mir_type_descr* ~a_get_descr(){\n" type-name)
        (format "\treturn &type_descr~a;\n" type-name)
        "}\n")
      callable module)))

;generate .c file for callable
(define (generate-c-source main-module module-map common?)
  (begin
    (if (not common?)
      (map 
        (lambda (key)
          (let([mod (hash-ref  module-map key)])
              (generate-callable mod)
              (generate-c-header mod module-map)
              (generate-c-src mod module-map)
              void))
      (module-def-requires main-module))
    (void))))

;generate source info without generating source file  
(define (get-c-source-info main-module module-map common?)
    (if (not common?)
      (append 
        (apply append
          (map
            (lambda (key)
              (let([mod (hash-ref module-map key )])
              (list
                (get-include-filename-full mod)
                (get-src-filename-full mod))))
          (module-def-requires main-module)))
        

    (let ([callables (list)])
      (map
        (lambda (key)
          (let([mod (hash-ref module-map key)])
            (map
             (lambda (memb)
                (cond
                  [(callable-def? memb) 
                      (set! callables(append callables (list (get-c-callable-inc-filename-full memb main-module ) (get-c-callable-src-filename-full memb main-module ))))]
                  [else ""]))
                (module-def-defs mod))))
        (module-def-requires main-module))
      callables))
      (list)
      ))
