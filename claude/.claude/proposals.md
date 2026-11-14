Guidance for design proposals
=============================

MUST, MUST NOT, SHOULD, SHOULD NOT and MAY carry their RFC 2119 meanings.

This covers proposals and agreements for an API or data model between services.


Before starting
---------------

* When I start working on a design, you MUST ask me, in the light of the context I have given you:
  1. how I want the document to be structured,
  2. what I am trying to trade off, and
  3. who the audience is, and how the audience affects the structure and the trade-offs.
* Ask these before you draft anything, and shape the document by my answers.


Mindset
-------

* Before writing, list the questions this reader will ask when they work with the proposal.
  Take the questions from the reader's job, not from the order in which you worked the problem out.
* Open with one sentence that states the question and its constraints,
  then state the core idea, with a diagram if the idea has a structure.
* Give each reader question one short answer in a table or list,
  so the reader can find their own question without reading the rest.
* Cut the account of how you reached the proposal. Keep only the text that answers a question.


Shape
-----

* A proposal MUST propose one option.
  List the alternatives considered in one line each, with the reason each was not taken.
* Open each option with its core idea in one sentence, then a diagram.
* Explain the implications as lenses rather than long prose:
  a table of the questions a developer would ask when working with the proposal, each with a short answer.
  Typical lenses are what references what, where each field is stored, routing and shared links,
  how a thing shows up before it fully exists, new versions, a failed write,
  and future cases such as running twice, duplicating or iterating in place.
* When a new question comes up, add a row to the lenses table rather than a new section.
  When a section grows long, replace it with lenses.
* Move points nobody disputes out of the discussion list and into decisions,
  so that meeting time goes on the open ones.


Content
-------

* Prefer the design with the fewest new concepts.
  Reuse existing structures and special-case them where they show up, rather than add a parallel type.
* State permissions plainly: who can read each thing, who can act on it, and what other users see.
* Give request and response bodies as JSON with JSON5 comments, not prose.
* Show data model changes as diagrams that show the foreign keys, not as SQL.
* Check each claim about current behaviour against the code, and mark any claim you have not checked.
* Once the proposal is agreed, the agreement document is the source of truth for the tickets,
  over notes and over code that lags it.
