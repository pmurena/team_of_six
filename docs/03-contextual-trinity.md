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
