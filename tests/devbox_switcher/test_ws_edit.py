"""Tests for ws-edit, with a stub editor script and a synthetic registry.

Run from the repo root:  python3 -m unittest discover tests/devbox_switcher
"""

import os
import subprocess
import tempfile
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT = os.path.join(REPO, "modules", "i3", ".local", "bin", "ws-edit")

ROWS = ["alpha\t-\tFirst\t2026-01-01T00:00:00+00:00\tmanual",
        "beta\t-\tSecond\t2026-01-02T00:00:00+00:00\tmanual"]


class WsEditTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = tmp.name
        self.state = os.path.join(self.dir, "state")
        self.devbox = os.path.join(self.state, "devbox")

    def stub(self, body, name="stub-editor"):
        path = os.path.join(self.dir, name)
        with open(path, "w") as f:
            f.write("#!/bin/sh\n" + body + "\n")
        os.chmod(path, 0o755)
        return path

    def write(self, regname, rows):
        os.makedirs(self.devbox, exist_ok=True)
        with open(os.path.join(self.devbox, regname), "w") as f:
            f.write("".join(r + "\n" for r in rows))

    def read(self, regname):
        with open(os.path.join(self.devbox, regname)) as f:
            return f.read().splitlines()

    def run_script(self, editor, *args, env_extra=None):
        env = {"PATH": "/usr/bin:/bin", "HOME": self.dir,
               "XDG_STATE_HOME": self.state, "VISUAL": editor}
        env.update(env_extra or {})
        r = subprocess.run(["bash", SCRIPT, *args], env=env,
                           capture_output=True, text=True, stdin=subprocess.DEVNULL)
        return r.returncode, r.stdout + r.stderr

    def test_deleting_a_line_removes_the_entry(self):
        self.write("registry.tsv", ROWS)
        code, _ = self.run_script(self.stub('sed -i /^alpha/d "$1"'))
        self.assertEqual(code, 0)
        self.assertEqual(self.read("registry.tsv"), [ROWS[1]])

    def test_ws_flag_edits_named_workspaces(self):
        self.write("registry.tsv", ROWS)
        self.write("named_workspaces.tsv", ROWS)
        code, _ = self.run_script(self.stub('sed -i /^beta/d "$1"'), "--ws")
        self.assertEqual(code, 0)
        self.assertEqual(self.read("named_workspaces.tsv"), [ROWS[0]])
        self.assertEqual(self.read("registry.tsv"), ROWS)

    def test_missing_registry_and_directory(self):
        code, _ = self.run_script(self.stub("true"))
        self.assertEqual(code, 0)
        self.assertEqual(self.read("registry.tsv"), [])

    def test_editor_gets_the_registry_content_when_missing_is_empty(self):
        out = os.path.join(self.dir, "seen")
        code, _ = self.run_script(self.stub(f'wc -c < "$1" > {out}'))
        self.assertEqual(code, 0)
        self.assertEqual(open(out).read().strip(), "0")

    def test_failing_editor_leaves_registry_alone(self):
        self.write("registry.tsv", ROWS)
        code, msg = self.run_script(self.stub('echo junk > "$1"; exit 1'))
        self.assertEqual(code, 1)
        self.assertIn("unchanged", msg)
        self.assertEqual(self.read("registry.tsv"), ROWS)
        self.assertEqual(os.listdir(self.devbox), ["registry.tsv"])

    def test_editor_fallback_to_EDITOR(self):
        self.write("registry.tsv", ROWS)
        editor = self.stub('sed -i /^alpha/d "$1"')
        code, _ = self.run_script("", env_extra={"VISUAL": "", "EDITOR": editor})
        self.assertEqual(code, 0)
        self.assertEqual(self.read("registry.tsv"), [ROWS[1]])


if __name__ == "__main__":
    unittest.main()
