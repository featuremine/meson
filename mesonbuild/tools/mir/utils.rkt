
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
(require "core.rkt")
(provide
    get-module-relative-path
    get-relative-path
    get-module-absolute-path
    get-current-absolute-path
    comment)

;slice list from start by offset
(define (slice l offset)
  (if (> offset 0)  (slice (cdr l) (- offset 1)) l))

;build return symbols "../" n times
(define (build-return-path-list  l offset)
   (if (> offset 0)  (build-return-path-list (append  (list (build-path "../")) l  ) (- offset 1)) l))

;build relative path from one path to another
(define (get-relative-path from to)
    (let ([f (explode-path (build-path from))]
          [t (explode-path (build-path to))]
          [b (explode-path (get-base-root-dir))])
            (let ([f2 (slice f (length b))]
                  [t2 (slice t (length b))])
                    (apply build-path (build-return-path-list t2 (length f2))))))

;return relative path for module from its absolute path
(define (get-module-relative-path module)
  (if (module-def-stx module) 
    (let ([mp (explode-path (get-module-path module))]
          [br (explode-path (get-base-root-dir))])
       (apply build-path(slice mp (length br))))
     (build-path ".")))  

;return module absolute path by its relative
(define (get-module-absolute-path rp)
    (if (relative-path? rp)
        (let ([file #f])
            (map (lambda(p)
              (let ([calc-file (simplify-path  (build-path p rp))])
                (if (file-exists? calc-file)  
                  (set! file (path->string calc-file))
                  #f))) 
            (append (get-include-dirs) (list (get-base-root-dir) (current-directory))))
            (if (not file) 
                  (error (format "can't found file ~a in include directories" rp))
                  file))
        (file-exists? rp rp (error (format "can't found file ~a in include directories" rp)))))

;return absolute path for relative path
(define (get-current-absolute-path rp)
    (if (relative-path? rp)
        (path->string (simplify-path  (build-path (current-directory) rp)))
        rp))

;create commented block from list of strings or single string
(define (comment vars)
  (string-append 
    "/**\n"
      (if (list? vars)
        (apply string-append 
          (map 
            (lambda (var) 
              (format "* ~a\n" var))
            vars))
        vars)
    "*/\n"))