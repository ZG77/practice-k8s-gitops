#!/usr/bin/env bash
# Tear down everything in the safe order, then check for leftovers.
# Order matters:
#   1. Karpenter must delete its own nodes and instance profile first.
#      (Terraform does not know about them. They block the VPC and IAM role delete.)
#   2. Then terraform destroy.
# Usage: scripts/down.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT/terraform/envs/dev"
REGION="eu-central-1"
CLUSTER="practice-dev"

step() { printf '\n==> %s\n' "$*"; }

if aws eks describe-cluster --region "$REGION" --name "$CLUSTER" >/dev/null 2>&1; then
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" >/dev/null

  step "1/4 Delete workloads that create AWS resources (Ingress -> ALB, PVC -> EBS)"
  # Argo CD apps first. Otherwise selfHeal recreates what we delete.
  if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
    kubectl delete applications.argoproj.io --all -n argocd --wait=true --timeout=10m
  fi
  kubectl delete ingress --all -A --ignore-not-found --wait=true
  kubectl delete pvc --all -A --ignore-not-found --wait=true
  kubectl delete deployment inflate --ignore-not-found

  step "2/4 Delete Karpenter NodePools and EC2NodeClasses (Karpenter removes its nodes)"
  if kubectl get crd nodepools.karpenter.sh >/dev/null 2>&1; then
    kubectl delete nodepool --all --wait=true --timeout=10m
    kubectl delete ec2nodeclass --all --wait=true --timeout=10m
  fi
  echo "Nodeclaims left: $(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l | tr -d ' ')"
else
  echo "Cluster $CLUSTER not found. Skipping Kubernetes cleanup."
fi

step "3/4 terraform destroy (about 15 minutes)"
terraform -chdir="$TF_DIR" init -input=false >/dev/null
terraform -chdir="$TF_DIR" destroy -input=false -auto-approve

step "4/4 Check for leftovers"
"$ROOT/scripts/check-leftovers.sh"
