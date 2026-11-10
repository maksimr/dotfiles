#!/usr/bin/env bash
# Point Pi at a CLIProxyAPI server. Prompts for a client API key, saves it to
# ~/.cli-proxy-api/client.key (overwrites), and writes the anthropic, openai-codex and xai
# providers of ~/.pi/agent/models.json for the given proxy URL. Other providers are kept.
# The key must match one of access.api-keys in the proxy config. Requires Python 3 and Pi
# (for the Codex model catalog). Rerun after Pi catalog updates to refresh the Codex models.
#
# Usage: bash ~/.dotfiles/.pi/scripts/setup_cliproxyapi.sh http://127.0.0.1:8317

set +x
set -Eeuo pipefail
umask 077

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 1 ]] || die "usage: ${0##*/} <cliproxyapi-url>"
URL="${1%/}"
URL="${URL%/v1}"
[[ "$URL" =~ ^https?://[^[:space:]/]+(/[^[:space:]]*)?$ ]] || die "invalid URL: $1"
command -v python3 >/dev/null 2>&1 || die 'required command not found: python3'

read -rsp 'CLIProxyAPI client API key: ' KEY || true
printf '\n' >&2
[[ -n "$KEY" ]] || die 'empty key'
[[ "$KEY" =~ ^[[:graph:]]+$ ]] || die 'key must not contain spaces or control characters'

DIR="$HOME/.cli-proxy-api"
mkdir -p "$DIR"
chmod 700 "$DIR"
TMP="$(mktemp "$DIR/client.key.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
printf '%s\n' "$KEY" > "$TMP"
mv -f "$TMP" "$DIR/client.key"
unset KEY
printf 'Saved client key to %s\n' "$DIR/client.key"

if command -v pi >/dev/null 2>&1; then
    pi update --models --no-approve >/dev/null ||
        printf 'Warning: Pi catalog refresh failed; using the cached catalog\n' >&2
fi

python3 - "$URL" <<'PY'
import json, os, sys, urllib.request

BASE = sys.argv[1]
HOME = os.path.expanduser('~')
# Same key command as import_cliproxyapi.sh; the Keychain fallback serves older setups.
KEY_CMD = 'cat ~/.cli-proxy-api/client.key 2>/dev/null || security find-generic-password -s cliproxyapi-client -w'
PI_DIR = os.environ.get('PI_CODING_AGENT_DIR') or os.path.join(HOME, '.pi', 'agent')


def load(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return default


catalog = load(os.path.join(PI_DIR, 'models-store.json'), {}).get('openai-codex', {}).get('models', [])
# Provider-level api applies only to listed models, so copy Pi's catalog entries.
codex_models = [{k: v for k, v in m.items() if k not in ('type', 'provider', 'api', 'baseUrl')} for m in catalog]
if not codex_models:
    sys.exit('Error: Pi has no cached openai-codex catalog; run "pi update --models" and retry')

path = os.path.realpath(os.path.join(PI_DIR, 'models.json'))  # write through dotfiles symlinks
config = load(path, {})
api_key = '!' + KEY_CMD
config.setdefault('providers', {}).update({
    'anthropic': {'baseUrl': BASE, 'apiKey': api_key,
                  'compat': {'sendSessionAffinityHeaders': True}},  # routing.session-affinity
    'openai-codex': {'name': 'Codex via CLIProxyAPI', 'baseUrl': BASE + '/v1', 'api': 'openai-responses',
                     'apiKey': api_key, 'models': codex_models},
    'xai': {'baseUrl': BASE + '/v1', 'apiKey': api_key},  # built-in Grok models already use openai-responses
})
os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + '.tmp'
with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write('\n')
os.replace(tmp, path)
print(f'Pi uses CLIProxyAPI at {BASE} for anthropic, openai-codex, xai: {path}')

auth = load(os.path.join(PI_DIR, 'auth.json'), {})
for provider in ('anthropic', 'openai-codex', 'xai'):
    if provider in auth:  # auth.json credentials take precedence over models.json apiKey
        print(f'Warning: Pi auth.json has a "{provider}" credential that overrides the proxy key; '
              'remove it with /logout in Pi', file=sys.stderr)

with open(os.path.join(HOME, '.cli-proxy-api', 'client.key')) as f:
    key = f.read().strip()
request = urllib.request.Request(BASE + '/v1/models', headers={'Authorization': 'Bearer ' + key})
try:
    with urllib.request.urlopen(request, timeout=10) as response:
        print(f"CLIProxyAPI answers with {len(json.load(response).get('data', []))} models")
except (OSError, ValueError) as error:
    print(f'Warning: {BASE}/v1/models failed ({error}); check the URL and that '
          'access.api-keys contains the client key', file=sys.stderr)
PY
