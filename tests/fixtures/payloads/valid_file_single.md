===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=1
TITLE=Add calculator
BODY=Implements add().
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
