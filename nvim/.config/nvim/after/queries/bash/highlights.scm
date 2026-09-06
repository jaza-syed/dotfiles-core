;; vim: ft=query
;; extends
;; Alabaster highlight query extensions for Bash.

(function_definition
  name: (word) @AlabasterDefinition)

((program . (comment) @AlabasterHashbang)
 (#match? @AlabasterHashbang "^#!/"))
