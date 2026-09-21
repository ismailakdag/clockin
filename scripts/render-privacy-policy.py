#!/usr/bin/env python3
"""Render the reviewed v2 policy; never publish missing owner details."""
import argparse
import html
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def render(owner, draft):
    name = owner.get('controller_name', '').strip()
    email = owner.get('contact_email', '').strip()
    if not name or not re.fullmatch(r'[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+', email):
        raise ValueError('Complete controller_name and contact_email in docs/privacy/owner.json first')
    text = draft.split('\n---\nPublisher checklist', 1)[0]
    text = '\n'.join(line for line in text.splitlines() if not line.startswith('DRAFT —'))
    text = text.replace('{{CONTROLLER_NAME}}', name).replace('{{CONTACT_EMAIL}}', email)
    # Markdown permits a paragraph immediately after a heading. Separate it
    # before rendering blocks so heading markers never leak into visible text.
    text = re.sub(r'(?m)^(#{1,3} .+)\n(?=\S)', r'\1\n\n', text)
    if '{{' in text or 'Publisher checklist' in text:
        raise ValueError('Unresolved policy draft content')
    blocks = []
    for paragraph in text.strip().split('\n\n'):
        paragraph = paragraph.strip()
        heading = re.fullmatch(r'(#{1,3}) (.+)', paragraph)
        if heading:
            level, content = len(heading[1]), html.escape(heading[2])
            language = ' lang="tr" id="turkce"' if heading[2] == 'Türkçe' else ''
            if heading[2] == 'English':
                language = ' id="english"'
            blocks.append(f'<h{level}{language}>{content}</h{level}>')
        else:
            blocks.append('<p>' + html.escape(paragraph).replace('\n', ' ') + '</p>')
    body = '\n'.join(blocks)
    return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="clockin-privacy-protocol" content="2">
<meta name="referrer" content="no-referrer">
<title>Clockin for iPhone — Privacy Policy</title>
<style>body{margin:0;background:#faf9f6;color:#222;font:17px/1.65 system-ui,sans-serif}
main{max-width:760px;margin:auto;padding:48px 24px 80px}h1{font-size:2rem;line-height:1.2}
h2{margin-top:3rem;border-top:1px solid #ddd;padding-top:2rem}h3{margin-top:2rem;font-size:1.2rem}
nav{display:flex;gap:24px}a{color:#18533f}p{overflow-wrap:anywhere}
@media(prefers-color-scheme:dark){body{background:#171916;color:#eee}a{color:#a8dabd}}
</style></head><body><main><nav aria-label="Language"><a href="#english">English</a>
<a href="#turkce" lang="tr">Türkçe</a></nav>''' + body + '\n</main></body></html>\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', type=Path, default=ROOT / 'docs/privacy/owner.json')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        page = render(json.loads(args.owner.read_text()),
                      (ROOT / 'docs/privacy/privacy-policy-draft.md').read_text())
    except ValueError as error:
        parser.error(str(error))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(page)
    print(f'Policy rendered: {args.output}')


if __name__ == '__main__':
    main()
