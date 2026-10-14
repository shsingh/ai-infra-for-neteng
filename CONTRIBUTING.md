# Contributing

Contributions are welcome. This document defines the working agreement: how changes are
proposed, reviewed, and merged, and what the CI gates enforce.

## Ground rules

1. **Never commit to `master` directly.** All work happens on a branch, one logical
   change per branch, merged via pull request. Branch names follow
   `<type>/<short-description>` in kebab-case — e.g. `feat/m8-blast-app`,
   `fix/frr-neighbor-port`, `docs/lab07-guide`.
2. **Conventional Commits.** Every commit message, pull-request title, and issue title
   follows the [specification](https://www.conventionalcommits.org/en/v1.0.0):
   `type(scope): subject`.
   - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, `chore`.
   - `scope` is the component: a module (`m01`…`m13`, the `docs/course/modules/` files), a
     directory (`apps`, `manifests`, `fabric`, `docs`, `course`), or a surface
     (`readme`, `facilitator`, `plan`).
   - Subject: imperative, lowercase, no trailing period. Body (optional): what changed
     and why; wrap at 72 columns.
3. **Sign commits.** Commits must be GPG-signed or SSH-signed. Unsigned commits are
   not merged. Verify locally with `git log --show-signature`.
4. **Never merge a pull request authored by the same contributor.** Build agents open PRs with green CI; the
   repository owner reviews and merges.
5. **Secrets never enter the repo.** Credential material (image-pull secret tarball,
   license JWT) lives in the gitignored `keys/` directory. The gitleaks hook and the
   secret-scanning gates below enforce this.
6. **Expected outputs are captured, never invented.** Every expected output quoted in a
   lab guide comes from an actual captured run stored under `docs/expected/`. Guides are
   frozen only after their commands have executed against the running cluster.
7. **No standalone shell scripts.** The only scripted surface is Nix (`flake.nix`,
   `apps/*.nix`, `pkgs/*.nix`). Anything a shell script would do becomes a Nix app.

## Content and code boundaries

- Student-facing guides (`docs/labs/`) are generated artifacts layered over the content
  system of record in `docs/course/` and the captured outputs in `docs/expected/`. Content
  fixes go to `docs/course/`; behavior fixes need a new capture.
- Manifests validate against the deployed CRDs, not documentation alone
  ([PLAN §6](PLAN.md#6-manifest-specifications)).
- Features labelled Early Access stay demo-only in guides and apps
  ([the honesty rule](docs/course/planes-and-analogies.md#honest-scoping-standing-rule)).

## CI gates

| Check | Enforces |
|---|---|
| `pre-commit` / pre-commit.ci | formatting, YAML/JSON/TOML validity, end-of-file, trailing whitespace, case conflicts, large files, private-key detection, [gitleaks](https://github.com/gitleaks/gitleaks) secret scan |
| Docs build (when Site workflow is enabled) | the lab guides site renders from `docs/course/` + `docs/` |

Run the hook set locally:

```
pre-commit run --all-files
```

## Security-sensitive changes

- Report vulnerabilities privately per [SECURITY.md](SECURITY.md) — never in public
  issues.
- Changes to `keys/`-adjacent tooling, the credential checks in `apps/bootstrap.nix`, or
  the secret-scanning configuration require extra review.

## Licensing

Contributions are licensed under the repository's LICENSE (MIT) upon acceptance.
