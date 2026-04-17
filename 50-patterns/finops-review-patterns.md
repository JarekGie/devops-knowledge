# Wzorce FinOps Review

#finops #patterns

## Wzorzec: miesięczny przegląd kosztów

```
1. Otwórz AWS Cost Explorer → previous month
2. Grupy po serwisie → znajdź top 5 kosztów
3. Grupy po tagu Project / Environment → znajdź anomalie
4. Porównaj z poprzednim miesiącem → % zmiana
5. Wygeneruj raport → [[cost-review-template]]
```

## Wzorzec: audyt tagowania

```bash
# Zasoby bez tagu Environment
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment \
  --query 'ResourceTagMappingList[?Tags[?Key==`Environment`]==`[]`].ResourceARN'

# Zasoby bez tagu ManagedBy
aws resourcegroupstaggingapi get-resources \
  --query 'ResourceTagMappingList[?Tags[?Key==`ManagedBy`]==`[]`].ResourceARN'
```

## Wzorzec: EC2 / RDS rightsizing

```bash
# EC2 Compute Optimizer recommendations
aws compute-optimizer get-ec2-instance-recommendations \
  --query 'instanceRecommendations[*].{instance:instanceArn,finding:finding,type:recommendationOptions[0].instanceType}'

# RDS nieużywane instancje (brak połączeń przez 7 dni)
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=NAZWA \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 --statistics Maximum
```

## Wzorzec: S3 cost optimization

```bash
# Buckets bez lifecycle policy
aws s3api list-buckets --query 'Buckets[*].Name' | \
  xargs -I {} aws s3api get-bucket-lifecycle-configuration --bucket {} 2>/dev/null

# Sprawdź klasy storage per bucket
aws s3api list-objects-v2 --bucket BUCKET \
  --query 'Contents[*].{key:Key,size:Size,class:StorageClass}'
```

## Wzorzec: idle / unused resources

| Typ | Jak znaleźć |
|-----|------------|
| Elastic IP bez instancji | `aws ec2 describe-addresses --query 'Addresses[?AssociationId==null]'` |
| EBS snapshot stare | Cost Explorer → EBS Snapshots > 90 days |
| Load balancer bez targetów | `describe-target-health` → empty |
| NAT Gateway bez ruchu | CloudWatch `BytesOutToDestination` = 0 |

## Wzorzec: Savings Plans / Reserved Instances

```
1. Cost Explorer → Savings Plans → Recommendations
2. Coverage Report → ile % pokryte
3. Utilization Report → czy kupiłeś za dużo
4. Decyzja: kupuj 1-rok / 3-rok / no-upfront
```

## Powiązane

- [[cost-review-template]]
- [[aws-tagging-standard]]
- [[finops-reporting]]
- `70-finops/`
