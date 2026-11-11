#!/usr/bin/env bash
# Print a Pi models.json for a CLIProxyAPI server to stdout. Changes nothing.
# For each model owner the proxy serves, Pi's built-in provider with the same model IDs (anthropic,
# xai, google, meta, moonshotai for Kimi) is pointed at the proxy and keeps its built-in models.
# OpenAI chat models are listed under openai-codex, which needs them listed to use the
# openai-responses API; models of other owners (Antigravity, Devin, ...) under cliproxyapi.
# Owners come from /v1/models; names, token limits and image input from the Gemini-style
# /v1beta/models. The key must match one of access.api-keys in the proxy config and
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

# Owner, Pi provider and API path of the Pi providers whose built-in model IDs match the proxy's
BUILTINS='anthropic anthropic
xai xai /v1
google google /v1beta
meta meta /v1
moonshot moonshotai /v1'

OWNERS="$(fetch /v1/models)"
MODELS="$(fetch /v1beta/models)"

SERVED=' '  # served owners from BUILTINS
CODEX=''    # model JSON lines for openai-codex
OTHERS=''   # model JSON lines for cliproxyapi
while IFS= read -r obj; do
    context="$(field "$obj" inputTokenLimit)"
    [[ -n "$context" ]] || continue  # image, video and speech models have no token limits
    id="$(field "$obj" name)"
    id="${id#\"models/}"
    id="${id%\"}"
    owner="$(field "$(grep -F "\"id\":\"$id\"" <<<"$OWNERS" || true)" owned_by)"
    owner="${owner//\"/}"
    if [[ $'\n'"$BUILTINS" == *$'\n'"$owner "* ]]; then
        SERVED+="$owner "
        continue
    fi
    name="$(field "$obj" displayName)"
    # shortcut: the proxy does not say which models think, so all may; use /thinking off where one fails
    entry="{\"id\": \"$id\", \"name\": ${name:-\"$id\"}, \"reasoning\": true"
    if [[ "$(field "$obj" supportedInputModalities)" == *'"image"'* ]]; then
        entry+=', "input": ["text", "image"]'
    fi
    entry+=", \"contextWindow\": $context"
    max_tokens="$(field "$obj" outputTokenLimit)"
    if [[ -n "$max_tokens" ]]; then entry+=", \"maxTokens\": $max_tokens"; fi
    if [[ "$owner" == openai ]]; then CODEX+="        $entry}"$'\n'; else OTHERS+="        $entry}"$'\n'; fi
done <<<"$MODELS"
[[ "$SERVED" != ' ' || -n "$CODEX$OTHERS" ]] || die 'CLIProxyAPI serves no chat models; sign in to a provider there'

API_KEY="${KEY//\$/\$\$}"  # Pi expands $NAME and a leading !command in apiKey
if [[ "$API_KEY" == \!* ]]; then API_KEY="\$$API_KEY"; fi
API_KEY="$(json_string "$API_KEY")"

SEPARATOR=''
# print_provider <provider> <baseUrl> [<more JSON fields>]
# sendSessionAffinityHeaders serves the proxy's routing.session-affinity
print_provider() {
    printf '%s\n    "%s": {\n      "baseUrl": %s,\n      "apiKey": %s,\n      "compat": {\n        "sendSessionAffinityHeaders": true\n      }%s\n    }' \
        "$SEPARATOR" "$1" "$(json_string "$2")" "$API_KEY" "${3:-}"
    SEPARATOR=','
}
# listed <name> <api> <model JSON lines>: JSON fields of a provider with listed models
listed() {
    printf ',\n      "name": "%s",\n      "api": "%s",\n      "models": [\n%s\n      ]' \
        "$1" "$2" "$(sed '$!s/$/,/' <<<"${3%$'\n'}")"
}

printf '{\n  "providers": {'
while read -r owner provider path; do
    if [[ "$SERVED" == *" $owner "* ]]; then print_provider "$provider" "$URL$path"; fi
done <<<"$BUILTINS"
if [[ -n "$CODEX" ]]; then
    print_provider openai-codex "$URL/v1" "$(listed 'Codex via CLIProxyAPI' openai-responses "$CODEX")"
fi
if [[ -n "$OTHERS" ]]; then
    print_provider cliproxyapi "$URL/v1" "$(listed CLIProxyAPI openai-completions "$OTHERS")"
fi
printf '\n  }\n}\n'
