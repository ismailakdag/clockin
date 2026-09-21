#!/usr/bin/env python3
"""Deploy the relay while preserving the exact published website file hashes.

Build functions first with services/live-activity/node_modules/.bin/netlify
functions:build --src functions --functions /tmp/clockin-live-functions.
Default creates a preview. --promote redeploys its verified bundles in production
context; restoring a preview would retain preview environment variables.
Credentials are read from the existing Clockin Netlify Keychain item, never printed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

SITE = '406e1766-2c8b-4b61-99a1-f4736b8c512a'
STATE = Path('/tmp/clockin-live-activity-deploy.json')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--promote', action='store_true')
    parser.add_argument('--bundle', default='/tmp/clockin-live-functions')
    parser.add_argument('--admin', action='store_true', help='Include the protected monitoring panel')
    parser.add_argument('--privacy-page', type=Path,
                        help='Add the rendered v2 policy at /privacy/; preserve every other site file')
    args = parser.parse_args()
    page = args.privacy_page.read_bytes() if args.privacy_page else None
    if args.promote and page is None:
        parser.error('Protocol 2 publication requires --privacy-page with completed owner details')
    if page is not None:
        assert b'<meta name="clockin-privacy-protocol" content="2">' in page, 'Render the v2 policy first'
        assert b'{{' not in page and b'DRAFT' not in page and b'Publisher checklist' not in page, 'Policy is incomplete'
    credential = subprocess.run(['security', 'find-generic-password', '-s', 'clockin-netlify', '-w'],
                                capture_output=True, text=True, check=True).stdout.strip()

    def api(method, path, body=None, binary=False):
        data = body if binary else json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request('https://api.netlify.com/api/v1' + path, data=data, method=method,
            headers={'Authorization': 'Bearer ' + credential,
                     'Content-Type': 'application/octet-stream' if binary else 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=45) as result:
                content = result.read()
                return json.loads(content) if content else None
        except urllib.error.HTTPError as error:
            # Do not print request/environment contents on failure.
            raise RuntimeError(f'Netlify {method} returned HTTP {error.code}') from None

    site = api('GET', '/sites/' + SITE)
    assert site['name'] == 'getclockin', 'Unexpected destination'
    base = site['published_deploy']['id']
    if args.promote:
        saved = json.loads(STATE.read_text())
        assert saved['base'] == base, 'The live site changed; prepare a new preview'
        assert saved['verified'], 'Verify preview before publishing'

    old_functions = api('GET', f'/sites/{SITE}/functions')
    if isinstance(old_functions, dict):
        old_functions = old_functions.get('functions', [])
    expected_functions = {'live-activity', 'live-activity-tick'} | ({'admin'} if args.admin else set())
    assert all(f.get('name', f.get('n')) in expected_functions
               for f in old_functions), 'Unrelated functions exist'
    files = api('GET', f'/deploys/{base}/files')
    file_hashes = {f['path']: f['sha'] for f in files}
    page_path = ('/' if any(path.startswith('/') for path in file_hashes) else '') + 'privacy/index.html'
    page_sha = hashlib.sha1(page).hexdigest() if page is not None else None
    if page is not None:
        file_hashes[page_path] = page_sha
    manifest = json.loads((Path(args.bundle) / 'manifest.json').read_text())
    funcs = manifest['functions']
    assert {f['name'] for f in funcs} == expected_functions
    config, hashes, schedules = {}, {}, []
    for f in funcs:
        hashes[f['name']] = hashlib.sha256(Path(f['path']).read_bytes()).hexdigest()
        config[f['name']] = {k: f[v] for k, v in {
            'routes': 'routes', 'build_data': 'buildData', 'priority': 'priority',
        }.items() if v in f}
        if f.get('schedule'):
            schedules.append({'name': f['name'], 'cron': f['schedule']})
        if f.get('trafficRules'):
            action = f['trafficRules']['action']
            rate = action['config']['rateLimitConfig']
            config[f['name']]['traffic_rules'] = {'action': {'type': action['type'], 'config': {
                'rate_limit_config': {'algorithm': rate['algorithm'], 'window_size': rate['windowSize'],
                                      'window_limit': rate['windowLimit']},
                'aggregate': action['config']['aggregate'],
            }}}
    assert schedules == [{'name': 'live-activity-tick', 'cron': '* * * * *'}]
    if args.promote:
        assert hashes == saved['function_hashes'], 'Function bundles changed; prepare a new preview'
        assert page_sha == saved.get('privacy_sha'), 'Privacy page changed; prepare a new preview'
    deployed = api('POST', f'/sites/{SITE}/deploys', {
        'files': file_hashes, 'functions': hashes,
        'functions_config': config, 'function_schedules': schedules,
        'draft': not args.promote, 'async': False,
    })
    required = set(deployed.get('required', []))
    assert required <= ({page_sha} if page is not None else set()), 'Existing website assets unexpectedly need upload'
    if page_sha in required:
        path = urllib.parse.quote(page_path.lstrip('/'), safe='/')
        api('PUT', f'/deploys/{deployed["id"]}/files/{path}', page, True)
    for f in funcs:
        if hashes[f['name']] not in deployed.get('required_functions', []):
            continue
        query = urllib.parse.urlencode({'runtime': f['runtimeVersion'], 'invocation_mode': f['invocationMode']})
        api('PUT', f'/deploys/{deployed["id"]}/functions/{f["name"]}?{query}', Path(f['path']).read_bytes(), True)
    deadline = time.monotonic() + 180
    while deployed['state'] != 'ready':
        if deployed['state'] == 'error' or time.monotonic() > deadline:
            raise RuntimeError('Deployment did not become ready')
        time.sleep(3)
        deployed = api('GET', '/deploys/' + deployed['id'])
    copied = api('GET', f'/deploys/{deployed["id"]}/files')
    assert file_hashes == {f['path']: f['sha'] for f in copied}, 'Website hashes changed unexpectedly'
    if args.promote:
        live = api('GET', '/sites/' + SITE)
        assert live['published_deploy']['id'] == deployed['id'], 'Publish not confirmed'
        assert deployed['context'] == 'production', 'Incorrect deployment environment'
    url = live['ssl_url'] if args.promote else deployed['deploy_ssl_url']
    with urllib.request.urlopen(url + '/api/v1/live-activity', timeout=20) as response:
        health = json.load(response)
    assert health['service'] == 'clockin-live-activity' and health['intervalSeconds'] == 60 and health['protocol'] == 2
    if page is not None:
        with urllib.request.urlopen(url + '/privacy/', timeout=20) as response:
            assert response.read() == page, 'Published privacy page differs from the verified file'
    if args.promote:
        assert health['pushConfigured'], 'Production APNs environment not loaded'
    else:
        STATE.write_text(json.dumps({'id': deployed['id'], 'base': base, 'url': url,
                                     'verified': True, 'function_hashes': hashes, 'privacy_sha': page_sha}))
    print(json.dumps({'published' if args.promote else 'preview': url, 'id': deployed['id'],
                      'preserved_files': len(files), 'health': health}))


if __name__ == '__main__':
    main()
