# practice-k8s-gitops

Spot-based EKS platform for practice. See `assignment_prod.md` for the requirements.

Two repos:

| Repo | Content |
|------|---------|
| **practice-k8s-gitops** (this one) | Terraform, Argo CD config, Helm values. What runs in the cluster. |
| [practice-k8s-apps](https://github.com/ZG77/practice-k8s-apps) | Source code of `web`, `api`, `worker` and their CI. CI writes new image tags here. |

## Layout

| Folder | Content | Tool |
|--------|---------|------|
| `terraform/envs/shared` | ECR repos, GitHub OIDC role for CI. **Long-lived. Never destroy after a session.** | Terraform |
| `terraform/envs/dev` | VPC, EKS, system nodes, Karpenter AWS side. Destroy after each session. | Terraform |
| `terraform/modules` | vpc, eks, karpenter-aws, iam-pod-identity, argocd-bootstrap | Terraform |
| `bootstrap/root-app` | Argo CD root Application (app-of-apps) | Argo CD |
| `platform/` | Cluster add-ons (Karpenter, KEDA, VPA, LB controller, monitoring, storage, mesh) | Helm via Argo CD |
| `apps/<service>/values.yaml` | Helm values per service. `image.tag` is set by CI. | Helm via Argo CD |
| `scripts/` | `up.sh`, `down.sh`, `check-leftovers.sh` | Bash |
| `docs/` | Scenario notes and diagrams | Markdown |

## Rule

- Terraform: AWS resources and the Argo CD bootstrap.
- Argo CD + Helm: everything inside Kubernetes.
- Do not edit `image.tag` by hand. CI owns it. Roll back with `git revert`.

## Setup

```bash
# One time (long-lived)
terraform -chdir=terraform/envs/shared apply

# Each session
scripts/up.sh --test
```

## Teardown

```bash
scripts/down.sh   # safe order + leftover check. Does not touch terraform/envs/shared.
```
