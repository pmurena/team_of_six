# The Contextual Trinity

The cornerstone of this project is the **Contextual Trinity**. We prevent cognitive collapse by mapping the agent's bounds directly to version control primitives.

### 1. One Issue (The Intent)
* **Definition:** The bounded scope of *why* we are making a change.
* **Function:** It focuses goal-seeking behavior. If a proposal does not serve the Issue, it is discarded, preventing feature creep and architectural tangents.

### 2. One PR (The Change)
* **Definition:** The exact, isolated set of modifications being proposed (The Context).
* **Function:** It scopes the LLM's working memory strictly to what is currently being altered. This eliminates context drift and ensures reviews are focused on a clear diff.

### 3. One Branch (The Baseline)
* **Definition:** The foundational, deterministic state of the codebase (The Reality).
* **Function:** This grounds the LLM in the factual, working reality of the code as it exists *now*, providing a solid anchor before any new logic is applied.
