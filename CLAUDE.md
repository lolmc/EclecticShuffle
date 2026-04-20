# Project: DevOps & Systems Infrastructure

## 1. Context
- **Purpose**: Infrastructure as Code (IaC), and systems automation.
- **Goal**: Ensure reliable, repeatable, and secure deployments.

## 2. Core Commands
- **Install/Init**: `terraform init`, `docker build`.
- **Validation**: `terraform plan`, `shellcheck scripts/*.sh`.
- **Apply**: `terraform apply`.
- **Scan**: `trivy image [name]`.

## 3. Coding Standards (IaC & Shell)
- **Shell**: Use `sh` or `bash` with strict error handling (`set -euo pipefail`).
- **Docker**: No root users, multi-stage builds, minimal base images.

## 4. Workflows
- **Discovery**: Read Dockerfiles and CI/CD config files before modification.
- **Safety**: Perform dry-runs or plans before applying changes.
- **Verification**: Verify service health post-deployment.

## 5. Anti-Patterns
- NO hardcoded secrets or .env files in the repository.
- NO unverified shell scripts.
- NO manual production changes; everything via IaC.

## 6. Logs & Git
- **Git Operations:** Always perform `git add`, `git commit`, and `git push` after completing a file edit.
- **Conversations:** Always log conversations between the user and the agent in a file called `CONVERSATIONS.log`.
- **Commit Format**: Follow Conventional Commits.

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
