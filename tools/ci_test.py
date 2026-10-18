"""Regression checks for the release publication guards; no game data needed."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import ci
import package


class ReleaseChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.commit = 'a' * 40
        self.source = {
            'manifest.json': json.dumps({'id': 'kanto_gear', 'version': '1.2.3',
                                         'game_version': '>=0.3.20 <2.0.0'}).encode(),
            'main.lua': b'return {}\n',
        }
        self.package = self.directory / 'kanto_gear-1.2.3.zip'
        self.report_path = self.package.with_suffix('.verification.json')
        self.write_package(self.source)
        self.report = {'source_commit': self.commit, 'id': 'kanto_gear', 'version': '1.2.3',
                       'engine_range': '>=0.3.20 <2.0.0', 'diagnostic': False, 'transformed_files': [],
                       'files': {name: hashlib.sha256(body).hexdigest() for name, body in self.source.items()}}
        self.write_report()

    def write_package(self, files):
        with zipfile.ZipFile(self.package, 'w') as archive:
            for name, body in files.items():
                archive.writestr(name, body)

    def write_report(self):
        self.report['sha256'] = hashlib.sha256(self.package.read_bytes()).hexdigest()
        self.report_path.write_text(json.dumps(self.report), encoding='utf-8')
        self.package.with_suffix('.sha256').write_text(
            f'{self.report["sha256"]}  {self.package.name}\n', encoding='utf-8')

    def verify(self):
        return ci.verify_assets(self.directory, self.source, self.commit)

    def test_matching_artifacts_pass(self):
        self.assertEqual(self.verify(), self.report['sha256'])

    def test_package_bytes_are_independent_of_platform_zip_defaults(self):
        windows, linux = self.directory / 'windows.zip', self.directory / 'linux.zip'
        with patch('zipfile.sys.platform', 'win32'):
            package.write_package(windows, self.source)
        with patch('zipfile.sys.platform', 'linux'):
            package.write_package(linux, self.source)
        self.assertEqual(windows.read_bytes(), linux.read_bytes())

    def test_report_from_another_commit_is_rejected(self):
        self.report['source_commit'] = 'b' * 40
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'source commit'):
            self.verify()

    def test_modified_zip_is_rejected_even_with_updated_checksum(self):
        self.write_package({**self.source, 'main.lua': b'return {modified=true}\n'})
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'content differs'):
            self.verify()

    def test_unexpected_zip_file_is_rejected(self):
        self.write_package({**self.source, 'tests/private_fixture.lua': b'return {}'})
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'inventory mismatch'):
            self.verify()

    def test_diagnostic_build_is_rejected(self):
        self.report['diagnostic'] = True
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'diagnostic'):
            self.verify()

    def test_wrong_checksum_is_rejected(self):
        self.package.with_suffix('.sha256').write_text('incorrect\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'checksum file'):
            self.verify()

    def test_extra_release_asset_is_rejected(self):
        (self.directory / 'old.zip').write_bytes(b'old artifact')
        with self.assertRaisesRegex(ValueError, 'exactly'):
            self.verify()

    def test_tag_must_match_manifest_version(self):
        with self.assertRaisesRegex(ValueError, 'manifest version'):
            ci.validate_tag('v9.9.9', '1.2.3', self.commit)

    def test_tag_must_identify_checked_out_commit(self):
        with patch.object(ci, 'git', return_value='b' * 40):
            with self.assertRaisesRegex(ValueError, 'identify HEAD'):
                ci.validate_tag('v1.2.3', '1.2.3', self.commit)

    def test_release_requires_main_ancestry_and_tracked_notes(self):
        with patch.object(ci, 'ROOT', self.directory), patch.object(ci, 'git', return_value=self.commit), \
                patch.object(ci.subprocess, 'run') as command:
            with self.assertRaisesRegex(ValueError, 'release notes'):
                ci.validate_tag('v1.2.3', '1.2.3', self.commit)
            command.assert_called_once_with(
                ['git', 'merge-base', '--is-ancestor', self.commit, 'origin/main'],
                cwd=self.directory, check=True)
            (self.directory / 'release-notes').mkdir()
            (self.directory / 'release-notes/v1.2.3.md').write_text('Player-facing changes.\n', encoding='utf-8')
            ci.validate_tag('v1.2.3', '1.2.3', self.commit)


if __name__ == '__main__':
    unittest.main()
