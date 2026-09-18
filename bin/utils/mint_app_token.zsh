#!/bin/zsh
# ==============================================================================
# Title: GitHub App Installation Token
# Usage: mint_app_token.zsh        (prints a token to stdout)
#
# Mints a short-lived installation access token for the Ghost's GitHub App.
#
# WHY AN APP RATHER THAN A PAT
#   A PAT is a long-lived bearer credential sitting on disk. The App's private
#   key is not a credential — it mints tokens that expire in one hour, and it
#   cannot be replayed against the API directly. The Ghost therefore never
#   holds a durable secret.
#
#   It also gives the Ghost a GitHub identity of its own (<slug>[bot]), which
#   the phase gate requires: GitHub refuses to let anyone approve their own
#   pull request, and the Ghost authors every Trinity PR.
#
# CONFIG (conf/config)
#   TOS_APP_ID           numeric App ID
#   TOS_APP_INSTALL_ID   numeric installation ID
#   TOS_APP_PEM          path to the private key, mode 0400, Ghost-owned
# ==============================================================================

: "${TOS_APP_ID:?TOS_APP_ID is not set}"
: "${TOS_APP_INSTALL_ID:?TOS_APP_INSTALL_ID is not set}"
: "${TOS_APP_PEM:?TOS_APP_PEM is not set}"

[[ -r "$TOS_APP_PEM" ]] || { echo "🚨 Cannot read the App private key at $TOS_APP_PEM" >&2; exit 1; }

_b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '=' }

_HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | _b64url)
_NOW=$(date +%s)
# iat backdated 60s for clock skew; exp 9 minutes (GitHub's ceiling is 10).
_PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $(( _NOW - 60 )) $(( _NOW + 540 )) "$TOS_APP_ID" | _b64url)
_SIG=$(printf '%s.%s' "$_HEADER" "$_PAYLOAD" \
        | openssl dgst -sha256 -sign "$TOS_APP_PEM" -binary | _b64url) || {
    echo "🚨 Could not sign the JWT. Is $TOS_APP_PEM a valid RSA private key?" >&2
    exit 1
}
_JWT="${_HEADER}.${_PAYLOAD}.${_SIG}"

# curl rather than gh: gh resolves credentials from its own config and the
# precedence against an explicit Authorization header is not guaranteed. Here
# the JWT must be the only credential in play.
_RESPONSE=$(curl -sS -X POST \
    -H "Authorization: Bearer ${_JWT}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/${TOS_APP_INSTALL_ID}/access_tokens" 2>&1) || {
    echo "🚨 Network failure requesting an installation token." >&2
    exit 1
}

_TOKEN=$(printf '%s' "$_RESPONSE" | tr ',' '\n' \
    | grep -m1 '"token"' | sed 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [[ -z "$_TOKEN" || "$_TOKEN" == *'"'* ]]; then
    echo "🚨 GitHub did not return an installation token." >&2
    echo "    Response: ${_RESPONSE}" >&2
    exit 1
fi

print -r -- "$_TOKEN"
