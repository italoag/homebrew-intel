"""Verifica invariantes críticos sem Homebrew nem acesso a GitHub."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def load(name):
    path = Path(__file__).with_name(name + '.py')
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


p = load('pipeline')
client = load('install-binary')
sync = load('sync-installed')


class SafetyTests(unittest.TestCase):
    def test_scan_does_not_confuse_older_intel_with_exact_tahoe(self):
        installed = {'name': 'jq', 'tap': 'homebrew/core', 'installed': [{'version': '1.0'}]}
        current = {'name': 'jq', 'urls': {'stable': {'url': 'https://example.org/jq.tar.gz'}},
                   'bottle': {'stable': {'files': {'sequoia': {'url': 'old'}, 'arm64_tahoe': {'url': 'arm'}}}}}
        row = sync.classify(installed, current)
        self.assertTrue(row['candidate'])
        self.assertEqual(row['older_intel_bottle_tags'], ['sequoia'])
        current['bottle']['stable']['files']['all'] = {'url': 'universal'}
        self.assertFalse(sync.classify(installed, current)['candidate'])

    def test_disabled_and_foreign_formulae_not_added(self):
        current = {'name': 'jq', 'disabled': True, 'urls': {'stable': {'url': 'source'}}}
        self.assertFalse(sync.classify({'name': 'jq', 'tap': 'homebrew/core'}, current)['candidate'])
        current['disabled'] = False
        self.assertFalse(sync.classify({'name': 'jq', 'tap': 'other/tap'}, current)['candidate'])

    def test_plan_never_migrates_when_candidate_not_yet_published(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            work = root / '.work'
            work.mkdir()
            (root / 'snapshot.json').write_text(json.dumps({'tap': 'u/intel', 'order': ['jq']}))
            (work / 'intel-scan.json').write_text(json.dumps({'candidates': ['missing']}))
            with patch.object(sync, 'ROOT', root), patch.object(sync, 'WORK', work), \
                 patch.object(sync, 'platform_check'), patch.object(sync, 'brew') as commands:
                with self.assertRaisesRegex(SystemExit, 'ainda não publicou'):
                    sync.migration_plan()
                commands.assert_not_called()

    def test_migration_download_failure_keeps_existing_packages(self):
        with tempfile.TemporaryDirectory() as tmp:
            plan = [{'full_name': 'u/intel/jq', 'action': 'reinstall', 'previous_origin': 'homebrew/core'}]
            with patch.object(sync, 'WORK', Path(tmp)), \
                 patch.object(sync, 'migration_plan', return_value=({'tap': 'u/intel'}, [], plan)), \
                 patch.object(sync, 'brew', side_effect=RuntimeError('network down')) as commands:
                with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(RuntimeError, 'network down'):
                    sync.migrate(True)
                self.assertEqual(commands.call_args.args, ('fetch', '--force-bottle', 'u/intel/jq'))

    def test_local_run_blocked_before_commands(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(p, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'execução local bloqueada'):
                p.main()
            run.assert_not_called()

    def test_cycle_fails_before_build(self):
        with self.assertRaisesRegex(RuntimeError, 'Ciclo'):
            p.topo(['a'], {'a': ['b'], 'b': ['a']})

    def test_dependencies_precede_consumers(self):
        self.assertEqual(p.topo(['a', 'c'], {'a': ['b'], 'b': [], 'c': ['b']}), ['b', 'a', 'c'])

    def test_source_keeps_resources_and_redirects_deps(self):
        source = '''class Jq < Formula
  bottle do
    on_macos do
      sha256 tahoe: "old"
    end
  end
  depends_on "oniguruma"
  uses_from_macos "zlib"
  resource "data" do
    url "https://example.org/data"
    sha256 "keep"
  end
  def install
    puts Formula["oniguruma"].opt_prefix
  end
end
'''
        result = p.transform(source, 'user/intel', {'oniguruma'})
        self.assertNotIn('bottle do', result)
        # Membros do core ficam com nome curto: o keg satisfaz a dep e
        # dep.name continua compatível com o código upstream.
        self.assertIn('depends_on "oniguruma"', result)
        self.assertIn('Formula["oniguruma"]', result)
        self.assertIn('uses_from_macos "zlib"', result)
        self.assertIn('sha256 "keep"', result)

    def test_external_tap_rejected(self):
        with self.assertRaises(RuntimeError):
            p.canonical('another/tap/thing')

    def test_transform_removes_no_autobump(self):
        source = ('class Readline < Formula\n'
                  '  no_autobump! because: :incompatible_version_format\n'
                  'end\n')
        self.assertNotIn('no_autobump', p.transform(source, 'user/intel', set()))

    def test_implicit_extractor_dep_maps_to_tap_and_installs_in_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'scripts').mkdir()
            (root / 'snapshot.json').write_text(json.dumps({
                'tap': 'user/intel', 'order': ['p7zip', 'imagemagick'], 'tag': 'tahoe-1'}))
            bottle = {'bottle': {'stable': {'files': {'tahoe': {
                'url': 'https://github.com/user/homebrew-intel/releases/download/tahoe-1/x.bottle.tar.gz'}}}}}
            def fake_brew(*args):
                if args == ('--prefix',):
                    return '/usr/local\n'
                if args[0] == 'deps':
                    return 'p7zip\n'
                return json.dumps({'formulae': [bottle]})
            with patch.object(client, '__file__', str(root / 'scripts/install-binary.py')), \
                 patch.object(client.sys, 'argv', ['script', 'install', 'imagemagick']), \
                 patch.object(client.platform, 'system', return_value='Darwin'), \
                 patch.object(client.platform, 'machine', return_value='x86_64'), \
                 patch.object(client.subprocess, 'check_output', return_value='26.7\n'), \
                 patch.object(client, 'brew', side_effect=fake_brew), \
                 patch.object(client.subprocess, 'run') as install:
                client.main()
                installed = [call.args[0][-1] for call in install.call_args_list]
                self.assertEqual(installed, ['user/intel/p7zip', 'user/intel/imagemagick'])

    def test_transform_keeps_reusable_bottle_and_redirects_external_dep(self):
        source = ('class Crush < Formula\n'
                  '  bottle do\n'
                  '    sha256 tahoe: "official"\n'
                  '  end\n'
                  '  depends_on "charmbracelet/tap/mods"\n'
                  'end\n')
        names = {'charmbracelet/tap/mods'}
        result = p.transform(source, 'user/intel', names, keep_bottle=True)
        self.assertIn('bottle do', result)
        self.assertIn('sha256 tahoe: "official"', result)
        self.assertIn('depends_on "user/intel/mods"', result)

    def test_transform_qualifies_short_name_provided_only_by_external_tap(self):
        source = 'class C < Formula\n  depends_on "mods"\nend\n'
        result = p.transform(source, 'user/intel', {'charmbracelet/tap/mods'})
        self.assertIn('depends_on "user/intel/mods"', result)

    def test_canonical_allows_members_of_external_source_taps_only(self):
        self.assertEqual(p.canonical('anomalyco/tap/opencode', {'anomalyco/tap'}),
                         'anomalyco/tap/opencode')
        with self.assertRaises(RuntimeError):
            p.canonical('anomalyco/tap/opencode')
        with self.assertRaises(RuntimeError):
            p.canonical('anomalyco/tap/opencode', {'other/tap'})

    def test_scan_adds_external_tap_formula_with_full_package_name(self):
        installed = {'name': 'crush', 'tap': 'charmbracelet/tap',
                     'installed': [{'version': '0.1'}]}
        upstream = {'name': 'crush', 'full_name': 'charmbracelet/tap/crush',
                    'urls': {'stable': {'url': 'https://example.org/crush.tar.gz'}},
                    'bottle': {'stable': {'files': {}}}}
        row = sync.classify(installed, upstream)
        self.assertTrue(row['candidate'])
        self.assertEqual(row['package'], 'charmbracelet/tap/crush')
        upstream['full_name'] = 'charmbracelet/tap/renamed'
        self.assertFalse(sync.classify(installed, upstream)['candidate'])

    def test_client_installs_reused_bottle_without_release_url(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'scripts').mkdir()
            (root / 'snapshot.json').write_text(json.dumps({
                'tap': 'user/intel', 'order': ['jq'], 'tag': 'tahoe-1',
                'reused': ['jq']}))
            bottle = {'bottle': {'stable': {'files': {'sequoia': {
                'url': 'https://ghcr.io/v2/homebrew/core/jq/blobs/sha256:x'}}}}}
            def fake_brew(*args):
                if args == ('--prefix',):
                    return '/usr/local\n'
                if args[0] == 'deps':
                    return ''
                return json.dumps({'formulae': [bottle]})
            with patch.object(client, '__file__', str(root / 'scripts/install-binary.py')), \
                 patch.object(client.sys, 'argv', ['script', 'install', 'jq']), \
                 patch.object(client.platform, 'system', return_value='Darwin'), \
                 patch.object(client.platform, 'machine', return_value='x86_64'), \
                 patch.object(client.subprocess, 'check_output', return_value='26.7\n'), \
                 patch.object(client, 'brew', side_effect=fake_brew), \
                 patch.object(client.subprocess, 'run') as install:
                client.main()
                installed = [call.args[0][-1] for call in install.call_args_list]
                self.assertEqual(installed, ['user/intel/jq'])

    def test_member_fp_cascades_through_dependents(self):
        order = ['a', 'b', 'c']
        graph = {'a': [], 'b': ['a'], 'c': ['b']}
        owner = {'a': 'a', 'b': 'b', 'c': 'c'}
        base = p.member_fps(order, graph, {k: 'src-' + k for k in order}, owner)
        changed = p.member_fps(order, graph,
                               {'a': 'src-a2', 'b': 'src-b', 'c': 'src-c'}, owner)
        self.assertEqual(base['a'] != changed['a'], True)
        self.assertEqual(base['b'] != changed['b'], True)
        self.assertEqual(base['c'] != changed['c'], True)

    def test_member_fp_dropped_member_inherits_owner_fp(self):
        # Membro externo descartado resolve para o dono core mesmo vindo antes.
        order = ['x/t/mods', 'consumer', 'mods']
        graph = {'x/t/mods': [], 'consumer': ['x/t/mods'], 'mods': []}
        file_owner = {'mods': 'mods', 'consumer': 'consumer'}
        normalized = {'x/t/mods': 'ext-src', 'mods': 'core-src',
                      'consumer': 'consumer-src'}
        fps = p.member_fps(order, graph, normalized, file_owner)
        self.assertEqual(fps['x/t/mods'], fps['mods'])
        # A fonte do membro descartado não influencia dependentes: só a do dono.
        other = p.member_fps(order, graph,
                             {**normalized, 'x/t/mods': 'ext-src-2'}, file_owner)
        self.assertEqual(fps['consumer'], other['consumer'])

    def test_partition_covers_members_and_clusters_deps(self):
        order = ['m4', 'autoconf', 'wget', 'jq']
        graph = {'m4': [], 'autoconf': ['m4'], 'wget': [], 'jq': ['oniguruma'],
                 'oniguruma': []}
        order = ['m4', 'oniguruma', 'autoconf', 'wget', 'jq']
        shards = p.partition(order, graph, {'autoconf', 'wget', 'jq'}, 2)
        flat = [n for shard in shards for n in shard]
        self.assertEqual(sorted(flat), sorted(order))
        autoconf_shard = next(i for i, s in enumerate(shards) if 'autoconf' in s)
        self.assertIn('m4', shards[autoconf_shard])

    def test_client_missing_dependency_bottle_never_installs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'scripts').mkdir()
            (root / 'snapshot.json').write_text(json.dumps({
                'tap': 'user/intel', 'order': ['jq', 'dep'], 'tag': 'tahoe-1'}))
            def fake_brew(*args):
                if args == ('--prefix',):
                    return '/usr/local\n'
                if args[0] == 'deps':
                    return 'user/intel/dep\n'
                return json.dumps({'formulae': [{'bottle': {'stable': {'files': {}}}}]})
            with patch.object(client, '__file__', str(root / 'scripts/install-binary.py')), \
                 patch.object(client.sys, 'argv', ['script', 'install', 'jq']), \
                 patch.object(client.platform, 'system', return_value='Darwin'), \
                 patch.object(client.platform, 'machine', return_value='x86_64'), \
                 patch.object(client.subprocess, 'check_output', return_value='26.7\n'), \
                 patch.object(client, 'brew', side_effect=fake_brew), \
                 patch.object(client.subprocess, 'run') as install:
                with self.assertRaisesRegex(SystemExit, 'Bottle do snapshot ausente'):
                    client.main()
                install.assert_not_called()


if __name__ == '__main__':
    unittest.main()
