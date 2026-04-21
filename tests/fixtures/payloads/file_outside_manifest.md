===TOS_META_START===
TARGET_PROJECT=test-project
TARGET_TRINITY=1
TITLE=Rogue file attempt
BODY=Should be rejected by manifest check.
===TOS_META_END===
===TOS_FILE_START: rogue.zsh===
#!/bin/zsh
echo "I should not exist"
===TOS_FILE_END===
