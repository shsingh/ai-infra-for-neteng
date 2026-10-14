# AGENTS.md — Lab Repo Operating Contract

This file is the operating contract for any autonomous coding agent working in this
repository. Read it together with `PLAN.md`, which contains the full work plan, per-module
specifications, pins, and acceptance gates — and `docs/course/README.md`, the entry point to
the content system of record (the case study, the teaching model, and the per-module
scripts that explain how and why the course teaches what it teaches). If files disagree,
`PLAN.md` wins on build questions and `docs/course/` wins on content questions; raise any
real discrepancy as a repo issue.

## What this repository is

`ai-infra-for-neteng` is the public lab repository for the instructor-led course
**AI Infrastructure for Network Engineers** (BIG-IP Next for Kubernetes 2.4 edition). When
the build is complete, cloning this repo onto a plain Linux amd64 VM and running:

```text
git clone https://github.com/shsingh/ai-infra-for-neteng.git
cd ai-infra-for-neteng
nix run .#bootstrap
nix develop
nix run .#doctor
```

stands up the complete lab environment — no other tooling installed by hand except Docker
and Nix itself. The repository also renders the student lab guides (AppWorld-style,
task-based) to GitHub Pages, and an offline bundle mode (`airgap-bundle`) makes the VM
fully self-sustained: environment, guides, and locally rendered docs run with no internet
connection.

The course teaches: Kubernetes for network engineers, BNK (BIG-IP Next for Kubernetes) 2.4
installation in demo mode, BGP/VRF/EVPN routing via CRDs, Gateway API ingress, traditional
L4/LB and firewall services, AI inference routing with InferencePool and the F5 Endpoint
Picker (F5EPP), observability, and optional modules (bnk-forge GUI, OSS-vs-BNK analysis,
prompt-security screening, multi-tenant token governance).

## Mission for the build agent

Build, in order, and verify against a running environment:

1. **The lab environment automation** — a Nix flake with pinned tools (kind, kubectl, helm,
   jq, yq, kindbnkctl), one app per course step (`apps/`), validated YAML manifests in
   course order (`manifests/`), an FRR fabric-peer container (`fabric/`), fault injection
   (`nix run .#break-fix`), and a bootstrap app that takes a bare VM to a green doctor board.
2. **The lab guides** — one guide per module under `docs/labs/`, in the task-based format
   defined in [PLAN — Lab guides](PLAN.md#7-lab-guides-appworld-format), rendered by Sphinx (f5_sphinx_theme — the AppWorld/clouddocs look) to GitHub Pages
   via GitHub Actions and locally on the lab VM (`nix run .#docs`, offline-capable).
3. **The operating contract** — bootstrap / sync / reset / teardown commands as specified in
   [PLAN — Environment contract](PLAN.md#8-environment-contract-init-sync-reset), plus `README.md` (student quickstart) and `FACILITATOR.md` (T-minus checklist,
   version ledger, credentials how-to).

## Non-negotiable rules

1. **Never commit secrets.** The two credential files (an image-pull secret tarball and a
   license JWT) belong in `keys/`, which is gitignored from the first commit. Never read,
   print, move, or copy their contents. If they are missing, tooling must fail with a human
   message pointing at `FACILITATOR.md`. Agents never request or handle credentials.
2. **No standalone shell scripts in the repo.** The only scripted surface is Nix (`flake.nix`,
   `apps/*.nix`, `pkgs/*.nix`). Anything a shell script would do becomes a Nix app.
3. **Expected outputs are captured, never invented.** Every expected output quoted in a lab
   guide comes from an actual captured run stored under `docs/expected/`. Guides are frozen
   only after their commands have executed against the running cluster.
4. **Branch protection: never merge your own pull request.** Work happens on feature
   branches; open PRs for review; the repository owner merges. CI (`nix flake check`,
   manifest validation, docs build) must be green before a PR is opened.
5. **Stop conditions.** If the pinned deployer cannot be made to deliver BNK 2.4.0 (see the
   release-manifest override in [PLAN — Version pins](PLAN.md#5-version-pins)), stop and surface the failure — never build the
   course on an older BNK release and never silently substitute feature behavior. Likewise
   stop if a manifest's documented fields do not validate against the actually-deployed CRDs.
6. **x86_64 only.** The F5 container images are published for linux/amd64. Every host, VM,
   and preflight asserts amd64; do not attempt arm64.
7. **Idempotent everything.** Every Nix app: (1) prints what it will do and why, (2) runs,
   (3) verifies, (4) prints expected output. Safe to re-run. All waits poll status with a
   timeout, never wall-clock guesses.
8. **Progress discipline on long operations** (bootstrap, traffic blast): print progress at
   least every 50 items or 30 seconds, with success and fail counts.
9. **Immutability.** The routing CRDs and `poolRef` on F5EPP are immutable: changes are
   delete-and-recreate. Tooling implements this; nothing patches these fields in place.
10. **Honest scoping.** Features that are Early Access (semantic caching) or outside the
    demo-mode shape (DPU, SR-IOV, GRPCRoute) appear as demo/slides material only; guides say
    so explicitly.

## Target repository tree

```text
ai-infra-for-neteng/
├── AGENTS.md                 # this file
├── PLAN.md                   # the full work plan (source of truth for the build)
├── README.md                 # student quickstart
├── FACILITATOR.md            # T-minus checklist, drills, version ledger, keys/ how-to
├── LICENSE
├── .gitignore                # keys/, reports/, artifacts/ from the first commit
├── flake.nix / flake.lock
├── pkgs/                     # kindbnkctl.nix, gaie-crds.nix, spine-image.nix, course-libs.nix
├── apps/                     # bootstrap, deploy, doctor, sync, m1..m13, break-fix, timing,
│                             # report, reset, ocp-demo, teardown
├── devShells/default.nix
├── manifests/                # 00..15 + bgp/ — plain YAML, applied by hand, in course order
├── fabric/                   # spine image derivation + frr.conf
├── docs/                     # sphinx site (conf.py, index.rst) + course/ (content
│                             # system of record) + labs/ + expected/
└── reports/                  # gitignored: build + scenario reports
```

The complete tree, per-file purpose, and per-manifest key fields are specified in [PLAN — Repository layout](PLAN.md#4-repository-layout)
and [PLAN — Manifest specifications](PLAN.md#6-manifest-specifications).

## Command contract

| Command | Purpose |
|---|---|
| `nix run .#bootstrap` | preflight → image pre-pull → kind+BNK deploy (2.4.0 override) → GAIE CRDs → fabric spine → doctor |
| `nix run .#doctor` | environment green board; the arbiter of "ready to teach" |
| `nix develop` | pinned student shell (KUBECONFIG, kind/kubectl/helm/jq/yq) |
| `nix run .#sync` | repo-to-cluster sync: dry-run, apply changed manifests, drift report |
| `nix run .#break-fix -- <id> apply\|restore` | inject/restore a taught fault (8 faults, [PLAN — Fault injection](PLAN.md#64-fault-injection-8-faults-apply--taught-diagnosis--exact-inverse-restore)) |
| `nix run .#reset -- <module>` | return a module to pristine state |
| `nix run .#teardown` | symmetric destroy |

Per-module apps (`m1-orient` … `m13-breach`) are specified in [PLAN — Per-module apps](PLAN.md#83-per-module-apps-course-order).

## Current status

Update this section as stages complete, referencing [PLAN — Build order](PLAN.md#9-build-order-stages-and-exit-gates) (Stage 0 … Stage 10).

| Stage | Scope | Status |
|---|---|---|
| 0 | Repo created; AGENTS.md + PLAN.md + .gitignore committed | **done** (pre-commit + governance live; merged) |
| 1 | Flake skeleton + doctor | not started |
| 2 | BNK 2.4.0 install path (risk stage; do first among build stages) | not started |
| 3 | GAIE CRDs + verification plumbing | not started |
| 4 | M4 fabric + routing manifests | not started |
| 5 | M5–M7 manifests | not started |
| 6 | M8 three-CR AI path | not started |
| 7 | M9–M13 | not started |
| 8 | Faults, resets, timing | not started |
| 9 | Lab guides + docs pipeline | not started |
| 10 | Acceptance run (two clean bootstraps, airgap check) + PR | not started |

## Definition of done

All acceptance gates in [PLAN — Acceptance gates](PLAN.md#10-acceptance-gates) pass (flake check, install, routing, ingress, classic LB,
AI path with tmctl evidence, faults, guides derived from captures, two consecutive
clean-clone bootstraps, symmetric teardown, airgap path), and the final PR is merged by the
repository owner.