"""Tests for ws-mark (needs a pty: the script refuses without a terminal).

Fake i3-msg on PATH serves a workspace list and logs the commands it gets.

Run from the repo root:  python3 -m unittest discover tests/devbox_switcher
"""

import json
import os
import pty
import re
import subprocess
import tempfile
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT = os.path.join(REPO, "modules", "i3", ".local", "bin", "ws-mark")


class WsMarkTest(unittest.TestCase):
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

    def fake_rofi(self, *answers):
        """Stub rofi: prints the next answer per call, logs the list it was given."""
        self.rofi_in = os.path.join(self.dir, "rofi.in")
        counter = os.path.join(self.dir, "rofi.n")
        with open(os.path.join(self.dir, "rofi"), "w") as f:
            f.write(f'#!/bin/sh\ncat >> {self.rofi_in}\nn=$(cat {counter} 2>/dev/null || echo 0)\n'
                    f'echo $((n+1)) > {counter}\n')
            f.write("case $n in\n")
            for i, a in enumerate(answers):
                f.write(f"{i}) " + ("exit 1" if a is None else f"printf '%s\\n' '{a}'") + " ;;\n")
            f.write("esac\n")
        os.chmod(os.path.join(self.dir, "rofi"), 0o755)

    def run_rofi(self, *flags):
        r = subprocess.run(["bash", SCRIPT, "--rofi", *flags], env={
            "PATH": f"{self.dir}:/usr/bin:/bin", "HOME": self.dir,
            "XDG_STATE_HOME": self.state}, cwd=self.cwd, capture_output=True,
            text=True, stdin=subprocess.DEVNULL)
        return r.returncode, r.stdout + r.stderr

    def write_registry(self, *names):
        os.makedirs(os.path.dirname(self.registry), exist_ok=True)
        with open(self.registry, "w") as f:
            for n in names:
                f.write(f"{n}\t/p/{n}\t{n} title\t2026-01-01T00:00:00+00:00\n")

    def test_rofi_lists_running_then_registry_only_and_moves_without_tty(self):
        self.set_workspaces([{"name": "10", "focused": True}, {"name": "dev:run"}])
        self.write_registry("old", "run")
        self.fake_rofi("old")
        code, out = self.run_rofi()
        self.assertEqual(code, 0, out)
        with open(self.rofi_in) as f:
            self.assertEqual(f.read().split(), ["run", "old"])
        self.assertIn('move container to workspace "dev:old"', self.i3_calls())
        self.assertEqual([l[0] for l in self.registry_lines()], ["old", "run"])
        self.assertEqual(self.registry_lines()[0][1], "/p/old")  # line kept

    def test_rofi_open_devbox_can_receive_another_window(self):
        self.set_workspaces([{"name": "10", "focused": True}, {"name": "dev:run"}])
        self.fake_rofi("run")
        self.assertEqual(self.run_rofi()[0], 0)
        self.assertIn('"dev:run"', self.i3_calls())

    def test_rofi_new_name_asks_title_and_registers(self):
        self.fake_rofi("fresh", "Fresh box")
        code, out = self.run_rofi()
        self.assertEqual(code, 0, out)
        (name, path, title, _w, kind), = self.registry_lines()
        self.assertEqual((name, path, title, kind), ("fresh", "-", "Fresh box", "manual"))
        self.assertIn('"dev:fresh"', self.i3_calls())

    def test_rofi_invalid_new_name_is_rejected(self):
        self.fake_rofi("not valid!")
        code, out = self.run_rofi()
        self.assertEqual(code, 1)
        self.assertIn("1-16 letters", out)
        self.assertEqual(self.i3_calls(), "")
        self.assertFalse(os.path.exists(self.registry))

    def test_ws_rofi_uses_own_prefix_and_registry(self):
        self.write_registry("devonly")
        self.set_workspaces([{"name": "10", "focused": True}, {"name": "dev:run"}, {"name": "ws:docs"}])
        self.fake_rofi("fresh", "Fresh page")
        code, out = self.run_rofi("--ws")
        self.assertEqual(code, 0, out)
        with open(self.rofi_in) as f:
            self.assertEqual(f.read().split(), ["docs"])
        self.assertIn('move container to workspace "ws:fresh"', self.i3_calls())
        with open(os.path.join(self.state, "devbox", "named_workspaces.tsv")) as f:
            rows = [l for l in f.read().splitlines() if l and not l.startswith("#")]
        self.assertEqual(re.split(r"\t|  +", rows[0])[:3], ["fresh", "-", "Fresh page"])
        self.assertEqual([l[0] for l in self.registry_lines()], ["devonly"])  # devbox registry untouched

    def test_ws_terminal_mode_with_args(self):
        self.assertEqual(self.run_script("--ws", "docs", "Docs")[0], 0)
        self.assertIn('"ws:docs"', self.i3_calls())
        self.assertFalse(os.path.exists(self.registry))

    def test_rofi_cancel_does_nothing(self):
        self.fake_rofi(None)
        self.assertEqual(self.run_rofi()[0], 0)
        self.assertEqual(self.i3_calls(), "")

    def i3_calls(self):
        if not os.path.exists(self.log):
            return ""
        with open(self.log) as f:
            return f.read()

    def registry_lines(self):
        with open(self.registry) as f:
            return [l.rstrip("\n").split("\t") for l in f]

    def test_prompts_registers_and_moves(self):
        code, out = self.run_script(answers="alpha\nMy box\n\n")
        self.assertEqual(code, 0, out)
        self.assertIn('move container to workspace "dev:alpha"', self.i3_calls())
        (name, path, title, _when, kind), = self.registry_lines()
        self.assertEqual((name, path, title, kind), ("alpha", "-", "My box", "manual"))
        self.assertEqual(os.listdir(self.cwd), [])

    def test_prompt_yes_records_current_directory(self):
        code, out = self.run_script(answers="alpha\nMy box\ny\n")
        self.assertEqual(code, 0, out)
        self.assertIn("[y/N]", out)
        (name, path, title, _when, kind), = self.registry_lines()
        self.assertEqual((name, path, title), ("alpha", os.path.realpath(self.cwd), "My box"))

    def test_prompt_no_keeps_dash_and_ws_asks_too(self):
        self.assertEqual(self.run_script(answers="alpha\nMy box\nn\n")[0], 0)
        self.assertEqual(self.registry_lines()[0][1], "-")
        code, out = self.run_script("--ws", answers="docs\nDocs\ny\n")
        self.assertEqual(code, 0, out)
        with open(os.path.join(self.state, "devbox", "named_workspaces.tsv")) as f:
            rows = [l for l in f.read().splitlines() if l and not l.startswith("#")]
        self.assertEqual(re.split(r"\t|  +", rows[0])[1], os.path.realpath(self.cwd))

    def test_args_never_ask_about_directory(self):
        code, out = self.run_script("alpha", "one")
        self.assertEqual(code, 0, out)
        self.assertNotIn("directory", out)
        self.assertEqual(self.registry_lines()[0][1], "-")

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
        code, out = self.run_script("bad name", answers="ok\n\n\n")
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
