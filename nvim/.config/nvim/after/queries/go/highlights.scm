;; vim: ft=query
;; extends
;; Alabaster highlight query extensions for Go.

(package_clause
  (package_identifier) @AlabasterDefinition)

(const_declaration
  (const_spec
    name: (identifier) @AlabasterDefinition))

(function_declaration
  name: (identifier) @AlabasterDefinition)

(method_declaration
  name: (field_identifier) @AlabasterDefinition)
