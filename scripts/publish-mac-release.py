#!/usr/bin/env python3
"""Network steps of scripts/publish-mac.sh: GitHub releases, the website and
the update feed. Everything here is verified anonymously after it is written.

Credentials are read at run time and kept in memory only:
- GitHub: the token Git already uses for this repository (`git credential fill`).
- Netlify: a personal access token stored once in the login Keychain under the
  service name `clockin-netlify` (see docs/macos-releases.md).
Neither is ever printed; API errors report only the status and GitHub's message.
"""
import hashlib, io, json, os, pathlib, re, shutil, subprocess, sys, tempfile, time, urllib.error, urllib.parse, urllib.request, zipfile

REPO = 'ismailakdag/clockin'
API = 'https://api.github.com/repos/' + REPO
FEED_TAG = 'macos-updates'
FEED_URL = f'https://github.com/{REPO}/releases/download/{FEED_TAG}/appcast.xml'
NETLIFY_SITE = os.environ.get('NETLIFY_SITE', 'getclockin.netlify.app')
NETLIFY_KEYCHAIN_SERVICE = 'clockin-netlify'
ROOT = pathlib.Path(__file__).resolve().parent.parent
WEBSITE = ROOT / 'website' / 'dist'
DMG_NAME = re.compile(r'Clockin-\d+\.\d+\.\d+-\d+\.dmg')


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

    if WEBSITE.joinpath('index.html').exists():
        links = sorted(set(DMG_NAME.findall(WEBSITE.joinpath('index.html').read_text())))
        print(f'Website download link: {", ".join(links) or "none found"}')
        if not links:
            fail('website/dist/index.html has no DMG download link to replace.')
    else:
        fail('website/dist is missing; the website cannot be updated.')

    if check_credentials:
        step('Checking access (tokens are not printed)')
        token = github_token()
        if not token:
            fail('Git has no stored GitHub credential for this repository.')
        _, repo = api_json('GET', API, token)
        if not repo.get('permissions', {}).get('push'):
            fail('The stored GitHub credential cannot publish releases to ' + REPO)
        print('GitHub: can publish releases')
        token = netlify_token()
        if not token:
            fail(f'No Netlify token in the Keychain (service "{NETLIFY_KEYCHAIN_SERVICE}"). '
                 'See "One-time setup" in docs/macos-releases.md.')
        _, site = api_json('GET', f'https://api.netlify.com/api/v1/sites/{NETLIFY_SITE}', token)
        print(f'Netlify: can deploy {site.get("ssl_url") or site.get("url")}')
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


def publish_website(version, build, release_dir):
    token = netlify_token()
    dmg = release_dir / f'Clockin-{version}-{build}.dmg'
    step(f'Deploying the website ({NETLIFY_SITE})')
    with tempfile.TemporaryDirectory() as temp:
        staging = pathlib.Path(temp) / 'dist'
        shutil.copytree(WEBSITE, staging, ignore=shutil.ignore_patterns('.DS_Store'))
        downloads = staging / 'downloads'
        for old in downloads.glob('Clockin-*.dmg'):
            old.unlink()
        shutil.copy2(dmg, downloads / dmg.name)
        changed = 0
        for path in (staging / 'index.html', staging / '_headers'):
            text = path.read_text()
            updated = DMG_NAME.sub(dmg.name, text)
            changed += text != updated
            path.write_text(updated)
        if changed != 2:
            fail('Could not update the download links in index.html and _headers.')

        deploy_directory(staging, token)

        site = f'https://{NETLIFY_SITE}'
        print('Checking the live website')
        page, _ = anonymous_bytes(site + '/')
        if dmg.name.encode() not in page:
            fail('The live website does not link to the new DMG yet.')
        public, headers = anonymous_bytes(f'{site}/downloads/{dmg.name}')
        if sha256(public) != sha256(dmg.read_bytes()):
            fail('The website DMG does not match the built one.')
        if 'attachment' not in (headers.get('Content-Disposition') or ''):
            fail('The website serves the DMG without an attachment header.')

        # Keep the local site in step with what is live.
        shutil.rmtree(WEBSITE)
        shutil.copytree(staging, WEBSITE)
    print(f'Live: {site}/downloads/{dmg.name}')


def deploy_directory(directory, token):
    """Uploads a folder to Netlify as a production deploy and waits until it is live."""
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zipped:
        for file in sorted(directory.rglob('*')):
            if file.is_file() and file.name != '.DS_Store':
                zipped.write(file, file.relative_to(directory).as_posix())
    _, deploy = api_json('POST', f'https://api.netlify.com/api/v1/sites/{NETLIFY_SITE}/deploys', token,
                         data=archive.getvalue(), content_type='application/zip')
    deadline = time.time() + 600
    while deploy.get('state') != 'ready':
        if deploy.get('state') == 'error' or time.time() > deadline:
            fail(f'Netlify deploy did not finish: {deploy.get("error_message") or deploy.get("state")}')
        time.sleep(4)
        _, deploy = api_json('GET', f'https://api.netlify.com/api/v1/deploys/{deploy["id"]}', token)


def publish_site_only():
    """Deploys website/dist as it is, for page changes between app releases.
    The DMG it links to must already be in website/dist/downloads."""
    token = netlify_token()
    if not token:
        fail(f'No Netlify token in the Keychain (service "{NETLIFY_KEYCHAIN_SERVICE}").')
    index = (WEBSITE / 'index.html').read_text()
    links = set(DMG_NAME.findall(index))
    if len(links) != 1 or not (WEBSITE / 'downloads' / next(iter(links))).exists():
        fail('index.html must link to exactly one DMG that exists in website/dist/downloads.')
    step(f'Deploying website/dist to {NETLIFY_SITE}')
    deploy_directory(WEBSITE, token)
    print('Checking every file on the live website')
    site = f'https://{NETLIFY_SITE}'
    for file in sorted(WEBSITE.rglob('*')):
        if not file.is_file() or file.name in ('.DS_Store', '_headers'):
            continue
        path = file.relative_to(WEBSITE).as_posix()
        live, _ = anonymous_bytes(f'{site}/{urllib.parse.quote(path)}')
        if sha256(live) != sha256(file.read_bytes()):
            fail(f'The live {path} does not match the local file.')
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
    elif command == 'site':
        publish_site_only()
    elif command == 'publish':
        version, build, release_dir, notes, commit, info_plist = args
        release_dir = pathlib.Path(release_dir)
        build = int(build)
        # Order matters: the DMG and website are public before the feed tells
        # existing installs to update.
        publish_github(version, build, release_dir, notes, commit)
        publish_website(version, build, release_dir)
        publish_feed(version, build, release_dir, info_plist)
    else:
        fail('Usage: publish-mac-release.py preflight VERSION with-credentials|no-credentials | site | publish ...')


if __name__ == '__main__':
    main()
