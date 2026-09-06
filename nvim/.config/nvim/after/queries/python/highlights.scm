;; vim: ft=query
;; extends
;; Alabaster highlight query extensions for Python.

(function_definition
  name: (identifier) @AlabasterDefinition)
(class_definition
  name: (identifier) @AlabasterDefinition)

; Treat standalone string statements as docstrings so they don't inherit the
; normal string background tint.
(expression_statement
  (string) @AlabasterDocString)

((module . (comment) @AlabasterHashbang)
 (#match? @AlabasterHashbang "^#!/"))

(decorator
  (identifier) @AlabasterBase)

; ALL_CAPS names used in type positions (annotations, subscripts) are tagged
; @constant by the stock ALL_CAPS heuristic. The @type capture then wins the
; fg but not the bg, so the constant background tint leaks under type names
; (blue-on-purple in light themes). Re-tag them as a type reference whose
; explicit bg clears the tint. Guarded to type ancestors, so real constants
; and type-alias definitions (which are not under a `type` node) are untouched.
((identifier) @AlabasterTypeRef
  (#lua-match? @AlabasterTypeRef "^%u[%u%d_]*$")
  (#has-ancestor? @AlabasterTypeRef "type"))
