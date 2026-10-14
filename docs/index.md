# AI Infrastructure for Network Engineers — Lab Guides

Task-based lab guides for the course: BIG-IP Next for Kubernetes 2.4, delivered as a
self-bootstrapping lab from [this repository](https://github.com/shsingh/ai-infra-for-neteng).

## The lab environment

| Variable | Value (adjust per delivery) |
|---|---|
| Lab host | Linux amd64 VM, 16 vCPU / 32 GB RAM / 160 GB disk |
| Access | SSH to the assigned host; work in `nix develop` |
| KUBECONFIG | exported by `nix develop` (the bootstrap kubeconfig path is printed by `doctor`) |
| External VIPs | 11.19.1.0/16 (Gateway VIPs, controller-allocated) |
| Fabric peering | 198.51.100.0/24 — the fabric spine container (AS 65110) |
| Tenant classes | tenant-teaching, tenant-research, tenant-ai (built in the labs), tenant-industry |
| The case study | Meridian University Research Computing — `course/case-study.md` in the repository |

Start with lab01. Guides are plain, task-based, and every expected output in them comes
from a captured run in this repository.

## Guides

01. [Kubernetes for network engineers](labs/lab01-kubernetes.md)
02. [Install the platform](labs/lab02-install-bnk.md)
03. [BGP, VRF, EVPN](labs/lab03-routing-bgp.md)
04. [Tenant isolation deep dive](labs/lab04-tenant-isolation.md)
05. [Gateway API](labs/lab05-gateway-api.md)
06. [Traditional load balancing](labs/lab06-traditional-lb.md)
07. [AI inference routing](labs/lab07-ai-inference.md)
08. [Observability](labs/lab08-observability.md)
09. [Management GUI](labs/lab09-bnk-forge.md) (optional)
10. [Open source vs buy](labs/lab10-oss-vs-bnk.md) (optional)
11. [Prompt screening at the edge](labs/lab11-ai-sec.md) (optional)
12. [Shared-model metering and protection](labs/lab12-shared-model-security.md) (optional)
