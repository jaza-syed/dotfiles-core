Guidance for Linear tickets
===========================

MUST, MUST NOT, SHOULD, SHOULD NOT and MAY carry their RFC 2119 meanings.


Content
-------

* A ticket MUST NOT name code, such as classes, modules, functions, ports or files, unless the ticket is unclear without it.
  When a developer needs a starting point, name that one place and nothing else.
* A title MUST be an action that says what changes, and it MUST make sense on its own,
  e.g. "Show the agent panel on an agent's resource" rather than "Agent resource component".
* A word MUST keep its meaning in the codebase.
  A component is a UI element, so logic with nothing to see is not a component.
* A ticket MUST contain only what its acceptance criteria need. Cut background, history and restatements.
* A ticket MUST NOT have a Dependencies or Relations section.
* Check each claim against the code and the agreed design before writing it into a ticket.
  Where the code lags the design, the design decides what the ticket asks for.


Splitting work
--------------

* Split work by what can be built and tested on its own,
  e.g. logic with unit tests in one ticket and the UI that shows it in the next.
* Work that fits in one merge request SHOULD be one ticket.
* Read the code for scope that no ticket covers, e.g. a page that needs data only another page loads.


Dependencies
------------

* Record dependencies only as Linear relations.
* Link only direct blockers. A blocker that another blocker already reaches MUST NOT get its own link.
* "Blocked by" MUST mean the ticket can't be built or tested without the other.
  Two tickets that change the same file only need an order,
  and a ticket that only an end-to-end test needs blocks the end-to-end ticket.


Prompting the Linear agent
--------------------------

* A prompt MUST name the exact tickets to change and MUST say to change nothing else,
  including status, assignee, milestone, labels, priority, estimate and cycle.
* A prompt MUST give each title exactly, and each description verbatim between START and END markers,
  and MUST tell the agent to copy it without rewording.
* A prompt MUST list each link to add, with its URL, and MUST say to add no others.
* A prompt MUST tell the agent to stop and report when a step fails, and to report the result at the end.
* A prompt MUST refer to tickets by their Linear identifiers, never by planning numbers such as "T5".
* Check that a ticket still exists before linking it.
* After the agent runs, read the tickets back from Linear and check them against the prompt,
  because the agent adds links nobody asked for.
