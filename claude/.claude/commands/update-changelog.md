---
description: Ensure changelog fragments are up to date for the current branch
---

# Update Changelog

We use an internal tool called [Changeling](https://gitlab.com/generative/infra/changeling) to maintain our changelog.

## Changelog Fragment Guidance

We mostly follow the [Common Changelog](https://common-changelog.org/) standard.

- Only document public-facing changes or significant internal changes that might affect consumers (e.g. a major dependency upgrade).
- Each bullet must be a sentence in the imperative mood (e.g. "Make foo act more bar-like.").
- Use `**Breaking:**` prefix for removals or changes that break backwards compatibility.
- Concisely describe the change from the user's perspective, not the implementation.
- Use nested bullets for complicated changes.
- Read `.editorconfig` and respect the maximum width of the file(s).
- Use [sembr](https://sembr.org/) – one logical phrase per line, unless they are very short.
- Avoid blank lines after h3 headings (and ensure only between consecutive h3s);
  the formatter will normalise some _but not all_ formatting.

### Deviations from the spec

We permit an additional `Patched` category,
which may contain changes that are not obviously public-facing,
yet which maintainers / consumers may care about (e.g. dependency upgrades).

## Instructions

1. Check the changes against the the branch root commit. Sometimes this will not be main, 
   if we are on a stacked feature branch.
2. If not aleady on the feature branch, create a new branch for the feature / bug according to standards and named according to changes.
3. Check if `changelog.d/` exists, and has changelog fragments in it.
4. If required, add a new fragment with `Bash(changeling create)`.
   Prioritise using the CLI's `--fixed` / `--changed` / `--added` etc. flags, as a one-shot flow.
5. If the _changes being documented_ are already committed, then you _must_ commit the fragment.
6. If the _changes being documented_ are staged, then stage the fragment.
