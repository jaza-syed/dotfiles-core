;; vim: ft=query
;; extends
;; Alabaster highlight query extensions for JavaScript.

(function_declaration
  name: (identifier) @AlabasterDefinition)

(variable_declarator
  name: (identifier) @AlabasterDefinition)

(for_in_statement
  left: (identifier) @AlabasterDefinition)

(field_definition
  [
    (property_identifier)
    (private_property_identifier)
  ] @AlabasterDefinition)

(undefined) @AlabasterConstant
