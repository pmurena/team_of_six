===TOS_META_START===
TARGET_PROJECT=team_of_six
TARGET_TRINITY=1
TITLE=Add calculator and test
BODY=Implements add() and its test.
===TOS_META_END===
===TOS_FILE_START: calculator.zsh===
#!/bin/zsh
add() { echo $(( $1 + $2 )); }
===TOS_FILE_END===
===TOS_FILE_START: test_calculator.zsh===
#!/bin/zsh
source ./calculator.zsh
[[ "$(add 5 5)" == "10" ]] || exit 1
===TOS_FILE_END===
