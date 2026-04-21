===TOS_META_START===
TARGET_PROJECT=test-project
TARGET_TRINITY=1
TITLE=Missing path marker
BODY=Parser should reject this FILE block.
===TOS_META_END===
===TOS_FILE_START===
#!/bin/zsh
echo "no path was specified on the FILE_START marker"
===TOS_FILE_END===
