#!/usr/bin/env bash
# ============================================================
# PlanOdkupow QA — Tagging Compliance Audit Script
# Scope:   vpc-007d115c41f079bf3 (new QA VPC ONLY)
# Account: 333320664022
# Profile: plan  |  Region: eu-central-1
#
# Usage:
#   bash planodkupow-qa-tagging-audit.sh 2>&1 | tee /tmp/planodkupow-qa-audit-$(date +%Y-%m-%d).txt
#
# Prerequisites: aws cli v2, jq
# ============================================================

set -euo pipefail

# ── Config ───────────────────────────────────────────────────
VPC_ID="vpc-007d115c41f079bf3"
PROFILE="${AWS_PROFILE:-plan}"
REGION="${AWS_REGION:-eu-central-1}"
ECS_CLUSTER="planodkupow-qa-Klaster"

# Expected tag values (case-insensitive match on Project)
REQUIRED_PROJECT="planodkupow"
REQUIRED_ENV="qa"

# ── Counters ─────────────────────────────────────────────────
TOTAL=0; COMPLIANT=0; CRITICAL=0; MAJOR=0; MINOR=0; ORPHAN=0; PROP_BREAKS=0

declare -a CRIT_LIST=(); declare -a MAJ_LIST=(); declare -a MIN_LIST=()
declare -a ORPHAN_LIST=(); declare -a PROP_BREAK_LIST=()

# ── AWS CLI wrapper ──────────────────────────────────────────
A() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

# ── Tag extractor ────────────────────────────────────────────
# Usage: get_tag TAGS_JSON KEY
get_tag() { echo "$1" | jq -r --arg k "$2" '.[] | select(.Key==$k) | .Value' 2>/dev/null | head -1; }

# ── Core tag analyzer ────────────────────────────────────────
# Returns pipe-delimited: SEVERITY|CRIT_MISSING|MAJ_MISSING|MIN_MISSING|DRIFT|MANAGED_BY
analyze_tags() {
  local tags_json="$1"
  local resource_id="$2"
  local resource_type="$3"

  local project env owner managed_by cost_center name service component
  project=$(get_tag    "$tags_json" "Project")
  env=$(get_tag        "$tags_json" "Environment")
  owner=$(get_tag      "$tags_json" "Owner")
  managed_by=$(get_tag "$tags_json" "ManagedBy")
  cost_center=$(get_tag "$tags_json" "CostCenter")
  name=$(get_tag       "$tags_json" "Name")
  service=$(get_tag    "$tags_json" "Service")
  component=$(get_tag  "$tags_json" "Component")

  local crit="" maj="" min="" drift=""

  # Required: Project
  if [ -z "$project" ]; then
    crit="Project"
  elif ! echo "${project,,}" | grep -qE "^planodkupow$"; then
    drift="Project=${project}(unexpected)"
  fi

  # Required: Environment
  if [ -z "$env" ]; then
    crit="${crit:+$crit,}Environment"
  elif [ "${env,,}" != "qa" ]; then
    drift="${drift:+$drift; }Env=${env}≠qa"
  fi

  # Required: CostCenter
  [ -z "$cost_center" ] && crit="${crit:+$crit,}CostCenter"

  # Required: Owner
  [ -z "$owner" ] && maj="Owner"

  # Required: ManagedBy + value validation
  if [ -z "$managed_by" ]; then
    maj="${maj:+$maj,}ManagedBy"
  elif ! echo "${managed_by,,}" | grep -qE "^(cloudformation|terraform)$"; then
    drift="${drift:+$drift; }ManagedBy=${managed_by}∉allowed"
  fi

  # Recommended
  [ -z "$name" ]      && min="Name"
  [ -z "$service" ]   && min="${min:+$min,}Service"
  [ -z "$component" ] && min="${min:+$min,}Component"

  local severity
  if [ -n "$crit" ]; then
    severity="CRITICAL"; ((CRITICAL++)) || true
    CRIT_LIST+=("$resource_id [$resource_type]: missing $crit")
  elif [ -n "$maj" ] || [ -n "$drift" ]; then
    severity="MAJOR";    ((MAJOR++)) || true
    MAJ_LIST+=("$resource_id [$resource_type]: ${maj:+missing $maj }${drift:+DRIFT:$drift}")
  elif [ -n "$min" ]; then
    severity="MINOR";    ((MINOR++)) || true
    MIN_LIST+=("$resource_id [$resource_type]: missing $min")
  else
    severity="OK";       ((COMPLIANT++)) || true
  fi
  ((TOTAL++)) || true

  # Orphan: no Project AND no ManagedBy = manual creation suspected
  if [ -z "$project" ] && [ -z "$managed_by" ]; then
    ((ORPHAN++)) || true
    ORPHAN_LIST+=("$resource_id [$resource_type]")
  fi

  echo "${severity}|${crit:-none}|${maj:-none}|${min:-none}|${drift:-none}|${managed_by:-ABSENT}"
}

# ── Propagation check ────────────────────────────────────────
check_propagation() {
  local parent_id="$1"
  local child_id="$2"
  local child_type="$3"
  local parent_tags_json="$4"
  local child_tags_json="$5"

  local p_project p_env c_project c_env
  p_project=$(get_tag "$parent_tags_json" "Project")
  p_env=$(get_tag     "$parent_tags_json" "Environment")
  c_project=$(get_tag "$child_tags_json"  "Project")
  c_env=$(get_tag     "$child_tags_json"  "Environment")

  local break_found=0
  local reason=""
  [ "${p_project,,}" != "${c_project,,}" ] && break_found=1 && reason="Project:${p_project}→${c_project}"
  [ "${p_env,,}" != "${c_env,,}" ] && break_found=1 && reason="${reason:+$reason; }Env:${p_env}→${c_env}"

  if [ "$break_found" -eq 1 ]; then
    ((PROP_BREAKS++)) || true
    PROP_BREAK_LIST+=("PROPAGATION BREAK: $parent_id → $child_id [$child_type]: $reason")
    echo "BREAK|$reason"
  else
    echo "OK|"
  fi
}

# ── Print table row ──────────────────────────────────────────
row() {
  local id="$1" type="$2" analysis="$3" evidence="${4:-}"
  IFS='|' read -r sev crit maj min drift mby <<< "$analysis"
  local missing="${crit/none/}${maj:+${crit:+,}$maj}"
  missing="${missing/none/}"
  printf "| %-44s | %-28s | %-8s | %-32s | %-22s | %-15s | %s\n" \
    "$id" "$type" "$sev" "$missing" "${drift/none/}" "$mby" "$evidence"
}

# ── Section header ───────────────────────────────────────────
section() { printf "\n### %s\n\n" "$1"; }

header() {
  printf "| %-44s | %-28s | %-8s | %-32s | %-22s | %-15s | %s\n" \
    "ResourceId" "ResourceType" "Severity" "MissingTags" "Drift" "ManagedBy" "Evidence"
  printf "|%s|%s|%s|%s|%s|%s|%s\n" \
    "$(printf '%0.s-' {1..46})" "$(printf '%0.s-' {1..30})" \
    "$(printf '%0.s-' {1..10})" "$(printf '%0.s-' {1..34})" \
    "$(printf '%0.s-' {1..24})" "$(printf '%0.s-' {1..17})" \
    "$(printf '%0.s-' {1..20})"
}

# ============================================================
# MAIN AUDIT
# ============================================================

echo "# PlanOdkupow QA — Tagging Compliance Audit"
echo "# Date: $(date +%Y-%m-%d)"
echo "# VPC: $VPC_ID  |  Profile: $PROFILE  |  Region: $REGION"
echo ""

# ── A: VPC ───────────────────────────────────────────────────
section "A. VPC"
header
VPC_TAGS=$(A ec2 describe-vpcs --vpc-ids "$VPC_ID" | jq '.Vpcs[0].Tags // []')
VPC_ANALYSIS=$(analyze_tags "$VPC_TAGS" "$VPC_ID" "VPC")
row "$VPC_ID" "VPC" "$VPC_ANALYSIS" "root resource"

# ── B: Subnets ───────────────────────────────────────────────
section "B. Subnets"
header
SUBNETS=$(A ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  | jq '.Subnets[] | {id: .SubnetId, tags: (.Tags // []), az: .AvailabilityZone, cidr: .CidrBlock}')
while IFS= read -r subnet; do
  sid=$(echo "$subnet" | jq -r '.id')
  stags=$(echo "$subnet" | jq '.tags')
  az=$(echo "$subnet" | jq -r '.az')
  cidr=$(echo "$subnet" | jq -r '.cidr')
  analysis=$(analyze_tags "$stags" "$sid" "Subnet")
  row "$sid" "Subnet" "$analysis" "$az $cidr"
done < <(A ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  | jq -c '.Subnets[] | {id: .SubnetId, tags: (.Tags // []), az: .AvailabilityZone, cidr: .CidrBlock}')

# ── C: Route Tables ──────────────────────────────────────────
section "C. Route Tables"
header
while IFS= read -r rt; do
  rtid=$(echo "$rt" | jq -r '.id')
  rttags=$(echo "$rt" | jq '.tags')
  analysis=$(analyze_tags "$rttags" "$rtid" "RouteTable")
  row "$rtid" "RouteTable" "$analysis" ""
done < <(A ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" \
  | jq -c '.RouteTables[] | {id: .RouteTableId, tags: (.Tags // [])}')

# ── D: Internet Gateway ──────────────────────────────────────
section "D. Internet Gateway"
header
while IFS= read -r igw; do
  igwid=$(echo "$igw" | jq -r '.id')
  igwtags=$(echo "$igw" | jq '.tags')
  analysis=$(analyze_tags "$igwtags" "$igwid" "InternetGateway")
  row "$igwid" "InternetGateway" "$analysis" "attached to $VPC_ID"
done < <(A ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  | jq -c '.InternetGateways[] | {id: .InternetGatewayId, tags: (.Tags // [])}')

# ── E: NAT Gateways ──────────────────────────────────────────
section "E. NAT Gateways"
header
NAT_COUNT=$(A ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
  | jq '.NatGateways | length')
if [ "$NAT_COUNT" -eq 0 ]; then
  echo "_No NAT Gateways in new QA VPC (expected — public subnet architecture)._"
else
  while IFS= read -r nat; do
    natid=$(echo "$nat" | jq -r '.id')
    nattags=$(echo "$nat" | jq '.tags')
    analysis=$(analyze_tags "$nattags" "$natid" "NatGateway")
    row "$natid" "NatGateway" "$analysis" "unexpected in new VPC"
  done < <(A ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    | jq -c '.NatGateways[] | {id: .NatGatewayId, tags: (.Tags // [])}')
fi

# ── F: VPC Endpoints ─────────────────────────────────────────
section "F. VPC Endpoints"
header
VPC_EP_COUNT=$(A ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=vpc-endpoint-state,Values=available,pending" \
  | jq '.VpcEndpoints | length')
if [ "$VPC_EP_COUNT" -eq 0 ]; then
  echo "_No VPC Endpoints in new QA VPC. All 4 standard endpoints reside in OLD VPC (out of scope). Architecture: internet egress via IGW._"
else
  while IFS= read -r ep; do
    epid=$(echo "$ep" | jq -r '.id')
    eptags=$(echo "$ep" | jq '.tags')
    svc=$(echo "$ep" | jq -r '.service')
    analysis=$(analyze_tags "$eptags" "$epid" "VpcEndpoint")
    row "$epid" "VpcEndpoint" "$analysis" "svc:$svc"
  done < <(A ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=vpc-endpoint-state,Values=available,pending" \
    | jq -c '.VpcEndpoints[] | {id: .VpcEndpointId, tags: (.Tags // []), service: .ServiceName}')
fi

# ── G: Network ACLs ──────────────────────────────────────────
section "G. Network ACLs"
header
while IFS= read -r nacl; do
  naclid=$(echo "$nacl" | jq -r '.id')
  nacltags=$(echo "$nacl" | jq '.tags')
  is_default=$(echo "$nacl" | jq -r '.default')
  analysis=$(analyze_tags "$nacltags" "$naclid" "NetworkAcl")
  row "$naclid" "NetworkAcl" "$analysis" "${is_default:+default}"
done < <(A ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  | jq -c '.NetworkAcls[] | {id: .NetworkAclId, tags: (.Tags // []), default: .IsDefault}')

# ── H: Security Groups ───────────────────────────────────────
section "H. Security Groups"
header
while IFS= read -r sg; do
  sgid=$(echo "$sg" | jq -r '.id')
  sgtags=$(echo "$sg" | jq '.tags')
  sgname=$(echo "$sg" | jq -r '.name')
  analysis=$(analyze_tags "$sgtags" "$sgid" "SecurityGroup")
  row "$sgid" "SecurityGroup" "$analysis" "name:$sgname"
done < <(A ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  | jq -c '.SecurityGroups[] | {id: .GroupId, tags: (.Tags // []), name: .GroupName}')

# ── I: Workload ENIs (non-infrastructure) ────────────────────
section "I. Workload ENIs (ECS task + data service ENIs)"
header
# Exclude: AWS-managed requester IDs (nat-gateway, vpc-endpoint, elb, lambda, efa)
while IFS= read -r eni; do
  eniid=$(echo "$eni" | jq -r '.id')
  enitags=$(echo "$eni" | jq '.tags')
  desc=$(echo "$eni" | jq -r '.desc // ""' | cut -c1-40)
  req=$(echo "$eni" | jq -r '.requester // ""')
  # Skip pure AWS-managed ENIs
  if echo "$req" | grep -qE "^(amazon-|aws-|elb-|nat-|vpce-)"; then
    continue
  fi
  analysis=$(analyze_tags "$enitags" "$eniid" "ENI")
  row "$eniid" "ENI" "$analysis" "$desc"
done < <(A ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  | jq -c '.NetworkInterfaces[] | {
      id: .NetworkInterfaceId,
      tags: (.TagSet // []),
      desc: .Description,
      requester: (.RequesterManaged | tostring)
    }')

# ── J: Application Load Balancer ─────────────────────────────
section "J. Application Load Balancer"
header
ALB_DATA=$(A elbv2 describe-load-balancers | jq --arg vpc "$VPC_ID" \
  '.LoadBalancers[] | select(.VpcId==$vpc)')
ALB_ARN=$(echo "$ALB_DATA" | jq -r '.LoadBalancerArn')
ALB_NAME=$(echo "$ALB_DATA" | jq -r '.LoadBalancerName')

if [ -z "$ALB_ARN" ]; then
  echo "_No ALB found in VPC $VPC_ID._"
else
  ALB_TAGS=$(A elbv2 describe-tags --resource-arns "$ALB_ARN" \
    | jq '.TagDescriptions[0].Tags // []')
  ALB_ANALYSIS=$(analyze_tags "$ALB_TAGS" "$ALB_ARN" "ALB")
  row "$ALB_NAME" "ALB" "$ALB_ANALYSIS" "${ALB_ARN##*/}"
fi

# ── K: Target Groups ─────────────────────────────────────────
section "K. Target Groups"
header
if [ -n "${ALB_ARN:-}" ]; then
  while IFS= read -r tg; do
    tgarn=$(echo "$tg" | jq -r '.arn')
    tgname=$(echo "$tg" | jq -r '.name')
    tgproto=$(echo "$tg" | jq -r '.proto')
    TGTAGS=$(A elbv2 describe-tags --resource-arns "$tgarn" \
      | jq '.TagDescriptions[0].Tags // []')
    analysis=$(analyze_tags "$TGTAGS" "$tgarn" "TargetGroup")
    row "$tgname" "TargetGroup" "$analysis" "proto:$tgproto"

    # Propagation check: ALB → TG
    prop=$(check_propagation "$ALB_ARN" "$tgarn" "TargetGroup" "$ALB_TAGS" "$TGTAGS")
    if [[ "$prop" == BREAK* ]]; then
      IFS='|' read -r _ reason <<< "$prop"
      echo "  ⚠ PROPAGATION BREAK: ALB→TG $tgname: $reason"
    fi
  done < <(A elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" \
    | jq -c '.TargetGroups[] | {arn: .TargetGroupArn, name: .TargetGroupName, proto: .Protocol}')
fi

# ── L: ECS Cluster ───────────────────────────────────────────
section "L. ECS Cluster"
header
CLUSTER_ARN=$(A ecs list-clusters | jq -r --arg n "$ECS_CLUSTER" \
  '.clusterArns[] | select(contains($n))')
if [ -z "$CLUSTER_ARN" ]; then
  echo "_ECS cluster $ECS_CLUSTER not found._"
else
  CLUSTER_TAGS=$(A ecs list-tags-for-resource --resource-arn "$CLUSTER_ARN" \
    | jq '.tags | map({Key: .key, Value: .value})')
  CLUSTER_ANALYSIS=$(analyze_tags "$CLUSTER_TAGS" "$CLUSTER_ARN" "ECSCluster")
  row "$ECS_CLUSTER" "ECSCluster" "$CLUSTER_ANALYSIS" ""

  # ── M: ECS Services ──────────────────────────────────────
  section "M. ECS Services"
  header
  while IFS= read -r svc_arn; do
    svc_name="${svc_arn##*/}"
    SVC_TAGS=$(A ecs list-tags-for-resource --resource-arn "$svc_arn" \
      | jq '.tags | map({Key: .key, Value: .value})')
    svc_analysis=$(analyze_tags "$SVC_TAGS" "$svc_arn" "ECSService")
    row "$svc_name" "ECSService" "$svc_analysis" ""

    # Propagation: Cluster → Service
    prop=$(check_propagation "$CLUSTER_ARN" "$svc_arn" "ECSService" "$CLUSTER_TAGS" "$SVC_TAGS")
    if [[ "$prop" == BREAK* ]]; then
      IFS='|' read -r _ reason <<< "$prop"
      echo "  ⚠ PROPAGATION BREAK: Cluster→Service $svc_name: $reason"
    fi
  done < <(A ecs list-services --cluster "$CLUSTER_ARN" | jq -r '.serviceArns[]')
fi

# ── N: RDS ───────────────────────────────────────────────────
section "N. RDS"
header
while IFS= read -r db; do
  dbid=$(echo "$db" | jq -r '.id')
  dbarn=$(echo "$db" | jq -r '.arn')
  dbvpc=$(echo "$db" | jq -r '.vpc')
  [ "$dbvpc" != "$VPC_ID" ] && continue
  RDS_TAGS=$(A rds list-tags-for-resource --resource-name "$dbarn" \
    | jq '.TagList | map({Key: .Key, Value: .Value})')
  analysis=$(analyze_tags "$RDS_TAGS" "$dbid" "RDSInstance")
  row "$dbid" "RDSInstance" "$analysis" "vpc:$dbvpc"
done < <(A rds describe-db-instances \
  | jq -c '.DBInstances[] | {id: .DBInstanceIdentifier, arn: .DBInstanceArn, vpc: .DBSubnetGroup.VpcId}')

# ── O: ElastiCache ───────────────────────────────────────────
section "O. ElastiCache"
header
while IFS= read -r ec; do
  ecid=$(echo "$ec" | jq -r '.id')
  ecarn=$(echo "$ec" | jq -r '.arn')
  ecvpc=$(echo "$ec" | jq -r '.vpc // ""')
  [ "$ecvpc" != "$VPC_ID" ] && [ -n "$ecvpc" ] && continue
  EC_TAGS=$(A elasticache list-tags-for-resource --resource-name "$ecarn" \
    | jq '.TagList | map({Key: .Key, Value: .Value})')
  analysis=$(analyze_tags "$EC_TAGS" "$ecid" "ElastiCache")
  row "$ecid" "ElastiCache" "$analysis" "vpc:${ecvpc:-check-subnet}"
done < <(A elasticache describe-cache-clusters --show-cache-node-info \
  | jq -c '.CacheClusters[] | {
      id: .CacheClusterId,
      arn: .ARN,
      vpc: (.CacheSubnetGroupName // "")
    }')

# ── P: Amazon MQ ─────────────────────────────────────────────
section "P. Amazon MQ Brokers"
header
while IFS= read -r broker; do
  bid=$(echo "$broker" | jq -r '.id')
  bname=$(echo "$broker" | jq -r '.name')
  bstate=$(echo "$broker" | jq -r '.state')

  # Get full broker details to check VPC
  BROKER_DETAIL=$(A mq describe-broker --broker-id "$bid")
  BROKER_VPC=$(echo "$BROKER_DETAIL" | jq -r '.SubnetIds[0] // ""')
  BROKER_ARN=$(echo "$BROKER_DETAIL" | jq -r '.BrokerArn // ""')

  # Check if subnet belongs to our VPC
  if [ -n "$BROKER_VPC" ]; then
    SUBNET_VPC=$(A ec2 describe-subnets --subnet-ids "$BROKER_VPC" \
      | jq -r '.Subnets[0].VpcId // ""' 2>/dev/null)
    [ "$SUBNET_VPC" != "$VPC_ID" ] && continue
  fi

  BROKER_TAGS=$(echo "$BROKER_DETAIL" | jq '.Tags | to_entries | map({Key: .key, Value: .value})')
  analysis=$(analyze_tags "$BROKER_TAGS" "$bid" "AmazonMQ")
  row "$bname" "AmazonMQ" "$analysis" "state:$bstate"
done < <(A mq list-brokers | jq -c '.BrokerSummaries[] | {id: .BrokerId, name: .BrokerName, state: .BrokerState}')

# ── Q: CloudWatch Log Groups ─────────────────────────────────
section "Q. CloudWatch Log Groups (ECS scope)"
header
# Scope: /ecs/ prefix and /planodkupow prefix — no VPC association possible
for PREFIX in "/ecs/" "/planodkupow"; do
  while IFS= read -r lg; do
    lgname=$(echo "$lg" | jq -r '.name')
    lgarn=$(echo "$lg" | jq -r '.arn // ""')

    # Log groups don't have tags accessible via describe — use list-tags-log-group
    LG_TAGS=$(A logs list-tags-log-group --log-group-name "$lgname" 2>/dev/null \
      | jq 'to_entries | map({Key: .key, Value: .value})') || LG_TAGS="[]"

    analysis=$(analyze_tags "$LG_TAGS" "$lgname" "LogGroup")
    row "$lgname" "LogGroup" "$analysis" ""
  done < <(A logs describe-log-groups --log-group-name-prefix "$PREFIX" \
    | jq -c '.logGroups[] | {name: .logGroupName, arn: (.arn // "")}')
done

# ── R: CloudWatch Alarms ─────────────────────────────────────
section "R. CloudWatch Alarms"
header
ALARM_COUNT=$(A cloudwatch describe-alarms | jq '.MetricAlarms | length')
if [ "$ALARM_COUNT" -eq 0 ]; then
  echo "_No CloudWatch Alarms found. (NOTE: Alarms are not taggable via standard tag API in all regions — verify if tagging is expected.)_"
else
  while IFS= read -r alarm; do
    aname=$(echo "$alarm" | jq -r '.name')
    aarn=$(echo "$alarm" | jq -r '.arn')
    ALARM_TAGS=$(A cloudwatch list-tags-for-resource --resource-arn "$aarn" \
      | jq '.Tags | map({Key: .Key, Value: .Value})')
    analysis=$(analyze_tags "$ALARM_TAGS" "$aname" "CWAlarm")
    row "$aname" "CWAlarm" "$analysis" ""
  done < <(A cloudwatch describe-alarms \
    | jq -c '.MetricAlarms[] | {name: .AlarmName, arn: .AlarmArn}' \
    | grep -i "planodkupow\|qa")
fi

# ── NON-TAGGABLE ─────────────────────────────────────────────
section "NON-TAGGABLE (by AWS design)"
cat <<'EOF'
| Resource                    | Reason                                                      |
|-----------------------------|-------------------------------------------------------------|
| ALB Listener Rules          | Rules share tags with their Listener; not separately taggable |
| VPC Route Table entries     | Individual routes are not resources; only RT itself is tagged |
| NACL entries/rules          | Individual rules are not taggable; only NACL resource is    |
| Security Group rules        | Individual rules are not taggable; only SG resource is      |
| ECS Task ENIs (auto)        | ECS propagates tags to task ENIs via PropagateTags setting  |
| Default VPC NACL            | Created by AWS; limited tagging support                     |
| ECS Task Definitions        | Not tracked in this audit (no VPC binding); IAM out of scope|
EOF

# ============================================================
# REPORT SUMMARY
# ============================================================

echo ""
echo "================================================================="
echo "## EXECUTIVE SUMMARY"
echo "================================================================="
echo ""
PCT=0
[ "$TOTAL" -gt 0 ] && PCT=$(( COMPLIANT * 100 / TOTAL ))
echo "| Metric                    | Value |"
echo "|---------------------------|-------|"
echo "| Total resources audited   | $TOTAL |"
echo "| Fully compliant           | $COMPLIANT ($PCT%) |"
echo "| CRITICAL findings         | $CRITICAL |"
echo "| MAJOR findings            | $MAJOR |"
echo "| MINOR findings            | $MINOR |"
echo "| Orphan/manual suspects    | $ORPHAN |"
echo "| Propagation breaks        | $PROP_BREAKS |"
echo ""

echo "## REMEDIATION LISTS"
echo ""
echo "### CRITICAL (fix before any SCP/tag policy enforcement)"
for item in "${CRIT_LIST[@]:-}"; do [ -n "$item" ] && echo "- $item"; done
[ "${#CRIT_LIST[@]:-0}" -eq 0 ] && echo "_None_"

echo ""
echo "### MAJOR (fix within sprint)"
for item in "${MAJ_LIST[@]:-}"; do [ -n "$item" ] && echo "- $item"; done
[ "${#MAJ_LIST[@]:-0}" -eq 0 ] && echo "_None_"

echo ""
echo "### MINOR (fix in next tagging pass)"
for item in "${MIN_LIST[@]:-}"; do [ -n "$item" ] && echo "- $item"; done
[ "${#MIN_LIST[@]:-0}" -eq 0 ] && echo "_None_"

echo ""
echo "### ORPHAN SUSPECTS (validate IaC ownership)"
for item in "${ORPHAN_LIST[@]:-}"; do [ -n "$item" ] && echo "- $item"; done
[ "${#ORPHAN_LIST[@]:-0}" -eq 0 ] && echo "_None_"

echo ""
echo "### PROPAGATION BREAKS"
for item in "${PROP_BREAK_LIST[@]:-}"; do [ -n "$item" ] && echo "- $item"; done
[ "${#PROP_BREAK_LIST[@]:-0}" -eq 0 ] && echo "_None_"

echo ""
echo "================================================================="
echo "# END OF AUDIT — $(date)"
echo "================================================================="
