# Infrastructure Management and Incident Analysis: PBMS, Planodkupow, and Maspex Systems

This briefing document provides a comprehensive synthesis of the current infrastructure status, recent critical incidents, and operational runbooks for three primary AWS-based projects: PBMS (Puzzler B2B Management System), Planodkupow, and Maspex. It highlights systemic risks associated with legacy versioning, CloudFormation stack dependencies, and microservice connectivity.

---

## Executive Summary

The analyzed technical context reveals a landscape of complex AWS environments—primarily utilizing ECS Fargate, CloudFormation, and Terraform—currently undergoing significant stabilization and refactoring. 

*   **PBMS (Puzzler B2B):** A .NET microservice architecture on ECS Fargate. While the development environment is active, the system faces technical debt involving empty ECR repositories (worker service), sensitive data exposure in configuration files, and potential Service Discovery bugs within the `app-stack` module.
*   **Planodkupow:** Recently recovered from a catastrophic `UPDATE_ROLLBACK_FAILED` state in the QA environment. The failure was triggered by AWS’s removal of End-of-Life (EOL) versions for Redis and RabbitMQ. Recovery required a full "delete and rebuild" strategy, exposing critical dependencies on external DNS and inadequate IAM permissions for infrastructure automation.
*   **Maspex:** Focuses on optimizing CloudFront delivery and resolving 502 errors for static assets. Current efforts involve implementing narrow fixes for origin request policies and managing task definition drifts caused by CI/CD pipelines operating outside of Terraform’s state.

---

## Detailed Analysis of Key Themes

### 1. Infrastructure as Code (IaC) Fragility and EOL Management
A recurring theme across the documents is the risk posed by AWS's deprecation of older service versions. 
*   **The EOL Cascade:** In the Planodkupow QA environment, a simple tag update failed because the template referenced Redis 5.0.0, which AWS had removed. This triggered a kaskadowy (cascading) failure across nested stacks. Similar issues were found with RabbitMQ 3.8.6.
*   **Template Drift:** Environments often drift from their IaC definitions. In Maspex, CI/CD deploys new task definitions (v31) while Terraform remains at v24, creating a management conflict. In Planodkupow, AWS auto-upgraded RabbitMQ versions without updating the CloudFormation state, leading to a "frozen" internal state that blocked subsequent deployments.

### 2. Microservice Connectivity and Health Discovery
The stability of microservice communication is hindered by configuration mismatches between application routing and infrastructure health checks.
*   **PBMS Service Discovery:** A known issue exists where ECS tasks may fail to register with Cloud Map, necessitating a patch to the `app-stack` module.
*   **Health Check Mismatches:** A major blocker in the Planodkupow rebuild was the `GatewaySerwis` failing to stabilize. The infrastructure expected a `/signin` health check, but the development team had removed that route from the Ocelot gateway configuration, causing a permanent `unhealthy` status.
*   **CloudFront Routing:** Maspex encountered 502 errors because static asset behaviors did not forward the necessary context (Host headers/SNI) to the Application Load Balancer (ALB).

### 3. Critical Failure Recovery Strategies
The documentation outlines a shift from attempting automated rollbacks to "controlled rebuilds" when stacks reach an irrecoverable state.
*   **The "Retain" Policy:** A vital lesson from the Planodkupow incident is the mandatory use of `DeletionPolicy: Retain` for stateful resources like RDS and S3. Without this, a failed stack rollback attempts to delete databases while they are in a "restoring" state, leading to a permanent hang.
*   **Blast Radius Reduction:** To prevent future kaskadowy failures, the RabbitMQ infrastructure for Planodkupow is being refactored out of the "Root" stack to live in its own lifecycle, using SSM parameters for cross-stack communication instead of direct CloudFormation exports.

---

## Important Quotes and Contextual Analysis

> **"Worker image = 'nginx:latest' — ECR repo puste, obraz nie zbudowany."**
*   **Context:** Found in the PBMS environment resources list. It indicates a critical gap in the deployment pipeline where the worker service is running a placeholder NGINX image rather than the actual application code, rendering the SQS-based processing non-functional.

> **"CloudFront odmawia stworzenia nowej dystrybucji z aliasem wskazującym na usuniętą/inną dystrybucję."**
*   **Context:** This occurred during the Planodkupow rebuild. It highlights a critical dependency on external DNS management. If a DNS CNAME points to a deleted CloudFront distribution, AWS prevents the creation of a new distribution with that alias, creating a deadlock for teams without direct DNS control.

> **"Jenkins timeout nie oznaczał awarii CFN. AWS sam domknął update."**
*   **Context:** Observations during the Planodkupow QA restoration. It serves as a reminder that CI/CD timeouts often misrepresent the actual state of long-running AWS infrastructure operations, potentially leading to unnecessary manual interventions.

---

## Actionable Insights and Technical Recommendations

### For PBMS Infrastructure
| Priority | Action Item | Description |
| :--- | :--- | :--- |
| **High** | **ECR Repository Sync** | Build and push the actual .NET worker image to `infra-puzzler-b2b-worker-dev` to replace the NGINX placeholder. |
| **High** | **Secrets Remediation** | Move Azure AD and DocumentDB credentials from `terraform.tfvars` to a secure CI/CD variable store or AWS Secrets Manager. |
| **Medium** | **Service Discovery Patch** | Apply the required patch to the `app-stack` module to ensure reliable Cloud Map task registration. |

### For Planodkupow Stability (UAT/PROD)
*   **Implement "Blue-Green" Rebuilds:** Given the complexity of the DNS and EOL issues, future updates should favor creating a parallel stack (`planodkupow-prod-new`) rather than updating existing nested stacks.
*   **IAM Policy Updates:** Ensure the deployment identity has `mq:UpdateBroker` and `mq:RebootBroker` permissions. Lack of these was a primary cause of the `UPDATE_ROLLBACK_FAILED` status.
*   **Audit External Dependencies:** Before any major stack operation, verify who manages the DNS records. For production, establish a 5-minute communication window with the DNS owner to update CloudFront CNAMEs.

### For Maspex Environment
*   **Resolve Task Drift:** Decide whether Terraform should manage ECS task versions. If CI/CD is the source of truth, Terraform should be configured to ignore changes to the `task_definition` attribute to prevent unwanted rollbacks.
*   **Standardize Static Caching:** Use the proven `min_ttl=86400` override pattern in CloudFront to bypass application-level `max-age=0` headers that currently force excessive origin hits.

### General CloudFormation Safety Checklist
1.  **Enable Deletion Protection:** Manually enable on all RDS instances before any stack delete operation.
2.  **Snapshot Pre-flight:** Always verify a manual RDS snapshot is `available` before initiating a stack rebuild.
3.  **VPC Audit:** Check for manual VPC Endpoints, Global Accelerators, or NAT Gateways. These resources create ENIs that block subnet deletion, causing CloudFormation to hang during the "Delete" phase.