# -*- coding: utf-8 -*-
# Sphinx configuration for the lab-guides site.
# Mirrors the F5 AppWorld labs template (f5_sphinx_theme) so the rendered site
# matches the production lab-guide look used across F5 training content.
# Markdown sources (docs/labs/*.md) parse via MyST.

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
