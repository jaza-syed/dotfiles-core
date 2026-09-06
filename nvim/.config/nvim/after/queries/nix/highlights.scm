;; vim: ft=query
;; extends
;; Keep interpolations visually inside Nix strings: green string background,
;; neutral foreground for the inline expression.
((interpolation) @AlabasterStringInterpolation
 (#set! priority 105))
