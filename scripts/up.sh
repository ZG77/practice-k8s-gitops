#!/usr/bin/env bash
# Create the cluster and install Karpenter and metrics-server.
# Usage: scripts/up.sh [--test]
#   --test  run the inflate test (5 pods x 1 CPU) and show the new Spot nodes
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT/terraform/envs/dev"
REGION="eu-central-1"
CLUSTER="practice-dev"
KARPENTER_VERSION="1.14.1"
METRICS_SERVER_VERSION="3.14.0"

step() { printf '\n==> %s\n' "$*"; }

step "1/6 Set your IP in terraform.tfvars"
MY_IP="$(curl -s https://checkip.amazonaws.com)"
echo "allowed_cidrs = [\"${MY_IP}/32\"]" > "$TF_DIR/terraform.tfvars"
echo "IP: $MY_IP"

step "2/6 terraform apply (about 15 minutes)"
terraform -chdir="$TF_DIR" init -input=false >/dev/null
terraform -chdir="$TF_DIR" apply -input=false -auto-approve

step "3/6 kubeconfig"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"
kubectl wait --for=condition=Ready nodes --all --timeout=5m

step "4/6 Install Karpenter $KARPENTER_VERSION"
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "$KARPENTER_VERSION" -n karpenter --create-namespace \
  -f "$ROOT/platform/karpenter/values.yaml" --wait --timeout 5m

step "5/6 Apply EC2NodeClass and NodePool"
kubectl apply -f "$ROOT/platform/karpenter/resources/"
kubectl wait --for=condition=Ready ec2nodeclass/default --timeout=3m
kubectl wait --for=condition=Ready nodepool/spot-arm64 --timeout=3m

step "6/6 Install metrics-server $METRICS_SERVER_VERSION"
helm upgrade --install metrics-server metrics-server \
  --repo https://kubernetes-sigs.github.io/metrics-server/ \
  --version "$METRICS_SERVER_VERSION" -n kube-system \
  -f "$ROOT/platform/metrics-server/values.yaml" --wait --timeout 5m

if [[ "${1:-}" == "--test" ]]; then
  step "Test: inflate 5 pods x 1 CPU"
  kubectl create deployment inflate --image=public.ecr.aws/eks-distro/kubernetes/pause:3.10 --replicas=0
  kubectl set resources deployment inflate --requests=cpu=1
  kubectl scale deployment inflate --replicas=5
  kubectl rollout status deployment inflate --timeout=5m
  kubectl get nodeclaims
  echo "Remove the test: kubectl delete deployment inflate"
fi

step "Done"
kubectl get nodes -L karpenter.sh/capacity-type,node.kubernetes.io/instance-type,topology.kubernetes.io/zone
echo
echo "Cost: about \$0.20/hour. Run scripts/down.sh when you finish."
