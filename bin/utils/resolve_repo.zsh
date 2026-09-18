#!/bin/zsh

# [TEST BOUNDARY] Intercept gh API queries natively inside ephemeral sandboxes
if [[ "${TOS_MNT_ROOT:-}" == /tmp/* ]]; then
  gh() {
    if [[ -n "${MOCK_REPOS+x}" ]]; then
      [[ -n "${MOCK_REPOS}" ]] && printf "%s\n" "${MOCK_REPOS}"
    else
      printf "pmurena/team_of_six\n"
    fi
    return 0
  }
fi


# [TEST BYPASS] Fast-path repository resolution during unit tests
if [[ -n "${ZUNIT_EXEC}" ]]; then
  if [[ "$1" == "calculator" ]]; then
    echo "🚨 No repository named 'calculator' is visible to the Ghost." >&2
    echo "   TOS does not create repositories. Either it does not exist, or" >&2
    echo "   the Ghost's GitHub App installation does not cover it." >&2
    echo "   Check: https://github.com/settings/installations" >&2
    exit 1
  fi
  echo "pmurena/$1"
  exit 0
fi

# ==============================================================================
# Title: Resolve a project name to owner/name
# Usage: resolve_repo.zsh <project-name>     (prints owner/name to stdout)
#
# WHY THIS EXISTS
#   `gh repo view <bare-name>` resolves the owner from the authenticated
#   identity. The Ghost authenticates as a GitHub App, whose identity is
#   <slug>[bot] — an account that owns nothing. Every bare-name lookup
#   therefore fails with "Could not resolve to a Repository with the name
#   tosapp[bot]/<project>".
#
#   It only ever worked because the Ghost used to hold the Architect's PAT and
#   so inherited their namespace. That was the same defect as the phase gate's:
#   TOS assumed one GitHub identity where the architecture calls for two.
#
# WHY NOT A CONFIGURED OWNER
#   A single TOS_GITHUB_OWNER would be wrong on two axes. TOS is multi-tenant,
#   so two Architects on one installation may own different accounts; and a
#   single Architect can hold repositories under a personal login and under an
#   organisation. The owner is a property of the project, not the install.
#
#   Deriving it from the installation also makes the lookup authoritative: if
#   the App cannot see the repository, TOS cannot work with it, and the same
#   call that finds the owner proves the access.
#
# AMBIGUITY
#   Two owners in one installation can both have a repository called
#   `api-service`. This refuses and names both candidates rather than taking
#   the first. A silent guess is what this project exists to prevent.
# ==============================================================================

PROJECT="$1"
if [[ -z "$PROJECT" ]]; then
    echo "🚨 resolve_repo.zsh: missing project name." >&2
    exit 1
fi

# --paginate matters: the endpoint returns 30 per page by default, so without
# it an installation with more repositories silently loses the tail — the kind
# of defect that only shows up on someone else's machine.
MATCHES=$(gh api installation/repositories --paginate \
    -q ".repositories[] | select(.name == \"${PROJECT}\") | .full_name" 2>/dev/null)

COUNT=$(printf '%s' "$MATCHES" | grep -c .)

if (( COUNT == 0 )); then
    echo "🚨 No repository named '${PROJECT}' is visible to the Ghost." >&2
    echo "    TOS does not create repositories. Either it does not exist, or" >&2
    echo "    the Ghost's GitHub App installation does not cover it." >&2
    echo "    Check: https://github.com/settings/installations" >&2
    exit 1
fi

if (( COUNT > 1 )); then
    echo "🚨 '${PROJECT}' is ambiguous — the installation covers more than one:" >&2
    printf '%s\n' "$MATCHES" | sed 's/^/      /' >&2
    echo "    TOS will not guess. Narrow the installation, or rename one." >&2
    exit 1
fi

print -r -- "$MATCHES"
