# Writing comments

MUST, MUST NOT, SHOULD, SHOULD NOT and MAY have their RFC 2119 meanings.

## Scope and length

- Comments and docstrings are for human readers. A comment or docstring MUST only contain context that cannot be inferred from the code and MUST NOT be kept because a model might read it later.
- You MUST follow the Plain Language output style in `~/.claude/output-styles/plain-language.md` when writing a comment or docstring, since both are prose a person may read.
- A new comment or docstring SHOULD state one or two facts, each in a sentence of its own. You MAY edit existing comments or docstrings that state more.
- A fact MUST appear once, on the definition it belongs to. A definition that follows the pattern of an existing one MUST NOT explain the pattern again.
- You MUST update or delete any comment or docstring that a change makes false and you MUST NOT refer to the session history, e.g. why the code takes a given approach instead of an earlier one, or leave notes to yourself about remaining steps.

## Docstrings

- Before you write a one-line docstring, you SHOULD check whether a slightly longer function or field name, clearer parameter names or an enum or custom type can say the same thing in the signature. If it can, change the name or type and do not write a docstring:
  - Delete `Mint a fresh evaluation-set id.` on `new_evaluation_set_id()` because the function name already says it.
  - Replace a docstring that explains a boolean parameter or a `String` or `Dict`, e.g. `True to include archived items`, with an enum, a custom type or a more specific parameter name.
  - A qualifier that recurs across a module's docstrings, e.g. "of the default evaluation", names a missing module or type.
- A docstring MUST only state what the symbol returns, does or guarantees for its callers. It MUST NOT narrate how the body does it. A sentence narrates the body if rewriting the body without changing what callers see would make the sentence false. A docstring MUST NOT have the name or signature as its whole content, and MUST NOT describe where a value comes from, who calls the function or what a caller does with the result. If the fact is visible on the next line or by grepping the name, do not write a docstring.
- The first line of a function or method docstring MUST open with a verb in the third person. The first line of a class docstring MUST be a sentence that states what the class does or guarantees. Neither MAY open with a noun phrase that defines the symbol:
  - `A task group that cancels its tasks.` becomes `The task group cancels its tasks.`
  - `Keep the session of a dead owner open, as a process that died behind a half-open connection leaves it, until Postgres would end it.` becomes `Models an owner process that crashed without closing its connection.`
- A docstring for a constant, attribute or property MAY be a noun phrase or a "Whether …" phrase. The phrase MUST add a property that the name lacks, such as a unit, a range or a scope, and MUST NOT have more than one relative clause. The noun before the relative clause MUST be the actor in it. The phrase MUST NOT be a clause headed by "where", "when", "what" or "how" and a relation MUST have the literal preposition rather than "about":
  - `Where the error is about` becomes `The location of the error in the inputs`.
  - `The shape of a stored view's body. Bump when the body stops being a bare JSON array.` becomes `The version of a stored view's body.`
- In a docstring you MUST state the fact and stop. You MUST NOT add a clause justifying the design or describing what would go wrong otherwise, whether after a colon, after "so" or in parentheses. When the main clause narrates and the "so" clause states what a caller relies on, keep the "so" clause as the fact:
  - `` Excludes dead evaluations (an upstream failed, so they never sent) and any lacking a `requested_at`/`completed_at` stamp, so each returned entry has honest bounds. `` becomes `` Excludes dead evaluations and any lacking a `requested_at`/`completed_at` stamp. ``
  - `The task's hash is its creation order, so a set of tasks iterates in the same order on every run.` becomes `A set of these tasks iterates in the same order on every run.`

## Inline comments

- If the purpose of code is visible from the lines around it or from standard syntax, do not write an inline comment:
  - Delete `` `**`, not `*`: these globs are minimatch, so `*` stops at a `/` and misses subgroups. `` above `matchRepositories: ["org/services/**"]`.
- You SHOULD only write an inline comment when a line's location or existence is unexpected, e.g. a behaviour that the function's name does not suggest, a workaround, or code that looks redundant with nearby configuration. Place the comment next to the code it describes and state the constraint without narrating how the rest of the code works:
  - `Tests may pre-set either persistence with a mock before the lifespan runs, so each is decided on its own: pre-setting one neither leaves the other unset nor gets overwritten by building it.` becomes `Tests may pre-set either persistence with a mock before the lifespan runs`.
- Put a reason where the person who needs it reads. A reason for a line that looks wrong goes in an inline comment on that line, and a reason that defends the design against an alternative goes in the commit message. When a caller relies on the consequence, the docstring states the consequence as a fact:
  - `The scheduler does not cancel a dead owner's statement, because a dead process cannot cancel its statement.` becomes the docstring sentence `A dead owner's statement runs to its end.` and the comment `# A dead process cannot cancel its statement` on the `is_refused()` line.
- In a long function a one-line comment MAY head each stage.
- A comment on defensive code SHOULD be an imperative that states the outcome, e.g. `# Ensure nothing left on S3` on a shielded cleanup, rather than the failure it prevents.
- A comment on a test MUST state the condition the test relies on rather than how the code makes that condition hold. If an `assert` checks the condition, put the text in the assertion message instead.
