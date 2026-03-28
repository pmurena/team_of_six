# The Mirror & Execute Protocol

Team of Six enforces a strict state-machine to prevent architectural drift. The LLM must never execute code without first aligning on intent. Every action follows a **Phase 1 (Mirror)** -> **Phase 2 (Execute)** cycle.

## The Full Lifecycle (Issue to PR)

### 1. Sync & Brainstorm
Always start by ensuring the Ghost has the latest context.
* **Terminal:** `tos <project> work main` (Fetches `main` branch state).
* **Chat:** Load the context into your AI buffer. Discuss the feature requirements until the architecture is agreed upon.

### 2. Issue Genesis & Scaffolding
* **Mirror:** The Ghost proposes a GitHub Issue title/body and file structure. You reply: *"Agreed"*.
* **Execute:** The Ghost generates a bash script to scaffold the directory and run `gh issue create`.
* **Terminal:** Run `tos <project> wrapper` to execute the setup.
* **Terminal:** Run `tos <project> work <ISSUE_ID>` to refocus the Ghost on the newly created issue context.

### 3. RED (The Contract)
* **Mirror:** The Ghost proposes a failing test representing the requirement. You reply: *"Execute"*.
* **Execute:** The Ghost generates the test code.
* **Terminal:** Run `tos <project> wrapper` (Writes the test) -> `tos <project> publish` (Pushes test to GitHub and creates a PR).

### 4. GREEN (The Implementation)
* **Mirror:** The Ghost proposes the logic to pass the test. You reply: *"Execute"*.
* **Execute:** The Ghost generates the code.
* **Terminal:** Run `tos <project> wrapper` -> `tos <project> publish` to update the PR with the passing code.

### 5. Done Protocol (Documentation & Retrospective)
Once the code is merged and the feature is complete, tell the Ghost: **"Done"**. This triggers the final cleanup phases:
* **Documentation:** The Ghost reviews the final codebase and generates a script to update the `README.md` and inline comments based strictly on what the code *actually does*.
* **Retrospective:** The Ghost performs a session retro. If it struggled with a specific instruction, it proposes textual updates to its own agent definition files to improve future performance.
