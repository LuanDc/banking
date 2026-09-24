---
name: conventional-commits
description: Write git commit messages following the Conventional Commits 1.0.0 spec. Use whenever creating a git commit in this repository, when the user asks to commit, or when asked to write/review a commit message.
---

# Conventional Commits

Every commit in this repository MUST follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

## Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

## Types

| Type       | When to use                                                        |
|------------|--------------------------------------------------------------------|
| `feat`     | New feature visible to users/consumers of the API                  |
| `fix`      | Bug fix                                                            |
| `refactor` | Code change that neither fixes a bug nor adds a feature            |
| `perf`     | Performance improvement                                            |
| `test`     | Adding or fixing tests only                                        |
| `docs`     | Documentation only                                                 |
| `style`    | Formatting only (`mix format`), no logic change                    |
| `build`    | Dependencies, `mix.exs`, `mix.lock`, build tooling                 |
| `ci`       | CI configuration (GitHub Actions, etc.)                            |
| `chore`    | Maintenance that doesn't touch src/test (configs, gitignore, etc.) |
| `revert`   | Reverts a previous commit                                          |

## Scopes

Optional, lowercase, naming the affected area. Prefer the domain context or layer, e.g.:
`accounts`, `transactions`, `ledger`, `web`, `repo`, `migrations`, `deps`, `config`, `tooling`.

## Rules

1. **Subject**: imperative mood ("add", not "added"/"adds"), lowercase first letter, no trailing period, max 72 chars for the whole header.
2. **Language**: write the message in English.
3. **Body** (optional): explain *what* and *why*, not *how*. Wrap at 72 chars. Separate from header by a blank line.
4. **Breaking changes**: add `!` after type/scope (`feat(api)!: ...`) AND a footer `BREAKING CHANGE: <description>`.
5. **Footers**: `Refs: #123`, `Closes: #123`, `Co-Authored-By: ...`.
6. **One logical change per commit.** If the staged diff mixes unrelated changes (e.g. a feature plus a dependency bump), split it into separate commits.

## Workflow

1. Run `git status` and `git diff --staged` (or `git diff` if nothing is staged) to see the actual change.
2. Pick the type from the table based on the dominant intent of the change.
3. Pick a scope from the affected area (omit if the change is truly cross-cutting).
4. Write the header; add a body only if the *why* isn't obvious from the header.
5. Commit using a HEREDOC to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
feat(transactions): add double-entry validation on transfer

Rejects transfers whose debit and credit entries don't sum to zero,
guaranteeing the ledger stays balanced.

Refs: #12
EOF
)"
```

## Examples

```
build(deps): add credo, dialyxir and excoveralls
feat(accounts): create account schema and migration
fix(transactions): prevent negative balance on concurrent debits
refactor(ledger): extract entry builder into its own module
test(accounts): cover account creation with invalid currency
chore: initialize phoenix project
feat(api)!: return amounts as integer cents

BREAKING CHANGE: `amount` fields are now integers in cents instead of decimal strings.
```

## Don'ts

- `update stuff`, `fix`, `wip`, `changes` — never.
- Past tense (`added`, `fixed`).
- Capitalized subject or trailing period.
- Bundling unrelated changes in one commit.
