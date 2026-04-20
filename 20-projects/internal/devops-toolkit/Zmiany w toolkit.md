You are working inside the devops-toolkit repository.

Your task is to implement a new audit that detects:

1. unsupported (EOL) AWS engine versions
    
2. drift between CloudFormation template and actual AWS state
    

This must be production-grade and consistent with existing toolkit architecture.

# CONTEXT

The toolkit already supports:

- audit packs (aws_tagging, aws_cost_full, etc.)
    
- normalized outputs
    
- findings with severity (PASS / PARTIAL / FAIL)
    
- project.yaml driven configuration
    

We want to extend it with a new audit:

Name: aws_engine_versions

# GOALS

Detect and report:

1. EOL / unsupported engine versions in IaC (CloudFormation / Terraform)
    
2. drift between IaC and real AWS state
    
3. mismatch between IaC version and AWS supported versions
    

# SUPPORTED SERVICES (initial scope)

Implement for:

- Amazon MQ (RabbitMQ)
    
- RDS (engine version)
    
- ElastiCache (Redis engine version)
    

# DATA SOURCES

Use:

- IaC parsing (existing toolkit mechanisms)
    
- AWS CLI / boto3:
    
    - mq.describe_broker_engine_types
        
    - rds.describe_db_engine_versions
        
    - elasticache.describe_cache_engine_versions
        
    - describe live resources
        

# DETECTION LOGIC

For each resource:

1. Extract version from IaC
    
2. Fetch supported versions from AWS
    
3. Compare:
    

CASE A — IaC version NOT in supported list:  
→ FAIL  
reason: unsupported / EOL version

CASE B — IaC version != live version:  
→ PARTIAL  
reason: drift

CASE C — IaC version supported and matches live:  
→ PASS

# OUTPUT FORMAT

Follow toolkit conventions:

- normalized JSON
    
- findings list
    

Example finding:

{  
"id": "WAF-OPS-ENG-001",  
"service": "mq",  
"resource": "BasicBroker",  
"iac_version": "3.8.6",  
"live_version": "3.13.7",  
"supported_versions": ["3.13", "4.2"],  
"status": "FAIL",  
"reason": "Engine version is no longer supported by AWS (EOL)"  
}

# INTEGRATION

- add new audit module under toolkit/plugins/aws_engine_versions/
    
- register it in audit-pack system
    
- allow enabling via project.yaml:
    

llz:  
audits:  
- aws_engine_versions

# TESTS

Create unit tests:

- EOL version → FAIL
    
- drift only → PARTIAL
    
- valid and matching → PASS
    

# CLI OUTPUT

Ensure:

- visible in CLI report
    
- included in Markdown report
    
- included in Confluence HTML
    

# IMPORTANT

- do NOT break existing audits
    
- do NOT change existing schema
    
- reuse existing helpers where possible
    
- follow existing naming conventions
    

# OUTPUT

Return:

1. file structure
    
2. full code for plugin
    
3. test cases
    
4. example output