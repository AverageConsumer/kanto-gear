"""ROM-free source checks, reproducible packaging and release verification."""
import argparse
import hashlib
from html import unescape
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'mod/kanto_gear/'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode('utf-8').strip()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def committed_source():
    raw = subprocess.check_output(['git', '-c', 'core.autocrlf=false', '-c', 'core.eol=lf',
                                   'archive', '--format=zip', 'HEAD', 'mod/kanto_gear'], cwd=ROOT)
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        ignored = set(archive.read(PREFIX + '.modkitignore').decode('utf-8').splitlines())
        files = {name[len(PREFIX):]: archive.read(name) for name in archive.namelist()
                 if name.startswith(PREFIX) and not name.endswith('/')
                 and name[len(PREFIX):] not in ignored and not name[len(PREFIX):].startswith('.')}
    require(not any(name.startswith('tests/') for name in files), 'test exclusions are stale')
    return files


def validate_tag(tag, version, commit):
    require(tag == 'v' + version, 'release tag must equal v<manifest version>')
    require(git('rev-parse', f'refs/tags/{tag}^{{commit}}') == commit, 'tag does not identify HEAD')
    subprocess.run(['git', 'merge-base', '--is-ancestor', commit, 'origin/main'], cwd=ROOT, check=True)
    notes = ROOT / 'release-notes' / (tag + '.md')
    require(notes.is_file() and notes.read_text(encoding='utf-8').strip(), 'committed release notes are required')
    require(git('ls-files', '--', notes.relative_to(ROOT).as_posix()), 'release notes must be tracked')


def verify_assets(directory, source, commit):
    manifest = json.loads(source['manifest.json'])
    version = manifest['version']
    base = f'kanto_gear-{version}'
    expected_names = {base + '.zip', base + '.verification.json', base + '.sha256'}
    require({p.name for p in directory.iterdir() if p.is_file()} == expected_names,
            'artifact directory must contain exactly the ZIP, verification report and checksum')
    package = directory / (base + '.zip')
    digest = hashlib.sha256(package.read_bytes()).hexdigest()
    report = json.loads((directory / (base + '.verification.json')).read_text(encoding='utf-8'))
    require(report['source_commit'] == commit, 'report source commit mismatch')
    require(report['id'] == manifest['id'] == 'kanto_gear' and report['version'] == version,
            'package ID or version mismatch')
    require(report['engine_range'] == manifest['game_version'], 'engine requirement mismatch')
    require(report['diagnostic'] is False and report['transformed_files'] == [],
            'diagnostic or transformed package cannot be released')
    require(report['sha256'] == digest, 'ZIP checksum mismatch')
    require((directory / (base + '.sha256')).read_text(encoding='utf-8') == f'{digest}  {base}.zip\n',
            'checksum file mismatch')
    expected_hashes = {name: hashlib.sha256(data).hexdigest() for name, data in source.items()}
    require(report['files'] == expected_hashes, 'verification inventory differs from committed source')
    with zipfile.ZipFile(package) as archive:
        require(len(archive.namelist()) == len(source) and set(archive.namelist()) == set(source),
                'ZIP file inventory mismatch')
        require(archive.testzip() is None, 'ZIP integrity check failed')
        for name, body in source.items():
            require(archive.read(name) == body, f'ZIP content differs from source: {name}')
    return digest


def heading_ids(text):
    text = re.sub(r'^```.*?^```\s*$', '', text, flags=re.M | re.S)
    counts, ids = {}, set()
    for heading in re.findall(r'^#{1,6}\s+(.+?)\s*#*$', text, re.M):
        slug = re.sub(r'[^\w\- ]', '', re.sub(r'<[^>]*>', '', heading).lower()).replace(' ', '-')
        number = counts.get(slug, 0)
        ids.add(slug + (f'-{number}' if number else ''))
        counts[slug] = number + 1
    return ids


def check_documents(root=ROOT):
    import yaml

    class UniqueLoader(yaml.BaseLoader):
        def construct_mapping(self, node, deep=False):
            keys = [self.construct_object(key, deep=deep) for key, _ in node.value]
            require(len(keys) == len(set(keys)), 'duplicate YAML mapping key')
            return super().construct_mapping(node, deep)

    for path in root.joinpath('.github').rglob('*.yml'):
        doc = yaml.load(path.read_text(encoding='utf-8'), Loader=UniqueLoader)
        require(isinstance(doc, dict), f'{path}: expected a YAML mapping')
        if path.parent.name == 'ISSUE_TEMPLATE' and path.name != 'config.yml':
            require(doc.get('name') and doc.get('description') and doc.get('body'), f'{path}: incomplete issue form')
            ids = [field['id'] for field in doc['body'] if 'id' in field]
            require(len(ids) == len(set(ids)), f'{path}: duplicate issue field ID')
    paths = [*root.glob('*.md'), *root.joinpath('.github').rglob('*.md'),
             *root.joinpath('release-notes').glob('*.md')]
    # Only tracked public documentation is checked; local working instructions stay local.
    tracked = set(git('ls-files', '-z').split('\0'))
    links = 0
    for path in paths:
        if path.relative_to(root).as_posix() not in tracked:
            continue
        text = path.read_text(encoding='utf-8')
        text = re.sub(r'^```.*?^```\s*$', '', text, flags=re.M | re.S)
        targets = re.findall(r'\]\(([^\s)]+)', text) + re.findall(r'(?:src|href)="([^"]+)"', text)
        for target in targets:
            parsed = urlsplit(unescape(target))
            if parsed.scheme or parsed.netloc:
                continue
            destination = (path.parent / unquote(parsed.path)).resolve() if parsed.path else path
            require(destination.is_relative_to(root), f'{path}: link escapes the repository: {target}')
            require(destination.exists(), f'{path}: missing link target {target}')
            if parsed.fragment and destination.suffix == '.md':
                require(unquote(parsed.fragment) in heading_ids(destination.read_text(encoding='utf-8')),
                        f'{path}: missing heading {target}')
            if destination.suffix.lower() == '.png':
                require(destination.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'), f'{path}: invalid PNG {target}')
            links += 1
    print(f'Documentation: YAML and {links} local links/anchors verified', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', default='', help='validate a release tag and its committed notes')
    parser.add_argument('--verify-only', action='store_true', help='verify downloaded artifacts without rebuilding')
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'dist', help='empty directory for this run; defaults to dist/')
    args = parser.parse_args()
    require(not git('status', '--porcelain', '--untracked-files=no'), 'commit all tracked changes before CI/package checks')
    source = committed_source()
    manifest = json.loads(source['manifest.json'])
    require(re.fullmatch(r'\d+\.\d+\.\d+', manifest['version']), 'invalid manifest version')
    commit = git('rev-parse', 'HEAD')
    if args.tag:
        validate_tag(args.tag, manifest['version'], commit)
    output = args.output_dir.resolve()
    if not args.verify_only:
        check_documents()
        subprocess.run([sys.executable, str(ROOT / 'tools/check.py')], cwd=ROOT, check=True)
        require(not output.exists() or not any(output.iterdir()), 'use an empty dist directory for CI checks')
        package = output / f"kanto_gear-{manifest['version']}.zip"
        subprocess.run([sys.executable, str(ROOT / 'tools/package.py'), '--output', str(package)], cwd=ROOT, check=True)
        digest = hashlib.sha256(package.read_bytes()).hexdigest()
        package.with_suffix('.sha256').write_text(f'{digest}  {package.name}\n', encoding='utf-8')
        second = ROOT / 'diagnostics' / 'reproducibility.zip'
        subprocess.run([sys.executable, str(ROOT / 'tools/package.py'), '--output', str(second)], cwd=ROOT, check=True)
        require(hashlib.sha256(second.read_bytes()).hexdigest() == digest, 'repeated package builds differ')
    digest = verify_assets(output, source, commit)
    print(f'Verified release assets from {commit}: SHA256 {digest}', flush=True)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as summary:
            summary.write(f'### Verified Kanto Gear {manifest["version"]}\n\nSource: `{commit}`\n\nZIP SHA-256: `{digest}`\n')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        raise SystemExit(str(error)) from error
