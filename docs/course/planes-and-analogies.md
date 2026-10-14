# Teaching Model — Planes, Analogies, and the Audience

## Intended audience

Cisco/Juniper network engineers, fluent in IP/MPLS and BIG-IP LTM, new to Kubernetes. They
are fluent in: TCP/IP, BGP/OSPF/IS-IS, MPLS L3VPN/VPLS, VXLAN/EVPN, ACLs, QoS/DSCP, and BIG-IP
LTM (virtual servers, pools, monitors, SNAT/automap, iRules, profiles, HA, tmsh). Many also
operate declarative estates already (ACI/FMC policy models, Junos Evolved, config-as-code
pipelines) and most have touched public cloud (AWS ALB/NLB, Azure LB, tenants/subscriptions).

Attendees think in devices, interfaces, VLANs, route tables, and control/data planes. The
course keeps that habit and re-points it rather than replacing it.

## The three planes (the course's spine)

| Plane | Classic network | This lab | Specifics |
|---|---|---|---|
| Management | SSH/tmsh/REST per box; config save and sync | The Kubernetes API: kubectl, CRDs, Git, RBAC — the only way to change anything | Controllers reconcile CRs into the forwarding/routing config; the optional GUI is a management-plane surface |
| Control | Routing protocols, RIB computation, keepalives | Controllers computing desired vs observed | The routing stack (OcNOS-class) inside the routing container runs the same protocols, programmed via CRDs; the endpoint picker is a new L7 control function reading application state; token/policy enforcement adds a second shared-model control function |
| Data | Line cards/ASICs forwarding packets | Pod network (CNI) + kube-proxy, and the forwarding engine as a pod | TMM: the hardware-grade forwarding engine — VIPs, SNAT, firewall (demo mode: virtio; production: SR-IOV/DPU) |

Every module ends with a planes check: one line naming which plane(s) the student just
configured, watched, or broke. By the end of the course students fill this table from
memory — that recall is the graduation test.

## Concept mapping (core teaching artifact — print as a one-page handout)

| Traditional construct | Kubernetes / BNK 2.4 analog | Where the analogy stops (taught explicitly) |
|---|---|---|
| Device (chassis) | Node (host) / pod (the forwarding engine runs as a pod) | The "box" is software; scale = replicas, not chassis |
| Management plane (SSH/tmsh) | kubectl + CRDs + controllers | No CLI login to "the device"; config is declarative YAML |
| VLAN + interface | The Infra CRD's VLAN sections with SelfIPs | Still recognizably VLANs — an early win |
| Static route | Infra CRD static-route section | Direct mapping |
| VRF | VRF section of the Infra CRD — GA in 2.4 with per-tenant ACL enforcement | Per-tenant via CRD, not per-box |
| BGP speaker in the routing stack | OcNOS in the routing container: BGP/EVPN/BFD | Same protocols, new plumbing: CRD → Go template → gRPC → CLI |
| Virtual server (VIP) | Gateway + listener (Gateway API) or L4Route CRs | The VIP is now a CR; IP allocation is a controller |
| Pool | InferencePool (AI pools) or Service endpoint discovery | Membership is live pod lifecycle, not static config |
| iRule | iRules still exist: the Irule CR + NetPolicy attachment | Supported events/commands are a subset |
| SNAT pool / egress | EgressGateway CR | Same mental model; now a Gateway-API-shaped object |
| ACL/Firewall | FwPolicy/FwRulelist attached via SecPolicy | The policy-attachment pattern |
| Route reflector / fabric | The campus fabric stays in place; peering is configured via BGP CRDs | Kubernetes does not replace the fabric |
| Console/LED status | kubectl get, CR status fields, pod logs | "Show commands" become kubectl get/describe/logs |

## The analogy grid (second handout — use the column most familiar to the student)

| Construct | BIG-IP/tmsh | Cisco/Juniper | Public cloud | Kubernetes |
|---|---|---|---|---|
| Partition (admin boundary) | Partitions | ACI tenant; FMC device groups | Azure tenant/subscription; AWS account | Namespace (CRs are namespace-scoped) |
| Reading config vs state | tmsh list vs tmsh show | show running-config | Console describe-* | kubectl get — desired and observed merged in one object |
| Declarative config input | load sys config from-terminal | Commit-style config; config-as-code CI | Infrastructure-as-code plan/apply | kubectl apply -f — the file is the config, the API reconciles it |
| Object model | Virtual server, pool, monitor | IOS/Junos stanzas | ALB listener + rules; frontend IP + LB rules | CRs: GlobalRoutingConfig, Gateway, HTTPRoute — stanzas in YAML |

A relevant precedent: tmsh was already partly declarative — `load sys config from-terminal`
accepts a complete config text and merges it against current state. BNK moves that text to
YAML files in Git and delegates the merge to a controller. The operator habit transfers
directly; the review and rollback path is stronger.

## Six recurring pitfalls for this audience (teach explicitly)

1. No per-device configuration. No one logs into the forwarding pod to configure it; the
   declarative path is writing CRs, which controllers reconcile. Debugging = reading CR status and pod logs.
2. Desired state versus imperative. Direct CR edits work but are replaced by the next
   apply; the configuration lives in Git — GitOps is the norm.
3. CNI is not the data plane. Calico gives pods L3; the F5 forwarding engine is a
   separate, hardware-grade plane attached via VLANs/SR-IOV (virtio in demo mode). Two
   routing stacks coexist — knowing which one carries what is a core skill.
4. Names are namespaces. Every CR is namespace-scoped; a "missing VIP" is usually a wrong
   namespace, not a misconfig. In 2.4 this carries an enforcement point: the F5EPP reconciliation only
   happens in namespaces listed in `CNEInstance.spec.eppNamespaces`.
5. Health is declarative. kubectl get shows desired vs observed; learn to read status
   conditions as the new "session up" signal.
6. Some CRs are immutable. Notably the routing CRDs — change = delete + recreate. The
   safety check moves from apply-time to review-time (Git review, maintenance windows).

## Teaching method

- Layer-cake framing in every module: Kubernetes runs containers and programs the network
  through controllers; the F5 plane is the forwarding "box"; CRDs are the configuration
  language; the campus fabric is unchanged.
- Every module: a short concept talk with the relevant mapping-slice → guided hands-on
  typed by the student (never pasted blindly) → verification checkpoint → one break-fix
  drill → one scenario step that advances the case study.
- Deliberately reuse networker reflexes: BGP neighbor states, show-equivalents (kubectl
  exec + tcpdump in the TMM pod), ACL logic.
- End every module with the planes check (above).

## The KV-cache lesson (why AI load balancing is not HTTP load balancing)

Serving an LLM is stateful per user: each running request holds a key-value cache (the
model's attention state for that conversation) in GPU memory. Two pods behind the same
Service are NOT identical — one holds the cached prefix of the user's long conversation,
the other starts cold. Losing the cache re-pays the entire prefill of the context, so a
round-robin pick between identical-looking pods can mean the difference between instant
continuation and re-processing a long prompt. Cache hit rate is the scarce resource;
queue depth and running-request counts are the visible signals. The endpoint picker reads
both (per-request, body-inclusive, via the ext_proc consult) and steers to the pod that
already holds the state. This is the conceptual anchor of module 8 and the direct answer
to "why is this not just LTM": because no packet-header control plane can see cache state.

## Scoping discipline (standing rule)

Features that are Early Access (semantic AI caching) or outside the demo-mode shape
(DPU/SR-IOV hardware paths, GRPCRoute on the two-node cluster) are taught as demo/slides
material with explicit labels, never as hands-on work, and lab exercises never depend on
them.
