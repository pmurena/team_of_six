# 💎 Team of Six (V57 GitOps Edition)

## 🏗️ Architecture (V57)
* **Ghost Ownership:** The `AI_USER` owns the repository to prevent permission leakage.
* **The Mutex Lock:** The wrapper and publisher use `.tos/commit_msg` and `.tos/pr_summary.md` to guarantee that code is published and GitHub PRs are updated before new work begins.
* **GitOps Review:** PR rejections happen natively on GitHub. Failing tests (`Red` state) are published immediately to ensure the contract is agreed upon before implementation.

## ⚡ Usage
**1. Execute AI Logic:**
```zsh
team_of_six wrapper
```
*(Fails if previous work is unpublished).*

**2. Publish & Sync:**
```zsh
team_of_six publish
```
*(Fails if AI forgot to provide commit message/summary. Automatically updates GitHub PRs).*
