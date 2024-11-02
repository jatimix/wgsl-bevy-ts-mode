;;; -*- lexical-binding: t; -*-
;;; wgsl-bevy-ts-mode.el --- Tree-sitter support
;;; for the WebGPU Shading Language with Bevy extension

;; Copyright (C) 2024 Gplv3
;; Author: Anthony Cowley for the base, someone making it work for bevy
;; URL: https://github.com/acowley/wgsl-ts-mode
;; Package-Requires: ((emacs "29.1"))
;; Keywords: wgsl bevy tree-sitter languages
;; Version: 1.0

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Syntax highlighting for the WebGPU Shading Language (WGSL) based on a tree-sitter grammar.
;;
;; The approach taken here is based on `rust-ts-mode' by Randy Taylor.

;;; Code:

(require 'prog-mode)
(require 'treesit)
(require 'c-ts-common)

(defvar wgsl-bevy-ts-mode--operators
  '("!"  "!=" "%" "%=" "&" "&=" "&&" "*" "*=" "+" "+=" "," "-" "-="
    "->" "." "/" "/=" ":" ";" "<<" "<" "<="
    "=" "==" ">" ">=" ">>" "@" "^" "^=" "|" "|=" "||")
  "WGSL operators for tree-sitter font-locking.")

(defvar wgsl-bevy-ts-mode--keywords
  '("if" "else" "fn" "switch" "case" "break" "default" "loop"
    "continue" "continuing" "for" "let" "var" "return" "struct" "const"
    "type" "while")
  "WGSL keywords for tree-sitter font-locking.")

(defvar wgsl-bevy-ts-mode--preprocessors
  '("#ifdef" "#ifndef" "#else" "#if" "#endif" "#import" "#define_import_path" "#define")
  "WGSL preprocessor keywords for tree-sitter font-locking.")

(defvar wgsl-bevy-ts-mode--builtins
  '(;; Constructor built-in functions
    "array" "bool" "f16" "f32" "i32" "mat2x2" "mat2x3" "mat2x4" "mat3x3"
    "mat3x3" "mat3x4" "mat4x2" "mat4x3" "mat4x4" "u32" "vec2" "vec3" "vec4"
    ;; Bit reinterpretation built-in functions
    "bitcast"
    ;; Logical built-in functions
    "all" "any" "select"
    ;; Array built-in functions
    "arrayLength"
    ;; Numeric built-in functions
    "abs" "acos" "acosh" "asin" "asinh" "atan" "atanh" "atan2" "ceil" "clamp"
    "cos" "cosh" "countLeadingZeros" "countOneBits" "countTrailingZeros"
    "cross" "degrees" "determinant" "distance" "dot" "exp" "exp2"
    "extractBits" "faceForward" "firstLeadingBit" "firstTrailingBit"
    "floor" "fma" "fract" "frexp" "insertBits" "inverseSqrt" "ldexp"
    "length" "log" "log2" "max" "min" "mix" "modf" "normalize" "pow"
    "quantizeToF16" "radians" "reflect" "refract" "reverseBits" "round"
    "saturate" "sign" "sin" "sinh" "smoothstep" "sqrt" "step" "tan" "tanh"
    "transpose" "trunc"
    ;; Derivative built-in functions
    "dpdx" "dpdxCoarse" "dpdxFine" "dpdy" "dpdyCoarse" "dpdyFine" "fwidth"
    "fwidthCoarse" "fwidthFine"
    ;; Texture built-in functions
    "textureDimensions" "textureGather" "textureGatherCompare" "textureLoad"
    "textureNumLayers" "textureNumLevels" "textureNumSamples" "textureSample"
    "textureSampleBias" "textureSampleCompare" "textureSampleCompareLevel"
    "textureSampleGrad" "textureSampleLevel" "textureSampleBaseClampToEdge"
    "textureStore"
    ;; Data packing built-in functions
    "pack4x8snorm" "pack4x8unorm" "pack2x16snorm" "pack2x16unorm"
    "pack2x16float"
    ;; Data unpacking built-in functions
    "unpack4x8snorm" "unpack4x8unorm" "unpack2x16snorm" "unpack2x16unorm"
    "unpack2x16float"
    ;; Synchronization built-in functions
    "storageBarrier" "textureBarrier" "workgroupBarrier" "workgroupUniformLoad"
    ;; Built-in inputs and outputs
    "frag_depth" "front_facing" "global_invocation_id" "instance_index"
    "local_invocation_id" "local_invocation_index" "num_workgroups"
    "position" "sample_index" "sample_mask" "vertex_index" "workgroup_id"
    )
  "WGSL built-in functions from https://www.w3.org/TR/WGSL/")

;; Note: The built-in inputs and outputs should perhaps not be lumped
;; in with the other built-in keywords. They are used in attributes,
;; but classifying them as general built-ins means that any use of
;; these identifiers receives the syntax highlighting of a built-in
;; value rather than a regular identifier.

(setq wgsl-bevy-ts-mode--builtins-hash-table
      (let ((tbl (make-hash-table :test 'equal)))
        (mapc (lambda (x) (puthash x t tbl)) wgsl-bevy-ts-mode--builtins)
        tbl))

(defun wgsl-bevy-ts-mode--is-builtin? (x)
  (gethash (treesit-node-text x) wgsl-bevy-ts-mode--builtins-hash-table))

(defvar wgsl-bevy-ts-mode--font-lock-rules
  `(:language wgsl_bevy
    :override t
    :feature comment
    (([(line_comment) (block_comment)]) @font-lock-comment-face)

    :language wgsl_bevy
    :override t
    :feature bitcast
    ((bitcast_expression) @font-lock-builtin-face)

    :language wgsl_bevy
    :override t
    :feature operator
    (([,@wgsl-bevy-ts-mode--operators]) @font-lock-operator-face)

    ;; :language wgsl_bevy
    ;; :override t
    ;; :feature constant
    ;; ((identifier) @font-lock-constant-face)

    :language wgsl_bevy
    :override t
    :feature constant
    ((import_path) @font-lock-constant-face)

    :language wgsl_bevy
    :override t
    :feature attribute
    ((attribute) @font-lock-preprocessor-face)

    :language wgsl_bevy
    :override t
    :feature type
    ((type_declaration) @font-lock-type-face)
    
    :language wgsl_bevy
    :override t
    :feature funcall
    ((type_constructor_or_function_call_expression) @font-lock-function-call-face)

    :language wgsl_bevy
    :override t
    :feature definition
    ((function_declaration attribute: (attribute) name: (import_path) @font-lock-function-name-face)
     (variable_identifier_declaration name: (identifier) @font-lock-property-name-face))
    
    :language wgsl_bevy
    :override t
    :feature bracket
    ((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)
    :language wgsl_bevy
    :override t
    :feature texel_format
    ((texel_format) @font-lock-builtin-face)

    :language wgsl_bevy
    :override t
    :feature builtin
    ;; (([,@wgsl-ts-mode--builtins]) @font-lock-builtin-face)
    (((identifier) @font-lock-builtin-face
      (:pred wgsl-bevy-ts-mode--is-builtin? @font-lock-builtin-face)))

    :language wgsl_bevy
    :override t
    :feature declaration
    ((struct_declaration) @font-lock-keyword-face)

    :language wgsl_bevy
    :override t
    :feature keyword
    (([,@wgsl-bevy-ts-mode--keywords]) @font-lock-keyword-face)

    :language wgsl_bevy
    :override t
    :feature keyword
    (([,@wgsl-bevy-ts-mode--preprocessors]) @font-lock-preprocessor-face)

    :language wgsl_bevy
    :override t
    :feature address_space
    (([(address_space) (access_mode)]) @font-lock-builtin-face)

    :language wgsl_bevy
    :override t
    :feature number
    (([(float_literal) (int_literal) (const_literal)]) @font-lock-number-face)

    :language wgsl_bevy
    :override t
    :feature constant
    ((bool_literal) @font-lock-constant-face)

    :language wgsl_bevy
    :override t
    :feature delimiter
    ((["," "." ";" ":"]) @font-lock-delimiter-face)
))

(defcustom wgsl-bevy-ts-mode-indent-offset 4
  "Number of spaces for each indentation step in `wgsl-ts-mode'."
  :version "29.1"
  :type 'integer
  :safe 'integerp
  :group 'wgsl_bevy)

(defun wgsl-bevy-ts-mode--standalone-parent-skip-preproc (_n parent &rest _)
  "Like the standalone-parent anchor but skips preproc nodes.
PARENT is the parent of the current node."
  (save-excursion
    (treesit-node-start
     (treesit-parent-until
      ;; Use PARENT rather than NODE, to handle the case where NODE is
      ;; nil.
      parent (lambda (node)
               (and node
                    (not (string-search "preproc" (treesit-node-type node)))
                    (progn
                      (goto-char (treesit-node-start node))
                      (looking-back (rx bol (* whitespace))
                                    (line-beginning-position)))))
      t))))


(defvar wgsl-bevy-ts-mode--indent-rules
  `((wgsl_bevy
     ((node-is "#endif") column-0 0)
     ((node-is "preproc") column-0 0)
     ((parent-is "source_file") column-0 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((and (node-is "}") (parent-is "import_list")) (or great-grand-parent grand-parent) 0)
     ((node-is "}") (and parent parent-bol) 0)
     ((and (parent-is "comment") c-ts-common-looking-at-star)
      c-ts-common-comment-start-after-first-star -1)
     ((parent-is "preproc") wgsl-bevy-ts-mode--standalone-parent-skip-preproc wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "comment") prev-adaptive-prefix 0)
     ((parent-is "arguments") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "assignment_statement") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "array_expression") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "binary_expression") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "compound_statement") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "declaration_list") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "enum_variant_list") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "field_declaration_list") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "field_expression") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "field_initializer_list") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "let_declaration") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "var_declaration") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((node-is "parameter_list") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "parameter") first-sibling 0)
     ((parent-is "import_path") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "import_list") first-sibling 0)
     ((parent-is "argument_list_expression") parent-bol wgsl-bevy-ts-mode-indent-offset)
     ((parent-is "struct_declaration") parent-bol wgsl-bevy-ts-mode-indent-offset)))
    "Tree-sitter indent rules for `wgsl-ts-mode'.")

(defun wgsl-bevy-ts-mode--syntax-propertize (beg end)
  "Apply syntax properties to special characters between BEG and END.

Apply syntax properties to various special characters with
contextual meaning between BEG and END.

The apostrophe \\=' should be treated as string when used for char literals.

< and > are usually punctuation, e.g., as greater/less-than.  But
when used for types, they should be considered pairs.

This function checks for < and > in the changed RANGES and apply
appropriate text property to alter the syntax of template
delimiters < and >'s."
  (goto-char beg)
  (while (search-forward "'" end t)
    (when (string-equal "char_literal"
                        (treesit-node-type
                         (treesit-node-at (match-beginning 0))))
      (put-text-property (match-beginning 0) (match-end 0)
                         'syntax-table (string-to-syntax "\""))))
  (goto-char beg)
  (while (re-search-forward (rx (or "<" ">")) end t)
    (pcase (treesit-node-type
            (treesit-node-parent
             (treesit-node-at (match-beginning 0))))
      (;(or "type_declaration" "type_parameters")
       "type_declaration"
       (put-text-property (match-beginning 0)
                          (match-end 0)
                          'syntax-table
                          (pcase (char-before)
                            (?< '(4 . ?>))
                            (?> '(5 . ?<))))))))

(defun wgsl-bevy-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (pcase (treesit-node-type node)
    ("function_declaration"
     (treesit-node-text
      (treesit-node-child-by-field-name node "name") t))
    ("struct_declaration"
     (treesit-node-text
      (treesit-node-child-by-field-name node "name") t))
    ("type_declaration"
     (treesit-node-text
      (treesit-node-child-by-field-name node "name") t))))

(defvar wgsl-bevy-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?+   "."      table)
    (modify-syntax-entry ?-   "."      table)
    (modify-syntax-entry ?=   "."      table)
    (modify-syntax-entry ?%   "."      table)
    (modify-syntax-entry ?&   "."      table)
    (modify-syntax-entry ?|   "."      table)
    (modify-syntax-entry ?^   "."      table)
    (modify-syntax-entry ?!   "."      table)
    (modify-syntax-entry ?@   "."      table)
    (modify-syntax-entry ?~   "."      table)
    (modify-syntax-entry ?<   "."      table)
    (modify-syntax-entry ?>   "."      table)
    (modify-syntax-entry ?/   ". 124b" table)
    (modify-syntax-entry ?*   ". 23"   table)
    (modify-syntax-entry ?\n  "> b"    table)
    (modify-syntax-entry ?\^m "> b"    table)
    table)
  "Syntax table for `wgsl-ts-mode'.")

(defun wgsl-bevy-ts-setup ()
  "Setup tree-sitter for wgsl-ts-mode."
  (setq-local syntax-propertize-function
              #'wgsl-bevy-ts-mode--syntax-propertize)
  (c-ts-common-comment-setup)

  (setq-local treesit-font-lock-settings
              (apply #'treesit-font-lock-rules
                     wgsl-bevy-ts-mode--font-lock-rules))

  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (keyword string)
                (assignment attribute builtin constant escape-sequence number
                            type address_space texel_format bitcast funcall)
                (bracket delimiter error function operator property variable)))

  (setq-local treesit-simple-imenu-settings
              `(("Struct" "\\`struct_declaration\\'" nil nil)
                ("Fn" "\\`function_declaration\\'" nil nil)))

  (setq-local treesit-font-lock-level 4)
  (setq-local indent-tabs-mode nil
              treesit-simple-indent-rules wgsl-bevy-ts-mode--indent-rules)
  (setq-local treesit-defun-type-regexp
              (regexp-opt '("function_declaration"
                            "struct_declaration")))
  (setq-local treesit-defun-name-function #'wgsl-bevy-ts-mode--defun-name)
  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode wgsl-bevy-ts-mode prog-mode "BevyWGSL[ts]"
  "Major mode for editing WGSL with tree-sitter."
  :syntax-table wgsl-bevy-ts-mode--syntax-table

  (when (treesit-ready-p 'wgsl_bevy)
    (treesit-parser-create 'wgsl_bevy)
    (wgsl-bevy-ts-setup)))

(if (treesit-ready-p 'wgsl_bevy)
    (add-to-list 'auto-mode-alist '("\\.wgsl\\'" . wgsl-bevy-ts-mode)))

(provide 'wgsl-bevy-ts-mode)

;;; wgsl-bevy-ts-mode.el ends here
