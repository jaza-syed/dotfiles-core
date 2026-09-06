;; vim: ft=query
;; extends
;; Alabaster highlight query extensions for Elm.

;; Functions
(type_annotation
  (lower_case_identifier) @AlabasterDefinition)

(function_declaration_left
  (lower_case_identifier) @AlabasterDefinition)

(port_annotation
  (lower_case_identifier) @AlabasterDefinition)

;; Types
(type_declaration
  (upper_case_identifier) @AlabasterDefinition)

(type_alias_declaration
  name: (upper_case_identifier) @AlabasterDefinition)
