# PLAN.md — Lab Build Plan: AI Infrastructure for Network Engineers (BNK 2.4 Edition)

Revision 1.0 — October 2026. Status: plan — the lab described here is specified in full and
not yet built. Companion: [AGENTS.md](AGENTS.md) (operating contract for build agents).

The course defines 13 instructor-led modules for network engineers, taught through a
three-planes model (management, control, data) and one university case study
([docs/course/](docs/course/README.md) — the content system of record: case study, teaching model,
per-module scripts). Everything in the course is declarative: custom resources in Git,
applied by students by hand, verified through status conditions and TMM `tmctl` tables.
This plan specifies the repository that makes the lab real and self-bootstrapping. The published
F5 documentation ([References](#13-references)) is the source of truth for every product behavior,
manifest field, and verification command quoted here; where this plan and the F5 docs
disagree, the F5 docs win and this plan must be corrected.

## 1. Objectives and deliverables

**Table 1: Deliverables**

| # | Deliverable | Verified by |
|---|---|---|
| 1 | Self-bootstrapping lab repo (Nix flake, apps, manifests, fabric, faults) | [Acceptance gates](#10-acceptance-gates) |
| 2 | Lab guides per module (AppWorld task-based format) rendered to GitHub Pages | [Guide contract](#7-lab-guides-appworld-format) |
| 3 | Operating contract: bootstrap / sync / reset / teardown for course delivery | [Environment contract](#8-environment-contract-init-sync-reset) |

Rules for any agent executing this plan:

- Credentials (FAR image-pull secret tarball, license JWT) are supplied by the facilitator
  or repository owner into `keys/` (gitignored) on the lab host. Agents never read their
  contents; the supply path is the ask-and-confirm handoff
  ([AGENTS.md — Credential and license handoff](AGENTS.md#credential-and-license-handoff-ask-then-confirm)).
- The build agent resolves where the lab VM lives before Stage 2 — a locally provisioned VM
  (vm-local) or a lab/cloud instance over SSH — per
  [AGENTS.md — Execution target](AGENTS.md#execution-target-vm-local-or-ssh).
- Every expected output in a guide must come from a captured run in `docs/expected/`.
- Work happens on feature branches; PRs are reviewed and merged by the repository owner.
- Stop conditions: see [AGENTS.md — Non-negotiable rules](AGENTS.md#non-negotiable-rules) rules 5–6. Never build on BNK < 2.4.0; never attempt arm64.

## 2. Lab architecture

**Table 2: Environment roles**

| Role | Runs as | Purpose |
|---|---|---|
| Lab host | One Linux amd64 VM: 16 vCPU, 32 GB RAM, 160 GB disk, Ubuntu 24.04 LTS or RHEL-family | Docker daemon + Nix; nothing else |
| Control-plane node | kind node container (`demo-control-plane`) | Kubernetes control plane + regular workloads |
| TMM worker | kind node container (`demo-worker`, label `app=f5-tmm`) | Full BNK stack incl. TMM demo mode (virtio) |
| Fabric spine | Docker container on the same host, peering over a Multus bridge | An eBGP peer students can log into (`vtysh show bgp`) |
| Traffic client | Ordinary pods in the cluster (curl/blast jobs) | Traffic generation; no separate VM |

One VM carries everything (the `bgp-peer-frr` pattern: the BGP session rides a Multus
bridge net1 on 192.168.99.0/24 inside the worker). A second VM is only for the optional
external-fabric variant — deferred, never gating. Where that VM lives is resolved at build
time, not assumed: a locally provisioned VM (vm-local) or a lab/cloud instance reached over
SSH (ssh) — identical tooling either way; the resolution contract and env schema are in
[AGENTS.md — Execution target](AGENTS.md#execution-target-vm-local-or-ssh). Classroom delivery
instances follow [the attendee-instance model](#81-the-attendee-instance-model).

Sizing rationale: the BNK chart set reserves roughly 20 Gi of memory on the TMM worker and
about 12 cores; the real steady-state working set is ≈ 6 GB. kind does not partition the
host, so worker reservations must fit the Docker daemon's allocation — hence the floor
(12c/24 GB) and the recommended 16c/32 GB. Disk: ~2.4 GB F5 images + ~1.4 GB kind image
+ tooling + ≥ 100 GB working room.

**Table 3: Address plan (deliberately LTM-familiar)**

| Segment | Range | Notes |
|---|---|---|
| External VIPs | 11.19.1.0/16 | Gateway VIPs, allocated by the F5 IPAM controller |
| Fabric peering | 198.51.100.0/24 | TMM external interface + FRR spine (spine router-id 198.51.100.1, AS 65110) |
| BGP NAD bridge | 192.168.99.0/24 | Multus net1 path both BGP endpoints ride |
| TMM ASN | 65001 | `startASN` in the RoutingTemplate |
| Tenant VRFs | tenant-teaching, tenant-research, tenant-ai, tenant-industry | Per-class isolation; the lab builds tenant-ai |

## 3. Course-to-build map

**Table 4: Modules mapped to repo deliverables** (content source of record: [docs/course/modules/](docs/course/modules/m01.md); this table maps the repo outputs only)

| Module | Build outputs | Lab guide |
|---|---|---|
| M1 Kubernetes for network engineers | README quickstart, devShell, `m1-orient` app, fault exercise `m1-endpoints` | labs/lab01-kubernetes.md |
| M2 Why AI runs on Kubernetes (concept) | Class intro + lab01 preamble | (class intro) |
| M3 Install BNK (host vs DPU; demo mode) | bootstrap/deploy apps, kindbnkctl 2.4.0 override, doctor | labs/lab02-install-bnk.md |
| M4 BGP, VRF, EVPN (OcNOS path) | `manifests/bgp/*`, `fabric/frr.conf`, m4 apps, faults `m4-bgp-secret`, `m4-vxlan-vni` | labs/lab03-routing-bgp.md |
| M5 VRF deep dive + per-tenant ACL | `policy-tenant-ai.yaml` (SecPolicy), m5 apps | labs/lab04-tenant-isolation.md |
| M6 Gateway API (VIP to Route) | `01-demo-app`, `02-gateway-httproute`, `03-irule-cneirule`, m6 apps, fault `m6-route-ns` | labs/lab05-gateway-api.md |
| M7 Traditional LB (L4Route, egress, firewall) | `04-l4route-gateway`, `05-egress-gateway`, `06-fw-policy`, m7 apps, fault `m7-l4port` | labs/lab06-traditional-lb.md |
| M8 AI ingress (InferencePool, F5EPP) | `07-ai-sim`, `08-f5epp`, `09-inferencepool`, `10-httproute-inference`, m8 blast + tmctl apps, faults `m8-epp-selector`, `m8-pool-ports` | labs/lab07-ai-inference.md |
| M9 Observability + consolidated review | `m9-telemetry`, `m9-drill`, `docs/expected/` captures | labs/lab08-observability.md |
| M10 bnk-forge GUI (optional) | runbook + screenshots | labs/lab09-bnk-forge.md |
| M11 Can OSS do this? (optional) | argument-table page (no cluster work) | labs/lab10-oss-vs-bnk.md |
| M12 AI-sec prompt screening (optional) | `11-nova-deployment`, `12-nova-rules`, `13-httproute-ai-sec`, `m12-attack` app | labs/lab11-ai-sec.md |
| M13 Shared-model token governance (optional) | `14-token-governance-gateway`, `15-m13-tenant-fw`, `m13-hsl-tail` + `m13-breach` apps | labs/lab12-shared-model-security.md |

Hard rules from the course: M8 is never cut entirely; M4/M5 absorb overruns; optional
modules (m10–m13) are the first cuts when a cohort runs long — each optional module is
also self-contained enough to run as a take-home exercise. Pacing decisions rest with the
facilitator, guided by the module scenario sections (which parts of a module are
demonstrable without the hands-on portion) rather than by a stopwatch.

## 4. Repository layout

```text
ai-infra-for-neteng/
├── flake.nix                  # inputs: pinned nixpkgs + flake-utils; apps, devShell, checks
├── flake.lock                 # the pin: nixpkgs rev, kindbnkctl version + sha256, GAIE CRD source
├── README.md                  # student-facing: what this is, how to start
├── FACILITATOR.md             # operational twin: T-minus checklist, drills, version ledger
├── LICENSE
├── AGENTS.md                  # agent operating contract
├── PLAN.md                    # this file
├── pkgs/
│   ├── kindbnkctl.nix         # pinned release binary: fetchurl + sha256
│   ├── gaie-crds.nix          # GAIE v1.4.0 CRDs, fetched at build + hashed
│   ├── spine-image.nix        # FRR spine container image via dockerTools (pinned FRR base)
│   └── course-libs.nix        # wait-for-status, blast-traffic, tally, hsl-tail
├── apps/
│   ├── bootstrap.nix          # preflight, image pre-pull, deploy, GAIE CRDs, spine, doctor
│   ├── airgap-bundle.nix      # offline-bundle producer: images + charts + nix closures
│   ├── deploy.nix             # kindbnkctl e2e wrapper (resume-safe)
│   ├── doctor.nix             # environment green board
│   ├── sync.nix               # repo-to-cluster sync: validate + apply changed manifests
│   ├── m1.nix ... m13.nix     # one app per course step (course order, §8.3)
│   ├── break-fix.nix          # nix run .#break-fix -- <id> apply|restore
│   ├── reset.nix              # nix run .#reset -- <module>
│   ├── report.nix             # post-class dump: faults run, event digest
│   ├── ocp-demo.nix           # recorded OpenShift walkthrough (production-target notes)
│   └── teardown.nix           # symmetric destroy
├── devShells/default.nix      # student shell: KUBECONFIG, PATH, pinned kubectl/kind/helm/jq/yq
├── manifests/
│   ├── 00-namespace.yaml
│   ├── 01-demo-app.yaml       # nginx + Service in tenant-ai (M6)
│   ├── 02-gateway-httproute.yaml   # Gateway + GatewaySettings + HTTPRoute (M6)
│   ├── 03-irule-cneirule.yaml      # F5BigCneIrule + NetPolicy (M6)
│   ├── 04-l4route-gateway.yaml     # TCP listener + L4Route (M7)
│   ├── 05-egress-gateway.yaml      # EgressGateway (M7)
│   ├── 06-fw-policy.yaml           # F5BigFwPolicy/Rulelist + SecPolicy (M7)
│   ├── 07-ai-sim.yaml              # llm-d-inference-sim x3, KV events on (M8)
│   ├── 08-f5epp.yaml               # F5EPP CR (M8)
│   ├── 09-inferencepool.yaml       # InferencePool CR (M8)
│   ├── 10-httproute-inference.yaml # backendRef kind InferencePool (M8)
│   ├── 11-nova-deployment.yaml     # Nova + Laya decision model (M12)
│   ├── 12-nova-rules.yaml          # block/flag/pass seed rules per tenant (M12)
│   ├── 13-httproute-ai-sec.yaml    # /v1/* through Nova before the pool (M12)
│   ├── 14-token-governance-gateway.yaml # k8s.f5.com/ai-token-counting Gateway (M13)
│   ├── 15-m13-tenant-fw.yaml       # per-tenant firewall matrix + HSL pool (M13)
│   └── bgp/
│       ├── routing-template.yaml   # Go template emitting OcNOS CLI (M4)
│       ├── global-routing-config.yaml
│       ├── vrf-tenant-ai.yaml      # VRF + VXLAN sections on the composite Infra CRD
│       ├── vxlan-tenant-ai.yaml
│       ├── routing-config-tenant-ai.yaml   # vxlanRef XOR vrf schema rule
│       └── policy-tenant-ai.yaml   # per-tenant ACL via SecPolicy (M5)
├── fabric/
│   ├── default.nix            # spine image derivation + run
│   └── frr.conf               # router bgp 65110, neighbor = kind node, redistribute kernel
├── docs/                      # rendered site + content system of record
│   ├── conf.py, index.rst     # Sphinx config (f5_sphinx_theme — the AppWorld pattern)
│   ├── Makefile, requirements.txt
│   ├── course/                # content source of record: case-study.md,
│   │                          #   planes-and-analogies.md, modules/m01..m13.md
│   ├── labs/lab01..lab12      # one md per module (Table 4)
│   └── expected/              # captured outputs; the ONLY source of expected results
└── reports/                   # gitignored: build + scenario reports
```

### 4.1 flake contract

- Inputs: nixpkgs (pinned rev in flake.lock) and flake-utils.
- `apps`: every command in [§8](#8-environment-contract-init-sync-reset) plus `airgap-bundle` ([offline bundle producer](#821-offline-bootstrap-self-sustained-vm)); each app obeys the four-part contract (announce → run →
  verify → print expected output) and is idempotent. All CR waits go through
  `course-libs.wait-for-status` (status polling + timeout + human-readable failure).
- `devShells.default`: pinned kind, kubectl, helm, jq, yq, git; sets `KUBECONFIG`; shell
  prompt `(ai-infra-neteng)`. Students install nothing.
- `packages`: kindbnkctl binary (fetchurl + sha256 of a pinned GitHub release), GAIE CRD
  manifest set (hashed), FRR spine image, course libs.
- `apps.docs`: renders the lab-guides site in place on the lab VM (`nix run .#docs`)
  with the pinned Sphinx toolchain (f5-sphinx-theme, the AppWorld pattern) — the site
  builds with no network access
  and no CI dependency, so a fully offline VM can serve `docs/site/` directly.
- `checks`: `nix flake check` passes on every PR — flake evaluation, manifest YAML parse,
  client-side dry-run, docs build.

### 4.2 kindbnkctl integration

kindbnkctl is a single-binary CLI that deploys BNK on a two-node kind cluster (TMM in demo
mode, resume-safe, symmetric destroy). It is pinned by hash, never hand-installed. Key
properties the lab relies on: `kindbnkctl init demo` creates a PoC workspace with
`poc.yaml` as declarative state; `keys/` holds the customer-supplied FAR tarball + JWT;
phases: cluster up → deploy prereqs → deploy flo → deploy cne; minimum host floor enforced
by `kindbnkctl doctor` (see [the lab architecture sizing](#2-lab-architecture)). The BNK version moves via the release-manifest
override ([§5](#5-version-pins)), not via re-pin of the binary.

## 5. Version pins

**Table 5: Pin set**

| Component | Pinned by | This edition |
|---|---|---|
| BNK release manifest | kindbnkctl pin/override | **2.4.0** (override recorded in FACILITATOR.md; record FLO/CNE manifest ids at first deploy) |
| kindbnkctl binary | `pkgs/kindbnkctl.nix` | latest release at build time (`v2.3.0-11` at plan time). Releases follow `v<bnk-version>-<n>` — if a 2.4-pinned release exists, prefer it over the override |
| Kubernetes (kind node image) | kindbnkctl | 1.30.8 (kind v0.26) — verify against the BNK 2.4.0 system requirements at Stage 2 and bump if required |
| Calico | kindbnkctl | v3.28.2 |
| cert-manager | kindbnkctl | v1.16.2 |
| FLO chart | resolved at deploy from the 2.4.0 release manifest | record ids after first deploy |
| GAIE CRDs | `pkgs/gaie-crds.nix` | **v1.4.0**, hashed; applied after BNK is up, before M8 |
| Inference sim | flake input | `ghcr.io/llm-d/llm-d-inference-sim`, pinned tag **+ digest** |
| EPP image | — | **removed from the pin list**: the F5EPP controller renders the EPP stack and image from the BNK release manifest [4] |
| FRR spine | dockerTools sourceRef | pinned FRR base |
| nixpkgs | flake.lock | pinned rev — governs kind/kubectl/helm/jq/yq |

Deliberate changes from the earlier-generation pin list: GAIE CRDs enter the pin set; the
EPP image line is deleted (the controller owns the EPP stack in 2.4 — the single biggest
simplification).

The 2.4 wave, per the release notes [2]: the composite `Infra` CRD (`gateway.k8s.f5.com/v1alpha1`)
consolidates VLANs, static routes, VRFs, VXLANs; `GatewaySettings` and `EgressGateway` CRDs
replace legacy declarations; `BNKSecPolicy`/`BNKNetPolicy` rename to `SecPolicy`/`NetPolicy`;
the legacy `BNKGateway` CRD is removed; the F5 Analyzer/EPP architecture implements GAIE
(InferencePool, InferenceModelRewrite, Gateway with an EPP-annotation; multiple EPPs per
namespace); VRF with per-tenant ACL enforcement is **GA**, as is VXLAN-based EVPN over BGP;
the Observer CRD is GA for per-tenant statistics. Semantic AI caching stays **Early Access**
(demo only in this course). Every manifest written in this repo validates against these
schemas as actually deployed — never against documentation alone.

## 6. Manifest specifications

Every manifest: plain YAML in course order, applied by students by hand (apps exist for
waits, verification, traffic, and faults — never for applies). Every manifest passes
`kubectl apply --dry-run=server` against the deployed 2.4.0 CRDs before it enters a PR, and
CI re-checks YAML parse and client-side dry-run on every PR.

**Table 6: Per-manifest key fields and sources of truth**

| File | Key fields to get right | Source (References) |
|---|---|---|
| bgp/routing-template.yaml | Go template body producing OcNOS CLI; `startASN` substitution; `$nbr.ip` / `$nbr.interface` patterns | [11] — reproduce verbatim |
| bgp/global-routing-config.yaml | templateRef; ASN range; routerId; neighbors incl. spine 198.51.100.10 remoteAs 65110; neighborSecrets → K8s Secret | [11] |
| bgp/vrf-tenant-ai.yaml, vxlan-tenant-ai.yaml | Tenant VRF + VXLAN sections on the **composite Infra CRD** | [2],[9] |
| bgp/routing-config-tenant-ai.yaml | `vxlanRef` XOR `vrf` mutual exclusion; template+global CRs must exist first | [11] |
| bgp/policy-tenant-ai.yaml | Per-tenant ingress/egress ACL attached via SecPolicy | [2] |
| 01-demo-app.yaml | nginx + Service in tenant-ai | — |
| 02-gateway-httproute.yaml | gatewayClassName matching BNK's installed class; **GatewaySettings** extension; listener allowedRoutes; static `spec.addresses` VIP from 11.19.1.0/16 | [10],[2] |
| 03-irule-cneirule.yaml | F5BigCneIrule spec.iRule (log-only); **NetPolicy** extensionRefs + targetRefs (Gateway, sectionName), same namespace | [2] |
| 04-l4route-gateway.yaml | listener protocol TCP; L4Route spec.protocol TCP; one L4 route per listener | [12] |
| 05-egress-gateway.yaml | EgressGateway CR; namespace-scoped tenant egress identity | [2] |
| 06-fw-policy.yaml | F5BigFwPolicy + F5BigFwRulelist attached via SecPolicy | [2] |
| 07-ai-sim.yaml | 3 replicas llm-d-inference-sim; OpenAI-protocol; port 8000; label `app: vllm-sim`; **ZMQ KV-event publishing enabled** on the engine (verify the sim's exact flag against its README) | [16],[4] |
| 08-f5epp.yaml | poolRef.name: llm-pool; engine: vllm; optional blockSize 16; tokenizer block only if pinning | [4],[5] |
| 09-inferencepool.yaml | v1 InferencePool; selector matchLabels `app: vllm-sim`; targetPorts 8000; endpointPickerRef name llm-pool-epp, port 9002, **failureMode FailClose** | [4] |
| 10-httproute-inference.yaml | backendRef group `inference.networking.k8s.io`, kind **InferencePool**; PathPrefix /v1; exactly one InferencePool per rule, no mixed backends (violation ⇒ ResolvedRefs=False / PartiallyInvalid) | [4],[6] |
| 11-nova-deployment.yaml | Nova + Laya (CPU-class); verdict logging; images pinned (tag + digest) at build | [17],[20] |
| 12-nova-rules.yaml | Seed prompt rules — block/flag/pass tiers per tenant class | [20] |
| 13-httproute-ai-sec.yaml | HTTPRoute: Nova as first backendRef for /v1/*, InferencePool second; TMM enforces 403 on block | [20] |
| 14-token-governance-gateway.yaml | Gateway annotations: full `k8s.f5.com/ai-token-counting` block ([§6.2](#62-token-counting-annotation-m13-anchor)); HSL pool name | [13] |
| 15-m13-tenant-fw.yaml | Per-tenant firewall matrix + log/HSL profiles | [2],[13] |

### 6.1 The M8 three-CR path (course anchor)

Namespace `ai-inference` (registered in `CNEInstance.spec.eppNamespaces` so the controller
reconciles it). The pool, its F5EPP, and the model pods share that namespace. Reference
shapes (validate against the live CRDs before use):

```yaml
apiVersion: inference.k8s.f5.com/v1alpha1
kind: F5EPP
metadata:
  name: llm-pool-epp
  namespace: ai-inference
spec:
  poolRef:
    name: llm-pool
  engine: vllm
---
apiVersion: inference.networking.k8s.io/v1
kind: InferencePool
metadata:
  name: llm-pool
  namespace: ai-inference
spec:
  selector:
    matchLabels:
      app: vllm-sim
  targetPorts:
    - number: 8000
  endpointPickerRef:
    name: llm-pool-epp
    port:
      number: 9002
    failureMode: FailClose
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: llm-route
  namespace: ai-inference
spec:
  parentRefs:
    - name: my-gateway
      namespace: gateway-ns
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /v1
      backendRefs:
        - group: inference.networking.k8s.io
          kind: InferencePool
          name: llm-pool
          port: 8000
```

Verification cascade: F5EPP conditions Accepted → ResolvedRefs → Programmed → Available all
True; pods/Service named `<pool>-epp*` (9002 ext_proc, 9003 health, 9090 Prometheus);
`poolRef` is immutable (delete + recreate to repoint). `failureMode` is set ONLY on
`endpointPickerRef` — FailClose is the deliberate default; argue FailOpen only in M13's
availability discussion.

### 6.2 token-counting annotation (M13 anchor)

On the Gateway, per the token-counting how-to [13]:

```yaml
annotations:
  k8s.f5.com/ai-token-counting: |
    token_counting=enabled, user_id_source=api_key, user_id_header=x-api-key,
    enforcement=enabled,
    rate_limit_policy=per_user_per_model,
    rate_limits=[
      {"model":"meridian-teaching","tokens":50000,"window":3600},
      {"model":"meridian-research","tokens":100000,"window":3600},
      {"model":"partner-*","tokens":100000,"window":86400},
      {"model":"*","tokens":500000,"window":86400}
    ],
    concurrent_sessions_limit=5,
    rate_limit_action=drop,
    hsl_pool=usage-logging-pool
```

Read it as: credential-identified rate-limit policy with token-based counters; 429 on breach;
HSL rows are the billing feed; recommended rollout is log_only first, then flip tiers to drop.

### 6.3 Fabric spine

`frr.conf`: `router bgp 65110`, `router-id 198.51.100.1`, neighbor = the kind node address
(as used in GlobalRoutingConfig.neighbors), `ipv4-unicast` activate,
`redistribute kernel` (so TMM's advertised VIP routes appear). Students verify with
`show bgp neighbor` / `show bgp ipv4 unicast` via the m4-bgp-verify app. Demo-mode caveat
printed by the app: on real hardware the peer is the actual spine/leaf.

### 6.4 Fault exercises (8 faults; attendee-run apply → taught diagnosis → exact-inverse restore)

| Fault ID | Module | Symptom taught |
|---|---|---|
| m1-endpoints | M1 | Service selector label deleted; Endpoints <none> |
| m3-scheduling | M3 | Wrong `app=f5-tmm` nodeSelector; pod Pending |
| m4-bgp-secret | M4 | Corrupted neighbor Secret; CRD success but BGP idle |
| m4-vxlan-vni | M4 | VNI mismatch; route present, no east-west traffic |
| m6-route-ns | M6 | HTTPRoute wrong namespace; Gateway up, route not attached |
| m7-l4port | M7 | L4Route backend port wrong; TCP accepts then resets |
| m8-epp-selector | M8 | EPP Service selector mismatch; consults fail per failureMode |
| m8-pool-ports | M8 | targetPorts ≠ sim containerPort; 5xx through the pool |

Design rules: faults never touch the kind control plane; apply prints the symptom first;
each fault is fully attendee-executed — apply, diagnosis, and restore all run on the
attendee's own instance without assistance of any kind; `reset -- <module>` returns pristine
state (delete + reapply; routing CRDs delete-and-recreate).

## 7. Lab guides (AppWorld format)

The guide template (from the F5 AppWorld 2026 AI labs repo [18]) — one guide per module:

1. Title; framing paragraph in three parts: **Business problem**, **Technical problem**,
   **Solution with BNK** — written for the course's university case study (a central
   research-computing platform on a service-provider-style campus fabric: teaching, academic
   research, AI research, and paying industry-partner tenants; the AI pool becomes a paid,
   metered shared service).
2. Numbered **Task sections**: commands and UI paths, screenshots where a GUI is involved,
   plain-state call-outs of what the student should see.
3. **Expected outcome** line closing each task.
4. **Validation** section (concrete, checkable state) at the end of the lab.
5. **Troubleshooting**: symptom → check pairs, drawn from real build failures.
6. **Clean-Up** (optional), then a **What Was Learned** bullet summary.
7. The course's own addition: a **Planes check** line at the end of every lab (which
   management/control/data-plane surfaces the lab just touched).

Class-wide pages: index (lab environment, access, lab variables: host address, KUBECONFIG
location, VIP ranges, tenant list) and a closing page. Nav order follows Table 4.

Authoring rules (the captured-output contract):

- Every command in a guide executes against the running lab before the guide is frozen; its
  output is captured into `docs/expected/`. Invented outputs are a defect.
- Screenshots come from actual lab runs.
- Captures record the deployed BNK pods, CRD apiVersions, and tmctl tables exactly as
  deployed and cross-reference the FACILITATOR.md version ledger.
- Pipeline: markdown in `docs/labs/` (Sphinx + MyST + f5_sphinx_theme); rendered with `nix run .#docs` on
  the lab VM (offline-capable — the pinned site toolchain comes from the flake) and by
  GitHub Actions, which deploys Pages on main. The VM and CI produce identical output. Guides stay plain markdown (readable in-editor and on the web).

## 8. Environment contract (init, sync, reset)

### 8.1 The attendee-instance model

Every attendee receives their own freshly booted lab instance at the start of the course —
the facilitator does not stand environments up for them. An instance is a clean linux/amd64
VM with web or CLI access (SSH or console); the attendee bootstraps the lab from the public
repository themselves, on their own instance, in the opening minutes of the course. Two
properties make this work:

1. **The image bakes the tool base.** The estate (or course) image ships Docker Engine and
   Nix with flakes enabled (Determinate Systems installer, multi-user) — nothing else; the
   flake pins and delivers every other tool. This is host-prep done once per image build,
   not per attendee or per cohort.
2. **The repository is the only other input.** Everything else the attendee needs arrives
   through `git clone` + `nix run .#bootstrap` — so the same flow works identically for a
   self-paced remote attendee over SSH and for an in-room attendee with browser + console
   access.

The facilitator has no access to attendee instances and runs none for them: their own
seat is for demonstrating steps on the shared screen and for the post-class report. Every
exercise — including fault drills — is self-contained on each attendee VM and is driven
entirely by the attendee through the documented Nix apps.

### 8.2 Bootstrap

Run by each attendee on their own instance at course start (CLI/SSH/console path):

```text
git clone https://github.com/shsingh/ai-infra-for-neteng.git
cd ai-infra-for-neteng
nix run .#bootstrap      # 10-20 min first run; streams progress
nix develop              # pinned shell; KUBECONFIG set
nix run .#doctor         # green board = the lab is ready
```

Web-access attendees do the same inside the browser terminal (or via their platform's
console shell); the guides only ever assume a shell — the way it is reached (SSH client,
web terminal, or console) does not change any step.

Bootstrap order (each step checks-then-acts, idempotent, resume-safe):

1. Preflight: assert linux/amd64, ≥ 12 cores, ≥ 28 GB free RAM, ≥ 120 GB disk, Docker
   reachable; human message and stop below the floor.
2. Nix check: if Nix/flakes absent, print the exact installer command and stop — never
   installs Nix itself.
3. Keys check: FAR tarball and JWT present in `keys/`; else a human message pointing at
   FACILITATOR.md (the credentials are pre-baked into the image for course VMs, so the
   per-attendee bootstrap needs no manual key handling).
4. Image pre-pull: BNK release-manifest images, llm-d-inference-sim, FRR spine, nginx,
   curl. With `--offline`, loads from the [airgap bundle](#821-offline-bootstrap-self-sustained-vm) instead and skips the
   network entirely.
5. Cluster up + BNK deploy: kindbnkctl e2e with the **2.4.0 release-manifest override**;
   the long step; streams pod status; exits when TMM pods Ready and CNEInstance Available.
6. GAIE CRDs applied from the hashed v1.4.0 source; verified registered.
7. Fabric spine up on the kind docker network.
8. Smoke: `nix run .#doctor` full green board (nodes, TMM, CRDs incl. f5 + inference,
   spine reachable, VIP IPAM responding, eppNamespaces sane, end-to-end curl) — the
   attendee's signal that their lab is ready for Module 1.

Zero-clone variant: `nix run github:shsingh/ai-infra-for-neteng#bootstrap` evaluates and
runs the flake straight from the fetched source, no local checkout needed. The clone path
stays the documented default: the course applies manifests by hand, which requires the
checkout.

### 8.2.1 Offline bootstrap (self-sustained VM)

The lab runs without internet, once the bundle exists. Two pinned apps close the loop:

- **Producer** (run once, on any internet-connected host):
  `nix run .#airgap-bundle -- --out <dir>` writes:
  - `labimages.tar` — every container image the lab pulls: the BNK release-manifest image
    set, llm-d-inference-sim (pinned digest), the FRR spine, nginx, curl, and the kind
    node image;
  - the FLO/CNE release-manifest charts and manifests, downloaded from repo.f5.com using
    the FAR credentials from `keys/`;
  - the Nix closures for the flake itself (pinned tools, devShell, GAIE CRDs, spine
    derivation, docs toolchain) via `nix copy --to file://<dir>/closure`.
- **Consumer**: `nix run .#bootstrap -- --offline --bundle <dir>` imports the Nix closures
  (`nix copy --from`), loads `labimages.tar` into Docker, injects the staged charts as the
  release-manifest source, and runs the standard pipeline with no outbound network.

With the bundle present, the complete lab — environment, locally rendered docs
(`nix run .#docs` resolves from the same closure), and the lab guides — builds and runs on
an isolated VM. First-time host prep (Docker + Nix install, [§8.1](#81-the-attendee-instance-model)) still needs one online
session or a preinstalled estate image; every subsequent cohort run is fully offline. The
producer is re-run only on version bumps (between cohorts); its output hash is recorded in
FACILITATOR.md.

### 8.3 Per-module apps (course order)

```text
nix run .#doctor                 # environment check (incl. GAIE CRDs)
nix run .#m1-orient              # nodes/pods overview; extract BNK pod names
nix run .#break-fix -- m1-endpoints apply|restore   # run by each attendee on their instance
nix run .#m3-status              # bnkgatewayclass, CRD inventory (incl. F5EPP/GatewaySettings)
nix run .#m3-tmm-console         # guided kubectl exec into f5-tmm
nix run .#m4-bgp-template|global|verify
nix run .#m4-vrf|routing-config|immutable-drill
nix run .#m5-tenant-policy
nix run .#m6-demo-app|gateway|irule
nix run .#m7-l4route|egress-gateway|fw
nix run .#m8-sim-deploy|blast
nix run .#m8-f5epp               # apply F5EPP CR; wait all four conditions True
nix run .#m8-pool                # apply InferencePool; rewire HTTPRoute backendRef
nix run .#m8-blast-again         # per-pod tally + TTFT comparison
nix run .#m8-tmctl               # print the four tmctl tables (§6.1 verification)
nix run .#m9-telemetry           # curated kubectl/jsonpath 'show' set + EPP Prom metrics
nix run .#m9-drill -- <fault-id>
nix run .#m12-attack             # seed jailbreak corpus through the Gateway
nix run .#m13-hsl-tail           # follow the token-usage HSL stream
nix run .#m13-breach             # drive a teaching-tier key past its budget (429 demo)
nix run .#reset -- <module>
nix run .#docs                   # render the lab-guides site locally (offline-capable)
nix run .#teardown               # full destroy
```

Implementation notes: apps are thin (course-libs helpers + pinned binaries); applies stay
hand-typed by students; `m8-blast` uses a fixed prompt corpus with shared prefixes
(reproducible cache behavior) and prints TTFT percentiles; `m8-blast-again` prints the
per-pod tally; progress lines every 50 items or 30 s during blast and bootstrap.

### 8.4 M8 verification (primary evidence of AI-path correctness)

Inside the TMM debug container:

```text
tmctl -d blade inference_stats        # intercepted vs passthrough vs misconfigured
tmctl -d blade inference_epp_stats    # schedule calls/successes/fallbacks, µs latency
tmctl -d blade profile_ext_proc_stat  # per-VS gRPC counters; the <ns>-llm-pool-epp-ivs row
tmctl -d blade profile_http_stat      # 2xx/4xx/5xx per virtual server
```

Expect: requests_intercepted advancing; schedule_successes == schedule_calls; the epp-ivs
row non-zero; no fallbacks/errors/timeouts; consult latency well under 1 ms. Prometheus side
(port-forward the EPP service to 9090): `kv_event_lag`, `prefix_index_rebuild_lag`,
`prefix_index_lookups` (hit rate), `hcl_pod_classification` (HOT/COLD), `scorer_score`.
Rising event lag = the early warning. The two blast runs prove the value: round-robin shows
per-pod counts even with cache hit rate ≈ 0; with steering active, per-pod counts converge
on cache-consistent targets and TTFT variance collapses.

### 8.5 Sync (operator flow)

```text
git pull
nix run .#sync          # validate + apply repo-to-cluster
nix run .#doctor
```

sync: diffs the working tree against deployed state, re-renders, server-side dry-runs,
applies only changed manifests (`kubectl diff`), prints a per-manifest drift report.
Routing-CRD and F5EPP changes are delete-and-recreate, never patch. Cohort-grade resets use
`reset -- <module>` or the full teardown/bootstrap cycle.

### 8.6 Classroom fleet

Every attendee owns a dedicated instance (no sharing by default — a pair-share fallback
is fine on constrained deliveries): identical image, identical repository flow, so
attendee seats are interchangeable. Any instance that falls behind re-runs bootstrap
before Module 1 — its owner, not the facilitator, does it. The facilitator's own instance
exists purely to demonstrate steps on the shared screen and to produce the post-class
report; the facilitator has no access to attendee instances and never interacts with them.
Fault exercises run entirely on the attendee's instance via
[`nix run .#break-fix`](#64-fault-exercises-8-faults-attendee-run-apply--taught-diagnosis--exact-inverse-restore)
and need no facilitator action.

## 9. Build order (stages and exit gates)

Order matters: the highest-risk step (Stage 2) is done first among build stages. The agent
does not proceed past a red gate.

| Stage | Work | Exit gate |
|---|---|---|
| 0 | Repo init; AGENTS/PLAN/.gitignore/README/FACILITATOR skeleton | files present; keys/ ignored |
| 1 | Flake skeleton + doctor; kindbnkctl pinned | `nix flake check` green; doctor honest |
| 2 | **BNK 2.4.0 install path** (risk stage): execution target resolved ([AGENTS.md — Execution target](AGENTS.md#execution-target-vm-local-or-ssh)); keys placed via the [credential handoff](AGENTS.md#credential-and-license-handoff-ask-then-confirm); init demo; 2.4.0 override; e2e; CRD inventory capture | CNEInstance Available=True; doctor green; CRD inventory recorded; **stop if 2.4.0 unachievable** |
| 3 | GAIE v1.4.0 CRDs hashed; doctor extended | doctor green incl. inference CRDs |
| 4 | M4: frr.conf + spine image; bgp manifests; apply in documented order; capture | BGP Established both sides; routes exchanged; immutability drill reproduces |
| 5 | M5–M7 manifests + apps; capture | every apply verified end to end |
| 6 | M8 three-CR path; blast before/after; tmctl capture | cascade all True; success == calls; convergence visible |
| 7 | M9–M13 telemetry/set/optimizer pages | each optional module reproduces its verification |
| 8 | All 8 faults: apply/diagnose/restore; reset apps | fault table green; resets return pristine state |
| 9 | Lab guides to the [guide contract](#7-lab-guides-appworld-format) + Sphinx/Pages pipeline | a reader with no prior context can follow lab02 and lab08 and reproduce the captured outputs |
| 10 | Acceptance: teardown → two consecutive clean-clone bootstraps green; airgap-mode check; final PR | all [acceptance gates](#10-acceptance-gates) pass; PR open |

Known-failure signature to recognize in Stage 2 (not a product error): pods Pending with
`FailedScheduling: Insufficient memory` on the worker ⇒ the VM is under the reservation
floor; fix sizing, re-run the phase (idempotent). Check the BNK 2.4.0 system-requirements
page for Kubernetes-version requirements at this stage and bump the kind node image pin if
required.

## 10. Acceptance gates

| Gate | Proof |
|---|---|
| G1 Flake | `nix flake check` green on the PR |
| G2 Install | CNEInstance Available=True; doctor green; CRD inventory + manifest ids recorded |
| G3 Routing | BGP Established both sides; routes exchanged; immutability drill reproduces |
| G4 Ingress | curl round-trip through Gateway to FIC-assigned VIP; iRule log line |
| G5 Classic LB | L4Route TCP probe; egress identity verified; firewall block with streamed log |
| G6 AI path | F5EPP cascade all True; tmctl tables show schedule_successes == schedule_calls; blast runs show cache-affinity convergence + TTFT variance drop |
| G7 Faults | each fault: apply → symptom → taught diagnosis demonstrated → restore verified |
| G8 Guides | every guide command executed against the cluster; outputs come from docs/expected/; Sphinx docs build green |
| G9 Contract | two consecutive clean-clone bootstraps green; teardown symmetric; airgap path runs |
| G10 Governance | PR open; reviewed and merged by the repository owner |

## 11. Risk register (first build)

| Risk | Failure signature | Mitigation |
|---|---|---|
| Deployer ships older BNK pins; 2.4.0 manifest override may not be supported as documented | CNE/FLO images remain old; 2.4-only CRDs (F5EPP, Infra, GatewaySettings, EgressGateway) absent | Stage 2 exists solely to de-risk this. Prefer a release-pinned 2.4 build of the deployer if available; else fork with bumped constants (decision recorded); **stop rather than build on the wrong version** |
| BNK 2.4.0 requires Kubernetes > 1.30.8 | Controllers crashloop; admission errors | Check [14] at Stage 2; bump the kind node image pin and re-run |
| GAIE CRD drift vs what the 2.4.0 F5EPP docs reference | InferencePool apply refused; F5EPP stuck ResolvedRefs=False | Hash-pinned CRD source; verify against [4] at Stage 3; record the served apiVersion after apply |
| Reservation floor vs real usage confusion | Pending pods, FailedScheduling: Insufficient memory | Preflight asserts ≥ 28 GB free; doctor prints worker allocated-vs-allocatable |
| KV-event flag on llm-d-inference-sim differs from assumed | EPP kv_event_lag rising or zero events | Verify the sim's exact flag against its README at Stage 6; pin by digest |
| Amber shapes on the 2-node demo shape (e.g. per-Gateway IPAM auto-creation) | Gateway never Programmed | Course uses static spec.addresses VIPs; GRPCRoute is not used; doctor preflights IPAM responsiveness |
| TMM restart churn during scenario runs | Some scenarios take minutes; TMM restarts mid-run | Apps wait on status, not wall-clock; capped wait tolerances |
| F5 images amd64-only | Platform-mismatch pods Pending | x86_64 VM mandatory; preflight asserts amd64 |
| Build driven against the wrong machine | Preflight green on the controller, red or absent on the actual VM; artifacts stranded away from the checkout | Execution-target gate before Stage 2 ([AGENTS.md — Execution target](AGENTS.md#execution-target-vm-local-or-ssh)); doctor/preflight always run on the lab host; captures copied back to the controller checkout after each gate |
| Repo hygiene | Git repo inside a cloud-synced path corrupts history | Working clones live under the home directory, never in sync-client-managed trees |
| Standalone scripts reintroduced during debugging | A lab.sh appears outside the Nix surface | No standalone .sh files; Nix apps only; reviewed in PRs |
| Secrets exposure | Credential material committed | keys/ gitignored from first commit; CI check that no staged file comes from keys/ |
| Credential handoff blocks a stage silently | Stage 2 parked with no owner response; agent improvises around a missing JWT or secret | One structured ask on the entry issue ([AGENTS.md — Credential and license handoff](AGENTS.md#credential-and-license-handoff-ask-then-confirm)); confirmed-only consumption; the gate is a stop condition |

## 12. Operating the course afterwards

- Between cohorts: version bumps only between cohorts; each bump is a reviewed flake.lock
  diff, tagged; FACILITATOR.md carries the ledger.
- Per cohort: verify the course image still bootstraps cleanly (one smoke instance);
  attendees bootstrap their own instances at course start; the facilitator reports on
  their own instance after class; issue filed for anything that needed manual fixing.
- Contingency cuts when a cohort runs long: drop to the module's demonstration mode or
  skip optional modules (m10–m13) entirely — M8 is never cut (§3, hard rules).
- T-minus rhythm: build on representative hardware two weeks out; dry-run with one or two
  engineers a week out (fix the three usual suspects: image pre-pull misses, status-wait too
  short, CRD version mismatch); Nix install + bootstrap on all classroom instances the day
  before; rehearse the M8 three-CR path + tmctl verification and one m13-breach cycle.

## 13. References

[1] BNK 2.4.0 release notes. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/releases/release-notes-bnk-2.4.0.html

[2] BNK overview (components, deployment models, demo mode). https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/overview.html

[3] AI Inference Routing with the F5 Endpoint Picker. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/how-tos/ai-related-features/intelligent-ai-load-balancing/ai-inference-routing-with-f5-endpoint-picker/ai-inference-routing-with-f5-endpoint-picker.html

[4] F5EPP custom-resource reference. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/how-tos/ai-related-features/intelligent-ai-load-balancing/ai-inference-routing-with-f5-endpoint-picker/cr-reference.html

[5] Configure the inference data path. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/how-tos/ai-related-features/intelligent-ai-load-balancing/ai-inference-routing-with-f5-endpoint-picker/configure-inference-path.html

[6] Verification and observability for the EPP data path. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/how-tos/ai-related-features/intelligent-ai-load-balancing/ai-inference-routing-with-f5-endpoint-picker/verify-monitor.html

[7] Gateway API Inference Extension. https://gateway-api-inference-extension.sigs.k8s.io/

[8] Configure network infrastructure with the Infra CRD. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/how-tos/configure-network-infrastructure-with-infra-crd.html

[9] Configure tenant traffic settings with GatewaySettings. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/how-tos/configure-tenant-traffic-settings-with-gatewaysettings.html

[10] Configure an egress gateway for outbound pod traffic. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/how-tos/configure-egress-gateway-for-outbound-pod-traffic.html

[11] BNK BGP routing with Kubernetes CRDs (OcNOS, templates, gRPC delivery). https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/how-tos/border-gateway-protocol/bnk-bgp-Introduction.html

[12] L4Route (TCP/UDP via Gateway API). https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/custom-resource-definitions/bnk-gateway-api-l4route.html

[13] Configure token counting and enforcement. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/how-tos/configure-token-counting-and-enforcement.html

[14] BNK (Host) system requirements. https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/install/bnk-host-self-managed-flo/prepare-your-computer-and-cluster/system-requirements.html

[15] kindbnkctl (demo-mode lab deployer). https://github.com/mwiget/kindbnkctl

[16] llm-d inference simulator. https://github.com/llm-d/llm-d-inference-sim

[17] bnk-forge (F5 DevCentral GUI). https://github.com/f5devcentral/bnk-forge

[18] F5 AppWorld 2026 AI labs (lab-guide format template). https://github.com/f5devcentral/f5-appworld-labs-ai

[19] OpenShift Container Platform 4.19 release notes (Gateway API GA; production target). https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/release_notes/ocp-4-19-release-notes

[20] Prompt-security gate reference implementation (Nova rules + Laya decision model). https://github.com/shsingh/ai-sec-lab