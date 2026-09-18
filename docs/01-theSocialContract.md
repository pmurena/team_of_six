← [00-llm-pitfalls.md](00-llm-pitfalls.md) | Next: [02-architecture.md](02-architecture.md)

---

# 01 — The Social Contract: Architect, Agent, and Ghost

In **01 — LLM Pitfalls**, we identified the psychological and technical traps that lead to AI-driven project failure: hallucination, context drift, and the loss of "Remote Truth." 

To solve these, Team of Six (TOS) does not treat you and the AI as a single pair. Instead, it structurally enforces a **trimodal team architecture**. It divides the development cycle into three distinct functional personas: the **Architect**, the **Agent**, and the **Ghost**.

### The "1 becomes 6" Premise
The core ambition of this project is a challenge of scale: **Can one person, assisted by an LLM, provide the output of a professional six-person team in both quantity and quality?** To achieve this, we don't just "chat" with an AI; we manage a team where Wisdom, Reasoning, and Execution are physically and logically separated to ensure high-velocity work never sacrifices high-integrity code.

---

## 1. The Principal Architect (Human Wisdom & Validation)
**Identity:** You. The human developer.
**The Guardrail:** Authority and Quality Control.

The Architect is the "Lead" of the operation. You provide the **Wisdom**—the strategic understanding of the business goals and the final word on architecture.

Unlike traditional AI assistants that edit your files behind your back, TOS preserves your role as the final gatekeeper.
* **Governing the Trinity:** You oversee the 1:1:1 mandate. While the Agent is tasked with proposing the Work Breakdown Structure (WBS) and specific tasks, you remain the final authority. 
* **Interaction with the Truth:** While the Ghost handles the heavy lifting in the sandbox, you are not disconnected from reality. You use your local development environment to review the Ghost's changes, execute test suites, and perform rigorous PR reviews before any code is ever merged into the main line.
* **The Approval Layer:** You are the ultimate "Human-in-the-Loop" (HITL). Nothing is committed or pushed without your explicit validation of the Agent's reasoning.

**The Architect’s Mantra:** *"I provide the wisdom; the team provides the labor."*

---

## 2. The Universal Agent (Cognitive Reasoning)
**Identity:** The Large Language Model (e.g., Gemini, Claude).
**The Guardrail:** Agnosticism and Protocol.

The Agent is the "Reasoning Engine." It is brilliant but inherently ungrounded. TOS mitigates this by forcing the Agent into a state of **Universal Agnosticism**. It "knows" nothing about your project until you provide context via the ephemeral outbox.

* **Declarative Development:** The Agent is strictly a "Declarative Developer." It is physically blocked from executing commands or touching files. It only writes raw text **Payloads** that describe its *intent*.
* **The Micro-Protocol:** To prevent the "Rush to Code" hallucination, the Agent is forced into a 4-step cadence:
    1.  **Mirror:** Repeat the request to prove context alignment.
    2.  **Challenge:** Critique the Architect’s request against the project’s documentation.
    3.  **Plan:** Step through logic before touching syntax.
    4.  **Execute:** Generate the payload (e.g., `write code` or `write issue`).
* **The Trinity Anchor:** In every payload, the Agent must declare the `TARGET_PROJECT` and `TARGET_TRINITY`. If it loses track of these, its work is rejected by the system.

**The Agent’s Mantra:** *"I am a declarative developer. I propose reality; I do not create it."*

---

## 3. The Ghost (Technical Execution)
**Identity:** The `team_of_six` system user (Linux Sandbox).
**The Guardrail:** Physical Isolation.

The Ghost is the "Mechanic." It is a restricted Unix system user account that lives inside an isolated **sandbox** (usually `${TOS_MNT_ROOT}/sandbox/`). 

* **Execution Barrier:** The Ghost is the only actor allowed to perform file mutations. It parses the Agent's text payloads and applies them to the filesystem. Because it lives in a sandbox, it cannot accidentally touch your home directory, your personal SSH keys, or your active working tree.
* **Automated Mirroring:** The Ghost is the "hands" that talk to the "Remote Truth" (GitHub). It handles the `git clone`, `git branch`, and `git push`. 
* **The IPC Gateway:** The Ghost acts as the interpreter for the engine's protocol. It validates the integrity of the Agent's payloads before applying changes, ensuring that the AI's "thoughts" follow the framework's strict rules.

**The Ghost’s Mantra:** *"I am the bridge between the Agent's thoughts and the physical code."*

---

## The Interaction: A Team Effort

In this model, "Grounding" is a shared responsibility between the Architect and the Ghost:
1.  The **Ghost** ensures the sandbox is a perfect mirror of the repository.
2.  The **Agent** reasons through the files provided by the Ghost.
3.  The **Architect** reviews the Ghost's mutations in their own dev environment, running tests to ensure the AI's "Reasoning" survived the transition to "Physical Reality."

This friction is the secret to the Team of Six's efficiency. By separating these concerns, you move from "one person struggling with a chat bot" to a **Lead Architect** managing a high-performance team capable of delivering professional-grade software at six times the standard solo speed.

---

← [00-llm-pitfalls.md](00-llm-pitfalls.md) | Next: [02-architecture.md](02-architecture.md)
