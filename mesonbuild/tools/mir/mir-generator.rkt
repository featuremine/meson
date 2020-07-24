#lang racket
(require "utils.rkt")
(require "core.rkt")
(require "main.rkt")
(require racket/cmdline)

(define show-info-def (make-parameter #f))
(define show-mir-info-def (make-parameter #f))
(define dest-dir-def (make-parameter #f))
(define root-dir-def (make-parameter "../"))
(define includes-dir-def (make-parameter null))
(define sources-def (make-parameter null))
(define common-def (make-parameter #f))

(define parser
  (command-line
   #:usage-help
    "mir-generator application for generating c headers and "
    "wrappers for python using descriptions of members from mir files"

   #:once-any
     [("-i" "--source-info") 
      "show source files which will be generated"
      (show-info-def #t)]
     [("-m" "--mir-info") 
      "show mir files which used for generation"
      (show-mir-info-def #t)]

   #:once-each
   [("-d" "--dest-dir") dest-dir
    "the destination folder for generated source"
    (dest-dir-def dest-dir)]

   [("-r" "--root-dir") root-dir
    "the root directory for input data"
    (root-dir-def root-dir)]

    [("-c" "--common") 
      "build common files"
      (common-def #t)]

   #:multi
    [("-s" "--source") s
    "source mir file"
    (sources-def (append (sources-def) (list s)))]
    [("-I" "--include-dir") include-dir
    "additional include directory for mir file"
    (includes-dir-def (append (includes-dir-def) (list include-dir)))]

   #:args () (void)))
  
(define (get-path p)
    (if (relative-path? p)  
      (simplify-path (build-path (current-directory) p))
      p))

;;check-source
(cond 
  [(null? sources-def)  (error "No source files. Please specify source mir files using -s")]
  [else
    ;;set include directories
    (set-include-dirs 
      (map 
          (lambda (l)(get-current-absolute-path l))
          (includes-dir-def)))

    ;;set base-root-dir
    (set-base-root-dir (get-path (root-dir-def)))

    ;;set destination-folder
    (set-destination-folder-name(get-path (dest-dir-def)))

    (define (get-source)
      (map 
          (lambda (l)(get-current-absolute-path l))
          (sources-def)))

    (if (or (show-info-def) (show-mir-info-def))
      (println (get-source-info (get-source) (show-info-def)  (show-mir-info-def) (common-def)))
      (generate-source (get-source) (common-def)))])

  

