"""Keep legacy policies and declarative presets aligned during migration."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DeclarationTest(unittest.TestCase):
    def test_common_network_matches_legacy(self):
        source = (ROOT/'config/sbx/allow-domains.txt').read_text()
        expected = {line.split('#')[0].strip() for line in source.splitlines()}
        expected.discard('')
        expected.add('localhost:22')
        kit = (ROOT/'config/sbx/kits/common/spec.yaml').read_text()
        self.assertEqual(set(re.findall(r'^      - "(.*)"$', kit, re.M)), expected)

    def test_ccmanager_environment_presets_forward_prompt_and_isolate_names(self):
        config = json.loads((ROOT/'config/ccmanager/config.json').read_text())
        presets = config['commandPresets']['presets']
        selected = [p for p in presets if p['id'].startswith('sbx-env')]
        self.assertEqual(len(selected), 5)
        self.assertEqual(len({p['id'] for p in presets}), len(presets))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            mock = path/'sbx-agent'
            mock.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
            mock.chmod(0o755)
            env = {**os.environ, 'HOME': tmp, 'PATH': tmp+':'+os.environ['PATH']}
            prompt = 'prompt with spaces; $(never-execute) "quotes"'
            for preset in selected:
                for field in ['args', 'fallbackArgs']:
                    with self.subTest(preset=preset['id'], field=field):
                        # zsh -c and bash -c both preserve this POSIX argv forwarding.
                        r = subprocess.run(['bash']+preset[field]+[prompt], env=env,
                                           text=True, capture_output=True, check=True)
                        args = json.loads(r.stdout)
                        self.assertEqual(args[-1], prompt)
                        self.assertEqual(args[args.index('--env-file')+1], tmp+'/.config/sbx/sbxenv.yaml')
                        self.assertTrue(args[args.index('--name-prefix')+1].startswith('env'))
                        self.assertNotIn('--env-force', args)

    def test_coderabbit_install_owned_by_mise(self):
        spec = (ROOT/'config/sbx/kits/coderabbit/spec.yaml').read_text()
        self.assertNotIn('setup:', spec)
        self.assertNotIn('curl ', spec)
        self.assertIn('"http:coderabbit"', (ROOT/'config/devcontainer/mise.toml').read_text())
        self.assertIn('mise install -C /mise;', (ROOT/'config/devcontainer/Dockerfile.sandbox').read_text())


if __name__ == '__main__':
    unittest.main()
