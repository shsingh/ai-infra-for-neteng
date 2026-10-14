# -*- coding: utf-8 -*-
# Sphinx configuration for the lab-guides site.
# Mirrors the F5 AppWorld labs template (f5_sphinx_theme) so the rendered site
# matches the production lab-guide look used across F5 training content.
# Markdown sources (docs/labs/*.md) parse via MyST.
#
# Asset policy (offline contract, PLAN §4.1 / §8.2.1): every browser asset is
# served from _static — no CDN, no analytics, no third-party favicon. Vendored
# copies live under _static/vendor/ and _static/fonts/.
#
# NOTE: font-awesome + jQuery + mark.js load via _themes/f5-neteng-theme/head.html;
# the CDN URLs there point at the vendored copies. Keep both sides in sync.

import os
import sys
import time

classname = "AI Infrastructure for Network Engineers"
github_repo = "https://github.com/shsingh/ai-infra-for-neteng"

smartquotes = False
year = time.strftime("%Y")

# -- Project information -----------------------------------------------------

project = classname
author = "ai-infra-for-neteng contributors"
copyright = "%s, %s" % (year, author)
version = ""
release = ""

# -- General configuration ---------------------------------------------------

extensions = [
    "sphinx.ext.extlinks",
    "sphinx_copybutton",
    "sphinxcontrib.mermaid",
    "myst_parser",
]

source_suffix = [".rst", ".md"]

myst_enable_extensions = ["colon_fence", "deflist", "tasklist"]
myst_fence_as_directive = ["mermaid"]  # render ```mermaid fences (GitHub-compatible) as diagrams
myst_heading_anchors = 3

templates_path = ["_templates"]
exclude_patterns = ["_build", "README.md", "pipeline.md", "requirements.txt", ".DS_Store", "expected/*"]

pygments_style = "sphinx"

# AppWorld-style substitution prolog
rst_prolog = """
.. |classname| replace:: %(cls)s
.. |classbold| replace:: **%(cls)s**
.. |year| replace:: %(year)s
.. |repoinfo| replace:: The content contained here is sourced from the GitHub
              repository at %(repo)s. Bugs and enhancement requests can be made
              by opening an issue in the repository.
""" % {"cls": classname, "year": year, "repo": github_repo}

extlinks = {
    "issues": ("%s/issues/%%s" % github_repo, "issue "),
}

# -- Vendored browser assets (offline contract) -------------------------------
# sphinxcontrib-mermaid accepts local absolute paths for its asset overrides;
# the vendored mermaid.esm.min.mjs imports its chunks relative to its own file,
# so no shim is needed. ELK is not used by any diagram and is not vendored.

mermaid_version = "11.12.1"      # kept for the asset ?v= hash; file resolved locally below
mermaid_use_local = "vendor/mermaid.esm.min.mjs"   # add_js_file prepends _static/; Sphinx links it depth-correct
mermaid_include_elk = ""         # ELK layout pack not used by any diagram ("" => no ELK script)
mermaid_d3_version = "7.9.0"
d3_use_local = "vendor/d3.min.js"

# -- Options for HTML output -------------------------------------------------

html_theme = "f5-neteng-theme"
html_theme_path = [os.path.abspath("_themes")]
html_sidebars = {"**": ["searchbox.html", "localtoc.html", "globaltoc.html"]}
html_theme_options = {
    "site_name": "AI Infrastructure for Network Engineers - Lab Guides",
    "next_prev_link": True,
}
html_last_updated_fmt = "%Y-%m-%d %H:%M:%S"

html_context = {
    "github_url": github_repo,
    "github_branch": "master",
}

html_static_path = ["_static"]
