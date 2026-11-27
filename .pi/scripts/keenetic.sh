#!/usr/bin/env bash
# Keenetic IPv4 static route import/export. Requires Python 3, no extra packages.
exec python3 - "$@" <<'PY'
import argparse
import getpass
import hashlib
import http.cookiejar
import ipaddress
import json
import re
import sys
import urllib.error
import urllib.request
from urllib.parse import urlsplit

p = argparse.ArgumentParser(prog='keenetic.sh', description='Export static routes to stdout, or add routes from a .bat file. Omit --password to prompt.')
p.add_argument('command', choices=['routes:download', 'routes:upload'])
p.add_argument('--host', default='192.168.1.1', help='router host or HTTPS URL (bare host uses HTTP; default: %(default)s)')
p.add_argument('--user', default='admin', help='router username (default: %(default)s)')
p.add_argument('--password')
p.add_argument('--interface', required=True, help='interface ID or exact description, e.g. PF1')
p.add_argument('--exclusive-route', choices=('true', 'false'), help='upload only: set or clear the exclusive flag on new and matching routes')
p.add_argument('file', nargs='?')
a = p.parse_intermixed_args()
if (a.command == 'routes:upload') != bool(a.file):
    p.error('only routes:upload takes a .bat file, and it requires one')
if a.exclusive_route is not None and not a.file:
    p.error('--exclusive-route is only valid for routes:upload')
base = a.host.rstrip('/') if '://' in a.host else 'http://' + a.host
url = urlsplit(base)
if url.scheme not in ('http', 'https') or not url.hostname or url.username is not None or url.path or url.query or url.fragment:
    p.error('expected a router hostname or http(s)://host[:port]')

# Never forward a login or an admin request to a redirected host.
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None

client = urllib.request.build_opener(NoRedirect(), urllib.request.ProxyHandler({}),
                                     urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
def request(path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base + path, data=data, headers={'Content-Type': 'application/json'})
    with client.open(req, timeout=60) as response:
        return response.read()

def login():
    try:
        request('/auth')
        return
    except urllib.error.HTTPError as e:
        if e.code != 401:
            raise
        realm, challenge = e.headers.get('X-NDM-Realm'), e.headers.get('X-NDM-Challenge')
    if not realm or not challenge:
        raise ValueError('router did not return a Keenetic authentication challenge')
    pw = a.password if a.password is not None else getpass.getpass('Router password: ')
    key = hashlib.md5(f'{a.user}:{realm}:{pw}'.encode()).hexdigest()
    digest = hashlib.sha256((challenge + key).encode()).hexdigest()
    request('/auth', {'login': a.user, 'password': digest})

def batch(commands):
    replies = json.loads(request('/rci/', commands))
    if not isinstance(replies, list) or len(replies) != len(commands):
        raise ValueError('unexpected RCI batch response')
    for cmd, reply in zip(commands, replies):
        while isinstance(cmd, dict) and len(cmd) == 1 and 'status' not in reply:
            k, cmd = next(iter(cmd.items()))
            reply = reply[k]
        statuses = reply['status']
        if not isinstance(statuses, list) or not statuses:
            raise ValueError('missing RCI command status')
        for s in statuses:
            if s.get('status') != 'message':
                raise ValueError(s.get('message') or str(s))

pattern = re.compile(r'route\s+add\s+([\d.]+)\s+mask\s+([\d.]+)\s+([\d.]+)(?:\s+::\s*rem(?:\s+(.*))?)?', re.I)
def parse_file():
    routes = {}
    with open(a.file, encoding='utf-8-sig') as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line or re.match(r'^(?:rem\b|::|@echo\s+off$)', line, re.I):
                continue
            m = pattern.fullmatch(line)
            if not m:
                raise ValueError(f'{a.file}:{i}: expected route add ADDRESS mask MASK GATEWAY [:: rem COMMENT]')
            addr, mask, gw, comment = m.groups()
            try:
                net = ipaddress.IPv4Network((addr, mask)); gateway = str(ipaddress.IPv4Address(gw))
                if mask != str(net.netmask):
                    raise ValueError('expected dotted netmask')
            except ValueError as e:
                raise ValueError(f'{a.file}:{i}: {e}') from e
            value = (gateway, comment or '')
            if net in routes and routes[net] != value:
                raise ValueError(f'{a.file}:{i}: conflicting entries for {net}')
            routes[net] = value
    return routes

def main():
    wanted = parse_file() if a.file else {}
    login()
    interfaces = json.loads(request('/rci/show/interface'))
    matches = {i['id'] for i in interfaces.values() if a.interface in (i['id'], i.get('description'))}
    if len(matches) != 1:
        raise ValueError(f'unknown or ambiguous interface: {a.interface}')
    iface = matches.pop()
    config = json.loads(request('/rci/show/sc/ip/route'))
    if not isinstance(config, list):
        raise ValueError('expected configured IPv4 route list')
    existing = {}
    lines = []
    for r in config:
        addr = r.get('host') or r.get('network')
        if not addr:
            continue
        net = ipaddress.IPv4Network((addr, r.get('mask', '255.255.255.255')))
        gw = r.get('gateway') or '0.0.0.0'
        existing.setdefault(net, []).append(r)
        if not a.file and r.get('interface') == iface:
            if r.get('reject') or r.get('metric') or not r.get('auto'):
                raise ValueError(f'{net}: .bat cannot preserve this route\'s flags')
            comment = ' '.join(r.get('comment', '').splitlines())
            lines.append(f'route add {net.network_address} mask {net.netmask} {gw}' + (f' :: rem {comment}' if comment else ''))
    if not a.file:
        for line in lines:
            print(line)
        return
    batches = []
    added = updated = 0
    reject = a.exclusive_route == 'true'
    for net, (gw, comment) in wanted.items():
        dest = str(net.network_address)
        route = {'host': dest} if net.prefixlen == 32 else {'network': dest, 'mask': str(net.netmask)}
        route.update(interface=iface, auto=True)
        if gw != '0.0.0.0':
            route['gateway'] = gw
        if comment:
            route['comment'] = comment
        changes = []
        if net in existing:
            matches = [r for r in existing[net] if r.get('interface') == iface and (r.get('gateway') or '0.0.0.0') == gw]
            if any(bool(r.get('reject')) == reject for r in matches):
                continue
            if a.exclusive_route is None or not matches or len(existing[net]) != 1:
                raise ValueError(f'{net} already has a different route; nothing uploaded')
            route = dict(matches[0])  # Keep the router's comment, metric and auto setting.
            route.pop('index', None)
            key = {k: route[k] for k in ('host', 'network', 'mask', 'gateway', 'interface', 'metric') if k in route}
            changes.append({'ip': {'route': dict(key, no=True)}})
            updated += 1
        else:
            added += 1
        if a.exclusive_route is not None:
            route['reject'] = reject
        changes.append({'ip': {'route': route}})
        # Do not split a delete/add pair across requests.
        if not batches or len(batches[-1]) + len(changes) > 100:
            batches.append([])
        batches[-1].extend(changes)
    if batches:
        try:
            for commands in batches:
                batch(commands)
            batch([{'system': {'configuration': {'save': {}}}}])
        except Exception:
            print('Upload incomplete: some routes may have been removed or added. Check running routes and save status.', file=sys.stderr)
            raise
    print(f'{iface}: added {added}, updated {updated}, skipped {len(wanted) - added - updated} existing.', file=sys.stderr)

try:
    main()
except (OSError, ValueError, KeyError, TypeError) as e:
    sys.exit(f'keenetic.sh: {e}')
PY
