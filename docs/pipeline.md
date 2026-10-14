# Documentation pipeline

Contents (AppWorld-pattern Sphinx site, matching the F5 production lab-guide look):
- `conf.py` — Sphinx config with the `f5_sphinx_theme` (the same theme family as
  clouddocs.f5.com and the F5 AppWorld labs template); markdown parsed via MyST.
- `index.rst` — landing page with the toctree (`labs/*`).
- `labs/` — one guide per module (task-based format). Currently placeholders; produced
  in build stage 9 of `PLAN.md` from the module scripts in `course/` plus captured
  outputs in `expected/`.
- `expected/` — captured command outputs; the ONLY source of expected results in guides
  (excluded from the site build).
- `requirements.txt` — pinned Sphinx/theme toolchain.

Two render paths, identical output:

1. **Local (offline-capable)**: the `apps.docs` Nix app — `nix run .#docs` — builds the
   site with the Sphinx toolchain pinned in the flake. After loading the offline bundle
   no network is needed.
2. **CI**: the docs workflow (`.github/workflows/docs.yml`) builds on every PR touching
   `docs/` or `course/`, and deploys GitHub Pages on master.


Verify before pushing (from `docs/`): `make html` (or `nix run .#docs` once the flake
lands). Guide freezes follow the captured-output contract in `PLAN.md §7`. The site renders
from `docs/` only; the `course/` sources are linked by path reference, not by site
link, because they must remain viewable in-repo regardless of the rendered site.

Theme note: the site uses the local wrapper theme `_themes/f5-neteng-theme` — derived from
`f5_sphinx_theme` 2.9.5 (Apache-2.0 headers preserved) whose changes make it work
outside the clouddocs.f5.com webserver root (GitHub Pages project sites) and fully
offline: CSS/JS paths moved from webserver-root `/assets/...` to the theme-shipped
`_static/...` files, Coveo cloud-search dropped (browser search only), analytics and
remote header/footer fetches removed, and all browser assets (mermaid 11.12.1, d3 7.9.0,
jQuery, mark.js, font-awesome, F5 fonts/images) vendored under `docs/_static/vendor/`,
`docs/_static/fonts/`, and the theme static dirs — no CDN dependency on any page.
Regenerate the vendored copies only when bumping the upstream theme or mermaid versions.

Preview: `make html` then serve over http — `python3 -m http.server -d _build/html 8000`
(not `file://` — mermaid and the sidebar scripts need http(s) to run; over file:// diagrams
show as code, exactly like viewing the markdown on GitHub).
