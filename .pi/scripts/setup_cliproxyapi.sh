#!/usr/bin/env bash
# Print a Pi models.json for a CLIProxyAPI server to stdout. Changes nothing.
# Points the anthropic and xai providers at the proxy and keeps their built-in models. Lists the
# OpenAI chat models the proxy serves under openai-codex, which needs them listed to use the
# openai-responses API. Owners come from /v1/models; names, token limits and image input from the
# Gemini-style /v1beta/models. The key must match one of access.api-keys in the proxy config and
# is written into the output. Requires curl.
#
# Usage: setup_cliproxyapi.sh --adress http://127.0.0.1:8317 --key <key> > ~/.pi/agent/models.json
#    or: CLIPROXY_API_URL=http://127.0.0.1:8317 CLIPROXY_API_KEY=<key> setup_cliproxyapi.sh

set +x
set -Eeuo pipefail

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
json_string() { local s="${1//\\/\\\\}"; printf '"%s"' "${s//\"/\\\"}"; }
# field <flat JSON object> <key>: raw value of a string, number or string-array field
field() { sed -En 's/.*"'"$2"'":("([^"\\]|\\.)*"|\[[^]]*\]|[^,}]*).*/\1/p' <<<"$1"; }
# fetch <path>: one flat JSON object per line, without the free-text descriptions
fetch() {
    curl -fsS --max-time 10 -H @- "$URL$1" <<<"Authorization: Bearer $KEY" |
        sed -E 's/"description":"([^"\\]|\\.)*",?//g' | grep -o '{[^{}]*}' ||
        die "$URL$1 failed; check the URL and that access.api-keys contains the key"
}

USAGE="usage: ${0##*/} --adress <cliproxyapi-url> --key <api-key> (or CLIPROXY_API_URL, CLIPROXY_API_KEY)"
URL="${CLIPROXY_API_URL:-}"
KEY="${CLIPROXY_API_KEY:-}"
while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || die "$USAGE"
    case "$1" in
        --adress|--address) URL="$2" ;;
        --key) KEY="$2" ;;
        *) die "$USAGE" ;;
    esac
    shift 2
done
URL="${URL%/}"
URL="${URL%/v1}"
[[ "$URL" =~ ^https?://[^[:space:]/]+(/[^[:space:]]*)?$ ]] || die "missing or invalid URL '$URL'; $USAGE"
[[ "$KEY" =~ ^[[:graph:]]+$ ]] || die "missing key, or it has spaces or control characters; $USAGE"
command -v curl >/dev/null 2>&1 || die 'required command not found: curl'

OWNERS="$(fetch /v1/models)"
MODELS="$(fetch /v1beta/models)"

ENTRIES=''  # one model JSON per line
while IFS= read -r obj; do
    context="$(field "$obj" inputTokenLimit)"
    [[ -n "$context" ]] || continue  # image, video and speech models have no token limits
    id="$(field "$obj" name)"
    id="${id#\"models/}"
    id="${id%\"}"
    owner="$(field "$(grep -F "\"id\":\"$id\"" <<<"$OWNERS" || true)" owned_by)"
    [[ "$owner" == '"openai"' ]] || continue
    name="$(field "$obj" displayName)"
    # the proxy does not say which models think; current OpenAI chat models all do
    entry="{\"id\": \"$id\", \"name\": ${name:-\"$id\"}, \"reasoning\": true"
    if [[ "$(field "$obj" supportedInputModalities)" == *'"image"'* ]]; then
        entry+=', "input": ["text", "image"]'
    fi
    entry+=", \"contextWindow\": $context"
    max_tokens="$(field "$obj" outputTokenLimit)"
    if [[ -n "$max_tokens" ]]; then entry+=", \"maxTokens\": $max_tokens"; fi
    ENTRIES+="        $entry}"$'\n'
done <<<"$MODELS"
[[ -n "$ENTRIES" ]] || die 'CLIProxyAPI serves no OpenAI models; sign in to Codex there'

API_KEY="${KEY//\$/\$\$}"  # Pi expands $NAME and a leading !command in apiKey
if [[ "$API_KEY" == \!* ]]; then API_KEY="\$$API_KEY"; fi
API_KEY="$(json_string "$API_KEY")"
BASE="$(json_string "$URL")"
V1="$(json_string "$URL/v1")"

# sendSessionAffinityHeaders serves the proxy's routing.session-affinity
cat <<EOF
{
  "providers": {
    "anthropic": {
      "baseUrl": $BASE,
      "apiKey": $API_KEY,
      "compat": {
        "sendSessionAffinityHeaders": true
      }
    },
    "openai-codex": {
      "name": "Codex via CLIProxyAPI",
      "baseUrl": $V1,
      "api": "openai-responses",
      "apiKey": $API_KEY,
      "models": [
$(sed '$!s/$/,/' <<<"${ENTRIES%$'\n'}")
      ]
    },
    "xai": {
      "baseUrl": $V1,
      "apiKey": $API_KEY,
      "compat": {
        "sendSessionAffinityHeaders": true
      }
    }
  }
}
EOF
