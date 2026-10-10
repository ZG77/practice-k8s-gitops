#!/usr/bin/env bash
# Read-only. Lists billable resources left after teardown. Empty output per line = clean.
# Usage: scripts/check-leftovers.sh
set -uo pipefail

REGION="eu-central-1"
CLUSTER="practice-dev"
TAG_PROJECT="practice-k8s"
FOUND=0

check() {
  local name="$1" out="$2"
  out="$(echo "$out" | sed '/^None$/d;/^$/d')"
  if [[ -n "$out" ]]; then
    printf '  LEFTOVER %-22s %s\n' "$name" "$(echo "$out" | tr '\n' ' ')"
    FOUND=1
  else
    printf '  ok       %s\n' "$name"
  fi
}

echo "Leftover check ($REGION):"

check "EKS cluster" "$(aws eks list-clusters --region "$REGION" --query "clusters[?@=='$CLUSTER']" --output text)"

check "EC2 instances" "$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag-key,Values=kubernetes.io/cluster/$CLUSTER" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"

check "EBS volumes (unattached)" "$(aws ec2 describe-volumes --region "$REGION" \
  --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output text)"

check "Load balancers (k8s-*)" "$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[?starts_with(LoadBalancerName, 'k8s-')].LoadBalancerName" --output text)"

check "NAT gateways" "$(aws ec2 describe-nat-gateways --region "$REGION" \
  --filter "Name=tag:Project,Values=$TAG_PROJECT" "Name=state,Values=pending,available,deleting" \
  --query 'NatGateways[].NatGatewayId' --output text)"

check "Elastic IPs" "$(aws ec2 describe-addresses --region "$REGION" \
  --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'Addresses[].PublicIp' --output text)"

check "VPCs" "$(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'Vpcs[].VpcId' --output text)"

check "Instance profiles" "$(aws iam list-instance-profiles \
  --query "InstanceProfiles[?starts_with(InstanceProfileName, '${CLUSTER}_')].InstanceProfileName" --output text)"

check "SQS queues" "$(aws sqs list-queues --region "$REGION" --queue-name-prefix "$CLUSTER" \
  --query 'QueueUrls' --output text 2>/dev/null)"

check "CloudWatch log groups" "$(aws logs describe-log-groups --region "$REGION" \
  --log-group-name-prefix "/aws/eks/$CLUSTER" --query 'logGroups[].logGroupName' --output text)"

echo
if [[ "$FOUND" == "0" ]]; then
  echo "Clean. No leftovers found."
else
  echo "Leftovers found. Delete them, or run terraform destroy again."
  exit 1
fi
