# Documentation pipeline

Contents:
- `mkdocs.yml` (at the repository root) — the lab-guides site (mkdocs-material).
- `index.md` — class intro: environment variables, the guide list.
- `labs/` — one guide per module (task-based AppWorld format). Currently placeholders;
  produced in build stage 9 of `PLAN.md` from the module scripts in
  `course/` plus captured outputs in `expected/`.
- `expected/` — captured command outputs; the ONLY source of expected results in guides.

Two render paths, identical output:

1. **Local (offline-capable)**: the `apps.docs` Nix app — `nix run .#docs` — renders
   with the mkdocs-material version pinned in the flake. After loading the offline
   bundle no network is needed.
2. **CI**: the docs workflow (`.github/workflows/docs.yml`)
   builds on every PR touching `docs/` or `course/`, and deploys GitHub Pages on
   master.

Verify before pushing: `mkdocs build --strict` from the repository root (or
`nix run .#docs` once the flake lands). Guide freezes follow the honesty contract in
`PLAN.md §7`. The site renders from `docs/` only — the `course/` sources are linked by
path reference, not by site link, because they must remain viewable in-repo regardless
of the rendered site.
