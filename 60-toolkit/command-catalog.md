# Katalog komend

Wszystkie komendy — toolkit i AWS CLI — w jednym miejscu.

#toolkit #commands #aws

## devops-toolkit

```bash
# Audyt IAM
toolkit audit iam --account ACCOUNT_ID

# Audyt tagowania
toolkit audit tagging --account ACCOUNT_ID --region eu-west-1

# Raport FinOps
toolkit finops report --month 2026-03 --output markdown

# Audyt S3
toolkit audit s3 --account ACCOUNT_ID
```

## AWS CLI — najczęstsze

```bash
# Tożsamość
aws sts get-caller-identity

# Profil
export AWS_PROFILE=nazwa

# ECS
aws ecs list-clusters
aws ecs list-services --cluster CLUSTER
aws ecs describe-services --cluster CLUSTER --services SERVICE
aws ecs update-service --cluster CLUSTER --service SERVICE --force-new-deployment

# ECR
aws ecr describe-images --repository-name REPO --query 'sort_by(imageDetails,&imagePushedAt)[-5:]'

# Logi
aws logs tail /ecs/SERVICE --follow
aws logs filter-log-events --log-group-name /ecs/SERVICE --filter-pattern "ERROR"

# IAM
aws sts get-caller-identity
aws iam simulate-principal-policy --policy-source-arn ARN --action-names s3:GetObject --resource-arns ARN

# Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2026-03-01,End=2026-04-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Project

# Tagging
aws resourcegroupstaggingapi get-resources --tag-filters Key=Environment,Values=prod

# S3
aws s3 ls s3://BUCKET --recursive --human-readable --summarize
aws s3api get-bucket-policy --bucket BUCKET

# RDS
aws rds describe-db-instances --query 'DBInstances[*].{id:DBInstanceIdentifier,class:DBInstanceClass,status:DBInstanceStatus}'

# Systems Manager (SSM Parameter Store)
aws ssm get-parameter --name /projekt/env/klucz --with-decryption
aws ssm get-parameters-by-path --path /projekt/ --recursive --with-decryption
```

## kubectl — najczęstsze

```bash
# Context
kubectl config get-contexts
kubectl config use-context CONTEXT

# Pody
kubectl get pods -n NAMESPACE
kubectl describe pod POD -n NAMESPACE
kubectl logs POD -n NAMESPACE --previous

# Deployment
kubectl rollout status deployment/DEPLOY -n NAMESPACE
kubectl rollout undo deployment/DEPLOY -n NAMESPACE
kubectl set image deployment/DEPLOY container=IMAGE:TAG -n NAMESPACE

# Debug
kubectl exec -it POD -n NAMESPACE -- /bin/sh
kubectl port-forward POD 8080:8080 -n NAMESPACE
```

## Terraform / Terragrunt

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform state list
terraform state show RESOURCE
terraform import RESOURCE ID
terraform force-unlock LOCK_ID
terragrunt plan
terragrunt apply
terragrunt run-all plan
```

## Powiązane

- [[contracts-index]]
- [[debugging-patterns]]
