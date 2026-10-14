# Case Study — Meridian University Research Computing

All lab steps are framed as work orders for a fictional but realistic employer. This gives
every module a purpose and gives the facilitator natural narrative beats between modules.

## The organisation

Meridian University operates a central Research Computing division alongside the
university's general IT estate. On the same campus fabric sit very different tenant
populations, each with different security posture, compliance obligations, and blast-radius
expectations:

| Tenant class | Who they are | What they need |
|---|---|---|
| Teaching and administration | Student record system, LMS, campus Wi-Fi | Predictable, isolated, boring |
| Academic research | Genomics, climate modelling, humanities lab | Disciplined multi-tenancy |
| AI research (natural-language and vision labs) | The GPU-hungry flagship | Performance at the VIP |
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

## The work orders (the narrative arc)

| Module | Work order the class works |
|---|---|
| m01 | "It's just Kubernetes, you'll figure it out" — get fluent in the object model and locate every piece on the three planes. |
| m02 | The CIO asks why AI specifically needs Kubernetes. Ground the answer in GPU scheduling and inference traffic patterns; explain why the HPC clusters stayed on their existing scheduler. |
| m03 | The GPU cluster is purchased; the software load balancer must be installed. Choose host vs DPU placement; install demo mode first, tour real-mode options. |
| m04 | The AI cluster must join the fabric: peer with the campus spine over BGP, isolate tenants with VRF over VXLAN — exactly the way the university separates teaching, research, and industry tenants today. |
| m05 | VRF deep dive: per-tenant routing plus per-tenant ACL enforcement, plus an honest footnote on the MPLS provider-edge status. |
| m06 | The platform team wants self-service ingress without tickets. Enter Gateway API — the "Kubernetes VIP" story, told as one request crossing all three planes. |
| m07 | Classic LB requirements resurface: TCP/UDP services for the genomics cluster, egress identity for tenant SNAT, ACLs between research divisions — all declarative now. |
| m08 | The flagship: 3 replicas of a vLLM-protocol model pool. Naive round-robin wrecks cache economics; install InferencePool + the endpoint picker and watch cache-aware routing work. |
| m09 | Incident review: telemetry, logs, the who-did-what trail — the questions asked during a night incident and after it by the ethics board. |
| m10 (optional) | The operations team wants a GUI for day-1/day-2 operations — and a discussion of what a management-plane surface should and should not hide. |
| m11 (optional) | The CIO's blunt question: can we just run OSS and skip the purchase order? An honest capability walk. |
| m12 (optional) | The security office asks who reads hostile prompts before the model does. A prompt-safety decision engine wired behind the edge. |
| m13 (optional) | The business office asks who meters the shared flagship pool, who protects it, and what happens when one tenant hammers it. The full shared-model control stack. |

## Why the flagship becomes a shared, paid service (m13's motivation)

The flagship model pool serves all tenant classes as a paid shared service: token
consumption is the billable unit, one tenant's bulk job can starve others, prompts from
tenant A must never become steering or cache signal for tenant B, and high-rate floods are
the same hostile pattern aimed at two different targets: network capacity and cache memory.
Module 13 assembles the protection stack on the architecture modules m06–m08 already
built: identity at the edge, isolation, metering, screening, and the audit chain — each a
declaration on the same management plane, enforced by the same data plane.
