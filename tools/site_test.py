"""Guard the site's release metadata and local links without network access."""
import copy
import unittest

import build_site


class SiteChecks(unittest.TestCase):
    def setUp(self):
        self.release = {'tag_name': 'v4.4.0', 'draft': False, 'prerelease': False,
            'assets': [{'name': 'kanto_gear-4.4.0.zip', 'state': 'uploaded',
                'browser_download_url': build_site.RELEASES + '/download/v4.4.0/kanto_gear-4.4.0.zip'}]}
        self.manifest = {'id': 'kanto_gear', 'version': '4.4.0',
                         'game_version': '0.0.0-dev || >=0.3.93 <2.0.0'}

    def test_tagged_release_drives_all_visible_fields(self):
        metadata = build_site.release_metadata(self.release, self.manifest)
        metadata.update(version='9.8.7', minimum_host='1.2.3')
        page = build_site.render_page((build_site.SITE / 'index.html').read_text(encoding='utf-8'), metadata)
        self.assertIn('Version 9.8.7', page)
        self.assertEqual(page.count('<span class="req">1.2.3</span>'), 2)
        self.assertEqual(page.count('href="' + metadata['download_url'] + '"'), 2)
        self.assertNotIn('Version 4.4.0', page)

    def test_mismatched_manifest_is_rejected(self):
        self.manifest['version'] = '4.5.0'
        with self.assertRaises(ValueError):
            build_site.release_metadata(self.release, self.manifest)

    def test_unpublished_or_prerelease_is_rejected(self):
        for key in ('draft', 'prerelease'):
            release = copy.deepcopy(self.release)
            release[key] = True
            with self.assertRaises(ValueError):
                build_site.release_metadata(release, self.manifest)

    def test_missing_or_ambiguous_zip_is_rejected(self):
        for assets in ([], self.release['assets'] * 2):
            release = dict(self.release, assets=assets)
            with self.assertRaises(ValueError):
                build_site.release_metadata(release, self.manifest)

    def test_external_download_is_rejected(self):
        self.release['assets'][0]['browser_download_url'] = 'https://example.org/other.zip'
        with self.assertRaises(ValueError):
            build_site.release_metadata(self.release, self.manifest)

    def test_unsupported_engine_range_is_rejected(self):
        self.manifest['game_version'] = '*'
        with self.assertRaises(ValueError):
            build_site.release_metadata(self.release, self.manifest)

    def test_local_assets_and_anchors_exist(self):
        build_site.check_site()


if __name__ == '__main__':
    unittest.main()
