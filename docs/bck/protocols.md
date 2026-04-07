# The Synthetic Output Protocols

The Ghost uses strictly formatted text blocks to declare intents, which the Engine's `awk` parsers translate into Git operations.

## 1. Code Update Protocol (`tos write code`)
Used to write files, commit changes, and open/update GitHub Pull Requests.

* Requires a `===TOS_META_START===` block defining the `TITLE` and `BODY`.
* Followed by one or more `===TOS_FILE_START: path/to/file===` blocks containing raw, unescaped code, closed by `===TOS_FILE_END===`.

## 2. Batch Issue Protocol (`tos work new`)
Used to break down scope and create new GitHub Issues.

* Bounded by `===TOS_ISSUE_START===` and `===TOS_ISSUE_END===`.
* The Engine parses these blocks and executes `gh issue create` for each block.

## 3. Comment Protocol (`tos write comment`)
Used to post thread replies or diagnostics directly to a GitHub Issue or Pull Request. Requires no synthetic tags; standard markdown is streamed via `gh issue comment` or `gh pr comment` depending on the target ID.
