# Lab Environment Architecture

The complete lab runs on ONE Linux amd64 VM per attendee: the two Kubernetes nodes are
containers (kind), the fabric spine is a container, and traffic clients are pods — nothing
outside the VM. See [PLAN.md](https://github.com/shsingh/ai-infra-for-neteng/blob/master/PLAN.md#2-lab-architecture) for sizing and the address plan.

## Attendee instance and environment shape

```mermaid
graph TB
  subgraph ATTENDEE["Attendee lab instance — fresh boot, one linux/amd64 VM (16c / 32 GB)"]
    direction TB
    subgraph DOCKER["Docker daemon"]
      subgraph KIND["kind network 172.18.0.0/16"]
        CP["demo-control-plane<br/>Kubernetes control plane<br/>+ regular workloads"]
        WK["demo-worker — label app=f5-tmm<br/>BNK stack pods"]
        subgraph WK_PODS["on demo-worker"]
          TMM["f5-tmm<br/>forwarding engine pod (data plane)"]
          RTS["f5-tmm-routing<br/>OcNOS routing stack (control)"]
          CNE["f5-cne-controller<br/>FLO / FIC (control)"]
          SIM["llm-d-inference-sim x3<br/>model pool (M8)"]
        end
        SPINE["frr-spine container<br/>fabric peer, AS 65110<br/>(vtysh show bgp)"]
      end
    end
    ATT["attendee shell<br/>nix develop — pinned kubectl / kind / helm / jq / yq<br/>KUBECONFIG set"]
  end
  NET{"the room network<br/>web terminal / SSH / console — any access path, same steps"}

  NET --> ATT
  ATT -->|kubectl apply -f manifests/*.yaml| CP
  CP --- WK
  TMM <-->|"eBGP session<br/>Multus net1 bridge 192.168.99.0/24"| SPINE
```

## The three planes a request crosses (m06 preview)

```mermaid
graph LR
  A["Management plane<br/>attendee applies CRs<br/>(Gateway / HTTPRoute / F5EPP)"] --> B["Control plane<br/>controllers compute desired vs observed<br/>FIC allocates VIP · CNE renders config ·<br/>OcNOS routes and advertises · EPP scores pods"]
  B --> C["Data plane<br/>TMM forwards: VIP, SNAT, firewall,<br/>per-request picker consult (ext_proc)"]
  C --> D["Model pods<br/>llm-d-inference-sim pool"]
```

## Module walk (the course arc)

```mermaid
graph LR
  M1["m01<br/>Kubernetes<br/>= mgmt plane"] --> M3["m03<br/>install<br/>BNK 2.4 demo"]
  M3 --> M4["m04<br/>BGP / VRF /<br/>EVPN vs spine"]
  M4 --> M5["m05<br/>per-tenant<br/>VRF + ACL"]
  M5 --> M6["m06<br/>Gateway API:<br/>VIP to route"]
  M6 --> M7["m07<br/>L4Route, egress,<br/>firewall"]
  M7 --> M8["m08<br/>InferencePool<br/>+ F5EPP"]
  M8 --> M9["m09<br/>observability<br/>+ finale"]
  M8 -.-> M10["m10 GUI<br/>(optional)"]
  M8 -.-> M11["m11 OSS<br/>vs buy(?)<br/>(optional)"]
  M8 -.-> M12["m12 prompt<br/>screening<br/>(optional)"]
  M12 --> M13["m13 shared-pool<br/>metering + protection<br/>(optional)"]
  M13 -.-> M10
```

## Offline / restricted-room flow

```mermaid
graph LR
  P["any connected host<br/>nix run .#airgap-bundle"] -->|"labimages.tar<br/>FLO/CNE charts<br/>nix closures"| B["bundle dir<br/>(hash recorded in FACILITATOR.md ledger)"]
  B --> C["attendee instance (no internet)<br/>nix run .#bootstrap -- --offline --bundle ..."]
  C --> D["same lab: environment +<br/>docs render + guides"]
```

## Repository build stages (what the build agent verifies, in order)

```mermaid
graph TB
  S1["stage 1<br/>flake skeleton + doctor"] --> S2["stage 2<br/>BNK 2.4.0 install path<br/>(stop-if-old-BNK gate)"]
  S2 --> S3["stage 3<br/>GAIE CRDs"]
  S3 --> S4["stage 4<br/>fabric spine + routing manifests<br/>BGP Established"]
  S4 --> S5["stage 5<br/>gateway + LB + firewall"]
  S5 --> S6["stage 6<br/>three-CR AI path + tmctl evidence"]
  S6 --> S7["stage 7<br/>optional modules m10-m13"]
  S7 --> S8["stage 8<br/>8 faults + resets"]
  S8 --> S9["stage 9<br/>lab guides from module scripts<br/>+ captured outputs"]
  S9 --> S10["stage 10<br/>2x clean-clone bootstrap +<br/>airgap proof + final PR"]
  S10 -.->|merge by repository owner| DONE["lab live"]
```

Notes: GitHub renders these in markdown directly; the Sphinx site renders the identical
fences (MyST `myst_fence_as_directive` + sphinxcontrib-mermaid). When Stage 9 generates
real guides, module diagrams may move into the module scripts
([docs/course/modules](https://github.com/shsingh/ai-infra-for-neteng/tree/master/docs/course/modules)) — these stay here as the environment
overview.
