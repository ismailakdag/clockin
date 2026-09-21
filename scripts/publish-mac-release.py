#!/usr/bin/env python3
"""Network steps of scripts/publish-mac.sh: the GitHub release, the website's
download and the update feed. Everything here is verified anonymously after it
is written.

The website links to a fixed GitHub URL (DOWNLOAD_URL), so a release replaces
that file on GitHub and never deploys to Netlify. Netlify bills every deploy
and every byte it serves; `website` deploys the site only when its content
changes.

Credentials are read at run time and kept in memory only:
- GitHub: the token Git already uses for this repository (`git credential fill`).
- Netlify (only for `website`): a personal access token stored once in the
  login Keychain under the service name `clockin-netlify`
  (see docs/macos-releases.md).
Neither is ever printed; API errors report only the status and the service's
message.
"""
import hashlib, io, json, os, pathlib, re, shutil, subprocess, sys, tempfile, time, urllib.error, urllib.parse, urllib.request, zipfile

REPO = 'ismailakdag/clockin'
API = 'https://api.github.com/repos/' + REPO
FEED_TAG = 'macos-updates'
FEED_URL = f'https://github.com/{REPO}/releases/download/{FEED_TAG}/appcast.xml'
# The Mac download lives next to the feed, in a release that is never
# "latest", because the repository also ships iPhone builds.
DOWNLOAD_NAME = 'Clockin.dmg'
DOWNLOAD_URL = f'https://github.com/{REPO}/releases/download/{FEED_TAG}/{DOWNLOAD_NAME}'
NETLIFY_SITE = os.environ.get('NETLIFY_SITE', 'getclockin.netlify.app')
NETLIFY_KEYCHAIN_SERVICE = 'clockin-netlify'
ROOT = pathlib.Path(__file__).resolve().parent.parent
WEBSITE = ROOT / 'website' / 'dist'


def step(message):
    print(f'\n==> {message}', flush=True)


def fail(message):
    print(f'\nSTOPPED: {message}', file=sys.stderr, flush=True)
    raise SystemExit(1)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


# --- HTTP -------------------------------------------------------------------

def http(method, url, token=None, json_body=None, data=None, content_type=None, allow=()):
    host = urllib.parse.urlparse(url).hostname
    headers = {'User-Agent': 'clockin-release'}
    if token:
        # A token only ever goes to the service it belongs to.
        assert host in ('api.github.com', 'uploads.github.com', 'api.netlify.com'), host
        headers['Authorization'] = 'Bearer ' + token
    if host.endswith('github.com'):
        headers['Accept'] = 'application/vnd.github+json'
        headers['X-GitHub-Api-Version'] = '2022-11-28'
    if json_body is not None:
        data = json.dumps(json_body).encode()
        content_type = 'application/json'
    if content_type:
        headers['Content-Type'] = content_type
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            body = response.read()
            return response.status, body, response.headers
    except urllib.error.HTTPError as error:
        if error.code in allow:
            return error.code, b'', error.headers
        try:
            detail = json.loads(error.read()).get('message', '')
        except Exception:
            detail = ''
        fail(f'{method} {urllib.parse.urlparse(url).path} returned HTTP {error.code} {detail}'.strip())


def api_json(method, url, token=None, **kwargs):
    status, body, _ = http(method, url, token, **kwargs)
    return status, (json.loads(body) if body else None)


def anonymous_bytes(url):
    status, body, headers = http('GET', url + ('&' if '?' in url else '?') + f'nocache={time.time_ns()}')
    return body, headers


# --- Credentials ------------------------------------------------------------

def github_token():
    result = subprocess.run(
        ['git', '-c', 'credential.interactive=false', 'credential', 'fill'],
        input=f'protocol=https\nhost=github.com\npath={REPO}.git\n\n',
        text=True, capture_output=True, env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'})
    values = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    return values.get('password')


def netlify_token():
    result = subprocess.run(['security', 'find-generic-password', '-s', NETLIFY_KEYCHAIN_SERVICE, '-w'],
                            text=True, capture_output=True)
    return result.stdout.strip() or None


# --- Feed -------------------------------------------------------------------

def live_feed_build():
    body, _ = anonymous_bytes(FEED_URL)
    builds = [int(b) for b in re.findall(rb'<sparkle:version>(\d+)</sparkle:version>', body)]
    if not builds:
        fail('The live update feed has no build number.')
    return max(builds)


# --- Commands ---------------------------------------------------------------

def preflight(version, check_credentials):
    """Prints `BUILD=<n>` for the shell script, after checking every service."""
    step('Checking the live release state')
    build = live_feed_build()
    print(f'Live update feed: build {build}')
    tag = f'macos-v{version}'
    status, _ = api_json('GET', f'{API}/releases/tags/{tag}', allow=(404,))
    if status != 404:
        fail(f'Release {tag} already exists. Choose a new version.')
    print(f'Release {tag}: not published yet')

    if check_credentials:
        step('Checking access (tokens are not printed)')
        token = github_token()
        if not token:
            fail('Git has no stored GitHub credential for this repository.')
        _, repo = api_json('GET', API, token)
        if not repo.get('permissions', {}).get('push'):
            fail('The stored GitHub credential cannot publish releases to ' + REPO)
        print('GitHub: can publish releases')
    print(f'BUILD={build + 1}')


def publish_github(version, build, release_dir, notes_file, commit):
    token = github_token()
    dmg = release_dir / f'Clockin-{version}-{build}.dmg'
    sums = release_dir / 'SHA256SUMS'
    tag = f'macos-v{version}'

    step(f'Creating GitHub release {tag}')
    notes = pathlib.Path(notes_file).read_text().strip()
    body = (f'{notes}\n\nOpen the DMG and drag Clockin into Applications. Requires macOS 14 or later; '
            'Apple Silicon and Intel. Installed copies update themselves from Settings or the menu bar.\n\n'
            'The app and the DMG are Developer ID signed and notarized by Apple.')
    _, release = api_json('POST', f'{API}/releases', token, json_body={
        'tag_name': tag, 'target_commitish': commit, 'name': f'Clockin for Mac {version}',
        'body': body, 'draft': True, 'prerelease': False, 'make_latest': 'false'})
    upload = release['upload_url'].split('{')[0]
    for path in (dmg, sums):
        print(f'Uploading {path.name}')
        api_json('POST', f'{upload}?name={urllib.parse.quote(path.name)}', token,
                 data=path.read_bytes(), content_type='application/octet-stream')
    api_json('PATCH', f'{API}/releases/{release["id"]}', token,
             json_body={'draft': False, 'make_latest': 'false'})

    url = f'https://github.com/{REPO}/releases/download/{tag}/{dmg.name}'
    print('Checking the public download')
    public, _ = anonymous_bytes(url)
    if sha256(public) != sha256(dmg.read_bytes()):
        fail(f'The downloaded DMG does not match the built one: {url}')
    print(f'Published: https://github.com/{REPO}/releases/tag/{tag}')


def replace_asset(token, release, name, data, content_type):
    """Replaces a release asset with as short a gap as GitHub allows: the new
    file is uploaded under a temporary name, then swapped in."""
    upload = release['upload_url'].split('{')[0]
    temporary = f'uploading-{time.time_ns()}-{name}'
    _, asset = api_json('POST', f'{upload}?name={urllib.parse.quote(temporary)}', token,
                        data=data, content_type=content_type)
    for old in release['assets']:
        if old['name'] == name:
            api_json('DELETE', f'{API}/releases/assets/{old["id"]}', token)
    api_json('PATCH', f'{API}/releases/assets/{asset["id"]}', token, json_body={'name': name})


def publish_download(version, build, release_dir):
    token = github_token()
    dmg = (release_dir / f'Clockin-{version}-{build}.dmg').read_bytes()
    step(f'Publishing the website download ({DOWNLOAD_URL})')
    _, release = api_json('GET', f'{API}/releases/tags/{FEED_TAG}', token)
    replace_asset(token, release, DOWNLOAD_NAME, dmg, 'application/octet-stream')
    for _ in range(10):
        public, _ = anonymous_bytes(DOWNLOAD_URL)
        if sha256(public) == sha256(dmg):
            break
        time.sleep(3)
    else:
        fail(f'The download at {DOWNLOAD_URL} does not match the built DMG.')
    print(f'Live: {DOWNLOAD_URL}')


def deploy_website():
    """Deploys website/dist to Netlify as it is. Run it only for site changes."""
    token = netlify_token()
    if not token:
        fail(f'No Netlify token in the Keychain (service "{NETLIFY_KEYCHAIN_SERVICE}"). '
             'See "One-time setup" in docs/macos-releases.md.')
    _, functions = api_json('GET', f'https://api.netlify.com/api/v1/sites/{NETLIFY_SITE}/functions', token)
    if functions:
        fail('This site has serverless functions. A static ZIP upload would remove them. '
             'Deploy website/dist and services/live-activity/functions together with Netlify CLI; '
             'see services/live-activity/README.md.')
    index = WEBSITE / 'index.html'
    if DOWNLOAD_URL not in index.read_text():
        fail(f'website/dist/index.html does not link to {DOWNLOAD_URL}.')
    stray = sorted(p.name for p in WEBSITE.rglob('*.dmg'))
    if stray:
        fail(f'website/dist still contains {", ".join(stray)}; the DMG is served from GitHub.')
    step(f'Deploying the website ({NETLIFY_SITE})')
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zipped:
        for file in sorted(WEBSITE.rglob('*')):
            if file.is_file() and file.name != '.DS_Store':
                zipped.write(file, file.relative_to(WEBSITE).as_posix())
    _, deploy = api_json('POST', f'https://api.netlify.com/api/v1/sites/{NETLIFY_SITE}/deploys', token,
                         data=archive.getvalue(), content_type='application/zip')
    deadline = time.time() + 600
    while deploy.get('state') != 'ready':
        if deploy.get('state') == 'error' or time.time() > deadline:
            fail(f'Netlify deploy did not finish: {deploy.get("error_message") or deploy.get("state")}')
        time.sleep(4)
        _, deploy = api_json('GET', f'https://api.netlify.com/api/v1/deploys/{deploy["id"]}', token)
    site = f'https://{NETLIFY_SITE}'
    page, _ = anonymous_bytes(site + '/')
    if DOWNLOAD_URL.encode() not in page:
        fail('The live website does not link to the GitHub download.')
    print(f'Live: {site}')


def publish_feed(version, build, release_dir, info_plist):
    token = github_token()
    feed = (release_dir / 'appcast.xml').read_bytes()
    step('Publishing the update feed (existing installs see the update after this)')
    _, release = api_json('GET', f'{API}/releases/tags/{FEED_TAG}', token)
    upload = release['upload_url'].split('{')[0]
    previous = next((a for a in release['assets'] if a['name'] == 'appcast.xml'), None)
    backup = None
    if previous:
        backup, _ = anonymous_bytes(FEED_URL)
        # GitHub does not replace an asset in place; the old one goes first.
        api_json('DELETE', f'{API}/releases/assets/{previous["id"]}', token)
    status, body, _ = http('POST', f'{upload}?name=appcast.xml', token, data=feed,
                           content_type='application/xml', allow=(400, 422, 500, 502, 503))
    if status >= 400:
        if backup:
            http('POST', f'{upload}?name=appcast.xml', token, data=backup, content_type='application/xml')
        fail(f'Uploading the new feed failed (HTTP {status}); the previous feed was restored.')

    print('Checking the live feed')
    for _ in range(10):
        live, _ = anonymous_bytes(FEED_URL)
        if live == feed:
            break
        time.sleep(3)
    else:
        fail('The live feed does not match the new one yet. Check it before announcing the release.')
    # verify-release.swift checks the archive signature too and looks for the
    # DMG next to the feed, so the downloaded feed needs the DMG beside it.
    with tempfile.TemporaryDirectory() as temp:
        pathlib.Path(temp, 'appcast.xml').write_bytes(live)
        dmg = release_dir / f'Clockin-{version}-{build}.dmg'
        shutil.copy2(dmg, pathlib.Path(temp, dmg.name))
        subprocess.run(['swift', str(ROOT / 'scripts/verify-release.swift'),
                        str(pathlib.Path(temp, 'appcast.xml')), info_plist], check=True)
    print(f'Live feed offers {version} ({build}): {FEED_URL}')


def main():
    command, *args = sys.argv[1:] or ['']
    if command == 'preflight':
        preflight(args[0], check_credentials=args[1] == 'with-credentials')
    elif command == 'publish':
        version, build, release_dir, notes, commit, info_plist = args
        release_dir = pathlib.Path(release_dir)
        build = int(build)
        # Order matters: the DMG and the website download are public before
        # the feed tells existing installs to update.
        publish_github(version, build, release_dir, notes, commit)
        publish_download(version, build, release_dir)
        publish_feed(version, build, release_dir, info_plist)
    elif command == 'download':
        # Points the website download at an already published release.
        version, build, release_dir = args
        publish_download(version, int(build), pathlib.Path(release_dir))
    elif command == 'website':
        deploy_website()
    else:
        fail('Usage: publish-mac-release.py preflight VERSION with-credentials|no-credentials | publish ... | download VERSION BUILD DIR | website')


if __name__ == '__main__':
    main()
