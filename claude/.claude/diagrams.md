Dependency diagrams
===================

MUST, MUST NOT, SHOULD, SHOULD NOT and MAY carry their RFC 2119 meanings.

A dependency diagram is a graph whose edges mean "depends on", e.g. flake inputs, module imports, service calls or ticket blockers.

* You MUST draw a dependency diagram as a Mermaid flowchart with this front matter,
  which lays it out with ELK, draws right-angled edges and puts each node one layer below
  the deepest node that depends on it:

  ```
  ---
  config:
    layout: elk
    theme: default
    flowchart:
      curve: step
    elk:
      layeringStrategy: LONGEST_PATH_SOURCE
      considerModelOrder: NODES_AND_EDGES
      forceNodeModelOrder: true
  ---
  flowchart TB
  ```

* An edge MUST point from the dependent to its dependency.
* You MUST declare the nodes in topological order, each node after every node that has an edge to it,
  so that ELK keeps that order within each layer.
* You MUST render the PNG with `mmdc -i <file>.mmd -o <file>.png -s 3 -b white`.
  Mermaid writes its labels as HTML inside the SVG, so a PNG converted from the SVG by ImageMagick has no text.
