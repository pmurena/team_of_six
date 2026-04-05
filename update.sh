#!/bin/zsh

# ==============================================================================
# TOS Documentation & Agent Upgrade Script: The Cognitive Cadence
# ==============================================================================
set -e

echo "🚀 Upgrading Framework Documentation: The Cognitive Cadence & Micro-Protocol..."

mkdir -p docs

# ==============================================================================
# 1. THE CORE ENGINE (docs/08-workflow.md)
# ==============================================================================
cat << 'EOF' > docs/08-workflow.md
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
EOF
echo "✅ Created docs/08-workflow.md"

# ==============================================================================
# 2. THE CONTEXTUAL TRINITY (docs/03-contextual-trinity.md)
# ==============================================================================
cat << 'EOF' > docs/03-contextual-trinity.md
# The Contextual Trinity

The Contextual Trinity is the foundational data structure of the Team of Six framework. It solves the LLM "Context Drift" problem by physically binding the AI's reasoning window to a localized, isolated reality.

## The 1:1:1 Bond
A Trinity is a strict 1:1:1 relationship between:
1. **One GitHub Issue:** The definition of the problem.
2. **One Feature Branch:** The isolated workspace.
3. **One Pull Request:** The formal review gateway.

## The Execution Sandbox
A Trinity is **not** a place for brainstorming. Brainstorming belongs in Trinity 0 (The Sanctuary). 

When an Architect runs `tos <project> sync trinity <ID>`, the engine acquires a persistent **Hard-Lock**. It generates an Ephemeral Outbox—a clean-room snapshot containing only the active PR thread, the issue comments, and the specific files the Architect chooses to `sync peek`. 

Inside this Execution Sandbox, the Ghost is blind to everything else. It must execute the Red-Green-Refactor loop based *only* on the evidence in the Outbox.

## The Wisdom Repository
A Trinity session must culminate in the **Retrospect Phase**. 
Because the Trinity is an isolated reasoning chamber, the epiphanies, technical debt discoveries, and domain rules established during the session will be lost when the chat window closes. 

Before the Architect merges the PR and drops the lock (`tos remove <ID>`), the Ghost must write these learnings into the target repository's documentation files. The Trinity acts as a temporary forge; the project's Git repository is the permanent Wisdom Repository.
EOF
echo "✅ Created docs/03-contextual-trinity.md"

# ==============================================================================
# 3. LLM PITFALLS (docs/01-llm-pitfalls.md)
# ==============================================================================
cat << 'EOF' > docs/01-llm-pitfalls.md
# LLM Pitfalls & Mitigation

The Team of Six is engineered entirely around mitigating the inherent psychological and technical flaws of Large Language Models. If you do not respect these pitfalls, the engine will collapse into hallucination.

## 1. Context Degradation (Prompt Drift)
**The Pitfall:** As an LLM's chat history grows, it begins to "forget" its initial system prompt and loses the thread of the architecture. It mixes up old trial-and-error logs with the current task.
**The Mitigation:** The **Ephemeral Outbox**. We overwrite (`>`) the Context Map on every turn. The Outbox provides a pure, single-turn snapshot of reality. When the LLM's internal chat history becomes polluted, the Architect starts a fresh chat window and feeds it the pristine Outbox.

## 2. The Brainstorming Trap
**The Pitfall:** If an LLM attempts to write code while it is still "wildly brainstorming" conceptual ideas, it will generate unanchored, hallucinated syntax that does not fit the repository.
**The Mitigation:** The **Event Horizon**. Brainstorming is strictly confined to Trinity 0 (Sanctuary). Code generation is strictly confined to Trinity 1+ (Workspace) via the Red-Green-Refactor loop.

## 3. Proprietary Pollution
**The Pitfall:** Developers often attempt to fix LLM mistakes by creating "custom project agents" or adding proprietary business rules directly into the AI's global system prompt. This breaks the air-gap, creates unmaintainable shadow logic, and pollutes the universal agent with client-specific secrets.
**The Mitigation:** The **Universal Agent Boundary**. The Team of Six Agent (`llm_agents/code.md`) is universally agnostic. It knows *how* to code, but it relies entirely on the target project's `README.md` and `docs/` folder to know *what* to code. If the AI hallucinates a business rule, you do not update the AI—you update the target project's documentation during the Retrospect phase.

## 4. Implicit Assumption
**The Pitfall:** LLMs are eager to please and will blindly execute tasks based on assumed logic, skipping over critical edge cases.
**The Mitigation:** The **Micro-Protocol (Mirror -> Challenge -> Plan -> Execute)**. The AI is physically forbidden from generating code until it reflects its intent to the human Architect and receives explicit approval.
EOF
echo "✅ Created docs/01-llm-pitfalls.md"

# ==============================================================================
# 4. HOW-TO GUIDE (docs/howto.md)
# ==============================================================================
cat << 'EOF' > docs/howto.md
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
EOF
echo "✅ Created docs/howto.md"

# ==============================================================================
# 5. THE UNIVERSAL GHOST BRAIN (llm_agents/code.md)
# ==============================================================================
cat << 'EOF' > llm_agents/code.md
# ROLE: Team of Six (The Universal Ghost)

You are the cognitive engine of the Team of Six framework. You are a Universal Agent. You pair-program with a human "Principal Architect" in a highly deterministic, air-gapped Unix environment.

## 1. THE UNIVERSAL BOUNDARY (No Proprietary Pollution)
You are an agnostic, universal framework component. You DO NOT possess or maintain custom, project-specific system prompts. 
* You must derive ALL architectural rules, style guides, and domain logic exclusively from the standard files (code, `README.md`, `docs/`) provided to you in the `outbox.md` context.
* If a domain rule is missing or unclear, it is YOUR responsibility during the Retrospect phase to write that missing rule into the target project's documentation.

## 2. THE EVENT HORIZON
* **Trinity 0 (Sanctuary):** When the Outbox indicates Trinity 0, you are allowed to engage in wild brainstorming, architecture discussions, and WBS generation. You are STRICTLY FORBIDDEN from outputting `write code` payloads in Trinity 0.
* **Trinity 1+ (Workspace):** When the Outbox indicates a specific Trinity ID, the Event Horizon has been crossed. Wild creativity is deactivated. You are locked into the Ephemeral Outbox context. You must execute the Red-Green-Refactor loop with absolute surgical precision.

## 3. THE COGNITIVE CADENCE (Macro-Phases)
You must guide the Architect through these phases for every feature:
1. **Scaffolding** (Trinity 0): Brainstorming and WBS generation.
2. **Red** (Trinity 1+): Write a failing test for ONE specific concept (Enforce 5-3-2 Test Strategy).
3. **Green** (Trinity 1+): Write the minimum code required to pass the test.
4. **Refactor** (Trinity 1+): Clean technical debt without breaking the passing test.
5. **Retrospect** (Trinity 1+): Extract learnings and update the target project's documentation files.

## 4. THE HITL MICRO-PROTOCOL (CRITICAL RULE)
To move through ANY phase, you must execute a strict 4-step communication loop. You are FORBIDDEN from outputting a `write` payload without explicit human approval of your plan.

For every single interaction, your output MUST be structured as follows:

**[MIRROR]**
State clearly what you understand the Architect wants you to achieve based on the Outbox.

**[CHALLENGE]**
Highlight any logical flaws, missing domain rules, or architectural pitfalls in the proposed approach.

**[PLAN]**
Provide a step-by-step numbered list of exactly what you intend to do. 
*Conclude with: "Do I have your approval to execute this plan?"*

**[EXECUTE]**
ONLY output this section (the `===TOS_META_START===` payload block) AFTER the Architect replies with approval. 

## 5. TRUST THE OUTBOX
The `outbox.md` is an ephemeral, clean-room snapshot. Do NOT rely on your previous conversation history if it contradicts the current Outbox. The Outbox is absolute reality. If your context window degrades, the Architect will provide you a fresh Outbox. Trust the Outbox.
EOF
echo "✅ Updated llm_agents/code.md"

echo "=============================================================================="
echo "✅ Upgrade Complete. The Cognitive Cadence is now the Common Reality."
echo "=============================================================================="
