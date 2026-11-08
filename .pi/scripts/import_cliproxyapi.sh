#!/usr/bin/env bash
# Move existing Pi and Claude Code subscription logins into CLIProxyAPI, then route
# Pi and Claude Code through the proxy. Run install_cliproxyapi.sh first.
# Quit Pi and Claude Code before running. Requires Python 3.
#
# Imports Pi auth.json "anthropic", "openai-codex" and "xai" (Grok) logins (plus
# pi-multi-pass "-N" copies) and the Claude Code login (macOS Keychain or
# ~/.claude/.credentials.json) into ~/.cli-proxy-api. Imported logins are removed from
# Pi and Claude Code: the providers rotate refresh tokens, so two holders of one login
# log each other out. Then points Pi models.json (anthropic, openai-codex, xai) and
# Claude Code settings.json at http://127.0.0.1:8317 with the proxy client key, for
# each provider that has an account in CLIProxyAPI. Rerun after Pi catalog updates
# to refresh the Codex model list, or after signing in to CLIProxyAPI directly;
# already imported logins are skipped.
#
# Usage: bash ~/.dotfiles/.pi/scripts/import_cliproxyapi.sh
# Undo: remove "anthropic", "openai-codex" and "xai" from ~/.pi/agent/models.json and
# "apiKeyHelper" plus env.ANTHROPIC_BASE_URL from ~/.claude/settings.json, then
# log in again in Pi (/login) and Claude Code.

set +x
set -Eeuo pipefail
umask 077

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 0 ]] || die "usage: ${0##*/}"
command -v python3 >/dev/null 2>&1 || die 'required command not found: python3'
[[ -d "$HOME/.cli-proxy-api" ]] || die 'CLIProxyAPI auth dir ~/.cli-proxy-api not found; run install_cliproxyapi.sh first'

if command -v pi >/dev/null 2>&1; then
    pi update --models --no-approve >/dev/null ||
        printf 'Warning: Pi catalog refresh failed; using the cached catalog\n' >&2
fi

exec python3 - <<'PY'
import base64, datetime, json, os, re, secrets, shutil, subprocess, sys, urllib.request

HOME = os.path.expanduser('~')
BASE = 'http://127.0.0.1:8317'  # shortcut: install_cliproxyapi.sh defaults; edit if your config
AUTH_DIR = os.path.join(HOME, '.cli-proxy-api')  # changed server.port or oauth.auth-dir
# install_cliproxyapi.sh writes client.key; older setups keep the key in the macOS Keychain.
KEY_CMD = 'cat ~/.cli-proxy-api/client.key 2>/dev/null || security find-generic-password -s cliproxyapi-client -w'
PI_DIR = os.environ.get('PI_CODING_AGENT_DIR') or os.path.join(HOME, '.pi', 'agent')
CLAUDE_DIR = os.path.join(HOME, '.claude')  # shortcut: ignores CLAUDE_CONFIG_DIR
KEYCHAIN = 'Claude Code-credentials'
HAVE_PI = shutil.which('pi') is not None or os.path.isdir(PI_DIR)
HAVE_CLAUDE = shutil.which('claude') is not None or os.path.isdir(CLAUDE_DIR)


def die(message):
    sys.exit('Error: ' + message)


def load(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return default


def save(path, data):
    path = os.path.realpath(path)  # write through dotfiles symlinks
    tmp = path + '.import-tmp'  # no .json suffix, so CLIProxyAPI ignores partial files
    mode = os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o600
    with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')
        f.flush()
        os.fsync(f.fileno())
    os.chmod(tmp, mode)
    os.replace(tmp, path)


def iso(ms=None):
    utc = datetime.timezone.utc
    t = datetime.datetime.now(utc) if ms is None else datetime.datetime.fromtimestamp(ms / 1000, utc)
    return t.astimezone().isoformat(timespec='seconds')


def jwt_claims(token):
    try:
        part = token.split('.')[1]
        return json.loads(base64.urlsafe_b64decode(part + '=' * (-len(part) % 4)))
    except (IndexError, ValueError):
        return {}


key = subprocess.run(['/bin/sh', '-c', KEY_CMD], capture_output=True, text=True).stdout.strip()
if not key:
    die('no proxy client key in ~/.cli-proxy-api/client.key or Keychain "cliproxyapi-client"')

codex_models = []
if HAVE_PI:
    catalog = load(os.path.join(PI_DIR, 'models-store.json'), {}).get('openai-codex', {}).get('models', [])
    # Provider-level api applies only to listed models, so copy Pi's catalog entries.
    codex_models = [{k: v for k, v in m.items() if k not in ('type', 'provider', 'api', 'baseUrl')} for m in catalog]
    if not codex_models:
        die('Pi has no cached openai-codex catalog; run "pi update --models" and retry')

known = set()  # refresh tokens already in the proxy
kinds = set()  # account types in the proxy
for name in os.listdir(AUTH_DIR):
    if name.endswith('.json'):
        try:
            data = load(os.path.join(AUTH_DIR, name), {})
        except ValueError:
            continue
        if isinstance(data, dict) and data.get('refresh_token'):
            known.add(data['refresh_token'])
            kinds.add(data.get('type'))


def add_to_proxy(kind, label, record):
    if record['refresh_token'] in known:
        print(f'Already in CLIProxyAPI: {label}')
        return
    record = {k: v for k, v in record.items() if v not in ('', None)}
    record.update(type=kind, last_refresh=iso(), disabled=False)
    stem = re.sub(r'[^A-Za-z0-9@._-]', '_', f"{kind}-{record.get('email') or label}")
    path, n = os.path.join(AUTH_DIR, stem + '.json'), 2
    while os.path.exists(path):
        path, n = os.path.join(AUTH_DIR, f'{stem}-{n}.json'), n + 1
    save(path, record)
    known.add(record['refresh_token'])
    kinds.add(kind)
    print(f'Imported {label} -> {path}')


def import_pi():
    auth_path = os.path.join(PI_DIR, 'auth.json')
    if not os.path.exists(auth_path):
        return {}
    lock = auth_path + '.lock'  # the proper-lockfile lock Pi takes before touching auth.json
    try:
        os.mkdir(lock)
    except FileExistsError:
        die(f'{lock} exists; quit Pi (or remove a stale lock) and retry')
    try:
        auth = load(auth_path, {})
        moved = []
        for provider, cred in auth.items():
            match = re.fullmatch(r'(anthropic|openai-codex|xai)(-\d+)?', provider)
            if not match or not isinstance(cred, dict) or cred.get('type') != 'oauth' or not cred.get('refresh'):
                continue
            access, expires = cred.get('access', ''), iso(cred.get('expires', 0))
            if match.group(1) == 'anthropic':
                # CLIProxyAPI fills email and organization on the first token refresh.
                add_to_proxy('claude', 'pi-' + provider, {
                    'access_token': access, 'refresh_token': cred['refresh'], 'expired': expires,
                    'claude_device_ids': [secrets.token_hex(32)],
                })
            elif match.group(1) == 'xai':
                claims = jwt_claims(access)
                add_to_proxy('xai', 'pi-' + provider, {
                    'access_token': access, 'refresh_token': cred['refresh'], 'expired': expires,
                    'email': claims.get('email'), 'sub': claims.get('sub'),
                    'base_url': 'https://api.x.ai/v1', 'auth_kind': 'oauth',
                })
            else:
                claims = jwt_claims(access)
                openai_auth = claims.get('https://api.openai.com/auth', {})
                add_to_proxy('codex', 'pi-' + provider, {
                    'access_token': access, 'refresh_token': cred['refresh'], 'expired': expires,
                    'account_id': cred.get('accountId') or openai_auth.get('chatgpt_account_id'),
                    'email': claims.get('https://api.openai.com/profile', {}).get('email'),
                    'plan_type': openai_auth.get('chatgpt_plan_type'),
                })
            moved.append(provider)
        for provider in moved:
            del auth[provider]
        if moved:
            save(auth_path, auth)
            print(f'Removed from Pi auth.json: {", ".join(moved)}')
        return auth
    finally:
        os.rmdir(lock)


def write_keychain(store):
    attrs = subprocess.run(['security', 'find-generic-password', '-s', KEYCHAIN],
                           capture_output=True, text=True, check=True).stdout
    account = re.search(r'"acct"<blob>="(.*)"', attrs).group(1)
    secret = json.dumps(store, separators=(',', ':')).encode().hex()
    command = f'add-generic-password -U -a "{account}" -s "{KEYCHAIN}" -X "{secret}"\n'
    if len(command) < 4000:  # stdin keeps the secret out of the process list
        subprocess.run(['security', '-i'], input=command, text=True, capture_output=True, check=True)
    else:
        # shortcut: security -i truncates long lines; argv shows the hex in ps briefly, like Claude Code's fallback
        subprocess.run(['security', 'add-generic-password', '-U', '-a', account, '-s', KEYCHAIN, '-X', secret],
                       capture_output=True, check=True)
    stored = subprocess.run(['security', 'find-generic-password', '-s', KEYCHAIN, '-w'],
                            capture_output=True, text=True).stdout
    if json.loads(stored or 'null') != store:
        die(f'could not remove the Claude login from Keychain "{KEYCHAIN}"; delete its claudeAiOauth entry')


def import_claude_code():
    profile = (load(os.path.join(HOME, '.claude.json'), {}) or {}).get('oauthAccount') or {}
    sources = []
    if sys.platform == 'darwin':
        found = subprocess.run(['security', 'find-generic-password', '-s', KEYCHAIN, '-w'],
                               capture_output=True, text=True)
        if found.returncode == 0:
            sources.append(('keychain', found.stdout))
    cred_file = os.path.join(CLAUDE_DIR, '.credentials.json')
    if os.path.exists(cred_file):
        with open(cred_file) as f:
            sources.append(('file', f.read()))
    for where, raw in sources:
        store = json.loads(raw)
        oauth = store.get('claudeAiOauth') or {}
        if not oauth.get('refreshToken'):
            continue
        add_to_proxy('claude', 'claude-code', {
            'access_token': oauth.get('accessToken'), 'refresh_token': oauth['refreshToken'],
            'expired': iso(oauth.get('expiresAt', 0)), 'email': profile.get('emailAddress'),
            'account_uuid': profile.get('accountUuid'), 'organization_uuid': profile.get('organizationUuid'),
            'organization_name': profile.get('organizationName'), 'claude_device_ids': [secrets.token_hex(32)],
        })
        del store['claudeAiOauth']  # keep other entries, such as MCP server logins
        if where == 'file':
            save(cred_file, store) if store else os.remove(cred_file)
        elif store:
            write_keychain(store)
        else:
            subprocess.run(['security', 'delete-generic-password', '-s', KEYCHAIN], capture_output=True, check=True)
        print(f'Removed the Claude Code login from its {where}')


pi_auth = import_pi() if HAVE_PI else {}
if HAVE_CLAUDE:
    import_claude_code()

if HAVE_PI:
    path = os.path.join(PI_DIR, 'models.json')
    config = load(path, {})
    providers = config.setdefault('providers', {})
    routes = {  # Pi provider -> settings, for account types the proxy holds
        'anthropic': ('claude', {'baseUrl': BASE}),
        'openai-codex': ('codex', {'name': 'Codex via CLIProxyAPI', 'baseUrl': BASE + '/v1',
                                   'api': 'openai-responses', 'models': codex_models}),
        'xai': ('xai', {'baseUrl': BASE + '/v1'}),  # built-in Grok models already use openai-responses
    }
    routed = [provider for provider, (kind, _) in routes.items() if kind in kinds]
    for provider in routed:
        providers.setdefault(provider, {}).update(routes[provider][1], apiKey='!' + KEY_CMD)
        if provider in pi_auth:  # auth.json credentials take precedence over models.json apiKey
            print(f'Warning: Pi auth.json still has a "{provider}" credential that overrides the proxy key; '
                  'remove it with /logout in Pi', file=sys.stderr)
    if 'anthropic' in routed:
        providers['anthropic'].setdefault('compat', {})['sendSessionAffinityHeaders'] = True  # routing.session-affinity
    if routed:
        save(path, config)
        print(f'Pi uses CLIProxyAPI for {", ".join(routed)}: {path}')

if not kinds & {'claude', 'codex', 'xai'}:
    print('No Claude, Codex or Grok accounts in CLIProxyAPI; sign in there and rerun')

if HAVE_CLAUDE and 'claude' in kinds:
    os.makedirs(CLAUDE_DIR, exist_ok=True)
    path = os.path.join(CLAUDE_DIR, 'settings.json')
    settings = load(path, {})
    before = json.dumps(settings)
    settings.setdefault('env', {})['ANTHROPIC_BASE_URL'] = BASE
    settings['apiKeyHelper'] = KEY_CMD
    if json.dumps(settings) != before:
        save(path, settings)
    print(f'Claude Code uses CLIProxyAPI: {os.path.realpath(path)}')

request = urllib.request.Request(BASE + '/v1/models', headers={'Authorization': 'Bearer ' + key})
try:
    with urllib.request.urlopen(request, timeout=10) as response:
        print(f"CLIProxyAPI answers with {len(json.load(response).get('data', []))} models")
except OSError as error:
    print(f'Warning: {BASE}/v1/models failed ({error}); check that CLIProxyAPI runs and its '
          'access.api-keys contains the client key', file=sys.stderr)
PY
