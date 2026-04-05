# Tool Calling & The Plaintext Protocol

A major pitfall in agentic frameworks is relying on JSON for tool calling. Shell environments handle JSON poorly, leading to catastrophic parsing failures due to escaping or hallucinated quotes.

### Why Plaintext?
TOS pins the LLM to strict, deterministic **plaintext formats**.
* **Resilience:** Plaintext is far more resilient to shell parsing errors than JSON.
* **Speed:** The engine uses standard POSIX tools (`awk`, `grep`, `sed`) to stream and parse blocks directly.
* **Determinism:** Synthetic boundary tags like `===TOS_FILE_START===` ensure outputs are machine-readable and executable without complex escaping.

### Protocol Tags
The engine's `parse_blocks.sh` utility extracts these blocks into isolated text files for execution:
* **`META`**: For commit titles and PR bodies.
* **`FILE`**: For raw code that overwrites target files.
* **`ISSUE`**: For batch ticket creation.
* **`COMMENT`**: For thread replies.
