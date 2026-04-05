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
