;; vim: ft=query
;; extends
;; Alabaster highlight query extensions for TypeScript.

(interface_declaration
  name: (type_identifier) @AlabasterDefinition)

(class_declaration
  name: (type_identifier) @AlabasterDefinition)

(method_definition
  name: (property_identifier) @AlabasterDefinition)

(method_signature
  name: (property_identifier) @AlabasterMethodDeclaration)

(function_declaration
  name: (identifier) @AlabasterDefinition)

(variable_declarator
  name: (identifier) @AlabasterDefinition)

(for_in_statement
  left: (identifier) @AlabasterDefinition)

(type_alias_declaration
  name: (type_identifier) @AlabasterDefinition)

(undefined) @AlabasterConstant
