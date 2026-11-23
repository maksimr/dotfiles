#!/usr/bin/env bash
# Print CLIProxyAPI client config to stdout for a harness. Changes nothing.
# Harnesses:
#   pi (default)  Pi models.json (queries /v1/models and /v1beta/models; requires curl).
#                 For each served owner, Pi's built-in provider (anthropic, xai, google, meta,
#                 moonshotai for Kimi) is pointed at the proxy and keeps its built-in models.
#                 OpenAI chat models are listed under openai-codex (openai-responses API).
#                 Antigravity models are listed under antigravity with the proxy's Gemini API;
#                 extensions/antigravity-prompt-guard.ts rewrites Pi's system prompt for them.
#                 Other owners go under cliproxyapi. Repeat --only / --exclude to filter providers.
#   claude-code   Claude Code settings.json snippet (~/.claude/settings.json).
#   codex         Codex CLI config.toml snippet (~/.codex/config.toml).
#   antigravity   Shell exports for Antigravity CLI (agy).
# The key must match one of access.api-keys in the proxy config and is written into the output.
#
# Usage: setup_cliproxyapi.sh [pi|claude-code|codex|antigravity] --adress http://127.0.0.1:8317 --key <key>
#    or: CLIPROXY_API_URL=http://127.0.0.1:8317 CLIPROXY_API_KEY=<key> setup_cliproxyapi.sh [harness]
#    or: setup_cliproxyapi.sh pi --adress <url> --key <key> --only openai-codex --only google
#    or: setup_cliproxyapi.sh claude-code --adress <url> --key <key>  # merge into ~/.claude/settings.json
#    or: setup_cliproxyapi.sh codex --adress <url> --key <key>        # merge at top of ~/.codex/config.toml
#    or: eval "$(setup_cliproxyapi.sh antigravity --adress <url> --key <key>)"

set +x
set -Eeuo pipefail

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
json_string() { local s="${1//\\/\\\\}"; printf '"%s"' "${s//\"/\\\"}"; }
sh_quote() {
    local s="$1" sq="'" out="'"
    while [[ "$s" == *"$sq"* ]]; do
        out+="${s%%"$sq"*}'\\''"
        s="${s#*"$sq"}"
    done
    printf "%s%s'" "$out" "$s"
}
# field <flat JSON object> <key>: raw value of a string, number or string-array field
field() { sed -En 's/.*"'"$2"'":("([^"\\]|\\.)*"|\[[^]]*\]|[^,}]*).*/\1/p' <<<"$1"; }
# fetch <path>: one flat JSON object per line, without the free-text descriptions
fetch() {
    curl -fsS --max-time 10 -H @- "$URL$1" <<<"Authorization: Bearer $KEY" |
        sed -E 's/"description":"([^"\\]|\\.)*",?//g' | grep -o '{[^{}]*}' ||
        die "$URL$1 failed; check the URL and that access.api-keys contains the key"
}

# Owner, Pi provider and API path of the Pi providers whose built-in model IDs match the proxy's
BUILTINS='anthropic anthropic
xai xai /v1
google google /v1beta
meta meta /v1
moonshot moonshotai /v1'
PROVIDERS=" $(cut -d' ' -f2 <<<"$BUILTINS" | tr '\n' ' ')openai-codex antigravity cliproxyapi "

HARNESSES=' pi claude-code codex antigravity '
USAGE="usage: ${0##*/} [pi|claude-code|codex|antigravity] --adress <cliproxyapi-url> --key <api-key> [--only <provider>]... [--exclude <provider>]...
(or CLIPROXY_API_URL, CLIPROXY_API_KEY); default harness: pi; pi providers:$PROVIDERS"
HARNESS=''
URL="${CLIPROXY_API_URL:-}"
KEY="${CLIPROXY_API_KEY:-}"
ONLY=' '
EXCLUDE=' '
while [[ $# -gt 0 ]]; do
    case "$1" in
        --adress|--address)
            [[ $# -ge 2 && "$2" != -* ]] || die "$USAGE"
            URL="$2"; shift 2 ;;
        --key)
            [[ $# -ge 2 && "$2" != -* ]] || die "$USAGE"
            KEY="$2"; shift 2 ;;
        --only|--exclude)
            [[ $# -ge 2 ]] || die "$USAGE"
            [[ "$2" != *[[:space:]]* && "$PROVIDERS" == *" $2 "* ]] || die "unknown provider '$2'; use one of:$PROVIDERS"
            if [[ "$1" == --only ]]; then ONLY+="$2 "; else EXCLUDE+="$2 "; fi
            shift 2 ;;
        -*) die "$USAGE" ;;
        *)
            [[ -z "$HARNESS" ]] || die "$USAGE"
            case "$1" in
                pi|claude-code|codex|antigravity) HARNESS="$1" ;;
                *) die "unknown harness '$1'; use one of:$HARNESSES" ;;
            esac
            shift ;;
    esac
done
HARNESS="${HARNESS:-pi}"
if [[ "$HARNESS" != pi && ( "$ONLY" != ' ' || "$EXCLUDE" != ' ' ) ]]; then
    die '--only and --exclude are supported only for pi'
fi
[[ "$URL" =~ ^https?://[^/[:cntrl:][:space:]?#]+(/[^[:cntrl:][:space:]?#]*)?$ ]] || die "missing or invalid URL '$URL'; $USAGE"
while [[ "$URL" == */ ]]; do URL="${URL%/}"; done
if [[ "$URL" =~ ^(https?://[^/]+)(/.*)$ ]]; then
    url_path="${BASH_REMATCH[2]}"
    case "$url_path" in
        */v1) url_path="${url_path%/v1}" ;;
        */v1beta) url_path="${url_path%/v1beta}" ;;
    esac
    while [[ "$url_path" == */ ]]; do url_path="${url_path%/}"; done
    URL="${BASH_REMATCH[1]}$url_path"
fi
[[ "$KEY" =~ ^[[:graph:]]+$ ]] || die "missing key, or it has spaces or control characters; $USAGE"

case "$HARNESS" in
    claude-code)
        printf '{\n  "$schema": "https://json.schemastore.org/claude-code-settings.json",\n  "env": {\n    "ANTHROPIC_BASE_URL": %s,\n    "ANTHROPIC_AUTH_TOKEN": %s,\n    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1"\n  }\n}\n' \
            "$(json_string "$URL")" "$(json_string "$KEY")"
        exit 0 ;;
    codex)
        printf 'model_provider = "cliproxyapi"\n\n[model_providers.cliproxyapi]\nname = "CLIProxyAPI"\nbase_url = %s\nwire_api = "responses"\nrequires_openai_auth = false\nsupports_websockets = true\nexperimental_bearer_token = %s\n' \
            "$(json_string "$URL/v1")" "$(json_string "$KEY")"
        exit 0 ;;
    antigravity)
        printf 'export GOOGLE_GEMINI_BASE_URL=%s\nexport GEMINI_API_KEY=%s\n# Requires {"modelProvider": "gemini"} in ~/.gemini/antigravity-cli/settings.json\n# or run: agy --settings '\''{"modelProvider":"gemini"}'\''\n' \
            "$(sh_quote "$URL")" "$(sh_quote "$KEY")"
        exit 0 ;;
esac

command -v curl >/dev/null 2>&1 || die 'required command not found: curl'

OWNERS="$(fetch /v1/models)"
MODELS="$(fetch /v1beta/models)"

SERVED=' '  # served owners from BUILTINS
CODEX=''    # model JSON lines for openai-codex
ANTIGRAVITY=''  # model JSON lines for antigravity
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
    name="${name:-\"$id\"}"
    # shortcut: the proxy does not say which models think, so all may; use /thinking off where one fails
    entry="{\"id\": \"$id\", \"name\": $name, \"reasoning\": true"
    if [[ "$(field "$obj" supportedInputModalities)" == *'"image"'* ]]; then
        entry+=', "input": ["text", "image"]'
    fi
    entry+=", \"contextWindow\": $context"
    max_tokens="$(field "$obj" outputTokenLimit)"
    if [[ -n "$max_tokens" ]]; then entry+=", \"maxTokens\": $max_tokens"; fi
    sort_key="${name#\"}"
    line="${sort_key%\"}"$'\t'"        $entry"
    if [[ "$owner" == openai ]]; then
        # a listed model replaces Pi's built-in one, which unlocked xhigh and max; without a map Pi stops at high
        CODEX+="$line, \"thinkingLevelMap\": {\"xhigh\": \"xhigh\", \"max\": \"max\"}}"$'\n'
    elif [[ "$owner" == antigravity && "$id" == *-xhigh ]]; then
        # shortcut: xhigh support is read from the -xhigh ID suffix, as the proxy does not list levels;
        # Pi's Gemini API stops at high, so antigravity-prompt-guard.ts turns this high back into xhigh
        ANTIGRAVITY+="$line, \"thinkingLevelMap\": {\"xhigh\": \"high\"}}"$'\n'
    elif [[ "$owner" == antigravity ]]; then
        ANTIGRAVITY+="$line}"$'\n'
    else
        OTHERS+="$line}"$'\n'
    fi
done <<<"$MODELS"

API_KEY="${KEY//\$/\$\$}"  # Pi expands $NAME and a leading !command in apiKey
if [[ "$API_KEY" == \!* ]]; then API_KEY="\$$API_KEY"; fi
API_KEY="$(json_string "$API_KEY")"

OUT=''  # provider JSON blocks
# add_provider <provider> <baseUrl> [<more JSON fields>]: adds it unless --only or --exclude drops it
# sendSessionAffinityHeaders serves the proxy's routing.session-affinity
add_provider() {
    [[ "$EXCLUDE" != *" $1 "* && ( "$ONLY" == ' ' || "$ONLY" == *" $1 "* ) ]] || return 0
    OUT+="$(printf '%s\n    "%s": {\n      "baseUrl": %s,\n      "apiKey": %s,\n      "compat": {\n        "sendSessionAffinityHeaders": true\n      }%s\n    }' \
        "${OUT:+,}" "$1" "$(json_string "$2")" "$API_KEY" "${3:-}")"
}
# listed <name> <api> <sort-key TAB model JSON lines>: JSON fields of a provider with listed models
listed() {
    local body
    body="$(LC_ALL=C sort -t$'\t' -k1,1f <<<"${3%$'\n'}" | cut -f2- | sed '$!s/$/,/' )" || return
    printf ',\n      "name": "%s",\n      "api": "%s",\n      "models": [\n%s\n      ]' \
        "$1" "$2" "$body"
}

while read -r owner provider path; do
    if [[ "$SERVED" == *" $owner "* ]]; then add_provider "$provider" "$URL$path"; fi
done <<<"$BUILTINS"
if [[ -n "$CODEX" ]]; then
    fields="$(listed 'Codex via CLIProxyAPI' openai-responses "$CODEX")"
    add_provider openai-codex "$URL/v1" "$fields"
fi
if [[ -n "$ANTIGRAVITY" ]]; then
    fields="$(listed Antigravity google-generative-ai "$ANTIGRAVITY")"
    add_provider antigravity "$URL/v1beta" "$fields"
fi
if [[ -n "$OTHERS" ]]; then
    fields="$(listed CLIProxyAPI openai-completions "$OTHERS")"
    add_provider cliproxyapi "$URL/v1" "$fields"
fi
[[ -n "$OUT" ]] || die 'no providers to print; sign in to a provider in CLIProxyAPI or change --only and --exclude'
printf '{\n  "providers": {%s\n  }\n}\n' "$OUT"
