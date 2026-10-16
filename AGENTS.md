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
   course order (`manifests/`), an FRR fabric-peer container (`fabric/`), the attendee-run fault exercises
   (`nix run .#break-fix`), and a bootstrap app that takes a bare VM to a green doctor board.
2. **The lab guides** — one guide per module under `docs/labs/`, in the task-based format
   defined in [PLAN — Lab guides](PLAN.md#7-lab-guides-appworld-format), rendered by Sphinx (f5_sphinx_theme — the AppWorld/clouddocs look) to GitHub Pages
   via GitHub Actions and locally on the lab VM (`nix run .#docs`, offline-capable).
3. **The operating contract** — bootstrap / sync / reset / teardown commands as specified in
   [PLAN — Environment contract](PLAN.md#8-environment-contract-init-sync-reset), plus `README.md` (student quickstart) and `FACILITATOR.md` (run order, version
   ledger, credentials how-to). The facilitator has no access to attendee instances and
   runs none for them: every exercise, including fault drills, is self-contained on each
   attendee VM and driven through the documented Nix apps; nothing in the tooling may
   assume a facilitator or peer machine touches an attendee environment.

## Non-negotiable rules

1. **Never commit secrets.** The two credential files (an image-pull secret tarball and a
   license JWT) belong in `keys/`, which is gitignored from the first commit. Agents never
   read, print, or log their contents; their contents are consumed only by the pinned
   deployer and the image pre-pull. Supplying them follows the ask-and-confirm handoff
   ([Credential and license handoff](#credential-and-license-handoff-ask-then-confirm)): an
   agent may request that the repository owner supply them and, once the owner explicitly
   hands them over, copy the files byte-for-byte, unopened, into `keys/` on the lab host.
   If they are still missing, tooling must fail with a human message pointing at
   `FACILITATOR.md`.
2. **No standalone shell scripts in the repo.** The only scripted surface is Nix (`flake.nix`,
   `apps/*.nix`, `pkgs/*.nix`). Anything a shell script would do becomes a Nix app.
3. **Expected outputs are captured, never invented.** Every expected output quoted in a lab
   guide comes from an actual captured run stored under `docs/expected/`. Guides are frozen
   only after their commands have executed against the running cluster.
4. **Branch protection: never merge a pull request authored by the same contributor.** Work happens on feature
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
10. **Accurate scoping.** Features that are Early Access (semantic caching) or outside the
    demo-mode shape (DPU, SR-IOV, GRPCRoute) appear as demo/slides material only; guides say
    so explicitly.
11. **Resolve the execution target before any build action.** Every Nix app, preflight, and
    capture executes on the lab host — either a locally provisioned VM (vm-local) or a
    lab/cloud instance reached over SSH (ssh) — per
    [Execution target](#execution-target-vm-local-or-ssh). The agent never assumes the machine
    it is running on is the lab host, and never lets a preflight score the controller where it
    should score the VM: rule 6 asserts amd64 on the lab host; the controller is only a driver.
12. **Never consume license or credential material without a confirmed handoff.** Any
    entitlement a build step needs — the operator license JWT, the FAR image-pull secret, or
    any additional license the plan or a module introduces — passes the
    [ask-and-confirm handoff](#credential-and-license-handoff-ask-then-confirm) first: ask,
    wait for explicit owner confirmation, then proceed. A missing or unconfirmed entitlement
    is a stop condition, handled exactly like a red doctor board (rule 5).

## Execution target (vm-local or ssh)

The lab host is one Linux amd64 VM per [PLAN — Lab architecture](PLAN.md#2-lab-architecture).
Before Stage 2 — and before any command whose preflight asserts the environment floor — the
build agent resolves where that VM lives and how commands reach it. Two supported modes, and
the tooling is identical in both: the Nix apps, `doctor`, and every captured output always
execute on the lab host; the machine the agent runs on is only a controller.

Resolution order — first match wins:

1. `AIFNE_TARGET_MODE` set in the agent session (`vm-local` or `ssh`).
2. `targets/target.env` at the top of the controller checkout (gitignored; schema below).
3. Neither present → the agent stops and asks the repository owner before provisioning or
   running anything, records the answer in `targets/target.env`, and states it on the entry
   issue so later stages and session restarts resolve deterministically.

When the answer is not already recorded, the agent presents both options with what they mean
for the next stage:

- **vm-local — the VM runs on the controller host (development/testing).** The agent reuses
  an existing local VM or provisions one, sized to the [floor](PLAN.md#2-lab-architecture)
  (16c/32 GB recommended, 12c/28 GB absolute), with Docker Engine and Nix present inside it
  ([the host-prep model](PLAN.md#81-the-attendee-instance-model)). Commands run through
  `AIFNE_TARGET_SHELL` — whatever opens a non-interactive shell inside that VM (the VM
  runner's shell command, or SSH on its forwarded port). A VM that emulates amd64 on a
  non-amd64 controller passes the in-VM architecture check but is not a supported Stage 2+
  build path — TMM and kind performance under emulation does not represent the lab; if the
  controller cannot host a floor-sized amd64 VM natively, use the ssh mode instead.
- **ssh — the build happens on an existing lab/cloud instance.** The agent works through SSH
  (BatchMode, a dedicated key), runs long operations detached (`nohup` or a terminal
  multiplexer) so a dropped connection never kills a bootstrap, and brings captured outputs
  (`docs/expected/`, `reports/`) back to the controller checkout with `scp`/`rsync` after
  each stage gate. Hostnames and IPs live in `targets/target.env` — never in issues, PRs,
  captures, or committed files.

`targets/target.env` schema (never committed — it resolves the target; it carries no secrets):

```text
AIFNE_TARGET_MODE=vm-local|ssh                  # which machine hosts the lab VM
AIFNE_TARGET_SHELL=<vm-local: command that opens a non-interactive shell inside the VM, or raw exec when the agent already runs on the VM>
AIFNE_TARGET_SSH_HOST=<ssh: hostname or IP>     # required under ssh
AIFNE_TARGET_SSH_USER=<ssh: user>               # optional
AIFNE_TARGET_SSH_PORT=<ssh: port>               # optional
AIFNE_TARGET_SSH_KEY=<ssh: identity file path>  # optional; otherwise ssh agent defaults
AIFNE_LAB_DIR=<path of the repository checkout on the lab host>
```

Mode rules:

- The floor is always asserted **on the lab host** (doctor/preflight already do this); a
  controller that meets the floor never excuses a VM below it.
- Under ssh, every path in the guides, apps, and this contract is a lab-host path; the Nix
  apps run inside `AIFNE_LAB_DIR` on that host, and `keys/` belongs to that host's checkout.
- Under vm-local, the controller checkout and the lab checkout are distinct trees: unless the
  shell transport literally executes inside the VM, nothing build-related runs on the
  controller (only repo sync and capture archival do).
- Every mode keeps the four-part app contract (announce → run → verify → expected output) and
  rule 8 progress discipline; long operations stream through the transport unbuffered.

## Credential and license handoff (ask-then-confirm)

Credential material is never invented, guessed, or treated as available before the
repository owner confirms it. When a build stage reaches a step that consumes the two
credential files (FAR image-pull secret tarball, operator license JWT — the preflight in
`apps/bootstrap.nix` checks their presence by name and count, never content), or when a new
license/entitlement requirement appears anywhere in the build:

1. **Check** — on the resolved execution target, check `keys/` for the expected files:
   existence and rough size only; contents stay sealed (rule 1).
2. **Ask** — if missing, or a new entitlement shows up in the plan, post one structured ask
   on the entry issue: which files, the exact `keys/` path on the lab host, and the two
   supply channels —
   - the repository owner places the files into `keys/` on the lab host themselves; or
   - the owner hands the agent the files' local paths in-session, and the agent copies them
     byte-for-byte, unopened, into `keys/` on the lab host — never printed, logged,
     committed, or included in a capture.
3. **Confirm** — proceed only after the owner confirms placement; re-check, then continue
   the stage. No confirmation → the stage parks and the agent waits. This gate is a stop
   condition, not a prompt to improvise (rule 12).
4. **Env-var channel (owner opt-in only)** — where the deployer's documented mechanism
   accepts a license or release override as an environment variable
   ([PLAN — kindbnkctl integration](PLAN.md#42-kindbnkctl-integration); the 2.4.0 override
   note in `FACILITATOR.md`), the owner may prefer to supply the value that way. The agent
   applies it only within the deploy step's session on the lab host, never echoes it, never
   writes it into any repo file, guide, capture, issue, or PR, and records only the
   mechanism (never the value) in the version ledger. Files-in-`keys/` remains the default;
   the env channel exists for material the owner is comfortable transiting the session.
5. **New entitlements** (an Early Access feature, or a future module needing another license)
   go through the same gate before anything is downloaded, mounted, or configured for them —
   the agent surfaces the requirement and waits; it never works around a missing license.

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
| `nix run .#break-fix -- <id> apply\|restore` | attendee-run fault exercise (8 faults, [PLAN — Fault exercises](PLAN.md#64-fault-exercises-8-faults-attendee-run-apply--taught-diagnosis--exact-inverse-restore)) |
| `nix run .#reset -- <module>` | return a module to pristine state |
| `nix run .#teardown` | symmetric destroy |

Per-module apps (`m1-orient` … `m13-breach`) are specified in [PLAN — Per-module apps](PLAN.md#83-per-module-apps-course-order).

## Current status

Update this section as stages complete, referencing [PLAN — Build order](PLAN.md#9-build-order-stages-and-exit-gates) (Stage 0 … Stage 10).

| Stage | Scope | Status |
|---|---|---|
| 0 | Repo created; AGENTS.md + PLAN.md + .gitignore committed | **done** (pre-commit + governance live; merged) |
| 1 | Flake skeleton + doctor | **done** (flake check green, doctor honest, kindbnkctl pinned) |
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