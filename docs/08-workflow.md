# Workflow: The Cognitive Cadence

The Team of Six operates on a strictly deterministic workflow designed to bound Large Language Model (LLM) context, prevent hallucination, and guarantee code quality. 

We do not simply "ask the AI to code." We force the AI into a rigid **Cognitive Cadence**. This cadence is divided into **Macro-Phases** (the lifecycle of a feature) and a **Micro-Protocol** (the required communication loop within every single phase).

## The Event Horizon: Sanctuary vs. Workspace
Before understanding the phases, you must understand the Event Horizon.
* **The Sanctuary (Trinity 0):** This is the baseline, read-only state of the project (`main` branch). Here, the Architect and the Ghost are allowed to engage in "wild brainstorming." You can discuss broad architecture, debate paradigms, and create Work Breakdown Structures (WBS). 
* **The Workspace (Trinity 1+):** Once a specific task is selected, the Architect acquires a Hard-Lock (`tos <project> sync trinity 1`). This is the Event Horizon. Wild creativity is now strictly forbidden. The Ghost is locked into an Ephemeral Outbox and must execute with surgical precision.

---

## 1. The Macro-Phases (The Feature Lifecycle)
Every feature or issue must strictly pass through these five phases.

### Phase 1: Scaffolding (Runs in Trinity 0)
* **Goal:** Conceptual alignment.
* **Action:** Brainstorming, creating the Work Breakdown Structure (WBS), and defining architectural choices. No code is written here. 

### Phase 2: Red (Runs in Trinity 1+)
* **Goal:** Bounding the context.
* **Action:** The Ghost writes a failing test for *one* of the specific topics discussed in Scaffolding. We follow the 5-3-2 Test Strategy (5 Unit, 3 Integration, 2 E2E). Writing a failing test forces the LLM to anchor its reasoning to a highly specific, verifiable goal before generating heavy syntax.

### Phase 3: Green (Runs in Trinity 1+)
* **Goal:** Passing the test.
* **Action:** The Ghost writes the absolute minimum required code to make the Red test pass. 

### Phase 4: Refactor (Runs in Trinity 1+)
* **Goal:** Architectural hygiene.
* **Action:** The Ghost cleans up the implementation, removes technical debt, and ensures code elegance without breaking the passing tests.

### Phase 5: Retrospect (Runs in Trinity 1+)
* **Goal:** Wisdom Persistence.
* **Action:** The Ghost evaluates the journey. If it learned a new project-specific domain rule or encountered architectural friction, it documents this knowledge in the target project's standard documentation (e.g., updating the project's `README.md` or `docs/`). 

---

## 2. The Micro-Protocol (The HITL Engine)
To move through *any* of the Macro-Phases, the Ghost must execute a strict 4-step communication loop with the human Architect. The Ghost is never permitted to blindly act.

For every single interaction, the Ghost must output:
1. **Mirror:** "Here is what I understand you want to achieve in this phase." *(Ensures intent alignment).*
2. **Challenge:** "Here are the logical flaws, pitfalls, or missing domain rules I see in this approach based on the outbox." *(The Architect's safety check).*
3. **Plan:** "Here is my step-by-step execution plan."
4. **Execute:** *[Requires Human Approval]* Only after the Architect explicitly approves the Plan may the Ghost output the actual `write` payload (tasks, code, or comments).

Execution without Mirroring and Planning is a critical violation of the framework.
