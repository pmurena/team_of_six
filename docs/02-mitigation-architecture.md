# Mitigation Architecture: Neutralizing Pitfalls

Our architecture does not rely on making the LLM "smarter"; it relies on making the system constraints stricter.

### Strict State Management
We externalize memory. The Ghost is forced to read from a single, deterministic source of truth—the file system and version control—rather than its internal context window.

### Intent Alignment & Architect Review
We prevent errors *before* code is written. Every turn follows a **Mirror & Challenge** cycle where the Architect (human) and Ghost (agent) align on intent. The **Architect PR Review** feedback loop catches logic flaws early, using specific flags like `[FIXME]` or `[CHALLENGE]` to route corrections.

### Context Scoping (RAG for Code)
We use a "Typewriter" architecture where the engine dynamically feeds only strictly relevant files and dependencies into the `outbox.md` context. This prevents context pollution and keeps reasoning sharp.
