# FACILITATOR.md — Course Operations

For the person provisioning the environment and running the session. The student-facing
content lives in `docs/labs/` (rendered site); the content system of record lives in
[`docs/course/`](docs/course/README.md); the build spec is [`PLAN.md`](PLAN.md); the agent contract
is [`AGENTS.md`](AGENTS.md). This file is the operational twin: run order, credentials,
drills, and the version ledger.

## Facilitator run order (first time)

1. Build/verify the **course image**: linux/amd64, Ubuntu 24.04 or the RHEL-family estate
   image ([sizing rationale](PLAN.md#2-lab-architecture)) with Docker Engine and Nix
   preinstalled ([PLAN §8.1](PLAN.md#81-the-attendee-instance-model) — the
   only two baked-in installs; Nix via the Determinate Systems installer, multi-user,
   flakes enabled). Every attendee instance boots **from this image**, and each attendee
   bootstraps their own lab on it at course start. The facilitator neither starts nor
   accesses attendee environments.
2. Smoke-test the image: boot one instance from it and run the full
   [bootstrap flow](PLAN.md#82-bootstrap) end to end; record results in the version
   ledger.
3. Obtain the two credential files through F5 channels:
   - the FAR image-pull secret tarball,
   - the operator license JWT.
   Drop both into `keys/` (gitignored). Never commit them; the tooling fails with a
   human message if they are missing ([rules](AGENTS.md#non-negotiable-rules)).
4. Clone and bootstrap ([full bootstrap order](PLAN.md#82-bootstrap)):
   ```
   git clone https://github.com/shsingh/ai-infra-for-neteng.git
   cd ai-infra-for-neteng
   nix run .#bootstrap       # 10–20 min; streams progress
   nix develop
   nix run .#doctor          # green board = ready
   ```
5. Work through the module apps once yourself, following the guide
   (`docs/labs/lab02-install-bnk.md` onward) before the course; fix anything that needs
   fixing and record it in the version ledger below.

## Supplying credentials during the build (agent handoff)

During the build stages, the lab host is resolved first: a locally provisioned VM
(`vm-local`) or a lab/cloud instance over SSH (`ssh`). The build agent asks which when the
answer is not already recorded in `targets/target.env`
([AGENTS.md — Execution target](AGENTS.md#execution-target-vm-local-or-ssh), including that
gitignored file's schema).

Credentials reach the build two ways:

1. **Direct placement (preferred).** Place the FAR tarball and the operator JWT into `keys/`
   of the checkout **on the lab host**, then tell the agent they are placed. The agent
   checks existence only — it never opens the files.
2. **Agent hand-over (opt-in).** Hand the agent the files' local paths in the session; it
   copies them byte-for-byte, unopened, into `keys/` on the lab host. Nothing is printed,
   logged, or committed.

Where the deployer accepts a license or release override as an environment variable (see the
2.4.0 override note below), the agent applies it only inside the deploy step on the lab host,
records the mechanism (never the value) in the version ledger, and never echoes it. Any new
entitlement the plan introduces (for example an Early Access feature) follows the same
ask-and-confirm gate before anything is consumed for it
([AGENTS.md — Credential and license handoff](AGENTS.md#credential-and-license-handoff-ask-then-confirm)).

## Running the day

- Before students arrive: `nix run .#doctor` green; projector + printed handout from
  [course/planes-and-analogies.md](docs/course/planes-and-analogies.md) (concept-mapping table
  + analogy grid).
- During: students keep their own pace via the guides; apps handle waits, verification,
  traffic, and faults — students hand-apply every manifest. Guides carry the expected
  outcomes (captured outputs in `docs/expected/`; never invent an expected output).
- Fault drills are attendee-executed end to end: `nix run .#break-fix -- <id> apply|restore`
  with the fault table in [PLAN §6.4](PLAN.md#64-fault-exercises-8-faults-attendee-run-apply--taught-diagnosis--exact-inverse-restore).
  Every fault has an exact-inverse restore; `nix run .#reset -- <module>` returns a
  module to pristine. The facilitator's role is advisory only: they never inject, apply,
  or restore anything inside an attendee instance.
- Between cohorts: attendee instances are disposed and re-created fresh per seat; on a
  persistent seat, `nix run .#teardown` then `nix run .#bootstrap`, or keep the cluster
  warm and use `nix run .#reset -- <module>`.

## Airgapped or restricted delivery venues

Produce the offline bundle once, on any connected host
([PLAN §8.2.1](PLAN.md#821-offline-bootstrap-self-sustained-vm)):

```
nix run .#airgap-bundle -- --out /path/to/bundle
```

then on the isolated VM: `nix run .#bootstrap -- --offline --bundle /path/to/bundle`.
The bundle carries every container image, the release-manifest charts (produced on the connected host — the
F5 credentials are used only while producing the bundle there), and the Nix
closures; the VM needs no outbound network after that.

## Version ledger

Record every pin as actually deployed. The flake pins tools; the deployer's release
manifest determines the platform version — verify both at build time and record here.
Update before and after each cohort; bump versions only between cohorts, one reviewed
`flake.lock` diff per bump.

| Component | Expected (this edition) | As deployed | Notes |
|---|---|---|---|
| BNK release manifest | 2.4.0 (override — see below) | _record at Stage 2_ | FLO/CNE manifest ids recorded here once first deploy completes |
| Kubernetes (kind node image) | 1.30.8 (bump if 2.4.0 requires newer — verify against the [2.4.0 system requirements](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/install/bnk-host-self-managed-flo/prepare-your-computer-and-cluster/system-requirements.html)) | _at Stage 2_ | |
| kindbnkctl binary | v2.3.0-11 (or a 2.4-pinned release if published) | _at Stage 2_ | releases follow `v<bnk>-<n>` |
| GAIE CRDs | v1.4.0 (pinned + hashed in `pkgs/gaie-crds.nix`) | _at Stage 3_ | applied after BNK, before Module 8 |
| llm-d-inference-sim | pinned tag **+ digest** (verify the KV-event flag against its README at Stage 6) | _at Stage 6_ | |
| FRR spine | pinned base image | _at Stage 4_ | |
| nixpkgs | pinned rev in flake.lock | _at Stage 1_ | governs kind/kubectl/helm/jq/yq |

**The 2.4.0 override** — the deployer ships pinned to an earlier BNK release; this lab
requires 2.4.0. Apply the release-manifest override per the tool's documented mechanism
(poc.yaml field or env), and record here verbatim: which mechanism, the resulting FLO/CNE
manifest ids, and the CRD apiVersions actually served (`kubectl get crds -o wide |
grep -Ei "f5|inference"`). If the override cannot deliver 2.4.0, the build stops — that
is a non-negotiable stop condition ([plan risk table](PLAN.md#11-risk-register-first-build)).

Content source: what each module teaches lives in
[`docs/course/modules/`](docs/course/README.md) — update content there, not in the guides; the
guides render from it.

## After each cohort

- `nix run .#report` — dumps timing, faults run, and a cluster-events digest into
  `reports/` (gitignored); file issues for anything that needed manual fixing.
- Review the ledger above; bump pins only between cohorts.

## What this course deliberately does NOT do

- No DPU hardware: the DPU segment is a recorded demo with captured output.
- No Early Access hands-on: semantic caching stays a demo + discussion (labeled in the
  guides); anything requiring EA licensing is out of scope unless the course owner arranges it.
- No OpenShift cluster in class: the production-target delta is covered by a recorded
  walkthrough (`nix run .#ocp-demo`) and notes in the closing guide.
- No MPLS provider-edge lab: Early Access path from the previous release; not announced
  in the 2.4 release notes; verify with the F5 account team.
