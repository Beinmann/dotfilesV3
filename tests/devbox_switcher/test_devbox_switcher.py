"""Tests for devbox_switcher.sh.

Fake i3-msg / fzf / tilix / notify-send on PATH record their calls in a log
file; the real i3_switch_workspace.sh is replaced by a recording stub next to
a copy of the script.

Run from the repo root:  python3 -m unittest discover tests/devbox_switcher
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT = os.path.join(REPO, "modules", "i3", ".config", "i3", "scripts", "devbox_switcher.sh")


class DevboxSwitcherTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = tmp.name
        self.log = os.path.join(self.dir, "calls.log")
        self.script = os.path.join(self.dir, "devbox_switcher.sh")
        shutil.copy(SCRIPT, self.script)
        self.stub("i3_switch_workspace.sh", 'echo "switch $*" >> "$LOG"')
        self.set_workspaces(["10", "dev:beta", "20", "dev:alpha"])
        self.registry = os.path.join(self.dir, "state", "devbox", "registry.tsv")
        self.stub("fzf", 'tee "$LOG.fzf" | head -n1')  # picks the first row; keeps the list
        self.stub("tilix", 'echo "tilix $*" >> "$LOG"')
        self.stub("notify-send", 'echo "notify $*" >> "$LOG"')

    def stub(self, name, body):
        path = os.path.join(self.dir, name)
        with open(path, "w") as f:
            f.write(f"#!/bin/sh\n{body}\n")
        os.chmod(path, 0o755)

    def set_workspaces(self, names, i3_up=True):
        data = os.path.join(self.dir, "ws.json")
        with open(data, "w") as f:
            json.dump([{"name": n} for n in names], f)
        self.stub("i3-msg", f'[ {"1" if i3_up else "0"} = 1 ] || exit 1\n'
                            f'[ "$2" = get_version ] && exit 0\ncat {data}')

    def run_script(self, *args):
        env = {"PATH": f"{self.dir}:/usr/bin:/bin", "LOG": self.log,
               "HOME": "/h", "XDG_STATE_HOME": os.path.join(self.dir, "state")}
        r = subprocess.run(["bash", self.script, *args], env=env,
                           capture_output=True, text=True)
        calls = ""
        if os.path.exists(self.log):
            with open(self.log) as f:
                calls = f.read()
        return r, calls

    def test_pick_switches_to_first_sorted_devbox(self):
        r, calls = self.run_script("--pick")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(calls, "switch dev:alpha\n")

    def write_registry(self, *lines):
        os.makedirs(os.path.dirname(self.registry), exist_ok=True)
        with open(self.registry, "w") as f:
            f.write("".join("\t".join(l) + "\n" for l in lines))

    def fzf_rows(self):
        with open(self.log + ".fzf") as f:
            return f.read().splitlines()

    def test_rows_show_path_name_and_title_from_registry(self):
        self.write_registry(
            ("alpha", "/h/proj/box", "Alpha box", "t"),
            ("beta", "-", "Remote thing", "t", "manual"),
            ("gone", "/h/x", "Not open", "t"))
        self.run_script("--pick")
        self.assertEqual(self.fzf_rows(),
                         ["alpha\t~/proj/box:alpha  Alpha box", "beta\tbeta  Remote thing"])

    def test_registry_title_equal_to_name_is_not_repeated_and_later_line_wins(self):
        self.write_registry(("alpha", "/old", "alpha", "t"), ("alpha", "/other/dir", "alpha", "t"))
        self.run_script("--pick")
        self.assertEqual(self.fzf_rows()[0], "alpha\t/other/dir:alpha")

    def test_missing_registry_shows_plain_names(self):
        self.run_script("--pick")
        self.assertEqual(self.fzf_rows(), ["alpha\talpha", "beta\tbeta"])

    def test_pick_cancelled_does_nothing(self):
        self.stub("fzf", "exit 130")
        r, calls = self.run_script("--pick")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(calls, "")

    def test_launcher_opens_floating_picker(self):
        r, calls = self.run_script()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("tilix --new-process --class=devbox_switcher", calls)
        self.assertIn("--pick", calls)

    def test_no_running_devboxes_notifies_and_fails(self):
        self.set_workspaces(["10", "20"])
        for args in ((), ("--pick",)):
            r, calls = self.run_script(*args)
            self.assertNotEqual(r.returncode, 0)
            self.assertIn("No running devboxes", calls)
            self.assertNotIn("tilix", calls)
            os.remove(self.log)

    def test_i3_unreachable_fails_loudly(self):
        self.set_workspaces(["dev:alpha"], i3_up=False)
        r, calls = self.run_script()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("i3 is not reachable", r.stderr)
        self.assertIn("notify", calls)
        self.assertNotIn("tilix", calls)

    def test_prefix_is_not_matched_in_the_middle(self):
        self.set_workspaces(["xdev:nope", "dev:real"])
        r, calls = self.run_script("--pick")
        self.assertEqual(calls, "switch dev:real\n")


if __name__ == "__main__":
    unittest.main()
