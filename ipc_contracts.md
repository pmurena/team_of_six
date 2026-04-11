1. Inception Module (create)
These actions establish the "Remote Truth" and the initial workspace.

Action: project (Soft-lock)
intent: creates new project from sandbox over git to architects local. 
Inbox (Input):
Plaintext
===TOS_PROJECT_START===
NAME=project-name
VISIBILITY=public|private
README=Initial description
LICENSE=mit|apache|none
LANGUAGE=zsh|python|etc
===TOS_PROJECT_END===
Outbox (Output): Sandbox Git local diff and the gh repo view URL.

Action: trinity (Soft-lock)
intent: links issues with their PR and Branch, thereby creating the trinity. Can not deal with lists, only single trinity creation.
Inbox (Input):
Plaintext (only one or fail)
===TOS_TRINITY_START===
TITLE=Feature title
BODY=Detailed requirement description
===TOS_TRINITY_END===
Outbox (Output): List of created GitHub Issue IDs and the corresponding tos-work-<ID> branch confirmation.

Action: issue (Soft-lock)
intent: creates issues to nurture backlog, not trinity yet, only issues, can deal with lists.
Inbox (Input):
===TOS_ISSUE_LIST_START===
===TOS_ISSUE_START===
TITLE=Feature title
BODY=Detailed requirement description
===TOS_ISSUE_END===
===TOS_ISSUE_LIST_END===
Outbox (Output): List of created GitHub Issue IDs. 

2. Alignment Module (sync)
These actions ensure the Ghost’s sandbox and the Architect’s context are synchronized.

Action: Project (Soft-lock)
intent: clones or forces pulls the groundtruth from remote.
Inbox (Input): 
Plaintext
===TOS_PROJECT_START===
NAME=project-name
URL=<remote_url>
===TOS_PROJECT_END===
Outbox (Output): A git status summary of the sandbox showing alignment with origin/main.

Action: Trinity (Soft-lock)
intent:checksout the trinity into the sanbox and architect local. 
Inbox (Input): 
Plaintext
===TOS_TRINITY_START===
TARGET_PROJECT=repo-name
TARGET_TRINITY=ID
===TOS_TRINITY_END===
Outbox (Output): The Clean Room Snapshot, including the Issue body, PR comments, and current diff against main.

Action: peek (Soft-lock)
Inbox (Input):
===TOS_FILE_LIST_START===
path_to_file_1
path_to_file_2
path_to_file_3
path_to_file_...
===TOS_FILE_LIST_END===
Outbox (Output):
Plaintext
### File: `path/to/file`
[Raw file content]

3. Mutation Module (write)
These actions perform the actual repository changes via the Ghost.

Action: trinity (Soft-lock)
Intend: update the trinity description. 
Inbox (Input):
Plaintext
===TOS_TRINITY_START===
TARGET_PROJECT=repo-name
TARGET_TRINITY=ID
BODY=Updated issue and PR description
===TOS_TRINITY_END===

Outbox (Output): Verification that the remote Issue/PR has been updated.

Action: comment (Soft-lock)
Intend: add comment.
Inbox (Input):
Plaintext
===TOS_COMMENT_START===
TARGET=ID_OR_BRANCH
BODY=The comment text
===TOS_COMMENT_END===
Outbox (Output): The published Comment ID and a preview of the posted text.

Action: code
Intend: alters files in the repo. 
Inbox (Input): (Hard-lock)
Plaintext
===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
TITLE=Red: failing test for add()
BODY=Initial test suite using native zsh and utils.zsh.
===TOS_META_END===
===TOS_FILE_START: test_calculator.zsh===
content...
===TOS_FILE_END===
Outbox (Output): A Ghost Journal entry showing exactly which files were overwritten and the resulting Git diff.

4. Finality & Purge Modules (close & delete)
These actions manage the "Tear Down" of local and remote resources.

Action: close project (Soft-lock)
Intend: close and delete local and sanbox copy of a project, without delete remote.
Inbox (Input):
===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
REMOTE_URL=...
===TOS_META_END===
Outbox (Output): Proof of sandbox deletion (ls check) while noting the remote remains intact.

Action: close trinity (Hard-lock)
Inbox (Input):
Intend: close a trinity by clsoing the issue, the pr and merging the branch.  
Inbox (Input): 
===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
REMOTE_URL=...
===TOS_META_END===
Outbox (Output): Confirmation of PR merge, remote branch deletion, and Issue closure.

Action: delete project (Soft-lock)
Intend: close project including delete remote.
Inbox (Input): 
===TOS_META_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
REMOTE_URL=...
===TOS_META_END===
Outbox (Output): Proof of sandbox deletion (ls check) while noting the remote remains intact.

Action: delete trinity (Hard-lock)
Intend: wipe a trintiy clean to avoid it polluting the context. 
Inbox (Input): Trinity ID to be purged.
===TOS_TRINITY_START===
TARGET_PROJECT=repo-name
TARGET_TRINITY=ID
BODY=reason for deletion.
===TOS_TRINITY_END===
Outbox (Output): Verification that the remote branch and all associated PR/Issue metadata have been scrubbed. Keep the deletion reason for human context.
