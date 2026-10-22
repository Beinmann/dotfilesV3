"""Tests for devbox-mark (needs a pty: the script refuses without a terminal).

Fake i3-msg on PATH serves a workspace list and logs the commands it gets.

Run from the repo root:  python3 -m unittest discover tests/devbox_switcher
"""

import json
import os
import pty
import subprocess
import tempfile
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT = os.path.join(REPO, "modules", "i3", ".local", "bin", "devbox-mark")


class DevboxMarkTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = tmp.name
        self.log = os.path.join(self.dir, "i3.log")
        self.state = os.path.join(self.dir, "state")
        self.registry = os.path.join(self.state, "devbox", "registry.tsv")
        self.cwd = os.path.join(self.dir, "cwd")
        os.mkdir(self.cwd)
        self.set_workspaces([{"name": "10", "focused": True}])

    def set_workspaces(self, workspaces, i3_up=True):
        data = os.path.join(self.dir, "ws.json")
        with open(data, "w") as f:
            json.dump(workspaces, f)
        with open(os.path.join(self.dir, "i3-msg"), "w") as f:
            f.write(f'#!/bin/sh\n[ {1 if i3_up else 0} = 1 ] || exit 1\n'
                    f'[ "$2" = get_version ] && exit 0\n'
                    f'[ "$2" = get_workspaces ] && exec cat {data}\n'
                    f'echo "$*" >> {self.log}\n')
        os.chmod(os.path.join(self.dir, "i3-msg"), 0o755)

    def run_script(self, *args, answers="", tty=True):
        env = {"PATH": f"{self.dir}:/usr/bin:/bin", "HOME": self.dir,
               "XDG_STATE_HOME": self.state}
        if not tty:
            r = subprocess.run(["bash", SCRIPT, *args], env=env, cwd=self.cwd,
                               capture_output=True, text=True, stdin=subprocess.DEVNULL)
            return r.returncode, r.stdout + r.stderr
        master, slave = pty.openpty()
        p = subprocess.Popen(["bash", SCRIPT, *args], env=env, cwd=self.cwd,
                             stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        os.write(master, answers.encode())
        out = b""
        while True:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
        os.close(master)
        return p.wait(), out.decode()

    def i3_calls(self):
        if not os.path.exists(self.log):
            return ""
        with open(self.log) as f:
            return f.read()

    def registry_lines(self):
        with open(self.registry) as f:
            return [l.rstrip("\n").split("\t") for l in f]

    def test_prompts_registers_and_moves(self):
        code, out = self.run_script(answers="alpha\nMy box\n")
        self.assertEqual(code, 0, out)
        self.assertIn('move container to workspace "dev:alpha"', self.i3_calls())
        (name, path, title, _when, kind), = self.registry_lines()
        self.assertEqual((name, path, title, kind), ("alpha", "-", "My box", "manual"))
        self.assertEqual(os.listdir(self.cwd), [])

    def test_args_skip_prompts_and_name_replaces_old_entry(self):
        self.assertEqual(self.run_script("alpha", "one")[0], 0)
        self.assertEqual(self.run_script("alpha", "two")[0], 0)
        (line,) = self.registry_lines()
        self.assertEqual(line[2], "two")

    def test_other_registry_lines_are_kept(self):
        os.makedirs(os.path.dirname(self.registry))
        with open(self.registry, "w") as f:
            f.write("beta\t/some/path\tBeta\t2026-01-01T00:00:00+00:00\n")
        self.assertEqual(self.run_script("alpha")[0], 0)
        self.assertEqual([l[0] for l in self.registry_lines()], ["beta", "alpha"])

    def test_invalid_name_argument_is_asked_again(self):
        code, out = self.run_script("bad name", answers="ok\n\n")
        self.assertEqual(code, 0, out)
        self.assertIn("1-16 letters", out)
        self.assertEqual(self.registry_lines()[0][2], "ok")  # title defaults to name

    def test_refuses_name_open_elsewhere(self):
        self.set_workspaces([{"name": "10", "focused": True}, {"name": "dev:alpha"}])
        code, out = self.run_script("alpha")
        self.assertEqual(code, 1)
        self.assertIn("already open", out)
        self.assertEqual(self.i3_calls(), "")
        self.assertFalse(os.path.exists(self.registry))

    def test_rerun_on_its_own_workspace_is_fine(self):
        self.set_workspaces([{"name": "dev:alpha", "focused": True}])
        self.assertEqual(self.run_script("alpha")[0], 0)

    def test_no_i3_or_no_tty_fails_loudly(self):
        self.set_workspaces([], i3_up=False)
        code, out = self.run_script("alpha")
        self.assertEqual(code, 1)
        self.assertIn("i3 is not reachable", out)
        self.set_workspaces([{"name": "10", "focused": True}])
        code, out = self.run_script("alpha", tty=False)
        self.assertEqual(code, 1)
        self.assertIn("needs a terminal", out)
        self.assertFalse(os.path.exists(self.registry))


if __name__ == "__main__":
    unittest.main()
