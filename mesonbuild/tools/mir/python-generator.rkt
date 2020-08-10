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
(require "common-c.rkt")
(require "utils.rkt")
(provide
  get-python-source-info
  generate-python-source)

;use only for allias representation
(define type-dict-python '#hash(
  ("char" . "PyUnicode_Type") 
  ("string" . "PyUnicode_Type") 
  ("int8" . "PyLong_Type") 
  ("int16" . "PyLong_Type") 
  ("int32" . "PyLong_Type") 
  ("int64" . "PyLong_Type") 
  ("uint8" . "PyLong_Type") 
  ("uint16" . "PyLong_Type") 
  ("uint32" . "PyLong_Type") 
  ("uint64" . "PyLong_Type") 
  ("double" . "PyFloat_Type") 
  ("bool" . "PyBool_Type") 
  ("pointer" . "PyLong_Type") 
  ("none" . "PyNone")))

;use only for python typing
(define typing-python '#hash(
  ("char" . "str") 
  ("string" . "str") 
  ("int8" . "int") 
  ("int16" . "int") 
  ("int32" . "int") 
  ("int64" . "int") 
  ("uint8" . "int") 
  ("uint16" . "int") 
  ("uint32" . "int") 
  ("uint64" . "int") 
  ("double" . "float") 
  ("bool" . "bool") 
  ("pointer" . "int") 
  ("none" . "None")))

;wrapper function for python typing
(define (get-typing-python  type)
  (cond 
    [(default-def? type) (hash-ref typing-python (type-def-name type))]
    [(python-type-def? type) "typing.Any" ]
    [(callable-def? type) 
      (string-append
        "typing.Callable[["
        (string-join 
          (map 
            (lambda (arg)
              (format "~a" (get-typing-python (arg-def-type arg))))
            (callable-def-args type))
          ", ")
        (format "], ~a]"(get-typing-python (return-def-type (callable-def-return type)))))]
    [else (format "~a"(string-join (cdr (string-split (type-def-name type) ".")) "."))]))

;use as arguments for Pytuple
(define type-args-python '#hash(
  ("char" . "int") 
  ("string" . "char *") 
  ("int8" . "int8_t") 
  ("int16" . "int32_t") 
  ("int32" . "int32_t") 
  ("int64" . "int64_t") 
  ("uint8" . "uint8_t") 
  ("uint16" . "uint32_t") 
  ("uint32" . "uint32_t") 
  ("uint64" . "uint64_t") 
  ("double" . "double") 
  ("bool" . "int") 
  ("pointer" . "void *") 
  ("none" . "void")))

;describe formats for tuples
(define format-dict-python '#hash(
  ("char" . "C") 
  ("string" . "s") 
  ("int8" . "b") 
  ("int16" . "i") 
  ("int32" . "i") 
  ("int64" . "l") 
  ("uint8" . "B") 
  ("uint16" . "I") 
  ("uint32" . "I") 
  ("uint64" . "k") 
  ("double" . "d") 
  ("bool" . "p") 
  ("pointer" . "k") 
  ("none" . "l")))

;wrapper function for formats
(define (get-format type) 
 (cond [(default-def? type)
        (hash-ref format-dict-python (type-def-name type))]
    [(enum-def? type) "B"]
    [else "O"])) 

;use for converting from c to python
(define to-python-dict '#hash(
    ("char" . "PyUnicode_FromStringAndSize(~a,1)") 
    ("string" . "PyUnicode_FromString(~a)") 
    ("int8" . "PyLong_FromLong(~a)") 
    ("int16" . "PyLong_FromLong(~a)") 
    ("int32" . "PyLong_FromLong(~a)") 
    ("int64" . "PyLong_FromLong(~a)") 
    ("uint8" . "PyLong_FromUnsignedLong(~a)") 
    ("uint16" . "PyLong_FromUnsignedLong(~a)") 
    ("uint32" . "PyLong_FromUnsignedLong(~a)") 
    ("uint64" . "PyLong_FromUnsignedLong(~a)") 
    ("double" . "PyFloat_FromDouble(~a)") 
    ("bool" . "PyBool_FromLong(~a)") 
    ("pointer" . "PyLong_FromUnsignedLong((uint64_t)~a)") 
    ("none" . "PyNone ~a")
    ))

;wrapper function for convertations from c to python
(define (to-python-type type)
  (cond [(default-def? type) 
    (hash-ref to-python-dict (type-def-name type))]
     [(alias-def? type) 
      (to-python-type (alias-def-type type))]
    [(python-type-def? type) "~a"] 
    [(enum-def? type) 
      "PyLong_FromLong(~a)"]
    [else
    #f]))

;build return block of code for several places in python wrapper
(define (build-return-section data type module ref [after-section ""] [return-none #t])
  (let ([real-type (get-origin-alias-type type)]
    [python-t (to-python-type type)])
    (if python-t 
      (cond 
        [(equal? (type-def-name type) "char")
          (format "char _pycharret_data = ~a;\n~a return ~a;\n" data after-section (format python-t "&_pycharret_data"))]
        [(equal? (type-def-name type) "none")
          (if return-none
            (format "~a;\n~aPy_RETURN_NONE;\n" data after-section)
            (format "~a;\n~aPy_INCREF(self);\nreturn (PyObject*) self;\n" data after-section))]
        [(equal? (type-def-name type) "string")
          (string-append 
            (format "char * _py_string_ret_= ~a;\n"data)
            (format "PyObject* _pyret_ = ~a;\n"(format python-t "_py_string_ret_"))
            "free(_py_string_ret_);\n"
            after-section         
            "return (PyObject*) _pyret_;\n")]
        [(python-type-def? real-type) 
          (string-append 
            (format "~a* _pyret_ = ~a;\n"(get-python-type-name type module)(format python-t data))
            after-section         
            "return (PyObject*) _pyret_;\n")]
        [else 
          (string-append 
            (format "PyObject* _pyret_ = ~a;\n"(format python-t data))
            after-section         
            "return (PyObject*) _pyret_;\n")])
     
      (let ([python-type (get-python-type-name type module)])
        (string-append
          ( if ref
            (format "~a *_pyret_=(~a *) (PyObject*)_from_data~a(~a);\n" python-type python-type python-type data)
            (string-append
              (format "~a _py_data = ~a;\n" (get-c-type-name type module) data)
              (format "~a *_pyret_=(~a *)  _from_data~a(&_py_data);\n " python-type python-type python-type )))
                
           after-section         
          "return (PyObject*) _pyret_;\n"
        )
  ))))

;using for converting from c to python
(define to-c-dict '#hash(
  ("char" . "*PyUnicode_AsUTF8(~a)") 
  ("string" . "(char*) PyUnicode_AsUTF8(~a)") 
  ("int8" . "PyLong_AsLong(~a)") 
  ("int16" . "PyLong_AsLong(~a)") 
  ("int32" . "PyLong_AsLong(~a)") 
  ("int64" . "PyLong_AsLong(~a)") 
  ("uint8" . "PyLong_AsLong(~a)") 
  ("uint16" . "PyLong_AsLong(~a)") 
  ("uint32" . "PyLong_AsLong(~a)") 
  ("uint64" . "PyLong_AsLong(~a)") 
  ("double" . "PyFloat_AsDouble(~a)") 
  ("bool" . "PyObject_IsTrue(~a)") 
  ("pointer" . "(void*)PyLong_AsLong(~a)") 
  ("none" . "PyNone ~a")
  ))

;wrapper for convertations from c to python
(define (to-c-type type module)
 (cond [(default-def? type)
        (hash-ref to-c-dict (type-def-name type))]
      [(enum-def? type) "PyLong_AsLong(~a)"]
      [(python-type-def? type) (format "((~a*) ~a)" (type-def-name type) "~a")]
      [else (format "_get_data~a(~a)" (get-python-type-name type module) "~a")]))

;using for converting from c to python TypeObject
(define py_type_objects '#hash(
  ("char" . "PyUnicode_Type") 
  ("string" . "PyUnicode_Type") 
  ("int8" . "PyLongType") 
  ("int16" . "PyLongType") 
  ("int32" . "PyLongType") 
  ("int64" . "PyLongType") 
  ("uint8" . "PyLongType") 
  ("uint16" . "PyLongType") 
  ("uint32" . "PyLongType") 
  ("uint64" . "PyLongType") 
  ("double" . "PyLong_Type") 
  ("bool" . "PyBool_Type") 
  ("pointer" . "PyLong_Type") 
  ("none" . "PyNone_Type")
  ))

(define (get-python-type-object type mod)
  (cond
      [(default-def? type)
        (format "&~a" (hash-ref py_type_objects (type-def-name type)))]
      [(alias-def? type)
        (get-python-type-object (alias-def-type type) mod)]
      [(enum-def? type) "&PyLongType"]
      [else  (format "_get~a()" (get-python-type-name type mod))]))

;get struct word if struct as string
(define (get-if-struct type)
  (if (or (struct-def? type) (class-def? type)) "struct " ""))

;get python type name
(define (get-python-type-name type mod)
  (cond
      [(default-def? type)
        (hash-ref type-dict (type-def-name type))]
      [(alias-def? type)
        (get-python-type-name (alias-def-type type) mod)]
      [(python-type-def? type) (type-def-name type)]
      [(enum-def? type) "PyLong_Type"]
      [else  
      (let ([env (module-def-env mod)]
            [id  (type-def-name type)])
          (let ([ref (hash-ref env id #f)])
          (if ref 
              (format "_pys_~a"(string-replace  id "." "_"))
              (error 
                  (format "id ~a not found" id)))))]))
       
;return python type name for argument in pytuple
(define (get-python-arg-type-name type mod)
  (cond 
      [(default-def? type)
        (hash-ref type-args-python (type-def-name type))]
      [(alias-def? type)
        (get-python-arg-type-name (alias-def-type type) mod)]
      [(enum-def? type) "uint8_t"]
      [(python-type-def? type) (type-def-name type)]
      [else   
      (let ([env (module-def-env mod)]
            [id  (type-def-name type)])
          (let ([ref (hash-ref env id #f)])
          (if ref 
              (format "_pys_~a"(string-replace  id "." "_"))
              (error 
                  (format "id ~a not found" id)))))]))

;access to module environment as hash table and find out selected id
(define (id-find mod id)
  (let ([env (module-def-env mod)])
    (let ([ref (hash-ref env (symbol->string id) #f)])
      (if ref ref (hash-ref env (format "~a.~a" (string-join (cdr (module-def-ns mod)) ".") id) #f)))))
      
;return relative path to directory of module
(define (get-python-directory-name module)
   (apply build-path (append (list  "python" (path-only (get-module-relative-path module))) )))

;return relative path to directory with python callables
(define (get-python-callable-directory-name module)
  (build-path  "python" "_callables" ) )

(define (get-python-callable-directory-name-full module)
  (build-path (get-destination-folder-name) (get-python-callable-directory-name module) ))
;return full path to directory of module
(define (get-python-directory-name-full module)
  (build-path (get-destination-folder-name) (get-python-directory-name module) ))

;return .h relative path with python module filename
(define (get-python-filename-header module)
  (apply build-path (list (get-python-directory-name module)  (path-replace-extension (file-name-from-path (get-module-relative-path module)) ".h"))))

(define (get-python-filename-header-full module)
  (build-path (get-destination-folder-name) (get-python-filename-header module) ))

;return .c relative path with python  module filename
(define (get-python-filename-source module)
  (apply build-path (list (get-python-directory-name module)  (path-replace-extension (file-name-from-path (get-module-relative-path module)) ".c"))))

(define (get-python-filename-source-full module)
  (build-path (get-destination-folder-name) (get-python-filename-source module)))
  
;return .c relative path with python module filename
(define (get-python-module-filename module)
  (apply build-path (append (list  "python"  "_py_module.c" ))))

(define (get-python-module-filename-full module)
  (build-path (get-destination-folder-name) (get-python-module-filename module)))

;return .pyi relative path with python type info filename
(define (get-python-type-info-file-full module)
  (build-path (get-destination-folder-name)  "python" (format "~a.pyi" (car (module-def-ns module)))))

;return callable source filename
(define (get-python-callable-src-filename callable module)
  (apply build-path (list(get-python-callable-directory-name module) (format "~a.c"(type-def-name callable)))))

(define (get-python-callable-src-filename-full callable module)
  (build-path (get-destination-folder-name) (get-python-callable-src-filename callable module)))

;return callable inc filename
(define (get-python-callable-inc-filename callable module)
  (apply build-path (list(get-python-callable-directory-name module) (format "~a.h"(type-def-name callable)))))

(define (get-python-callable-inc-filename-full callable module)
  (build-path (get-destination-folder-name) (get-python-callable-inc-filename callable module)))

;save string data to .h file
(define (save-header data module )
  (begin
    (make-directory*  (get-python-directory-name-full module))
    (display-to-file	data  (get-python-filename-header-full  module) #:exists 'replace))
    )

;save string data to .c file
(define (save-source data module )
  (begin
    (make-directory*  (get-python-directory-name-full module))
    (display-to-file	data  (get-python-filename-source-full  module) #:exists 'replace)))

;save string module data to .c file
(define (save-module data module )
  (begin
    (make-directory*  (get-python-directory-name-full module))
    (display-to-file	data  (get-python-module-filename-full  module) #:exists 'replace)))

;save string type-info data to .pyi file
(define (save-type-info-file data module )
  (begin
    (make-directory*  (get-python-directory-name-full module))
    (display-to-file	data  (get-python-type-info-file-full  module) #:exists 'replace)))

;save callable src data to file
(define (save-callable-src-file data callable module)
  (begin
    (make-directory*  (get-python-callable-directory-name-full module))
    (display-to-file	data (get-python-callable-src-filename-full  callable module) #:exists 'replace)))
    

;save callable iclude data to file
(define (save-callable-inc-file data callable module)
  (begin
    (make-directory*  (get-python-callable-directory-name-full module))
    (display-to-file	data (get-python-callable-inc-filename-full  callable module) #:exists 'replace)))

;return guard name as string
(define (get-guard-header-name module)
  (format "H_~a" (string-upcase  (string-join(append (module-def-ns module) (list "python" (module-def-name module))) "_"))))

;return guard block as string
(define (get-guard-header module)
  (let ([guard (get-guard-header-name module)])
    (format "#ifndef ~a\n#define ~a\n" guard guard)))

;return name of callable header guard
(define (get-guard-callable-inc-name module callable)
  (format "H_~a" (string-upcase  (string-join(list (car(module-def-ns module)) "py" (type-def-name callable)) "_"))))

;return callable guard block
(define (get-guard-callable-inc-header module callable)
  (let ([guard (get-guard-callable-inc-name module callable)])
    (format "#ifndef ~a\n#define ~a\n" guard guard)))
    
;return includes block for module as string
(define (get-includes module module-map self)
  (string-append
    "#include <Python.h>\n" 
    "#include \"mir/pythongen/utils.h\"\n" 
    (if self (format "#include \"~a\"\n" (get-include-filename  module))"")
    (apply string-append  (map (lambda (ns)( format "#include \"~a\"\n" (get-python-filename-header (hash-ref module-map ns) )))(module-def-requires module)))))

;return includes block for source as string
(define (get-includes-source module module-map)
  (string-append
    "#include <Python.h>\n" 
    "#include <structmember.h>\n"
    (format "#include \"~a\"\n" (get-python-filename-header module))))

;return forward declaration block for module as string
(define (get-forward-declarations-header module)
  (apply 
    string-append
    (map (lambda (memb) 
            (cond
              [(or (class-def? memb) (struct-def? memb) (callable-def? memb))  
                (format "typedef struct ~a ~a;\n" (get-python-type-name memb module) (get-python-type-name memb module))]
              [else ""]))
      (module-def-defs module))))

;create members block as string
(define (get-members-header module )
  (apply 
    string-append
    (map (lambda (memb) 
            (cond
              [(alias-def? memb)  
                ""]
              [(variable-def? memb)  
                (string-append
                  "")]
              [(const-def? memb) 
                (string-append
                  "")]       

              [(struct-def? memb)  
                (let ([c-type (get-c-type-name memb module)]
                      [py-type (get-python-type-name memb module)])
                  (string-append
                    (comment (list (struct-def-brief memb) (struct-def-doc memb)))
                    (format "struct ~a {\nPyObject_HEAD\nstruct ~a data;\n};\n" 
                      py-type c-type )
                    (format "PyTypeObject * _get_pys_~a();\n" c-type)
                    (format "~a* _get_data~a(~a *);\n" c-type py-type py-type) 
                    (format "PyObject * _from_data_pys_~a(~a *);\n" c-type  c-type) 
                    ))]
               
              [(class-def? memb)  
                (let ([c-type (get-c-type-name memb module)]
                      [py-type (get-python-type-name memb module)])
                (string-append
                  (comment (list (class-def-brief memb) (class-def-doc memb)))
                  (format "struct ~a {\nPyObject_HEAD\nstruct ~a_t data;\n};\n" 
                       py-type c-type )
                    (format "PyTypeObject * _get_pys_~a();\n" c-type)
                    (format "~a* _get_data~a(~a *);\n" c-type py-type py-type) 
                    (format "PyObject * _from_data_pys_~a(~a *);\n" c-type  c-type) 
                    ))]

              [else ""]))
      (module-def-defs module))))

;get member defenition as string using for forward declarations. uses recursion
(define (get-member-def memb module) 
  (string-append
  (comment (list (member-def-brief memb)))
  (format "~a~a" (get-if-struct (member-def-type memb)) (get-c-type-name (member-def-type memb) module))
  (if (member-def-ref memb) "* " " ")
  (format "~a;\n"  (member-def-name memb))))

;return member name for struct
(define (get-struct-field-name struct-name member-name )
  (format "~a_~a" struct-name member-name))

;return member defenition for python representations of structs
(define (get-member-def-python  struct_name memb module)
  (let ([type-name-python (get-python-type-name (member-def-type memb) module)]
        [type-name (get-c-type-name (member-def-type memb) module)]                     
        [name (member-def-name memb)]  
        [brief (member-def-brief memb)]  
        [struct_memb (get-struct-field-name struct_name (member-def-name memb))])
    (string-append
      (format "{\"~a\", (getter)_get~a, (setter)_set~a, \n\t\"~a\",\nNULL},\n" name struct_memb struct_memb brief))))

;return get-sets block with implementations for member of struct
(define (get-member-get-sets-python  struct_name memb module)
  (letrec ([type-name-python (get-python-type-name (member-def-type memb) module)]
        [type-name (get-c-type-name (member-def-type memb) module)]                     
        [name (member-def-name memb)]  
        [type (member-def-type memb)]
        [brief (member-def-brief memb)] 
        [origin-type (get-origin-alias-type type)] 
        [struct_memb (get-struct-field-name struct_name (member-def-name memb))]
        [member-ref? (member-def-ref memb)])

    (string-append
      ;get
      "static PyObject*\n"
      (format "_get~a(~a* self,void*closure){\n" struct_memb struct_name)
      (if member-ref? 
        (format " if(self->data.~a==NULL)return Py_None;\n" name)
        "")
       (cond 
          [(class-def? origin-type)
            (format "Py_XINCREF(self->data.~a);" name )]
          [(callable-def? origin-type)
            (format "Py_XINCREF(self->data.~a.closure);" name )]
          [(python-type-def? origin-type)
            (format "Py_XINCREF(self->data.~a);" name )]
          [else ""])
      (build-return-section
        (format "~aself->data.~a"
          (if (default-def? type)
            ""
              (if member-ref? 
                (format "(~a*)" type-name) 
                "")) 
          name)
        type
        module 
        member-ref?)
      "}\n" 

      ;set
      (string-append
          "static int\n"
          (format "_set~a(~a* self,PyObject* value, void* closure){\n" struct_memb struct_name)
          (format "~a~a val=~a~a;\n" 
            type-name
            (if member-ref?
              "*"
              "")
            (if (or  (default-def? origin-type) (enum-def? origin-type) member-ref?) 
              "" "*")
            (format (to-c-type origin-type module) 
              (cond 
                [(default-def? origin-type) "value" ]  
                [(enum-def? origin-type) "value" ] 
                [else (format "(~a*)value" type-name-python )]
              )))
          "if (PyErr_Occurred()) {\n\treturn -1;\n\t}\n" 

          
            (cond  
              [(class-def? origin-type)
                  (string-append
                    (format "Py_XDECREF(self->data.~a);\n" name ))]
              [(callable-def? origin-type)
                  (string-append
                    (format "Py_XDECREF(self->data.~a.closure);\n" name ))]
              [(python-type-def? origin-type)
                (if member-ref?
                  (string-append
                    (format "Py_XDECREF(self->data.~a);\n" name ))
                  (string-append
                    (format "Py_XDECREF(&self->data.~a);\n" name )))]       
            [else ""])
          (format "self->data.~a = val;\n" name)
          "return 0;\n}\n"))))

;return Python type for py object
(define (type_of_py_object memb module)
  (format "_pyt_~a" (get-c-type-name memb module)))

;return block with method defenition
(define (get-method-def-python  struct_name mthd module)
  (let ([name (method-def-name mthd)])
    (string-append
      (format "{\"~a\", (PyCFunction)_method~a_~a, " name struct_name name )
      (if (>(length (method-def-args mthd)) 0)
        "METH_VARARGS | METH_KEYWORDS,\n"
        "METH_NOARGS,\n")
      (format "\"~a\\n~a\"},\n" (method-def-brief mthd) (method-def-doc mthd)))))

;return block with implementation for python method
(define (get-method-impl-python type-name struct_name mthd module)
  (let ([name (method-def-name mthd)]
        [struct-mthd-name (format "~a_~a" struct_name (method-def-name mthd))]
        [c-mthd-name (format "~a_~a" type-name (method-def-name mthd))]
        [args (method-def-args mthd)]
        [ret-type (return-def-type (method-def-return mthd))]
        [ret-ref (return-def-ref (method-def-return mthd))])
    (string-append
      (if (>(length args) 0)
        ;if has members
        (string-append
          (format "static PyObject* _method~a(~a* self, PyObject *args) {\n" struct-mthd-name struct_name)

          ;add args initialisation
          (args-initialisation-block args module)

          ;parse args
          (format "if (!PyArg_ParseTuple(args, \"~a\", ~a)) {\n"
            ;formats
            (apply string-append 
              (map 
                (lambda (arg)
                  (let ([arg-type (arg-def-type arg)])
                    (get-format arg-type)))
                args))
            ;references
            (string-join 
              (map 
                (lambda (arg)
                  (let ([arg-name (arg-def-name arg)])
                    (format "&_pyarg_~a" arg-name)))
                args)
              ", ")
            )
   
          "\treturn NULL;\n}\n" 

          ;check obj args
          (check-args-block args module "NULL")

          ;return section
          (build-return-section             
            (string-append
              (format "~a((~a*)self, " c-mthd-name type-name)
                (string-join 
                  (map 
                    (lambda (arg)
                      (let ([arg-type (arg-def-type arg)]
                            [arg-name (arg-def-name arg)])
                        (return-arg-representation arg-type arg-name (arg-def-ref arg) module )))
                    args)
                  ", ")
              ")"
              ) ret-type module ret-ref
              
            ;free python callable
            (apply string-append
                (map 
                  (lambda (arg)
                    (let ([origin-type (get-origin-alias-type (arg-def-type arg))]
                        [arg-name (arg-def-name arg)])
                      (cond 
                        [(callable-def? origin-type)
                          (free-py-callable-section (format "_py_is_python_~a" arg-name) (format "_pyargdata_~a" arg-name))]
                        [else ""])))
                args))))
              
  


        ;if doesn't have members
        (string-append
          (format "static PyObject* _method~a(~a* self) {\n" struct-mthd-name struct_name)
          (build-return-section  
            (format "~a((~a*)self)" c-mthd-name type-name) ret-type module ret-ref)))
      "}\n")))

;return operators hashtable from members list
(define (get-operators members )
  (let ([ret (make-hash)])
    (for ([memb members]) 
      (cond
        [(operator-def? memb) 
          (hash-set! ret (operator-def-num-name memb) memb)]))
    (if (hash-empty? ret) #f ret)))

; free python callable section
(define (free-py-callable-section is_python arg_name)
    (format "if(~a)  mir_dec_ref(~a);\n" is_python arg_name))

;return members definition block for python object
(define (get-members-source module )
  (apply 
    string-append
    (map (lambda (memb) 
            (cond
              [(alias-def? memb)  
                ""]
              [(variable-def? memb)  
                (string-append
                  "")]
              [(const-def? memb)  
                (string-append
                  "")]
           
              [(struct-def? memb)  
                (letrec ([py-type   (get-python-type-name memb module)]
                      [c-type   (get-c-type-name memb module)]
                      [memb-mmbrs  (struct-def-members memb)]
                      [args (filter member-def? memb-mmbrs)])
                  (string-append
                      (comment (list (struct-def-brief memb) (struct-def-doc memb)))
                      "//init function\n"
                      "static int\n"
                      (format "_init~a(~a *self, PyObject * args, PyObject *kwds)\n" py-type py-type)
                      "{\n"

                      (if (> (length args) 0)
                          (string-append

                          ;arg initialisation
                          (apply string-append 
                            (map 
                              (lambda (arg)
                                (let ([arg-type (member-def-type arg)]
                                      [arg-name (member-def-name arg)]
                                      [arg-py-type (get-python-arg-type-name (member-def-type arg) module)]
                                      [arg-c-type (get-c-type-name (member-def-type arg) module)])
                                    (arg-initialisation-block arg-type arg-name arg-py-type arg-c-type module)))
                              args))

                            ;parse tuple
                            (format "if (!PyArg_ParseTuple(args, \"~a\", ~a)) {\n"
                              ;formats
                              (apply string-append 
                                (map 
                                  (lambda (arg)
                                    (let ([arg-type (member-def-type arg)])
                                      (get-format arg-type)))
                                  args))
                              ;references
                              (string-join 
                                (map 
                                  (lambda (arg)
                                    (let ([arg-name (member-def-name arg)])
                                      (format "&_pyarg_~a" arg-name)))
                                  args)
                                ", ")
                              )
                     
                            "\treturn -1;\n}\n" 

                            ;check obj args
                            (apply string-append 
                              (map 
                                (lambda (arg)
                                  (let ([arg-type (member-def-type arg)]
                                        [arg-name (member-def-name arg)])
                                    (check-arg-block arg-type arg-name module "-1")))
                                args))
                            
                            ;set args
                            (apply string-append
                                (map 
                                  (lambda (arg)
                                    (letrec (
                                          [arg-name (member-def-name arg)]
                                          [arg-type (member-def-type arg)]
                                          [arg-real-type (get-origin-alias-type arg-type)]
                                          [arg-c-type (get-c-type-name arg-real-type module)]
                                          [ref (member-def-ref arg)]
                                          [arg-python-type (get-python-arg-type-name (member-def-type arg) module)]
                                          )
                                          (cond
                                              [(or (default-def? arg-real-type) (enum-def? arg-real-type))
                                                (format "self->data.~a = ~a;\n" arg-name (return-arg-representation arg-type arg-name (member-def-ref arg) module))]
                                              [(struct-def? arg-real-type)
                                                (if ref
                                                  (format "\t~a_get_descr()->copy_inplace_(self->data.~a , ~a);\n" arg-c-type arg-name (return-arg-representation arg-type arg-name (member-def-ref arg) module))
                                                  (format "\t~a_get_descr()->copy_inplace_(&self->data.~a , &~a);\n" arg-c-type arg-name (return-arg-representation arg-type arg-name (member-def-ref arg) module)))]
                                              [(or (class-def? arg-real-type) (callable-def? arg-real-type)) 
                                                (if ref
                                                  (string-append
                                                    (format "\tself->data.~a = ~a;\n~a_get_descr()->inc_ref_(self->data.~a);\n" arg-name (return-arg-representation arg-type arg-name (member-def-ref arg) module) arg-c-type arg-name))
                                                  (string-append
                                                    (format "\tself->data.~a = ~a;\n~a_get_descr()->inc_ref_(&self->data.~a);\n" arg-name (return-arg-representation arg-type arg-name (member-def-ref arg) module) arg-c-type arg-name)))])))
                                  args))
                                  
                                  ;free python callable
                                  (apply string-append
                                      (map 
                                        (lambda (arg)
                                          (let ([origin-type (get-origin-alias-type (member-def-type arg))]
                                              [arg-name (member-def-name arg)])
                                            (cond 
                                              [(callable-def? origin-type)
                                                (free-py-callable-section (format "_py_is_python_~a" arg-name) (format "_pyargdata_~a" arg-name))]
                                              [else ""])))
                                      args)) )
                        "")
                    "\treturn 0;\n}\n"

                    ;dealloc function
                    "//dealloc function\n"
                    "static void\n"
                    (format "_dealloc~a(~a *self)\n" py-type py-type)
                    "{\n"
              
                    (if (> (length args) 0)
                        (apply string-append 
                          (map 
                            (lambda (arg)
                                (letrec 
                                   ([arg-name (member-def-name arg)]
                                    [arg-type (member-def-type arg)]
                                    [arg-real-type (get-origin-alias-type arg-type)]
                                    [arg-c-type (get-c-type-name arg-real-type module)]
                                    [ref (member-def-ref arg)])
                                    (cond
                                        [(or (class-def? arg-real-type) (callable-def? arg-real-type)) 
                                          (if ref
                                            (string-append
                                              (format "\tif(self->data.~a) ~a_get_descr()->dec_ref_(self->data.~a);\n" arg-name arg-c-type arg-name))
                                            (string-append
                                              (format "\t~a_get_descr()->dec_ref_(&self->data.~a);\n" arg-c-type arg-name)))]
                                        [else ""])))
                              args))
                        "")
                    "\tPy_TYPE(self)->tp_free((PyObject *)self);\n}\n"

                    "//getsets\n"
                    (apply string-append  
                      (map 
                        (lambda (m)
                          (cond 
                            [(member-def? m)
                            (get-member-get-sets-python (get-python-type-name memb module) m module)]
                            [else ""]
                            ))
                        (struct-def-members memb)))  
                    "//members\n"
                    (format "static PyGetSetDef _getsets~a[] = {\n" py-type)
                    (apply string-append  
                      (map 
                        (lambda (m)
                          (cond 
                            [(member-def? m)  
                            (get-member-def-python (get-python-type-name memb module) m module)]
                            [else ""]
                            ))
                        (struct-def-members memb)))  
                    "{ NULL }\n};\n"

                    "//py-typeobject\n"
                    "static PyTypeObject\n"
                    (format "~a = {\n" (type_of_py_object memb module) )
                    (format "PyVarObject_HEAD_INIT(NULL, 0) \"~a\",   /* tp_name */\n" (type-def-name memb) )
                    (format "sizeof(~a),             /* tp_basicsize */\n" py-type)
                    "0,                         /* tp_itemsize */\n"
                    (format "(destructor)_dealloc~a, /* tp_dealloc */\n" py-type)
                    "0,                         /* tp_print */\n"
                    "0,                         /* tp_getattr */\n"
                    "0,                         /* tp_setattr */\n"
                    "0,                         /* tp_compare */\n"
                    "0,                         /* tp_repr */\n"
                    "0,                         /* tp_as_number */\n"
                    "0,                         /* tp_as_sequence */\n"
                    "0,                         /* tp_as_mapping */\n"
                    "0,                         /* tp_hash */\n"
                    "0,                         /* tp_call */\n"
                    "0,                         /* tp_str */\n"
                    "0,                         /* tp_getattro */\n"
                    "0,                         /* tp_setattro */\n"
                    "0,                         /* tp_as_buffer */\n"
                    "Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /* tp_flags*/\n"
                    (format "\"~a\\n~a\",          /* tp_doc */\n" (struct-def-brief memb) (struct-def-doc memb))
                    "0,                         /* tp_traverse */\n"
                    "0,                         /* tp_clear */\n"
                    "0,                         /* tp_richcompare */\n"
                    "0,                         /* tp_weaklistoffset */\n"
                    "0,                         /* tp_iter */\n"
                    "0,                         /* tp_iternext */\n"
                    "0,                         /* tp_methods */\n"
                    "0,                         /* tp_members */\n" 
                    (format "_getsets~a,                         /* tp_getset */\n"py-type)
                    "0,                         /* tp_base */\n"
                    "0,                         /* tp_dict */\n"
                    "0,                         /* tp_descr_get */\n"
                    "0,                         /* tp_descr_set */\n"
                    "0,                         /* tp_dictoffset */\n"
                    (format "(initproc)_init~a,      /* tp_init */\n" py-type)
                    "0,                         /* tp_alloc */\n"
                    "0,                         /* tp_new */\n"
                    "};\n"

                    (format "PyTypeObject * _get~a(){\nreturn (PyTypeObject*) &~a;\n};\n" py-type (type_of_py_object memb module) )
                    (format "~a * _get_data_pys_~a(~a * data) {\nreturn &data->data; };\n" c-type c-type py-type)

                    ;from data
                    (format "PyObject * _from_data_pys_~a(~a * data){\n"  c-type c-type)
                    "if (data==NULL) Py_RETURN_NONE;\n"
                    (format "PyTypeObject *type = &~a;\n" (type_of_py_object memb module))
                    (format "~a *self;\n" py-type)
                    (format "self = (~a *)type->tp_alloc(type, 0);\n" py-type)
                    "if (self == NULL) Py_RETURN_NONE;\n"
                    (format "memcpy (&self->data, data, sizeof(~a));\n" c-type)
                    "return (PyObject *) self;\n}\n";

                    
                ))]
                [(class-def? memb)  
                  (letrec ([py-type   (get-python-type-name memb module)]
                        [c-type   (get-c-type-name memb module)]
                        [memb-mmbrs  (class-def-members memb)]
                        [operators (get-operators memb-mmbrs)]
                        [memb-has-mthds  (> (apply + (map 
                                                      (lambda (m) 
                                                        (if (method-def? m) 1 0))
                                                          (class-def-members  memb)))
                                            0)]
                        [memb-has-mmbrs   (> (apply + (map 
                                                  (lambda (m) 
                                                    (if (member-def? m) 1 0))
                                                      (class-def-members  memb)))
                                              0)])
                    ;init function
                    (string-append
                      (comment (list (class-def-brief memb) (class-def-doc memb)))
                
                      "//init function\n"
                      "static int\n"
                      (format "_init~a(~a *self, PyObject * args, PyObject *kwds)\n" py-type py-type)
                      "{\n"

                      (let ([args (constructor-def-args (class-def-constructor memb))])
                        (if (> (length args) 0)
                          (string-append

                          ;arg initialisation
                          (apply string-append 
                            (map 
                              (lambda (arg)
                                (let ([arg-type (arg-def-type arg)]
                                      [arg-name (arg-def-name arg)]
                                      [arg-py-type (get-python-arg-type-name (arg-def-type arg) module)]
                                      [arg-c-type (get-c-type-name (arg-def-type arg) module)])
                                    (arg-initialisation-block arg-type arg-name arg-py-type arg-c-type module)))
                              args))

                            ;parse tuple
                            (format "if (!PyArg_ParseTuple(args, \"~a\", ~a)) {\n"
                              ;formats
                              (apply string-append 
                                (map 
                                  (lambda (arg)
                                    (let ([arg-type (arg-def-type arg)])
                                      (get-format arg-type)))
                                  args))
                              ;references
                              (string-join 
                                (map 
                                  (lambda (arg)
                                    (let ([arg-name (arg-def-name arg)])
                                      (format "&_pyarg_~a" arg-name)))
                                  args)
                                ", ")
                              )
                   
                            "\treturn -1;\n}\n" 

                            ;check obj args
                            (apply string-append 
                              (map 
                                (lambda (arg)
                                  (let ([arg-type (arg-def-type arg)]
                                        [arg-name (arg-def-name arg)])
                                    (check-arg-block arg-type arg-name module "-1")))
                                args))
                            
                            ;call constructor
                            (format "\t~a_constructor(" c-type)
                            (string-join
                              (append (list (format "(~a*) self" c-type))
                                (map 
                                  (lambda (arg)
                                    (let (
                                          [arg-name (arg-def-name arg)]
                                          [arg-type (arg-def-type arg)]
                                          [arg-python-type (get-python-arg-type-name (arg-def-type arg) module)]
                                          )
                                          (return-arg-representation arg-type arg-name (arg-def-ref arg) module)
                                        ))
                                  args))
                                  ", ")

                            ");\n"
                            ;free python callable
                            (apply string-append
                                (map 
                                  (lambda (arg)
                                    (let ([origin-type (get-origin-alias-type (arg-def-type arg))]
                                        [arg-name (arg-def-name arg)])
                                      (cond 
                                        [(callable-def? origin-type)
                                          (free-py-callable-section (format "_py_is_python_~a" arg-name) (format "_pyargdata_~a" arg-name))]
                                        [else ""])))
                                args)))
                          (format "\t~a_constructor((~a *)self);\n" c-type c-type) ))

                      "\treturn 0;\n}\n"
                      
                      ;dealloc function
                      "//dealloc function\n"
                      "static void\n"
                      (format "_dealloc~a(~a *self)\n" py-type py-type)
                      "{\n"
                      (format "\t~a_destructor((~a*)self);\n" c-type c-type)
                      "\tPy_TYPE(self)->tp_free((PyObject *)self);\n}\n"
                        
                      "//getsets\n"
                      (if memb-has-mmbrs 
                        (string-append
                          (apply string-append  
                            (map 
                              (lambda (m)
                                (cond 
                                  [(member-def? m)  
                                  (get-member-get-sets-python (get-python-type-name memb module) m module)]
                                  [else ""]
                                  ))
                              memb-mmbrs))  
                          "//members\n"
                          (format "static PyGetSetDef _getsets~a[] = {\n" py-type)
                          (apply string-append  
                            (map 
                              (lambda (m)
                                (cond 
                                  [(member-def? m)  
                                  (get-member-def-python (get-python-type-name memb module) m module)]
                                  [else ""]
                                  ))
                              memb-mmbrs))  
                          "{ NULL }\n};\n")
                        "")

                      "//methods\n"
                      (if memb-has-mthds  
                        (string-append
                          (apply string-append  
                            (map 
                              (lambda (m)
                                (cond 
                                  [(and (method-def? m) (not (operator-def? m)))  
                                  (get-method-impl-python (get-c-type-name memb module) (get-python-type-name memb module) m module)]
                                  [else ""]
                                  ))
                              memb-mmbrs))  
                            "//PyMethodDef\n"
                            (format "static PyMethodDef _methods~a[] = {\n" py-type)
                            (apply string-append  
                              (map 
                                (lambda (m)
                                  (cond 
                                    [(and (method-def? m) (not (operator-def? m)))   
                                    (get-method-def-python (get-python-type-name memb module) m module)]
                                    [else ""]
                                    ))
                                memb-mmbrs))  
                            "{NULL, NULL, 0, NULL}\n};\n")
                         "")
                        (if operators 
                          (let ([get-method (lambda(symb [f "~a"][return "NULL"])
                                              (if (hash-has-key? operators symb) (format f (format "(PyObject* (*) (PyObject*, PyObject*))~a_~a" py-type (method-def-name (hash-ref operators symb #f)))) return))])
                            (string-append
                              ;add num method defenitions
                              (apply string-append
                                (hash-map operators (lambda (symb mthd)
                                  (letrec (
                                        [name (method-def-name mthd)]
                                        [struct-mthd-name (format "~a_~a" py-type name)]
                                        [c-mthd-name (format "~a_~a" c-type name)]
                                        [args (method-def-args mthd)]
                                        [ret-type (return-def-type (method-def-return mthd))]
                                        [ret-ref (return-def-ref (method-def-return mthd))])
                                    (if (= (length args) 1)
                                      (letrec ([arg-name (arg-def-name (car args))]
                                               [arg-type (arg-def-type (car args))]
                                               [arg-c-type (get-c-type-name arg-type module)]
                                               [arg-py-type (get-python-type-name arg-type module)]
                                               [arg-value-name (format "_pyarg_~a" arg-name)])  
                                        (string-append
                                          (format "static PyObject* ~a(~a* self, PyObject* obj) {\n" struct-mthd-name py-type)
                                          (if (default-def? (arg-def-type (car args)))
                                            (string-append 
                                              (type-check-return-section "obj" (format "&~a"(hash-ref type-dict-python (type-def-name arg-type)))  (type-def-name arg-type) "NULL")
                                              (format "~a ~a = ~a;\n" arg-c-type arg-value-name (format (to-c-type (arg-def-type (car args)) module) "obj")))
                                            (string-append 
                                              (format "~a* ~a = (~a*) obj;\n" arg-py-type  arg-value-name arg-py-type)
                                              (check-arg-block (arg-def-type (car args)) (arg-def-name (car args)) module "NULL")))
                                          ;return section
                                   
                                          (build-return-section             
                                            (string-append
                                              (format "~a((~a*)self, " c-mthd-name c-type)
                                                (string-join 
                                                  (map 
                                                    (lambda (arg)
                                                      (let ([arg-type (arg-def-type arg)]
                                                            [arg-name (arg-def-name arg)])
                                                        (return-arg-representation arg-type arg-name (arg-def-ref arg) module )))
                                                    args)
                                                  ", ")
                                              ")") ret-type module ret-ref
                                            ;free python callable
                                            (apply string-append
                                                (map 
                                                  (lambda (arg)
                                                    (let ([origin-type (get-origin-alias-type (arg-def-type arg))]
                                                        [arg-name (arg-def-name arg)])
                                                      (cond 
                                                        [(callable-def? origin-type)
                                                          (free-py-callable-section (format "_py_is_python_~a" arg-name) (format "_pyargdata_~a" arg-name))]
                                                        [else ""])))
                                                args))
                                            #f)  

                                          "}\n" ))
                                      (error (format "in method ~a of ~a should be exactly one input argument" name c-type)))))))

                              (if (or (hash-has-key? operators "==") (hash-has-key? operators "<"))
                                (let ([less (hash-ref operators "<" #f)]
                                      [equal (hash-ref operators "==" #f)])
                                  (string-append
                                    (format "static PyObject *rich_compare~a(PyObject *obj1, PyObject *obj2, int op) {\n" py-type)
                                    "    switch (op) {\n"
                                    "    case Py_LT:\n"
                                    (if less (format "if (~a_~a((~a*)obj1, obj2)==Py_True)  Py_RETURN_TRUE;\n"py-type (method-def-name less) py-type ) "")
                                    "      break;\n"
                                    "    case Py_LE:\n"
                                    (if (and less equal) (format "if ((~a) ||\n (~a)) Py_RETURN_TRUE;\n"
                                                              (format "~a_~a((~a*)obj1, obj2)==Py_True"py-type (method-def-name less) py-type )
                                                              (format "~a_~a((~a*)obj1, obj2)==Py_True"py-type (method-def-name equal) py-type )) 
                                                          "")
                                    "      break;\n"
                                    "    case Py_EQ:\n"
                                    (if equal (format "if (~a_~a((~a*)obj1, obj2)==Py_True)  Py_RETURN_TRUE;\n"py-type (method-def-name equal) py-type ) "")
                                    "      break;\n"
                                    "    case Py_NE:\n"
                                    (if equal (format "if (~a_~a((~a*)obj1, obj2)!=Py_True)  Py_RETURN_TRUE;\n"py-type (method-def-name equal) py-type ) "")
                                    "      break;\n"
                                    "    case Py_GT:\n"
                                    (if (and less equal) (format "if (!(~a) &&\n !(~a)) Py_RETURN_TRUE;\n" 
                                                          (format "~a_~a((~a*)obj1, obj2)==Py_True"py-type (method-def-name less) py-type )
                                                          (format "~a_~a((~a*)obj1, obj2)==Py_True"py-type (method-def-name equal) py-type )) 
                                                      "")
                                    "      break;\n"
                                    "    case Py_GE:\n"
                                   (if less (format "if (~a_~a((~a*)obj1, obj2)!=Py_True)  Py_RETURN_TRUE;\n"py-type (method-def-name less) py-type ) "")
                                    "      break;\n"
                                    "    }\n"
                                    "    Py_RETURN_FALSE;\n"
                                    "  }\n"))
                                "")


                              (format "static PyNumberMethods num_methods~a[] = {{\n" py-type) 
                              (format "~a,       /*nb_add*/\n" (get-method "+"))
                              (format "~a,       /*nb_substract*/\n" (get-method "-"))
                              (format "~a,       /*nb_multiply*/\n" (get-method "*"))
                              "NULL,                           /*nb_remainder*/\n"
                              "NULL,                           /*nb_divmod*/\n"
                              (format "~a,                     /*nb_power*/\n" (get-method "^"))
                              "NULL,                           /*nb_negative*/\n"
                              "NULL,                           /*nb_positive*/\n"
                              "NULL,                           /*nb_absolute*/\n"
                              "NULL,                           /*nb_bool*/\n"
                              "NULL,                           /*nb_invert*/\n"
                              "NULL,                      /*nb_lshift*/\n"
                              "NULL,                      /*nb_rshift*/\n"
                              (format "~a,       /*nb_and*/\n" (get-method "&&"))
                              "NULL,                           /*nb_xor*/\n" 
                              (format "~a,        /*nb_or*/\n" (get-method "||"))
                              "NULL,                           /*nb_int*/\n"
                              "NULL,                           /*nb_reserved*/\n"
                              "NULL,                           /*nb_float*/\n"
                              (format "~a,                           /*nb_inplace_add*/\n" (get-method "+="))
                              (format "~a,                           /*nb_inplace_substract*/\n" (get-method "-="))
                              (format "~a,                           /*nb_inplace_multiply*/\n" (get-method "*="))
                              "NULL,                           /*nb_inplace_remainder*/\n"
                              (format "~a,                            /*nb_inplace_power*/\n" (get-method "^="))
                              "NULL,                           /*nb_inplace_lshift*/\n"
                              "NULL,                           /*nb_inplace_rshift*/\n"
                              (format "~a,                            /*nb_inplace_and*/\n" (get-method "&&"))
                              "NULL,                           /*nb_inplace_xor*/\n"
                              (format "~a,                           /*nb_inplace_or*/\n" (get-method "||"))
                              "NULL,                           /*nb_floor_divide*/\n"
                              (format "~a,                     /*nb_true_divide*/\n" (get-method "/"))
                              "NULL,                           /*nb_inplace_floor_divide*/\n"
                              (format "~a,                                /*nb_inplace_true_divide*/\n" (get-method "/="))
                              "NULL,                           /*nb_index*/\n"
                              "NULL,                           /*nb_matrix_multiply*/\n"
                              "NULL                            /*nb_inplace_matrix_multiply*/\n"
                              "}};\n"))
                            "")


                      "//py-typeobject\n"
                      "static PyTypeObject\n"
                      (format "~a = {\n" (type_of_py_object memb module) )
                      (format "PyVarObject_HEAD_INIT(NULL, 0) \"~a\",   /* tp_name */\n" (type-def-name memb) )
                      (format "sizeof(~a),             /* tp_basicsize */\n" py-type)
                      "0,                         /* tp_itemsize */\n"
                      (format "(destructor)_dealloc~a, /* tp_dealloc */\n" py-type)
                      "0,                         /* tp_print */\n"
                      "0,                         /* tp_getattr */\n"
                      "0,                         /* tp_setattr */\n"
                      "0,                         /* tp_compare */\n"
                      "0,                         /* tp_repr */\n"
                      (format "~a,                         /* tp_as_number */\n" (if operators  (format "num_methods~a"py-type) "0"))
                      "0,                         /* tp_as_sequence */\n"
                      "0,                         /* tp_as_mapping */\n"
                      "0,                         /* tp_hash */\n"
                      "0,                         /* tp_call */\n"
                      "0,                         /* tp_str */\n"
                      "0,                         /* tp_getattro */\n"
                      "0,                         /* tp_setattro */\n"
                      "0,                         /* tp_as_buffer */\n"
                      "Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /* tp_flags*/\n"
                      (format "\"~a\\n~a\",          /* tp_doc */\n" (class-def-brief memb) (class-def-doc memb))
                      "0,                         /* tp_traverse */\n"
                      "0,                         /* tp_clear */\n"
                      (format "~a,                /* tp_richcompare */\n" (if (and operators (or (hash-has-key? operators "==") (hash-has-key? operators "<")) ) (format "rich_compare~a"py-type) "0"))
                      "0,                         /* tp_weaklistoffset */\n"
                      "0,                         /* tp_iter */\n"
                      "0,                         /* tp_iternext */\n"
                      (if memb-has-mthds  
                        (format "_methods~a,                         /* tp_methods */\n" py-type)
                        "0,                         /* tp_methods */\n")
                      "0,                         /* tp_members */\n" 
                      (if memb-has-mmbrs 
                        (format "_getsets~a,                         /* tp_getset */\n" py-type)
                        "0,                         /* tp_getset */\n")
                      "0,                         /* tp_base */\n"
                      "0,                         /* tp_dict */\n"
                      "0,                         /* tp_descr_get */\n"
                      "0,                         /* tp_descr_set */\n"
                      "0,                         /* tp_dictoffset */\n"
                      (format "(initproc)_init~a,      /* tp_init */\n" py-type)
                      "0,                         /* tp_alloc */\n"
                      "0,                         /* tp_new */\n"
                      "};\n"

                      (format "PyTypeObject * _get~a()\n{\nreturn (PyTypeObject*) &~a;\n};\n" py-type (type_of_py_object memb module) )
                      (format "~a * _get_data_pys_~a(~a * data) {return(~a*) data; };\n" c-type c-type py-type c-type )
                      
                      (comment (format "return size of ~a\n" c-type))
                      (format "size_t ~a_size_(){\n" c-type)
                      (format "\treturn sizeof(~a);\n" py-type)
                      "}\n"

                      ;data
                      (format "~a_t * ~a_data_(~a * data){\n" c-type c-type c-type)
                      "if(data==NULL) return NULL;\n"
                      (format "return &((~a*)data)->data;\n}\n" py-type)
                      
                      ;new 
                      (format "~a * ~a_new_(){\n" c-type c-type )
                      (format "PyTypeObject *type = &~a;\n" (type_of_py_object memb module))
                      (format "~a *self;\n" py-type)
                      (format "self = (~a *)type->tp_alloc(type, 0);\n" py-type)
                      "if (self == NULL) return NULL;\n"
                      (format "return (~a*)self;\n}\n" c-type )

                      ;from data
                      (format "PyObject * _from_data_pys_~a(~a * data){\n" c-type c-type)
                      "if(data==NULL) Py_RETURN_NONE;\n"
                      "return(PyObject *) data;\n}\n"

                  ))]
              [else ""]))
      (module-def-defs module))))

;generates source and header file for mir module wrapper
(define (generate-python module module-map)
  (begin
    (save-header
      (string-append
        ;add header
        (get-copyright-header module)
        "\n"
        ;add include guard
        (get-guard-header module)
        "\n"
        ;add include
        (apply string-append 
          (map (lambda (memb)
            (if (callable-def? memb)
              (format "#include \"~a\"\n" (get-python-callable-inc-filename memb module ))
              "")) 
            (module-def-defs module)))
        (get-includes module module-map #t)
        "\n"
        ;add declarations
        (get-forward-declarations-header module)
        "\n\n"
        ;add members
        (get-members-header module)
        (format "#endif //~a\n" (get-guard-header-name module))
      )
      module)
      (save-source
        (string-append
          ;add header
          (get-copyright-header module)
          "\n"
          ;add include
          (get-includes-source module module-map)
          "\n"
          ;add members
          (get-members-source module)
        )
        module)))

;create module file members block as string
(define (get-module-mebers-block module modulearg)
  (apply string-append
    (map (lambda (memb) 
        (let ([ns (string-join (module-def-ns module) "_")])
          (cond
            [(variable-def? memb)  
              "-----------variable--------------"]
            [(or (struct-def? memb)  (class-def? memb) )
              (let ([py-type   (get-python-type-name memb module)])
                (format "add_type_to_module (_pyargmod_~a, _get~a(), \"~a\");\n" ns py-type (car (reverse (string-split (type-def-name memb) ".")))))]
            [else ""])))
        (module-def-defs module))))

;create module file alias block as string
(define (get-module-const-block module modulearg)
  (apply string-append
    (map (lambda (memb) 
        (let ([ns (string-join (module-def-ns module) "_")])
          (cond
            [(const-def? memb)  
              (letrec ([type (const-def-type memb)]
                       [real-type (get-origin-alias-type type)]
                       [name  (car (reverse (string-split (const-def-name memb) ".")) )]    
                       [absolute-name (string-replace (const-def-name memb) "." "_")]
                       [c-type (get-c-type-name type module)]
                       [c-type-real (get-c-type-name real-type module)])
                       (cond
                          [(default-def? real-type)
                            (format "add_const_to_module(_pyargmod_~a, \"~a\", ~a);\n" ns name 
                              (format (to-python-type (const-def-type memb)) absolute-name))]
                          [else 
                              (string-append 
                                (format "~a ~a const_data_~a = get_mir_const_~a();\n" c-type (if (const-def-ref memb) "*" "") c-type (get-c-type-name-from-string (const-def-name memb)))
                                (format "add_const_to_module(_pyargmod_~a, \"~a\", ~a);\n" ns name
                                  (format "_from_data_pys_~a(~aconst_data_~a)"c-type-real (if (const-def-ref memb) "" "&") c-type)))]))]
            [else ""])))
        (module-def-defs module))))

;create module file alias block as string
(define (get-module-alias-block module modulearg)
  (apply string-append
    (map (lambda (memb) 
        (let ([ns (string-join (module-def-ns module) "_")])
          (cond
            [(alias-def? memb)  
              (let ([type (get-origin-alias-type memb)])
                (format "add_alias_to_module(_pyargmod_~a, NewType, \"~a\", ~a);\n" 
                  ns 
                  (car (reverse (string-split (type-def-name memb) ".")) )
                  (format "(PyObject *) ~a" 
                    (cond 
                      [(default-def? type)  
                        (format "&~a"(hash-ref type-dict-python (type-def-name type)))]
                      [else
                        (format "_get~a()"  (get-python-type-name type module))]    
                  ))))]
            [else ""])))
        (module-def-defs module))))

;create block fpr one argument initialisation
(define (arg-initialisation-block arg-type arg-name arg-py-type arg-c-type module)
 (cond 
  [(default-def? arg-type) 
  (format "~a _pyarg_~a;\n" arg-py-type arg-name)]
  [(enum-def? arg-type) 
  (format "~a _pyarg_~a;\n" arg-py-type arg-name)]
  [(alias-def?  arg-type) 
    (arg-initialisation-block
      (alias-def-type arg-type) 
      arg-name
      (get-python-arg-type-name (alias-def-type arg-type) module)
      (get-c-type-name (alias-def-type arg-type) module)
        module)]
  [(callable-def? arg-type) 
  (format "~a* _pyarg_~a = NULL;\n~a* _pyargdata_~a = NULL;\n bool _py_is_python_~a = false;\n"  arg-py-type arg-name  arg-c-type arg-name arg-name)]
  [else 
    (format "~a* _pyarg_~a = NULL;\n" arg-py-type arg-name)]))

;create block with arguments initialisation for several palces
(define (args-initialisation-block args module)
  (apply string-append 
    (map 
      (lambda (arg)
        (let ([arg-type (arg-def-type arg)]
              [arg-name (arg-def-name arg)]
              [arg-py-type (get-python-arg-type-name (arg-def-type arg) module)]
              [arg-c-type (get-c-type-name (arg-def-type arg) module)])
            (arg-initialisation-block arg-type arg-name arg-py-type arg-c-type module)))
      args)))

;type check return section section
(define (type-check-return-section arg-value py-type arg-type-name ret-val [check-type #t][check #t])
  (if check-type
    (string-append
      (format "if (!PyObject_TypeCheck(~a, ~a)) {\n"  arg-value py-type)
      (format "PyErr_SetString(PyExc_TypeError, \"Argument provided must be an ~a\");\n" arg-type-name)
      (format "return ~a;\n}\n" ret-val))
    (string-append
      (format "if ( strcmp(((PyObject*) ~a)->ob_type->tp_name, \"~a\")!=0 ) {\n" arg-value py-type  )
      (format "PyErr_SetString(PyExc_TypeError, \"Argument provided must be an ~a\");\n" arg-type-name)
      (format "return ~a;\n}\n" ret-val))))   

;add block with one argument checks
(define (check-arg-block arg-type arg-name module ret-val)   
  (cond 
    [(default-def? arg-type) ""]
    [(alias-def?  arg-type) (check-arg-block (alias-def-type arg-type) arg-name module ret-val)]
    [(enum-def?  arg-type) ""]
    [(callable-def? arg-type) 
      (callable-check-block arg-type (format "_pyarg_~a" arg-name)  (format "_pyargdata_~a" arg-name) (format "_py_is_python_~a" arg-name) (get-python-type-name arg-type module) (get-c-type-name arg-type module) module ret-val)]
    [(python-type-def?  arg-type) 
      (if (not (equal? (python-type-def-real-name arg-type) "any"))
        (type-check-return-section (format "_pyarg_~a" arg-name )   (python-type-def-real-name arg-type) (type-def-name arg-type) ret-val #f)
        "")]
    [else    
      (type-check-return-section (format "_pyarg_~a" arg-name )   (format "_get~a()" (get-python-arg-type-name arg-type module)) (type-def-name arg-type) ret-val)]))

;add block with arguments checks
(define (check-args-block args module ret-val)
    (apply string-append 
      (map 
        (lambda (arg)
          (let ([arg-type (arg-def-type arg)]
                [arg-name (arg-def-name arg)])
            (check-arg-block arg-type arg-name module ret-val)))
        args)))

;return argumets variable name block as string 
(define (return-arg-representation arg-type arg-name arg-ref? module)
                (cond 
                      [(alias-def? arg-type) 
                            (return-arg-representation (alias-def-type arg-type) arg-name arg-ref? module)]
                      [(default-def? arg-type) 
                            (format "_pyarg_~a" arg-name)]
                      [(callable-def? arg-type) 
                            (format "*_pyargdata_~a" arg-name)]
                      [(enum-def? arg-type) 
                            (format "_pyarg_~a" arg-name)]
                      [(python-type-def? arg-type) 
                            (format "_pyarg_~a" arg-name)]
                      [else
                            (if arg-ref? 
                              (format "_get_data~a(_pyarg_~a)"  (get-python-arg-type-name arg-type module) arg-name)  
                              (format "_pyarg_~a->data" arg-name))
                            ]))


 ;return callable defenition 
(define (get-callable-def-python short-name mthd-name brief doc args module)
  (string-append
    (format "{\"~a\", (PyCFunction)~a, " short-name mthd-name )
    (if (>(length args) 0)
      "METH_VARARGS | METH_KEYWORDS,\n"
      "METH_NOARGS,\n")
    (format "\"~a\\n~a\"},\n" brief doc)
  ))

;return namespace name
(define (get-namespace-name ns)
    (string-join ns "_"))

;return module defenition
(define (add-module-def brief doc moduledef module-name ns module) 
  (string-append
      ;add-module-def
      "static PyModuleDef\n"
      (format "~a = {\n" moduledef)
      "PyModuleDef_HEAD_INIT,\n"
      (format "    \"~a\",\n" module-name)
      (format "    \"~a\\n~a\",\n"  brief doc)
      "    -1,\n"
      "    NULL,       /* methods */\n"          
      "    NULL,\n"
      "    NULL,       /* traverse */\n"
      "    NULL,       /* clear */\n"
      "    NULL\n"
      "};\n")
  )

;return namespaces hash map
(define (get-module-namespaces main-module module-map)
  (let ([ns-map (make-hash)]
        [get-namespaces (lambda(ns-list)
                          (let* ([curr-ns (car ns-list)]
                               [namespaces (cdr ns-list)])
                          (append (list curr-ns)
                            (map 
                              (lambda (ns)
                                (begin 
                                  (set! curr-ns (format "~a_~a" curr-ns ns))
                                  curr-ns))
                              namespaces)
                            )))])
               
    (map 
      (lambda (mod)
        (let* ([nss (get-namespaces (module-def-ns mod))]
              [parent #f]
              [members  (if (hash-has-key? ns-map (get-namespace-name (module-def-ns mod)))
                          (namespace-def-members (hash-ref!  ns-map  (get-namespace-name (module-def-ns mod)) #f))
                          (list))])

          ;add all namespaces
          (for ([ns nss]) 
            (begin
              (if (not (hash-has-key? ns-map ns ))
                  (begin       
                    (hash-set! ns-map ns (namespace-def ns ns (string-split ns "_") (list) (mutable-set)))
                    (if  parent 
                      (set-add! (namespace-def-child-nss (hash-ref! ns-map parent #f)) ns)
                      void))
                  void))
              (set! parent ns))

          ;add main namespace
           (letrec ([main-ns-name (string-join (module-def-ns mod)"_")]
                [main-ns (hash-ref ns-map main-ns-name #f)])

          (if (hash-has-key? ns-map main-ns-name)
              (begin
                (set-namespace-def-members! main-ns(append (module-def-defs mod) members))
                (set-namespace-def-brief! main-ns (module-def-brief mod))
                (set-namespace-def-doc!  main-ns (module-def-doc mod)))
              (hash-set! ns-map main-ns-name (namespace-def (module-def-brief mod) (module-def-doc mod) (module-def-ns mod) (append (module-def-defs mod) members) (mutable-set)))))))
      (append (list main-module) (hash-values module-map)))
    ns-map))
;return members of python module file block    
(define (get-members-module module module-map)
  (let ([ns-map (get-module-namespaces module module-map)]
        [module-name (module-def-name module)]
        [moduledef (format "_pymod_~a_def" (module-def-name module))]
        [modulearg (format "_pyargmod_~a" (module-def-name module))]
        [main-ns (get-namespace-name (module-def-ns module))]
        )
    (string-append

      "// Module definitions\n"

      (apply string-append 
        (hash-map ns-map
          (lambda (name ns)
            (add-module-def (namespace-def-brief ns) (namespace-def-doc ns) (format "_pymod_~a_def" name) name ns module))
                  ns-map))

      ;add enums
      "//Enum module defenitions\n"
      (apply string-append 
        (hash-map module-map
          (lambda (path mod)
              (apply string-append
                (map (lambda (memb) 
                    (let (
                      [ns (string-join (module-def-ns mod) "_")])
                      (cond
                        [(enum-def? memb)  
                        (let ([type-name (get-c-type-name memb module) ])
                         (add-module-def (enum-def-brief memb) (enum-def-doc memb) (format "_py_enum_mod_~a_def" type-name)  (car (reverse (string-split (type-def-name memb) "."))) ns mod))]
                        [else ""])))
                    (module-def-defs mod))))))

      "//add member to module\n"
      "int add_type_to_module(PyObject * _py_mod, PyTypeObject * _py_arg_type, const char * name ) {\n"
      "_py_arg_type->tp_new = PyType_GenericNew;\n"
      "if (PyType_Ready(_py_arg_type) < 0) {\n"
      "    Py_DECREF(_py_mod);\n"
      "    return 0;\n"
      "}\n"
      "Py_INCREF(_py_arg_type);\n"
      "return PyModule_AddObject(_py_mod, name, (PyObject *)_py_arg_type);\n"
      "}\n"

      "//add sub module\n"
      "int add_object_to_module( PyObject * _py_mod, PyObject * _py_arg_type, const char * name ) {\n"
      "return PyModule_AddObject(_py_mod, name, _py_arg_type);\n"
      "}\n"

      "//add consts\n"
      "int add_const_to_module(PyObject *_py_mod,  const char * name, PyObject * val){\n"
      "return add_object_to_module(_py_mod,val,name);\n"
      "}\n"

      "//add alias to module\n"
      "int add_alias_to_module(PyObject *_py_mod, PyObject * NewType, const char * name, PyObject * wrap_type) {\n"
      "    PyObject *arg_tuple = PyTuple_New(2);\n"
      "    PyTuple_SetItem(arg_tuple, 0, PyUnicode_FromString(name));\n"
      "    PyTuple_SetItem(arg_tuple, 1, wrap_type);\n"
      "    Py_INCREF(wrap_type);\n"
      "    PyObject *ret = PyObject_CallObject(NewType, arg_tuple);\n"
      "    Py_DECREF(arg_tuple);\n"
      "    return add_object_to_module(_py_mod,ret,name);\n"
      "}\n"

      "//init modules\n"
      "PyObject *\n"
      "PyInit__mir_wrapper(void)\n{\n"
      (apply string-append
        (hash-map ns-map 
          (lambda (name ns)
            (string-append
            (format "PyObject * ~a = PyModule_Create(&~a);\n" (format "_pyargmod_~a" name) (format "_pymod_~a_def" name))
            (format "if (~a == NULL) {\n" (format "_pyargmod_~a" name))
            "    return NULL;\n"
            "}\n"))))

      "//add namespaces\n"
      (apply string-append
        (hash-map ns-map 
          (lambda (name ns)
            (let ([namespaces (namespace-def-namespaces ns)])
              (if (not (equal? name main-ns))
                (format "add_object_to_module (_pyargmod_~a, _pyargmod_~a, \"~a\");\n" 
                  (get-namespace-name (reverse (cdr (reverse namespaces))))  
                  name 
                  (car (reverse namespaces)))
                "")))))
                  


        "//find NewType\n"
        "PyObject * typing = PyImport_ImportModule(\"typing\");\n"
        "if (!typing) return NULL;\n"
        "PyObject *NewType = PyObject_GetAttrString(typing, \"NewType\");\n"

      (apply string-append 
        (hash-map module-map
          (lambda (path mod)
              (get-module-mebers-block mod modulearg)))) 
      

      ;add enums
      (apply string-append 
        (hash-map module-map
          (lambda (path mod)
              (apply string-append
                (map (lambda (memb) 
                    (let (
                      [ns (string-join (module-def-ns mod) "_")])
                      (cond
                        [(enum-def? memb)  
                            (let ([type-name (get-c-type-name memb module) ])
                              (string-append
                                (format "//add enum ~a\n" type-name)
                                "{\n"
                                (format "\tPyObject * ~a = PyModule_Create(&~a);\n" (format "_py_enum_mod_~a" type-name) (format "_py_enum_mod_~a_def" type-name))
                                (format "\tif (~a == NULL) {\n" (format "_py_enum_mod_~a" type-name))
                                "\t\treturn NULL;\n"
                                "\t}\n"
                                (format "\tadd_object_to_module (_pyargmod_~a, _py_enum_mod_~a, \"~a\");\n"  ns type-name (car (reverse (string-split (type-def-name memb) "."))))
                                (string-join  
                                  (map 
                                    (lambda (val)
                                      (let (
                                          [name (format "~a_~a" type-name (enum-value-def-name val))]
                                          [value (enum-value-def-value val)])
                                        (format "\tPyModule_AddObject(_py_enum_mod_~a, \"~a\", PyLong_FromLong(~a));" type-name (enum-value-def-name val) name)))
                                    (enum-def-members memb))
                                  "\n")
                                "\n}\n"))]
                        [else ""])))
                    (module-def-defs mod))))))

      ;add callables
      (apply string-append 
        (hash-map (module-def-env module)
          (lambda (key memb)
              (if (callable-def? memb)
                  (let ([py-type   (get-python-type-name memb module)]
                    [ns (string-join (module-def-ns module) "_")])
                      (format "add_type_to_module (_pyargmod_~a, _get~a(), \"~a\");\n" ns py-type (car (reverse (string-split (type-def-name memb) ".")))))
                  ""))))

      (apply string-append 
        (hash-map module-map
          (lambda (path mod)
              (get-module-alias-block mod modulearg)))) 
      
      (apply string-append 
        (hash-map module-map
          (lambda (path mod)
              (get-module-const-block mod modulearg)))) 
      "//free NewType\n"
      "Py_DecRef(NewType);\n"
      ;return
      (format "return ~a;\n" modulearg)
      "}\n")))

;return callable implementation block
(define (get-callable-impl memb module)
  (letrec ([py-type   (get-python-type-name memb module)]
        [args (callable-def-args memb)]
        [arg-count (length (callable-def-args memb))]
        [c-type   (get-c-type-name memb module)]
        [ret-ref (return-def-ref (callable-def-return memb))]
        [ret-c-type-name (get-c-type-name (return-def-type (callable-def-return memb)) module)]
        [ret-python-type-name (get-python-type-name (return-def-type (callable-def-return memb)) module)]
        [ret-type (return-def-type (callable-def-return memb))]
        [real-ret-type (get-origin-alias-type ret-type)])
    (string-append
          "//init function\n"
          "static int\n"
          (format "_init~a(~a *self, PyObject * args, PyObject *kwds)\n" py-type py-type)
          "{\n"
          "\treturn 0;\n}\n"

          "//dealloc function\n"
          "static void\n"
          (format "_dealloc~a(~a *self)\n" py-type py-type)
          "{\n"
          "if (self->data.closure) Py_DECREF(self->data.closure);\n"
          "\tPy_TYPE(self)->tp_free((PyObject *)self);\n}\n"
          
          "//TODO: add description for call function\n"
          (format "PyObject *_call~a(PyObject *self, PyObject *args,\n" py-type)
          "              PyObject *kwargs) {\n"
          ;add args initialisationmodule
          (args-initialisation-block args module)

          ;parse args TODO: create common block for all PyArg_ParseTuple
          (if (>(length args) 0)
            (string-append
              (format "if (!PyArg_ParseTuple(args, \"~a\", ~a)) {\n"
                ;formats
                  (apply string-append 
                    (map 
                      (lambda (arg)
                        (let ([arg-type (arg-def-type arg)])
                          (get-format arg-type)))
                      args))
                ;references
                (string-join 
                  (map 
                    (lambda (arg)
                      (let ([arg-name (arg-def-name arg)])
                        (format "&_pyarg_~a" arg-name)))
                    args)
                  ", "))
           
            
          "\treturn NULL;\n}\n") 
            "")

          (check-args-block args module "NULL")

          "//return section\n"
          (build-return-section 
              (string-append
                (format "\n((~a *)self)\n->data.func(" py-type)
                (string-join
                  (append
                    (map 
                      (lambda (arg)
                        (let (
                              [arg-name (arg-def-name arg)]
                              [arg-type (arg-def-type arg)]
                              [arg-python-type (get-python-arg-type-name (arg-def-type arg) module)]
                              )
                              (return-arg-representation arg-type arg-name (arg-def-ref arg) module)
                            ))
                      args)
                    (list (format "\n((~a *)self)->data.closure)"py-type)))
                      ", "))
            ret-type module ret-ref
          ;free python callable
          (apply string-append
              (map 
                (lambda (arg)
                  (let ([origin-type (get-origin-alias-type (arg-def-type arg))]
                      [arg-name (arg-def-name arg)])
                    (cond 
                      [(callable-def? origin-type)
                        (free-py-callable-section (format "_py_is_python_~a" arg-name) (format "_pyargdata_~a" arg-name))]
                      [else ""])))
              args)) )


            "\n};\n"

          "//TODO:add comments for callable\n"
          "static PyTypeObject\n"
          (format "~a = {\n" (type_of_py_object memb module) )
          (format "PyVarObject_HEAD_INIT(NULL, 0) \"~a\",   /* tp_name */\n" (type-def-name memb) )
          (format "sizeof(~a),             /* tp_basicsize */\n" py-type)
          "0,                         /* tp_itemsize */\n"
          (format "(destructor)_dealloc~a, /* tp_dealloc */\n" py-type)
          "0,                         /* tp_print */\n"
          "0,                         /* tp_getattr */\n"
          "0,                         /* tp_setattr */\n"
          "0,                         /* tp_compare */\n"
          "0,                         /* tp_repr */\n"
          "0,                         /* tp_as_number */\n"
          "0,                         /* tp_as_sequence */\n"
          "0,                         /* tp_as_mapping */\n"
          "0,                         /* tp_hash */\n"
          (format "_call~a,                         /* tp_call */\n"py-type)
          "0,                         /* tp_str */\n"
          "0,                         /* tp_getattro */\n"
          "0,                         /* tp_setattro */\n"
          "0,                         /* tp_as_buffer */\n"
          "Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /* tp_flags*/\n"
          "0, //TODO:add doc for callable          /* tp_doc */\n"
          "0,                         /* tp_traverse */\n"
          "0,                         /* tp_clear */\n"
          "0,                         /* tp_richcompare */\n"
          "0,                         /* tp_weaklistoffset */\n"
          "0,                         /* tp_iter */\n"
          "0,                         /* tp_iternext */\n"
          "0,                         /* tp_methods */\n"
          "0,                         /* tp_members */\n" 
          "0,                         /* tp_getset */\n"
          "0,                         /* tp_base */\n"
          "0,                         /* tp_dict */\n"
          "0,                         /* tp_descr_get */\n"
          "0,                         /* tp_descr_set */\n"
          "0,                         /* tp_dictoffset */\n"
          (format "(initproc)_init~a,      /* tp_init */\n" py-type)
          "0,                         /* tp_alloc */\n"
          "0,                         /* tp_new */\n"
          "};\n"

          (format "PyTypeObject * _get~a(){return (PyTypeObject*) &~a;};" py-type (type_of_py_object memb module) )
          (format "~a * _get_data_pys_~a(~a * data) {return  &data->data;\n };\n" c-type c-type py-type  )
          (format "~a * _new_pys_~a()\n{  return malloc(sizeof(~a)); }\n" py-type c-type py-type)
          (format "void _free_pys_~a(~a * callable)\n{  free (callable); }\n" c-type py-type)

          (comment (format "return size of ~a\n" c-type))
          (format "size_t ~a_size_(){\n" c-type)
          (format "\treturn sizeof(~a);\n" py-type)
          "}\n"

          ;new implementation
          (format "~a * ~a_new_(){\n" c-type c-type )
            (format "PyTypeObject *type = &~a;\n" (type_of_py_object memb module))
            (format "~a *self;\n" py-type)
            (format "self = (~a *)type->tp_alloc(type, 0);\n" py-type)
            "if (self == NULL) return NULL;\n"
            (format "return (~a*)self;\n}\n" c-type )

          ;data
          (format "~a * ~a_data_(~a * data){\n" c-type c-type c-type)
          "if(data==NULL) return NULL;\n"
          (format "return &((~a*)data)->data;\n}\n" py-type)

          ;from data
          (format "PyObject * _from_data_pys_~a(~a * data){\n" c-type c-type)
          "if(data==NULL) Py_RETURN_NONE;\n"
          (format "PyTypeObject *type = &~a;\n" (type_of_py_object memb module))
          (format "~a * self = (~a *)type->tp_alloc(type, 0);\n" py-type py-type)
          "self->data = *data;\n"
          "return(PyObject *) self;\n}\n";

          ;from py callable
          (format "~a * _from_py_callable~a(PyObject * cb){\n" c-type c-type)
          "if(cb==NULL) return NULL;\n"
          (format "~a* _pyret = ~a_new_();\n"c-type c-type)
          (format "_pyret->func = &_wrap~a;\n" py-type) 
          "_pyret->closure = cb;\n" 
          "return _pyret;\n}\n"

          ;wrapper for callable
          (format "~a~a _wrap_pys_~a(~a){\n"  (get-c-type-name ret-type module) (if ret-ref "*" "") c-type 
            (string-join 
              (append
                (map 
                  (lambda (arg)
                    (let ([arg-name (arg-def-name arg)]
                          [ref (arg-def-ref arg)]
                          [arg-type (get-c-type-name (arg-def-type arg) module)])
                      (format "~a~a ~a"  arg-type (if ref "*" "") arg-name )))
                  args)
                  (list "void * callable"))
              ", "))
          (format "PyObject *_pytarg_tuple = PyTuple_New(~a);\n" arg-count)
          (let ([num -1])
            (apply string-append 
              (map 
                (lambda (arg)
                  (letrec ([arg-name (arg-def-name arg)]
                        [ref (arg-def-ref arg)]
                        [arg-type(arg-def-type arg)]
                        [real-arg-type(get-origin-alias-type arg-type)]
                        [python-arg-type(get-python-type-name (arg-def-type arg) module)]
                        [arg-type-name (get-c-type-name (arg-def-type arg) module)])
                    (set! num (+ num 1))
                    (cond [(or (default-def? real-arg-type) (enum-def? real-arg-type))
                        (format "PyTuple_SetItem(_pytarg_tuple, ~a, ~a);\n"  num (format (to-python-type arg-type) arg-name) )]
                        [(python-type-def? real-arg-type)
                        (string-append 
                              (format "Py_INCREF(~a);\n" arg-name) 
                              (format "PyTuple_SetItem(_pytarg_tuple, ~a, (PyObject*)~a);\n" num arg-name)  )]
                        [(callable-def? real-arg-type)
                          (string-append 
                                (format "~a *_pyarg~a=(~a *) _from_data~a(&~a);\n" python-arg-type python-arg-type python-arg-type python-arg-type arg-name)
                                (format "PyTuple_SetItem(_pytarg_tuple, ~a, (PyObject*)_pyarg~a);\n" num python-arg-type)  )]
                        [else
                          (string-append 
                              (format "~a *_pyarg~a=(~a *) _from_data~a(~a);\n" python-arg-type python-arg-type python-arg-type python-arg-type arg-name)
                              (format "Py_INCREF(_pyarg~a);\n" python-arg-type) 
                              (format "PyTuple_SetItem(_pytarg_tuple, ~a, (PyObject*)_pyarg~a);\n" num python-arg-type)  )])))
                args)))

            "//TODO: add type check\n"
            (cond 
              [(and (default-def? real-ret-type) (equal? (type-def-name real-ret-type) "none"))
                "PyObject_CallObject(callable, _pytarg_tuple);\n    Py_DECREF(_pytarg_tuple);\nreturn;\n"]
              [(callable-def? real-ret-type) 
                (string-append
                  "PyObject *_pyret_ret = PyObject_CallObject(callable, _pytarg_tuple);\n"
                  "Py_DECREF(_pytarg_tuple);\n"
                  (format "~a * ret_val = ~a;\nreturn *ret_val;\n"  (get-c-type-name ret-type module) 
                    (format (to-c-type real-ret-type module) 
                      (format "~a _pyret_ret"
                        (if (not (default-def? real-ret-type))
                          (format "(~a *)" ret-python-type-name)
                          "")))))]
              [else 
                (string-append
                  "PyObject *_pyret_ret = PyObject_CallObject(callable, _pytarg_tuple);\n"
                  "Py_DECREF(_pytarg_tuple);\n"
                  (format "return ~a;" 
                    (format (to-c-type real-ret-type module) 
                      (format "~a _pyret_ret"
                        (if (not (default-def? real-ret-type))
                          (format "(~a *)" ret-python-type-name)
                          "")))))])
      
            "}\n"

      )))

;return callable declaration block
(define (get-callable-decl memb module)
  (let ([py-type   (get-python-type-name memb module)]
        [c-type   (get-c-type-name memb module)]
        [args  (callable-def-args memb )]
        [ret-ref (return-def-ref (callable-def-return memb ))]
        [ret-type   (get-c-type-name (return-def-type (callable-def-return memb )) module)]
        )
    (string-append
        (format "struct ~a{\nPyObject_HEAD\n ~a data;\n};\n" py-type c-type )
        (format "void _free_pys_~a(~a * callable);\n" c-type py-type)
        (format "~a~a _wrap_pys_~a(~a);\n" ret-type (if ret-ref "*" "") c-type 
          (string-join 
            (append
              (map 
                (lambda (arg)
                  (let ([arg-name (arg-def-name arg)]
                        [ref (arg-def-ref arg)]
                        [arg-type (get-c-type-name (arg-def-type arg) module)])
                    (format "~a~a ~a"  arg-type (if ref "*" "") arg-name )))
                args)
                (list "void * callable")
            )
            ", ")
          )
        )))

;return callable check block
(define (callable-check-block type arg-name arg-data-name py_is_callable py-type-name c-name module ret-value) 
  (string-append
    (format "    if (!PyObject_TypeCheck(~a,\n" arg-name)
    (format "    _get~a())) {\n" py-type-name)
    (format "     PyObject * _pytempobj_ = (PyObject * )~a;\n" arg-name)
    "    		if (!PyCallable_Check(_pytempobj_)) {\n"
		"              PyErr_SetString(PyExc_TypeError,\n"
		"    			     \"Argument provided must be an callable\");\n"
    (format "              return ~a;\n" ret-value)
    "  	         }\n"
    (format "~a = _from_py_callable~a(_pytempobj_);\n" arg-data-name c-name)
    (format "~a=true;\n" py_is_callable)
    "}else{\n"
    (format "    ~a = _get_data~a(~a);\n"arg-data-name py-type-name arg-name   )
    "}\n"))


;it generates c and header filerepresentation for callable and save they to disk 
(define (generate-callable module-key module)
  (hash-map (module-def-env module) 
    (lambda(key val)
      (if (callable-def? val) 
        (begin
          (generate-callable-src-file val module)
          (generate-callable-inc-file val module)
        )
        void))))

;generate source file for callable wrapper
(define (generate-callable-src-file callable module)
  (begin
    ;generate callable header file
    (save-callable-src-file
      (string-append
        ;add header
        (get-copyright-header module)
        "\n"

        ;includes
        "#include <Python.h>\n" 
        "#include \"mir/pythongen/utils.h\"\n" 
        (format "#include \"~a\"\n" (get-python-callable-inc-filename callable module))
        
        ;add members
        (get-callable-impl callable module)

  
      )
      callable module)))

;generate forward declarations block for callable inc file
(define (get-forward-decl-callable-inc-file memb module)
  (let ([c-type (get-c-type-name memb module)]
        [py-type (get-python-type-name memb module)]
        [origin-type (get-origin-alias-type memb)])
    (cond
      [(python-type-def? origin-type)
          (format "typedef struct ~a ~a;\n"  (type-def-name origin-type ) (type-def-name origin-type ))]
      [(alias-def? memb)
        (string-append
          (get-forward-decl-callable-inc-file (alias-def-type memb) module)
          (format "typedef ~a ~a;\n" (get-c-type-name (alias-def-type memb) module) (get-c-type-name memb module) ))]
 
      [(or (class-def? memb) (struct-def? memb) (callable-def? memb))  
        (let ([py-type (get-python-type-name memb module)]
              [c-type (get-c-type-name memb module)])
          (string-append
            (format "typedef struct ~a ~a;\n"  py-type py-type)
            (format "PyTypeObject * _get_pys_~a();\n" c-type)
            (format "~a * _get_data_pys_~a(~a * data);\n" c-type c-type py-type)
            (format "PyObject * _from_data_pys_~a(~a * data);\n" c-type c-type)
            (if (callable-def? memb) (format "~a * _from_py_callable~a(PyObject * cb);\n" c-type c-type) "")))
            ]
      [else ""])))

;generate callable include python wrapper file and save to disc
(define (generate-callable-inc-file callable module)
  (begin
    ;generate callable header file
    (save-callable-inc-file
      (string-append
        ;add header
        (get-copyright-header module)
        "\n"
        ;add include guard
        (get-guard-callable-inc-header module callable)

        ;includes
        "#include <Python.h>\n" 
        (format "#include \"~a\"\n" (get-c-callable-inc-filename callable module))

        ;add declarations
        (apply string-append
          (let ([defs (collect-callable-defs callable (make-hash))])
            (hash-map defs
              (lambda(key memb)
                (get-forward-decl-callable-inc-file memb module)))))
   
        ;add members
        (get-callable-decl callable module)


        ;clouse guard
        (format "#endif //~a\n" (get-guard-callable-inc-name module callable))
      )
      callable module)))

;main function it generates c header file representation and save it to disk 
(define (generate-python-module module module-map)
  (begin

    ;generate module file
    (save-module
      (string-append
        ;add header
        (get-copyright-header module)
        "\n"
        
        ;add include
        (get-includes module module-map #f)
        "\n"
        ;add members
        (get-members-module module module-map)
      )
      module)))

;build string with intendation
(define (gen-indent indent str)
  (if (> indent 0) (gen-indent (- indent 1) (format "\t~a" str) )str))

;return python defeniton of class member
(define (get-typing-member memb module indent)
  (cond 
    [(member-def? memb)
      (gen-indent indent 
        (if(or (callable-def? (member-def-type memb)) (callable-def?(get-origin-alias-type  (member-def-type memb))))
          (format "~a: typing.Any\n" (member-def-name memb)) 
          (format "~a: ~a\n"(member-def-name memb) (get-typing-python (member-def-type memb)))))]  
    [(method-def? memb)
      (gen-indent indent 
        (string-append
          (format "def ~a("(method-def-name memb))
          (string-join 
            (append
              (list "self")
              (map 
                (lambda (arg)
                  (format "~a: ~a" (arg-def-name arg) (get-typing-python (arg-def-type arg))))
                (method-def-args memb)))
            ", ")
          (format ")->~a:...\n"(get-typing-python (return-def-type (method-def-return memb))))))]
    [else ""]))

;add namespace to typeinfo file
(define (add-typeinfo-namespace curr-ns ns-map module indent)
  (letrec ([child-nss (set->list(namespace-def-child-nss curr-ns))]
         [membs (namespace-def-members curr-ns)])
          (string-append 
            ;process child namespaces
            (apply string-append 
              (map 
                (lambda (sns-name)
                  (let*([ns (hash-ref! ns-map sns-name #f )])
                  (if ns 
                    (string-append
                      (gen-indent indent (format "class ~a:\n"(car  (reverse (namespace-def-namespaces ns)))))
                      (add-typeinfo-namespace ns ns-map module (+ indent 1)))
                    "")))
                child-nss))

            ;process members
            (string-append 
              (apply string-append 
                (map 
                  (lambda (memb)
                    (cond 
                      [(class-def? memb)
                          (string-append
                            (gen-indent indent (format "class ~a :\n" (car(reverse(string-split (type-def-name memb) ".")))))
                            (apply string-append
                              (map 
                                (lambda (m) (get-typing-member m module (+ indent 1)))
                                (class-def-members memb)))
                            (if (= (length (class-def-members memb))0) (gen-indent (+ indent 1) "pass\n") ""))]
                      [(struct-def? memb)
                          (string-append
                            (gen-indent indent (format "class ~a :\n" (car(reverse(string-split (type-def-name memb) ".")))))
                            (apply string-append
                              (map 
                                (lambda (m) (get-typing-member m module (+ indent 1)))
                                (struct-def-members memb)))
                            (if (= (length (struct-def-members memb))0) (gen-indent (+ indent 1) "pass\n") ""))]
                      [(alias-def? memb)
                        (let 
                          ([name (car(reverse(string-split(type-def-name memb) ".")))]
                          [python_type (get-typing-python(alias-def-type memb))])
                          (if (callable-def? (alias-def-type memb))
                            (gen-indent indent (format "~a = ~a\n" name python_type))
                            (gen-indent indent (format "~a = typing.NewType(\"~a\",~a)\n" name name python_type))))]
                        [(enum-def? memb)
                          (string-append
                            (gen-indent indent (format "class ~a(Enum) :\n" (car(reverse(string-split (type-def-name memb) ".")))))
                            (apply string-append
                              (map 
                                (lambda (m) 
                                  (gen-indent (+ indent 1) (format "~a~a\n" (enum-value-def-name m) (if (enum-value-def-value m) (format " = ~a" (enum-value-def-value m)) "= auto()") )))
                                (enum-def-members memb)))
                            (if (= (length (enum-def-members memb))0) (gen-indent (+ indent 1) "pass\n") ""))]
                        [(python-type-def? memb)
                          (let 
                            ([name (car(reverse(string-split(type-def-name memb) ".")))])
                            (gen-indent indent (format "~a = typing.Any #~a\n" name (python-type-def-real-name memb))))]
                      [(const-def? memb)
                        (let 
                          ([name (car(reverse(string-split(const-def-name memb) ".")))]
                          [python_type (get-typing-python(const-def-type memb))])
                          (gen-indent indent (format "~a : ~a\n" name python_type)))]
                      [else ""]))
                  membs)))
                (if (and (= (length membs) 0) (= (length child-nss) 0)) (gen-indent indent "pass\n") ""))))

;generate pyi file which contains type info for generated module
(define (generate-python-type-info-file module module-map)
  (letrec   
    ([ns-map (get-module-namespaces module module-map)])
    ;generate module file 
    (save-type-info-file
      (string-append
        ;add header
        "\"\"\"\n"
        "\t\tCOPYRIGHT (c) 2020 by Featuremine Corporation.\n"
        "\t\tThis software has been provided pursuant to a License Agreement\n"
        "\t\tcontaining restrictions on its use.  This software contains\n"
        "\t\tvaluable trade secrets and proprietary information of\n"
        "\t\tFeatureMine LLC and is protected by law.  It may not be\n"
        "\t\tcopied or distributed in any form or medium, disclosed to third\n"
        "\t\tparties, reverse engineered or used in any manner not provided\n"
        "\t\tfor in said License Agreement except with the prior written\n"
        "\t\tauthorization Featuremine Corporation.\n"
        "\"\"\"\n\n"
        ;add import
        "import typing\n"
        "from enum import Enum, auto\n\n"
        (apply string-append
          (hash-map ns-map 
            (lambda (key ns)
              (if (=(length (string-split key "_")) 1) (add-typeinfo-namespace ns ns-map module 0) "" ))))
        "\n"
      )
      module)))

;main function which responses for generating of all files
(define (generate-python-source main-module module-map common?)
  (begin
    (if (not common?)
      (for ([key (module-def-requires main-module)])
          (let([mod (hash-ref  module-map key)])
            (generate-python mod module-map)
            (generate-callable key mod)))
      
      (begin
        (generate-python-module main-module module-map)
        (generate-python-type-info-file main-module module-map)))))
    
;main function which responses for generating info about generated files
(define (get-python-source-info main-module module-map common?)
    (if common?
      (list 
        (get-python-module-filename-full main-module)
        (get-python-type-info-file-full main-module)
        )
      (append
        (apply append 
          (map
            (lambda (key)
              (let([mod (hash-ref module-map key )])
                  (list
                    (get-python-filename-source-full mod)
                    (get-python-filename-header-full mod))))
            (module-def-requires main-module)))

        (let ([callables (list)])
          (map
            (lambda (key)
              (let([mod (hash-ref module-map key)])
                (map
                  (lambda (memb)
                    (cond
                      [(callable-def? memb) 
                          (set! callables(append 
                                            callables 
                                            (list 
                                              (get-python-callable-inc-filename-full memb main-module )
                                              (get-python-callable-src-filename-full memb main-module )
                                              )))]
                      [else ""]))
                    
                  (module-def-defs mod))))
            (module-def-requires main-module))
            callables))))
            