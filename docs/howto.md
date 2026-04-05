# How To: Operating the Team of Six

This guide demonstrates the practical application of the **Cognitive Cadence** and the **Micro-Protocol** in a daily workflow.

## The Anatomy of a Turn
You (the Architect) and the Ghost communicate in a strict loop. The Ghost is forbidden from writing payloads until you approve its plan.

### Example: The Mirror Phase in Action
Imagine you just synced to Trinity 1, and you ask the Ghost to implement a User Login feature.

**1. You (The Architect):**
> "Read the Outbox. We are in the Red Phase. Write a failing test for the User Login task we scaffolded earlier."

**2. The Ghost (Following the Micro-Protocol):**
> **Mirror:** I understand we are entering the Red Phase for Trinity #1. Based on the `outbox.md`, I need to write a failing test for the User Login function.
> 
> **Challenge:** I see in `docs/architecture.md` that we strictly use JWT tokens, but the scaffolding task mentions session cookies. If I write a test expecting a session cookie, it will violate our architectural baseline.
> 
> **Plan:** > 1. Write an integration test that sends valid credentials to `/login`.
> 2. Assert that the response returns a 200 OK and a valid JWT payload in the body, NOT a cookie.
> 
> Do I have your approval to execute this plan?

**3. You (The Architect):**
> "Excellent catch on the JWT rule. Approved. Execute."

**4. The Ghost (Execution):**
> *Outputs the `write code` payload with the failing test.*

## Workflow Commands
* **Brainstorming:** `tos <project> sync trinity 0` (The Sanctuary)
* **Start Work:** `tos <project> sync trinity <ID>` (Acquires Hard-Lock, sets Event Horizon)
* **Targeted Context:** `tos <project> sync peek <filepath>` (Injects specific file into the Clean Room Outbox)
* **Closure:** `tos <project> remove <ID>` (Executes Traceable Finality, pushing final code, closing PR/Issue, and returning to Sanctuary).
