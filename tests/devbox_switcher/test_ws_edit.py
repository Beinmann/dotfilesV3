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

    def rows(self, regname):
        return [l for l in self.read(regname) if l and not l.startswith("#")]

    def names(self, regname):
        return [l.split()[0] for l in self.rows(regname)]

    def test_deleting_a_line_removes_the_entry(self):
        self.write("registry.tsv", ROWS)
        code, _ = self.run_script(self.stub('sed -i /^alpha/d "$1"'))
        self.assertEqual(code, 0)
        self.assertEqual(self.read("registry.tsv"), [ROWS[1]])

    def test_ws_round_trip_is_labelled_and_aligned(self):
        self.write("named_workspaces.tsv", ["# header"] + ROWS)
        code, _ = self.run_script(self.stub("true"), "--ws")
        self.assertEqual(code, 0)
        lines = self.read("named_workspaces.tsv")
        self.assertTrue(lines[0].startswith("#"))
        self.assertTrue(any(l.startswith("# NAME  PATH") for l in lines))
        self.assertEqual(self.names("named_workspaces.tsv"), ["alpha", "beta"])
        # TITLE column starts at the same offset in every row
        cols = {l.index("First") for l in lines if "First" in l}
        self.assertEqual(len(cols), 1)

    def test_ws_delete_a_line(self):
        self.write("registry.tsv", ROWS)
        self.write("named_workspaces.tsv", ["# header"] + ROWS)
        code, _ = self.run_script(self.stub('sed -i /^beta/d "$1"'), "--ws")
        self.assertEqual(code, 0)
        self.assertEqual(self.names("named_workspaces.tsv"), ["alpha"])
        self.assertEqual(self.read("registry.tsv"), ROWS)

    def test_ws_copied_and_renamed_line_with_spaces(self):
        self.write("named_workspaces.tsv", ["# header"] + ROWS)
        # editor replaced tabs by spaces and the user copied a line, new name
        editor = self.stub(
            'sed -i "s/\\t/    /g" "$1"; '
            'grep "^alpha" "$1" | sed "s/^alpha/alpha2/" >> "$1"')
        code, msg = self.run_script(editor, "--ws")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.names("named_workspaces.tsv"),
                         ["alpha", "beta", "alpha2"])

    def test_ws_path_may_be_dash_and_title_defaults(self):
        self.write("named_workspaces.tsv", ["# header"])
        code, _ = self.run_script(self.stub('printf "web  -  Some browser\\nmail\\n" >> "$1"'), "--ws")
        self.assertEqual(code, 0)
        rows = [l.split("  ") for l in self.rows("named_workspaces.tsv")]
        self.assertEqual([r[0] for r in rows], ["web", "mail"])
        self.assertIn("Some browser", self.rows("named_workspaces.tsv")[0])

    def test_ws_invalid_lines_are_reported_and_registry_kept(self):
        self.write("named_workspaces.tsv", ["# header"] + ROWS)
        before = self.read("named_workspaces.tsv")
        for bad in ("bad name!\t-\tx", "alpha\t-\tdup", "waytoolongname_for_ws\t-\tx",
                    "a\t-\tb\tc\td\te"):
            code, msg = self.run_script(self.stub(f'printf "{bad}\\n" >> "$1"'), "--ws")
            self.assertEqual(code, 1, bad)
            self.assertIn("unchanged", msg)
            self.assertIn("line", msg)
            self.assertEqual(self.read("named_workspaces.tsv"), before, bad)

    def test_ws_old_format_is_set_aside(self):
        self.write("named_workspaces.tsv", ROWS)
        code, msg = self.run_script(self.stub("true"), "--ws")
        self.assertEqual(code, 0)
        self.assertIn(".old", msg)
        self.assertEqual(self.read("named_workspaces.tsv.old"), ROWS)
        self.assertEqual(self.names("named_workspaces.tsv"), [])

    def test_missing_registry_and_directory(self):
        code, _ = self.run_script(self.stub("true"))
        self.assertEqual(code, 0)
        self.assertEqual(self.read("registry.tsv"), [])
        code, _ = self.run_script(self.stub("true"), "--ws")
        self.assertEqual(code, 0)

    def test_devbox_registry_stays_tab_separated(self):
        self.write("registry.tsv", ROWS)
        code, _ = self.run_script(self.stub('sed -i "s/\\t/    /g" "$1"'))
        self.assertEqual(code, 0)
        self.assertEqual(self.read("registry.tsv"), ROWS)

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
