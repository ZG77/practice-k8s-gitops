# Self-Practice: Spot-Based EKS Platform

## 1. Goal

Build a small, cheap EKS platform for practice.

Practice targets:

- EKS with Terraform / OpenTofu
- Karpenter on Spot (arm64)
- Autoscaling: HPA, KEDA, VPA (each on a different service)
- Argo CD (GitOps)
- AWS Load Balancer Controller (ALB)
- Prometheus + Grafana
- Spot interruption handling

This is **not** the interview assignment. It extends the work in `docs/assignment.md`.

---

## 2. Decisions (already made)

| Topic | Decision |
|-------|----------|
| Cloud | AWS EKS |
| IaC | Terraform / OpenTofu |
| Ingress | AWS Load Balancer Controller (ALB, IP target type) |
| DNS / TLS | No domain. Use the ALB hostname. HTTP only. ExternalDNS is a stretch goal. |
| Grafana | Runs in the cluster. Access with `kubectl port-forward`. Not public. |
| Node CPU | arm64 (Graviton) only |
| Capacity | Spot for all workloads. On-demand only for system nodes. |
| App | Black box. Only serves requests and burns CPU / memory on demand. |
| Environments | One cluster, one environment (`dev`). Staging / prod folders are optional. |
| Storage | EBS CSI driver with `gp3` volumes. Persistent disks for Prometheus and Grafana. |

---

## 3. Open Questions (my defaults)

Change these if you want.

| Question | Default |
|----------|---------|
| AWS region | `eu-central-1` (check Spot availability for your instance types) |
| Third service | Yes. Three services. See section 5. |
| Pod IAM | EKS Pod Identity (know IRSA too) |
| EKS version | `1.35` at start. Then practice upgrades: `1.35` → `1.36` → `1.37`. |

---

## 4. Infrastructure Requirements

### 4.1 Network (Terraform)

- One VPC, 3 AZs.
- Public and private subnets.
- **One** NAT gateway (cost). Document the HA trade-off.
- Subnet tags for ALB and Karpenter discovery.

### 4.2 EKS (Terraform)

- EKS cluster, public endpoint restricted to your IP.
- Core add-ons: VPC CNI, CoreDNS, kube-proxy, EKS Pod Identity Agent, EBS CSI driver.
- Network policy support enabled in VPC CNI.
- Control plane logging: enable only what you need (cost).
- **Do not use EKS Auto Mode.** You want to practice Karpenter yourself.

### 4.3 System node group

- Managed node group, **on-demand**, arm64, `t4g.medium`, 2 nodes (1 is acceptable for practice).
- Taint: `CriticalAddonsOnly`.
- Runs: Karpenter, CoreDNS, AWS LB Controller, Argo CD, metrics-server.
- Reason: Karpenter must not run on nodes that it creates.

### 4.4 Karpenter

- `EC2NodeClass`: AL2023 arm64 (or Bottlerocket), discovery by tags.
- `NodePool` for Spot:
  - Families: `t4g`, `c6g`, `c7g`, `m6g`, `m7g` (diversify for Spot).
  - Sizes: small to large.
  - `capacity-type: spot` only.
  - CPU limit on the pool (example: 16 vCPU) to cap cost.
  - Consolidation: `WhenEmptyOrUnderutilized`.
- Interruption handling: SQS queue + EventBridge rules.
- Learning point: `t4g` is burstable. Under load tests, CPU credits can run out. Compare with `c6g` / `c7g`.

### 4.5 IAM

- Pod Identity (or IRSA) for Karpenter, AWS LB Controller, and EBS CSI driver.
- Least-privilege policies. No `*` actions.

---

## 5. Application Requirements

Three tiny services. Treat each as a black box.

| Service | Namespace | Scaling practice |
|---------|-----------|------------------|
| `web` | `frontend` | **HPA** on CPU |
| `api` | `backend` | **KEDA** with a Prometheus trigger (requests per second) |
| `worker` | `backend` | **VPA** (no HPA / KEDA on this one) |

Each service must:

- Support `linux/arm64`. Use a multi-arch image.
- Expose `/healthz` and `/metrics` (Prometheus format).
- Have an endpoint that burns CPU (example: `/cpu?ms=200`).
- Have an endpoint that allocates memory (example: `/mem?mb=50`).
- Run as non-root, with requests, limits, and probes.

Image source: a small public image, or a tiny app you write. Keep the Dockerfile small.

**Rule:** never put HPA / KEDA and VPA on the same CPU or memory metric for the same workload. KEDA creates an HPA internally.

Stretch: run VPA in `Off` mode on `web` to only read recommendations.

---

## 6. Kubernetes Requirements

- Namespaces: `frontend`, `backend`, plus platform namespaces.
- Deployment, Service, ConfigMap, ServiceAccount per service.
- Resource requests and limits.
- Liveness and readiness probes.
- Security context (non-root, read-only root filesystem, drop all capabilities).
- PodDisruptionBudget on every service.
- `topologySpreadConstraints` across zones.
- NetworkPolicy: default deny, then allow only `web → api` and Prometheus scrape.
- Helm or Kustomize (choose one, explain why).
- metrics-server and VPA installed.

---

## 7. Ingress

- AWS Load Balancer Controller.
- **One shared ALB** (IngressGroup) to save cost.
- Paths: `/` → `web`, `/api` → `api`.
- Target type: `ip`.
- HTTP only. Document why (no domain, so no ACM certificate).

Stretch: ExternalDNS + Route53 + ACM TLS. Needs a domain or a delegated subdomain.

---

## 8. GitOps (Argo CD)

- Argo CD installed by Terraform (bootstrap only) or by one manual step. Document it.
- App-of-apps or ApplicationSet.
- Everything else is installed through Argo CD:
  - metrics-server, VPA, KEDA
  - AWS LB Controller
  - kube-prometheus-stack
  - the three services
- Auto-sync with `prune` and `selfHeal`.
- Use sync waves so CRDs install before resources that use them.
- Know how to roll back (Git revert and Argo CD history).

---

## 9. Monitoring

- `kube-prometheus-stack`: Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics.
- StorageClass `gp3` with `volumeBindingMode: WaitForFirstConsumer`. Installed by Argo CD.
- Prometheus: persistent volume (example: 10 GiB `gp3`). Short retention (example: 2d).
- Grafana: small persistent volume (example: 1 GiB `gp3`) for changes made in the UI.
- Dashboards as code (ConfigMap) are the source of truth. They survive `terraform destroy`. The disk does not.
- Learning point: an EBS volume is bound to one AZ. The pod can restart only in that AZ. A Spot shortage there can leave the pod `Pending`.
- Prometheus and Grafana are single replicas. A Spot interruption causes a few minutes of downtime. Data stays on the disk. Document it.
- `ServiceMonitor` for each service.
- Grafana: access with port-forward only.
- Dashboards: cluster, nodes, and one for the three services (requests, replicas, CPU, memory).
- At least **3 alerts**:
  - Pod crash looping
  - Deployment has no available replicas
  - HPA at max replicas for a long time
- Stretch alerts: Karpenter cannot provision, node under memory pressure.

---

## 10. Spot and Resilience

- All workloads run on Spot nodes.
- Every service has at least 2 replicas and a PDB.
- Prove interruption handling:
  - Send a test Spot interruption (AWS FIS or a test event to the Karpenter queue).
  - Confirm that pods move with no outage.
- Know what is **not** safe on Spot: single-replica stateful workloads (Prometheus, Grafana). The disk keeps the data, but the service has downtime during the move.

---

## 11. Cost Control

Approximate costs (check current AWS pricing):

| Item | Cost |
|------|------|
| EKS control plane | ~$0.10 / hour |
| NAT gateway | ~$0.045 / hour + data |
| ALB | ~$0.02 / hour + LCU |
| 2 × `t4g.medium` on-demand | ~$0.07 / hour total |
| Spot nodes | ~70% cheaper than on-demand |
| EBS `gp3` volumes (~11 GiB) | ~$0.90 / month |

Rules:

- AWS Budget alert (example: $20).
- Tag all resources.
- Destroy the cluster after each practice session.
- **Teardown order:**
  1. Delete Argo CD apps and Ingresses (this removes the ALB).
  2. Delete all PVCs (this removes the EBS volumes). Check that the PVs are gone.
  3. Wait for Karpenter nodes to disappear.
  4. `terraform destroy`.
  5. Check for leftover ALBs, ENIs, EBS volumes, and NAT gateways.

---

## 12. Practice Scenarios

Do each one. Write down what you saw.

1. **HPA:** load `web` with CPU requests. Watch replicas and new Spot nodes.
2. **KEDA:** send requests to `api`. Watch scaling by requests per second. Scale down to the minimum.
3. **VPA:** run `worker` under steady load. Compare the recommendation with your requests.
4. **Karpenter:** watch node launch, instance type choice, and consolidation after load stops.
5. **Spot interruption:** simulate it. Check for downtime.
6. **PDB:** drain a node. See the PDB block or slow the drain.
7. **Drift:** change a resource by hand. See Argo CD `selfHeal` restore it.
8. **Rollback:** deploy a bad image. Roll back with Git.
9. **NetworkPolicy:** try to call `api` from a wrong namespace. Confirm it fails.
10. **Burstable CPU:** run the same load on `t4g` and `c7g`. Compare throttling.

---

## 13. Deliverables

- Terraform code (VPC, EKS, node group, Karpenter, IAM, SQS, EBS CSI driver).
- GitOps repo folders (`apps/`, `platform/`, `bootstrap/`).
- Service source code and Dockerfile.
- README with setup and teardown steps.
- Architecture diagram.
- Notes for each scenario in section 12.
- Trade-offs and known limitations.

---

## 14. Suggested Order

1. VPC + EKS + system node group
2. Karpenter + first Spot node
3. Argo CD bootstrap
4. metrics-server, AWS LB Controller, ALB for `web`
5. `gp3` StorageClass + kube-prometheus-stack + Grafana (with persistent volumes)
6. `api` + KEDA
7. `worker` + VPA
8. NetworkPolicy + PDB + alerts
9. Scenarios from section 12
10. Documentation and teardown test

---

## 15. Definition of Done

- [ ] `terraform apply` creates a working cluster from zero.
- [ ] Argo CD installs everything else. No manual `kubectl apply` after bootstrap.
- [ ] All workload nodes are Spot and arm64.
- [ ] HPA, KEDA, and VPA each work on their own service.
- [ ] A Spot interruption causes no outage.
- [ ] Grafana shows metrics. Three alerts fire when tested.
- [ ] Prometheus metrics and Grafana UI changes survive a pod restart.
- [ ] `terraform destroy` leaves no leftover billable resources (including EBS volumes).
