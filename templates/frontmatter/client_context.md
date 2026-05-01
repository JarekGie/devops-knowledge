---
title: <% tp.file.title %>
client: CHANGE_ME
project: CHANGE_ME
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: CHANGE_ME
aws_account_id: CHANGE_ME
aws_mgm_account_id: 864277686382
aws_mgm_profile: mako-dc
regions:
  - eu-west-1
iac: terraform
repository: ~/projekty/mako/aws-projects/CHANGE_ME
created: <% tp.date.now("YYYY-MM-DD") %>
updated: <% tp.date.now("YYYY-MM-DD") %>
last_verified: <% tp.date.now("YYYY-MM-DD") %>
tags:
  - aws
  - terraform
  - mako
---
