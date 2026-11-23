"""Verifica invariantes críticos sem Homebrew nem acesso a GitHub."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import time
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
                 patch.object(sync, 'migration_plan', return_value=({'tap': 'u/intel'}, [], plan, {})), \
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
        # Deps de membros são qualificadas: o nome curto resolveria no core,
        # cuja versão diverge do keg publicado e matava a instalação.
        self.assertIn('depends_on "user/intel/oniguruma"', result)
        self.assertIn('Formula["user/intel/oniguruma"]', result)
        self.assertIn('uses_from_macos "zlib"', result)
        self.assertIn('sha256 "keep"', result)

    def test_transform_qualifies_alias_and_normalizes_dep_name(self):
        source = '''class Aom < Formula
  depends_on "pkg-config"
  depends_on "llvm"
  def install
    llvm = deps.map(&:name).find { |dep| dep.match?(/^llvm/) }
    openssl = deps.find { |dep| dep.name.start_with?("openssl@") }.name
  end
end
'''
        result = p.transform(source, 'user/intel', {'pkgconf', 'llvm', 'openssl@4'},
                             lookup={'pkg-config': 'pkgconf'})
        self.assertIn('depends_on "user/intel/pkgconf"', result)
        self.assertIn('depends_on "user/intel/llvm"', result)
        self.assertIn('deps.map { |d| d.name.split("/").last }', result)
        self.assertIn('dep.name.split("/").last.start_with?("openssl@")', result)

    def test_external_tap_rejected(self):
        with self.assertRaises(RuntimeError):
            p.canonical('another/tap/thing')

    def test_transform_removes_no_autobump(self):
        source = ('class Readline < Formula\n'
                  '  no_autobump! because: :incompatible_version_format\n'
                  'end\n')
        self.assertNotIn('no_autobump', p.transform(source, 'user/intel', set()))

    def test_transform_removes_disable_so_preserved_versions_install(self):
        source = ('class Icu4cAT77 < Formula\n'
                  '  disable! date: "2026-10-30", because: :versioned_formula\n'
                  'end\n')
        self.assertNotIn('disable!', p.transform(source, 'user/intel', set()))

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

    def test_strip_bottle_block_removes_only_the_bottle(self):
        source = ('class P < Formula\n'
                  '  url "https://example.org/p.tar.gz"\n'
                  '  bottle do\n'
                  '    root_url "https://github.com/u/homebrew-intel/releases/download/tahoe-bottles"\n'
                  '    sha256 tahoe: "abc"\n'
                  '  end\n'
                  '  depends_on "openssl@3"\n'
                  'end\n')
        stripped = p.strip_bottle_block(source)
        self.assertNotIn('bottle do', stripped)
        self.assertNotIn('sha256 tahoe', stripped)
        self.assertIn('url "https://example.org/p.tar.gz"', stripped)
        self.assertIn('depends_on "openssl@3"', stripped)
        # Sem bloco bottle (ou bloco que não casa com o formato padrão) é no-op.
        self.assertEqual(p.strip_bottle_block(stripped), stripped)
        weird = 'class W < Formula\n    bottle do\n    end\nend\n'
        self.assertIn('bottle do', p.strip_bottle_block(weird))

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

    def test_dead_tap_keeps_published_member_and_skips_unpublished(self):
        # Tap de origem sumiu: membro já publicado segue congelado a partir do
        # .rb local; membro nunca publicado sai do plano em vez de matar o plan.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'Formula').mkdir()
            (root / 'Formula' / 'opsy.rb').write_text('class Opsy < Formula\nend\n')

            def info(name):
                if name.endswith(('opsy', 'never')):
                    raise p.subprocess.CalledProcessError(1, 'brew')
                return {'full_name': 'jq', 'bottle': {}, 'aliases': [], 'oldnames': []}

            with patch.object(p, 'ROOT', root), patch.object(p, 'TAP_ROOT', root), \
                 patch.object(p, 'formula_info', side_effect=info), \
                 patch.object(p, 'deps', return_value=[]), \
                 patch.object(p, 'run', return_value='class Jq < Formula\nend\n'):
                graph, sources, reusable, aux = p.build_graph(
                    ['jq', 'datolabs-io/opsy/opsy', 'gone/tap/never'],
                    {'datolabs-io/opsy', 'gone/tap'})
            self.assertEqual(aux['frozen'], ['datolabs-io/opsy/opsy'])
            self.assertEqual(aux['skipped'], ['gone/tap/never'])
            self.assertIn('Opsy', sources['datolabs-io/opsy/opsy'])
            self.assertEqual(graph['datolabs-io/opsy/opsy'], [])
            self.assertTrue(reusable['datolabs-io/opsy/opsy'])
            self.assertNotIn('gone/tap/never', graph)

    def test_arm64_only_formula_detected_from_source(self):
        # openjdk 27 declara depends_on arch: :arm64 e o info JSON não expõe o
        # requisito; a detecção pela fonte tira a fórmula do plano Intel.
        with patch.object(p, 'formula_info',
                          return_value={'full_name': 'openjdk', 'bottle': {},
                                        'aliases': [], 'oldnames': []}), \
             patch.object(p, 'deps', return_value=[]), \
             patch.object(p, 'run', return_value=(
                 'class Openjdk < Formula\n  on_macos do\n'
                 '    depends_on arch: :arm64\n  end\nend\n')):
            graph, sources, reusable, aux = p.build_graph(['openjdk'], set())
        self.assertEqual(aux['arch_skipped'], ['openjdk'])

    def test_local_patch_block_injected_once(self):
        # Correções nossas (Patches/<short>/*.diff) entram no tap gerado sem
        # duplicar quando a fórmula já referencia o arquivo.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'Patches' / 'folly').mkdir(parents=True)
            (root / 'Patches' / 'folly' / 'fix.diff').write_text('diff')
            source = 'class Folly < Formula\n  url "x"\nend\n'
            with patch.object(p, 'ROOT', root):
                once = p.add_local_patches({'folly': source})['folly']
                twice = p.add_local_patches({'folly': once})['folly']
            self.assertIn('Patches/folly/fix.diff', once)
            self.assertEqual(once.count('patch do'), 1)
            self.assertEqual(twice.count('patch do'), 1)

    def test_heavy_deps_are_recognized_and_prioritized(self):
        self.assertTrue(p.heavy('llvm@21'))
        self.assertFalse(p.heavy('gonzo'))
        self.assertFalse(p.heavy('rustscan'))
        graph = {'llvm': [], 'jq': [], 'rust': ['llvm']}
        shards = p.prioritize([['jq', 'llvm', 'rust']], graph,
                              {'llvm', 'rust'})
        # Pesados primeiro, com llvm (dep do rust) antes do rust.
        self.assertEqual(shards[0], ['llvm', 'rust', 'jq'])

    def test_partition_clusters_transitive_heavy_dependents(self):
        # fish depende do llvm via libssh2; a afinidade por dep direta não vê
        # isso — os ancestrais pesados transitivos mantêm a cadeia no shard.
        graph = {'fish': ['libssh2'], 'libssh2': ['llvm'], 'llvm': [],
                 'jq': []}
        order = p.topo(['fish', 'jq'], graph)
        self.assertEqual(p.heavy_ancestors(order, graph)['fish'], {'llvm'})
        shards = p.partition(order, graph, {'llvm', 'rust'}, 2)
        llvm_shard = next(i for i, s in enumerate(shards) if 'llvm' in s)
        self.assertIn('fish', shards[llvm_shard])

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


Z3_SOURCE = '''class Z3 < Formula
  desc "High-performance theorem prover"
  url "https://github.com/Z3Prover/z3/archive/refs/tags/z3-5.4.1.tar.gz"
  sha256 "abc"
  bottle do
    root_url "https://github.com/u/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "89a6f824"
  end
end
'''


class BottleReferenceTests(unittest.TestCase):
    def test_formula_version_from_explicit_and_url(self):
        self.assertEqual(p.formula_version(Z3_SOURCE), '5.4.1')
        explicit = 'class P < Formula\n  version "2.3"\n  url "https://e.org/p.tgz"\nend\n'
        self.assertEqual(p.formula_version(explicit), '2.3')
        self.assertIsNone(p.formula_version('class N < Formula\n  head "x"\nend\n'))

    def test_bottle_block_missing_detects_version_drift(self):
        # Bloco sem url deriva o nome da versão atual: graft de um bloco antigo
        # sobre a fonte nova aponta para um asset que não existe (404 do z3).
        self.assertEqual(p.bottle_assets(Z3_SOURCE, 'z3'),
                         {'z3-5.4.1.tahoe.bottle.tar.gz',
                          'z3-5.4.1.all.bottle.tar.gz'})
        self.assertTrue(p.bottle_block_missing(
            Z3_SOURCE, 'z3', {'z3-5.4.0.tahoe.bottle.tar.gz'}))
        self.assertFalse(p.bottle_block_missing(
            Z3_SOURCE, 'z3', {'z3-5.4.1.tahoe.bottle.tar.gz'}))
        self.assertFalse(p.bottle_block_missing(
            'class N < Formula\n  url "https://e.org/n.tgz"\nend\n', 'n', set()))

    def test_bottle_block_with_revision_matches_revisioned_asset(self):
        # libgit2 1.9.7 com revision 2 publica libgit2-1.9.7_2: omitir a
        # revisão fazia um bloco válido parecer órfão e o publish o removia.
        source = ('class Libgit2 < Formula\n'
                  '  url "https://e.org/libgit2/v1.9.7.tar.gz"\n'
                  '  revision 2\n'
                  '  bottle do\n'
                  '    root_url "https://github.com/u/homebrew-intel/releases/download/tahoe-bottles"\n'
                  '    sha256 tahoe: "abc"\n'
                  '  end\nend\n')
        self.assertIn('libgit2-1.9.7_2.tahoe.bottle.tar.gz',
                      p.bottle_assets(source, 'libgit2'))
        self.assertFalse(p.bottle_block_missing(
            source, 'libgit2', {'libgit2-1.9.7_2.tahoe.bottle.tar.gz'}))

    def test_explicit_bottle_url_is_validated_by_basename(self):
        source = ('class P < Formula\n  url "https://e.org/p-1.0.tar.gz"\n'
                  '  bottle do\n'
                  '    root_url "https://github.com/u/homebrew-intel/releases/download/tahoe-bottles"\n'
                  '    url "https://github.com/u/homebrew-intel/releases/download/tahoe-bottles/p-1.0.tahoe.bottle.tar.gz"\n'
                  '  end\nend\n')
        self.assertEqual(p.bottle_assets(source, 'p'),
                         {'p-1.0.tahoe.bottle.tar.gz'})
        self.assertTrue(p.bottle_block_missing(source, 'p', {'other.tar.gz'}))
        self.assertFalse(p.bottle_block_missing(
            source, 'p', {'p-1.0.tahoe.bottle.tar.gz'}))

    def test_upstream_bottle_is_never_considered_missing(self):
        # Fórmula reutilizada mantém o bottle do mantenedor (ghcr.io): ele não
        # é asset do nosso release e validá-lo reprovaria todo pour.
        source = ('class P < Formula\n  url "https://e.org/p-1.0.tar.gz"\n'
                  '  bottle do\n    sha256 cellar: :any, tahoe: "abc"\n  end\nend\n')
        self.assertFalse(p.bottle_block_missing(source, 'p', set()))


class SingleOwnerBuildTests(unittest.TestCase):
    """Cada fórmula do build_set é compilada por um único shard."""

    def run_install(self, published, build_set=('z3',), installed=''):
        def fake_run(*args, **kwargs):
            return installed if args[1] == 'list' else 'u/intel/z3\n'
        with patch.object(p, 'run', side_effect=fake_run), \
             patch.object(p, 'brew_install') as install, \
             patch.object(p, 'wait_for_publish', return_value=published) as wait:
            try:
                p.install_missing_deps('u/intel/target', 'u/intel', {},
                                       {'id': 1}, set(build_set))
            except p.Deferred as dep:
                return ('deferred', str(dep)), install, wait
        return 'ok', install, wait

    def test_dependency_of_another_shard_is_deferred_not_compiled(self):
        # z3 está no build_set e ainda não foi publicado: nenhum shard pode
        # compilá-lo por conta própria (era o que duplicava o build em dois).
        outcome, install, wait = self.run_install(published=False)
        self.assertEqual(outcome, ('deferred', 'z3 ainda não publicada'))
        install.assert_not_called()
        wait.assert_called_once()

    def test_dependency_is_poured_once_the_owner_published(self):
        outcome, install, wait = self.run_install(published=True)
        self.assertEqual(outcome, 'ok')
        wait.assert_called_once()
        install.assert_called_once_with('--ignore-dependencies', 'u/intel/z3')

    def test_already_installed_dependency_is_not_touched(self):
        outcome, install, wait = self.run_install(published=False,
                                                  installed='z3\n')
        self.assertEqual(outcome, 'ok')
        install.assert_not_called()
        wait.assert_not_called()

    def test_dependency_outside_the_build_set_is_installed(self):
        outcome, install, wait = self.run_install(published=False, build_set=())
        self.assertEqual(outcome, 'ok')
        wait.assert_not_called()
        install.assert_called_once_with('--ignore-dependencies', 'u/intel/z3')

    def test_dependency_without_bottle_defers_instead_of_failing(self):
        # --build-bottle recusa o install quando a dep não tem bottle (o caso
        # llhttp/z3/llvm): adiar preserva a run em vez de marcá-la como falha.
        with tempfile.TemporaryDirectory() as tmp:
            formula_dir = Path(tmp) / 'Formula'
            formula_dir.mkdir()
            (formula_dir / 'z3.rb').write_text(
                'class Z3 < Formula\n  url "x"\nend\n')
            (formula_dir / 'openssl.rb').write_text(
                'class Openssl < Formula\n  url "x"\n  bottle do\n  end\nend\n')
            deps = 'italoag/intel/z3\nitaloag/intel/openssl\nhomebrew/core/jq\n'
            with patch.object(p, 'TAP_ROOT', Path(tmp)), \
                 patch.object(p, 'run', side_effect=['', deps]):
                self.assertEqual(
                    p.missing_bottles('italoag/intel/x', 'italoag/intel'), ['z3'])

    def test_installed_dependency_without_bottle_is_not_missing(self):
        # Dep já instalada e satisfeita o brew pula antes de validar o
        # --build-bottle: adiar ali só impediria o build de acontecer.
        with tempfile.TemporaryDirectory() as tmp:
            formula_dir = Path(tmp) / 'Formula'
            formula_dir.mkdir()
            (formula_dir / 'llvm.rb').write_text(
                'class Llvm < Formula\n  url "x"\nend\n')
            with patch.object(p, 'TAP_ROOT', Path(tmp)), \
                 patch.object(p, 'run',
                              side_effect=['llvm\nzstd\n', 'italoag/intel/llvm\n']):
                self.assertEqual(
                    p.missing_bottles('italoag/intel/rust', 'italoag/intel'), [])

    def test_link_retry_matches_keg_with_revision(self):
        # texinfo 7.3 com revision 1 instala o keg como "7.3_1": comparar só
        # com versions.stable nunca casa e o retry de link não acontece.
        info = {'versions': {'stable': '7.3'}, 'revision': 1,
                'installed': [{'version': '7.3_1'}]}
        with patch.object(p, 'formula_info', return_value=info):
            self.assertTrue(p.stable_version_installed('u/intel/texinfo'))
        info['installed'] = [{'version': '7.3'}]
        with patch.object(p, 'formula_info', return_value=info):
            self.assertTrue(p.stable_version_installed('u/intel/texinfo'))
        info['installed'] = [{'version': '7.2'}]
        with patch.object(p, 'formula_info', return_value=info):
            self.assertFalse(p.stable_version_installed('u/intel/texinfo'))

    def test_build_tool_bump_does_not_invalidate_dependents(self):
        # pkgconf/cmake entram como dep de quase tudo mas não mudam o binário:
        # contá-los no fp fazia um bump de patch invalidar 160 fórmulas,
        # inclusive o llvm, que não cabe nas 6h do job.
        order = ['pkgconf', 'jq']
        graph = {'pkgconf': [], 'jq': ['pkgconf']}
        owner = {'pkgconf': 'pkgconf', 'jq': 'jq'}
        base = p.member_fps(order, graph, {'pkgconf': 'p1', 'jq': 'j1'}, owner)
        bumped = p.member_fps(order, graph, {'pkgconf': 'p2', 'jq': 'j1'}, owner)
        self.assertEqual(base['jq'], bumped['jq'])
        # Dep de runtime continua invalidando em cascata.
        runtime = {'openssl': [], 'jq': ['openssl']}
        owner2 = {'openssl': 'openssl', 'jq': 'jq'}
        a = p.member_fps(['openssl', 'jq'], runtime,
                         {'openssl': 'o1', 'jq': 'j1'}, owner2)
        b = p.member_fps(['openssl', 'jq'], runtime,
                         {'openssl': 'o2', 'jq': 'j1'}, owner2)
        self.assertNotEqual(a['jq'], b['jq'])

    def test_published_bottle_survives_dependency_bump(self):
        # Mesma versão da fórmula = mesmo bottle, ainda que uma dep tenha
        # subido de patch: o publish do Homebrew também não reconstrói nesse
        # caso, e reconstruir o llvm custa 10h.
        source = ('class Jq < Formula\n'
                  '  url "https://e.org/jq-1.7.1.tar.gz"\n  revision 3\nend\n')
        self.assertTrue(p.bottle_matches_version(
            source, 'jq', 'jq-1.7.1_3.tahoe.bottle.tar.gz'))
        self.assertFalse(p.bottle_matches_version(
            source, 'jq', 'jq-1.7.1.tahoe.bottle.tar.gz'))
        self.assertFalse(p.bottle_matches_version(
            source, 'jq', 'jq-1.7.0_3.tahoe.bottle.tar.gz'))
        self.assertFalse(p.bottle_matches_version(source, 'jq', None))

    def test_wait_is_bounded_by_the_shard_deadline(self):
        # A segunda passada espera o dono publicar, mas nunca além do
        # orçamento do shard (o job morre em 6h).
        def fake_run(*args, **kwargs):
            return '' if args[1] == 'list' else 'u/intel/z3\n'
        with patch.object(p, 'run', side_effect=fake_run), \
             patch.object(p, 'brew_install'), \
             patch.object(p, 'wait_for_publish', return_value=True) as wait:
            p.install_missing_deps('u/intel/target', 'u/intel', {}, {'id': 1},
                                   {'z3'}, time.monotonic() + 600)
        self.assertGreater(wait.call_args.kwargs['timeout'], 500)
        self.assertLessEqual(wait.call_args.kwargs['timeout'], 600)
        self.assertEqual(p.wait_left(None), 0)

    def test_prioritize_never_puts_a_consumer_before_its_dependency(self):
        # rust é pesado, cmake é leve e dependência dele: ordenar só por peso
        # colocaria rust antes e o cmake seria compilado como dep e de novo
        # como membro.
        graph = {'rust': ['llvm', 'cmake'], 'llvm': [], 'cmake': [], 'jq': []}
        order = p.prioritize([['jq', 'rust', 'cmake', 'llvm']], graph,
                             {'rust', 'cmake', 'llvm', 'jq'})[0]
        self.assertEqual(order[0], 'llvm')
        self.assertLess(order.index('cmake'), order.index('rust'))

    def test_adopt_skips_formula_pointing_to_absent_bottle(self):
        with tempfile.TemporaryDirectory() as tmp:
            formula_dir = Path(tmp)
            target = formula_dir / 'z3.rb'
            original = 'class Z3 < Formula\n  url "x"\nend\n'
            target.write_text(original)
            release = {'id': 1}
            assets = {'name': 'Formula-z3.rb', 'browser_download_url': 'u'}
            with patch.object(p, 'run', return_value='u/intel/z3\n'), \
                 patch.object(p, 'release_assets', return_value=[assets]), \
                 patch.object(p, 'combined_manifest',
                              return_value={'z3': {'asset': 'z3-5.4.0.tahoe.bottle.tar.gz'}}), \
                 patch.object(p, 'fetch_if_present', return_value=Z3_SOURCE.encode()):
                p.adopt_bottles(release, 'u/intel/target', formula_dir)
            # .rb do z3 5.4.1 aponta para um bottle que não existe: não adota.
            self.assertEqual(target.read_text(), original)

    def test_adopt_keeps_formula_whose_bottle_exists(self):
        with tempfile.TemporaryDirectory() as tmp:
            formula_dir = Path(tmp)
            (formula_dir / 'z3.rb').write_text('class Z3 < Formula\n  url "x"\nend\n')
            release = {'id': 1}
            assets = [{'name': 'Formula-z3.rb', 'browser_download_url': 'u'},
                      {'name': 'z3-5.4.1.tahoe.bottle.tar.gz',
                       'browser_download_url': 'b'}]
            with patch.object(p, 'run', return_value='u/intel/z3\n'), \
                 patch.object(p, 'release_assets', return_value=assets), \
                 patch.object(p, 'combined_manifest',
                              return_value={'z3': {'asset': 'z3-5.4.1.tahoe.bottle.tar.gz'}}), \
                 patch.object(p, 'fetch_if_present', return_value=Z3_SOURCE.encode()):
                p.adopt_bottles(release, 'u/intel/target', formula_dir)
            self.assertIn('bottle do', (formula_dir / 'z3.rb').read_text())


class LocalModeTests(unittest.TestCase):
    def test_local_rebuild_targets_parses_env(self):
        with patch.dict(os.environ, {'PIPELINE_LOCAL_REBUILD': ' llvm , rust ,,'}):
            self.assertEqual(p.local_rebuild_targets(), {'llvm', 'rust'})
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(p.local_rebuild_targets(), set())

    def test_installed_member_is_uninstalled_only_when_requested(self):
        args = ('rust', 0, 'u/intel', 'u/intel/rust', 'rust', set(), {}, {},
                {}, {}, 'url', {})
        installed = {'installed': [{'version': '1.0'}]}
        with patch.dict(os.environ, {}, clear=True), \
             patch.object(p, 'formula_info', return_value=installed), \
             patch.object(p, 'run') as run:
            with self.assertRaisesRegex(p.Skipped, 'PIPELINE_LOCAL_REBUILD'):
                p.process_member(*args, local=True)
            run.assert_not_called()

    def test_requested_member_removes_keg_before_building(self):
        args = ('rust', 0, 'u/intel', 'u/intel/rust', 'rust', set(), {}, {},
                {}, {}, 'url', {})
        installed = {'installed': [{'version': '1.0'}]}
        with patch.dict(os.environ, {'PIPELINE_LOCAL_REBUILD': 'rust'}), \
             patch.object(p, 'formula_info', return_value=installed), \
             patch.object(p, 'run') as run, \
             patch.object(p.subprocess, 'run', side_effect=RuntimeError('probe')):
            with self.assertRaisesRegex(RuntimeError, 'probe'):
                p.process_member(*args, local=True)
            self.assertEqual(run.call_args.args, ('brew', 'uninstall', '--force',
                                                  '--ignore-dependencies',
                                                  'u/intel/rust'))

    def test_local_run_restores_the_users_tap_clone(self):
        with tempfile.TemporaryDirectory() as tmp:
            brew = Path(tmp) / 'brew'
            tap = brew / 'Library/Taps/u/homebrew-intel'
            tap.mkdir(parents=True)
            (tap / 'marker').write_text('clone do usuário')
            root = Path(tmp) / 'checkout'
            root.mkdir()
            with patch.object(p, 'TAP_ROOT', root), \
                 patch.object(p, 'run', return_value=str(brew) + '\n'), \
                 patch.object(p, '_tap_backup', None):
                p.link_own_tap('u', 'homebrew-intel', 'u/intel')
                # O build escreve no checkout; o clone do usuário fica guardado.
                self.assertTrue(tap.is_symlink())
                self.assertEqual(tap.resolve(), root.resolve())
                p.restore_tap()
                self.assertFalse(tap.is_symlink())
                self.assertEqual((tap / 'marker').read_text(), 'clone do usuário')
                self.assertFalse(tap.with_name('homebrew-intel.orig').exists())

    def test_interrupted_run_gets_the_clone_back_before_building(self):
        with tempfile.TemporaryDirectory() as tmp:
            brew = Path(tmp) / 'brew'
            parent = brew / 'Library/Taps/u'
            parent.mkdir(parents=True)
            (parent / 'homebrew-intel.orig').mkdir()
            (parent / 'homebrew-intel.orig' / 'marker').write_text('clone')
            (parent / 'homebrew-intel').symlink_to(Path(tmp) / 'apagado',
                                                   target_is_directory=True)
            with patch.object(p, 'run', return_value=str(brew) + '\n'), \
                 patch.object(p, '_tap_backup', None):
                p.recover_tap('u', 'homebrew-intel')
                tap = parent / 'homebrew-intel'
                self.assertFalse(tap.is_symlink())
                self.assertEqual((tap / 'marker').read_text(), 'clone')


if __name__ == '__main__':
    unittest.main()
