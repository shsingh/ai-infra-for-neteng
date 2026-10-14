# Case Study — Meridian University Research Computing

Every module is taught as a work order issued by a fictional but realistic employer,
Meridian University. The scenario gives each configuration change a technical and
organisational justification and links the thirteen modules into one continuous
engagement, from platform arrival to a governed shared model service.

## The organisation

Meridian University operates a central Research Computing division alongside the
university's general IT estate. On the same campus fabric sit very different tenant
populations, each with different security posture, compliance obligations, and blast-radius
expectations:

| Tenant class | Description | Requirements |
|---|---|---|
| Teaching and administration | Student record system, LMS, campus Wi-Fi | Predictability, isolation, stability |
| Academic research | Genomics, climate modelling, humanities lab | Disciplined multi-tenancy |
| AI research (natural-language and vision labs) | The GPU-intensive flagship pool | Performance at the VIP |
| Industry partners and collaborating institutions | Pay for compute time under data-sharing agreements | Metering, quotas, enforceable boundaries |

The isolation requirement is real, not decorative: a compromised undergraduate workload
must never share a routing table with a partner's proprietary training data, and the
governed human-health data project must be separable from everything else on demand.

## The network team's stake

The university runs its campus and research fabric the way a service provider runs a
network: BGP underlay, L3VPN-style tenant isolation, central firewalling. The network team
has run BIG-IP LTM for a decade; every external and cross-tenant service enters through a
BIG-IP VIP with tmsh-familiar operations behind it.

The AI platform lands on their desk with a clear brief: make ingress to the new GPU
cluster work like everything else — routed, firewalled, VRF-isolated per tenant class —
and let the platform team self-serve without raising tickets for every new service.

## Module work orders

- **m01 — Kubernetes for Network Engineers.** The platform team hands the AI platform over with "it's just Kubernetes." Attendees build fluency in the object model, inventory the running components, and locate every piece on the three planes. Deliverable: a diagnosed Service selector fault.
- **m02 — Why AI Runs on Kubernetes.** The CIO asks why the AI platform introduces Kubernetes when the estate already runs VMs behind BIG-IP. The module answers from GPU scheduling and inference traffic patterns, and establishes why packet-header load balancing cannot see cache state.
- **m03 — Installing the Platform.** The GPU cluster is approved; BNK 2.4 must be installed. Attendees install demo mode on the two-node lab cluster and compare host and DPU placement for production, including the OpenShift (Host) requirement and what demo mode omits.
- **m04 — BGP, VRF, EVPN.** The AI cluster must join the campus routing fabric like any other site: eBGP peering with the spine, tenant VRF over VXLAN, and advertisement of the future VIP — the same discipline the university uses to separate teaching, research, and industry tenants today, expressed as CRs.
- **m05 — Per-Tenant Isolation.** Tenant classes are policy, not just routing tables: per-tenant dynamic routing (VRF, GA in 2.4) plus per-tenant ACL enforcement, with the MPLS provider-edge capability (Early Access) scoped and explicitly excluded from the hands-on.
- **m06 — Gateway API: from VIP to Route.** Platform teams request self-service ingress without network-team tickets. Gateway API provides it: VIP allocation via FIC, one request traced across all three planes, and an iRule attached through the declarative path. Includes the wrong-namespace fault.
- **m07 — Traditional Load Balancing.** Classic requirements return on the same platform: TCP/UDP services for the genomics cluster, per-tenant egress identity (EgressGateway), and ACLs between research divisions — all declared as CRs, all verified in the data plane and the log stream.
- **m08 — AI Inference Routing.** Three vLLM-protocol replicas behind naive round-robin show poor time-to-first-token and near-zero cache hit rates. Attendees install InferencePool + the F5 endpoint picker and verify cache-aware steering with tmctl, including a fail-close configuration.
- **m09 — Observability and Consolidated Review.** The platform is live; the module consolidates operations: CR status, TMM telemetry, tmctl as the show-tech, a scored multi-fault break-fix drill, and a from-memory review of the concept mappings.
- **m10 (optional) — Management GUI.** Day-2 operations request a management surface: dashboards, audit trail, fleet view. bnk-forge is bound to the lab cluster and assessed for what a GUI may and may not replace on the management plane.
- **m11 (optional) — OSS Capability Assessment.** The CIO asks whether the platform can run on open-source software alone. Attendees walk the capability table from both sides and identify where a commercial platform is — and is not — a requirement.
- **m12 (optional) — Prompt Screening at the Edge.** The security office requires screening of arbitrary campus prompts before the model is reached: an open-weights decision model hosted by the rule engine, wired behind the edge, verified against a seed jailbreak corpus.
- **m13 (optional) — Protecting and Metering the Shared Model.** The flagship pool operates as a paid shared service for three tenant classes: edge identity, per-tenant isolation, token metering with per-policy budgets, DoS shielding, and the audit chain — all on the Module 8 architecture.

## Why the flagship pool is shared and metered (m13 motivation)

The flagship model pool serves all tenant classes as a paid shared service: token
consumption is the billable unit, one tenant's bulk job can starve others, prompts from
tenant A must never become steering or cache signal for tenant B, and high-rate floods are
the same hostile pattern aimed at two different targets: network capacity and cache memory.
Module 13 assembles the protection stack on the architecture modules m06–m08 already
built: identity at the edge, isolation, metering, screening, and the audit chain — each a
declaration on the same management plane, enforced by the same data plane.
