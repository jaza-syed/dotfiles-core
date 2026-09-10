# Writing comments

MUST, MUST NOT, SHOULD, SHOULD NOT and MAY carry their RFC 2119 meanings.

## Readers and length

- Comments and docstrings are for human readers. A comment or docstring MUST contain only context that cannot be inferred from the code, and MUST NOT be kept because a model might read it later.
- You MUST follow the Plain Language output style in `~/.claude/output-styles/plain-language.md` when writing a comment or docstring, since both are prose a person may read. Prose is British English, and a code name keeps the code's spelling.
- You SHOULD NOT write a new comment or docstring longer than one sentence (preferably less than one line of code) unless it is absolutely necessary to fulfill the purpose of the comment. You MAY edit existing comments or docstrings longer than one sentence.
- In a long function a one-line comment MAY head each stage.

## Content

- A docstring MUST state what the thing is or does. It MUST NOT narrate how the code below does it and MUST NOT restate the name of the function or field. If the fact is visible on the next line or by grepping the name, write no docstring.
  - `Mint a fresh evaluation-set id.` on `new_evaluation_set_id()` becomes no docstring.
  - `` `**`, not `*`: these globs are minimatch, so `*` stops at a `/` and misses subgroups. `` above `matchRepositories: ["generative/functions/**"]` becomes no comment.
- A docstring for a value, field, property or return MUST be a noun phrase whose head noun names the value. It MUST NOT be a clause headed by "where", "when", "whether", "what" or "how", and a relation MUST use the literal preposition rather than "about".
  - `Where the error is about` becomes `The location of the error in the inputs`.
  - `The shape of a stored view's body. Bump when the body stops being a bare JSON array.` becomes `The version of a stored view's body.`
- You MUST state the fact and stop. You MUST NOT add a clause justifying the fact or describing what would go wrong otherwise, whether after a colon, after "so", or in parentheses, and you MUST NOT detail your own reasoning or design choices. Those belong in your chain of thought.
  - `Tests may pre-set either persistence with a mock before the lifespan runs, so each is decided on its own: pre-setting one neither leaves the other unset nor gets overwritten by building it.` becomes `Tests may pre-set either persistence with a mock before the lifespan runs`.
  - `` Excludes dead evaluations (an upstream failed, so they never sent) and any lacking a `requested_at`/`completed_at` stamp, so each returned entry has honest bounds. `` becomes `` Excludes dead evaluations and any lacking a `requested_at`/`completed_at` stamp. ``
- A comment on a test MUST state the condition the test relies on, not the internals that make it true. If an `assert` checks the condition, put the text in the assertion message instead.
- You MUST NOT refer to the session history, e.g. why we use a given approach instead of an earlier one, or notes to yourself about remaining steps.

## Scope

- A docstring MUST describe the thing it is attached to. It MUST NOT describe where the value comes from, who calls the function, or what a caller does with the result.
- A fact MUST appear once, on the definition it belongs to. A comment MUST be next to the code it describes. A definition that follows the pattern of an existing one MUST NOT explain the pattern again.
- A comment SHOULD state why code exists when its location or its existence is unexpected, e.g. a behaviour inside a function whose name does not suggest it, or code that looks redundant with nearby configuration.
