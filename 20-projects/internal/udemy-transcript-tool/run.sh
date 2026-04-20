#!/bin/bash
source .venv/bin/activate
python -m udemy_obsidian export --course-url "https://www.udemy.com/course/aws-certified-cloudops-associate/" --vault "/Users/jaroslaw.golab/projekty/devops/devops-knowledge" --dry-run --verbose
