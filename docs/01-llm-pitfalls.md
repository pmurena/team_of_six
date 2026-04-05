# LLM Pitfalls in Agentic Coding

Reliable agentic coding requires first acknowledging that LLMs are fundamentally flawed for autonomous, deterministic tasks. Standard implementations often collapse due to four primary pitfalls:

### 1. Context Degradation & Prompt Drift
LLMs lose the thread of the original architecture over long sessions. As context windows fill with trial-and-error logs, the model's focus drifts, leading to fractured logic and "amnesia" regarding core project rules.

### 2. Hallucinated Syntax & Fictitious APIs
Without grounding in the actual repository state, LLMs rely on probabilistic training data. This results in the model inventing libraries, methods, or variables that do not exist in the current environment.

### 3. Infinite Action Loops
When an agent encounters a failing test, it often gets stuck repeatedly trying the same sub-optimal solution or entering a death spiral of slightly tweaked, incorrect code.

### 4. Premature Convergence
LLMs frequently commit confidently to an incorrect architectural path without adequately exploring alternatives or fully aligning with the developer's actual intent.
