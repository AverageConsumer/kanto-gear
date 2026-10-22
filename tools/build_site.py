"""Build the public site from the latest published release and its tagged manifest."""
import argparse
import html
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import shutil
from urllib.parse import unquote, urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / 'site'
REPO = 'AverageConsumer/kanto-gear'
RELEASES = f'https://github.com/{REPO}/releases'


def release_metadata(release, manifest):
    tag = release['tag_name']
    match = re.fullmatch(r'v(\d+\.\d+\.\d+)', tag)
    if not match or release.get('draft') or release.get('prerelease'):
        raise ValueError('site requires a published stable release')
    version = match[1]
    if manifest.get('id') != 'kanto_gear' or manifest.get('version') != version:
        raise ValueError('release tag and tagged manifest disagree')
    minimum = re.search(r'>=\s*(\d+\.\d+\.\d+)', manifest['game_version'])
    if not minimum:
        raise ValueError('tagged manifest has no minimum engine version')
    filename = f'kanto_gear-{version}.zip'
    assets = [a for a in release['assets'] if a['name'] == filename and a['state'] == 'uploaded']
    if len(assets) != 1:
        raise ValueError('release must contain exactly one official mod ZIP')
    download = f'{RELEASES}/download/{tag}/{filename}'
    if assets[0]['browser_download_url'] != download:
        raise ValueError('unexpected release download location')
    return {'version': version, 'tag': tag, 'minimum_host': minimum[1], 'download_url': download}


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.references = set(), []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            if attrs['id'] in self.ids:
                raise ValueError(f'duplicate HTML ID: {attrs["id"]}')
            self.ids.add(attrs['id'])
        self.references.extend(attrs[key] for key in ('src', 'href') if key in attrs)


def check_site(directory=SITE):
    page = Page()
    page.feed((directory / 'index.html').read_text(encoding='utf-8'))
    references = list(page.references)
    references.extend(re.findall(r'url\(["\']?([^\)"\']+)',
                                 (directory / 'site.css').read_text(encoding='utf-8')))
    for ref in references:
        parsed = urlsplit(ref)
        if parsed.scheme or parsed.netloc:
            continue
        if parsed.path:
            target = (directory / unquote(parsed.path)).resolve()
            if not target.is_relative_to(directory.resolve()) or not target.is_file():
                raise ValueError(f'missing or unsafe local asset: {ref}')
        elif parsed.fragment and parsed.fragment not in page.ids:
            raise ValueError(f'missing page anchor: {ref}')
    for look in ('pokegear', 'cgear'):
        for mode in ('light', 'dark'):
            if not (directory / f'img/4.0-home-{look}-{mode}.png').is_file():
                raise ValueError('missing theme screenshot')


def render_page(source, metadata):
    source, versions = re.subn(r'(<span class="lcd" id="ver">)Version [^<]+(</span>)',
                              lambda m: m[1] + 'Version ' + metadata['version'] + m[2], source)
    source, requirements = re.subn(r'(<span class="req">)[^<]+(</span>)',
                                  lambda m: m[1] + metadata['minimum_host'] + m[2], source)
    source, downloads = re.subn(r'<a\b[^>]*\bdata-release-download\b[^>]*>',
        lambda m: re.sub(r'href="[^"]*"', 'href="' + html.escape(metadata['download_url'], quote=True) + '"',
                         m[0], count=1), source)
    if versions != 1 or requirements < 2 or downloads != 2:
        raise ValueError('release fields are missing from the site template')
    return source


def fetch_json(url, token=None):
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'kanto-gear-site-build'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    with urlopen(Request(url, headers=headers), timeout=30) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='new output directory')
    args = parser.parse_args()
    check_site()
    output = args.output.resolve()
    if output == ROOT or output.is_relative_to(SITE) or output in SITE.parents:
        parser.error('output must not overwrite the source tree')
    release = fetch_json(f'https://api.github.com/repos/{REPO}/releases/latest', os.getenv('GH_TOKEN'))
    tag = release['tag_name']
    if not re.fullmatch(r'v\d+\.\d+\.\d+', tag):
        parser.error('latest release has no stable version tag')
    manifest = fetch_json(f'https://raw.githubusercontent.com/{REPO}/{tag}/mod/kanto_gear/manifest.json')
    metadata = release_metadata(release, manifest)
    rendered = render_page((SITE / 'index.html').read_text(encoding='utf-8'), metadata)
    shutil.copytree(SITE, output)
    (output / 'index.html').write_text(rendered, encoding='utf-8')
    (output / 'release.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    check_site(output)
    print(f'Site built from {metadata["tag"]}; requires Recomp {metadata["minimum_host"]}; {output}')


if __name__ == '__main__':
    main()
