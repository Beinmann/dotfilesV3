#!/usr/bin/env python3
import os
import subprocess
import sys
import argparse

MODULE_LIST_FILE = ".module_list"
MODULES_DIR = "modules"
SYS_MODULES_DIR = "sys_modules"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Script for initializing or deinitializing stow dotfiles"
    )

    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-D", "--deinit",
        action="store_true",
        help="Unstow the dotfiles (remove all links)"
    )
    group.add_argument(
        "-R", "--restow",
        action="store_true",
        help="Unstow everything then stow again (useful after moving files)"
    )

    return parser.parse_args()

PERSISTENT_FILES = [
    ("~/.config/dotfiles/system_local", "bashrc.sh"),
    ("~/.config/dotfiles/system_local", "i3_config_addon"),
    ("~/.config/dotfiles/system_local", "gitconfig"),
    ("~/.config/dotfiles/system_local", "monitors.sh"),
]


class StowHelper:
    def __init__(self):
        self.args = parse_args()

    def ensure_persistent_files(self):
        for dir_path, filename in PERSISTENT_FILES:
            expanded = os.path.expanduser(dir_path)
            os.makedirs(expanded, exist_ok=True)
            filepath = os.path.join(expanded, filename)
            if not os.path.exists(filepath):
                open(filepath, "a").close()
                print(f"Created persistent file: {filepath}")

    def run_stow(self, target, directory, modules, deinit=False, sudo=False):
        if not modules:
            print(f"No modules to stow in {directory}")
            return
        cmd = ["stow", "-t", target, "-d", directory] + modules
        if deinit:
            cmd.insert(1, "-D")
        if sudo:
            cmd.insert(0, "sudo")
        print(f"Attempting to run: {' '.join(cmd)}")
        try:
            subprocess.run(cmd, check=True, stdin=subprocess.PIPE)
            print(f"Command finished without errors")
        except subprocess.CalledProcessError as e:
            print(f"Error running stow: {e}")
            sys.exit(1)

    def stow_all(self, home_modules, sys_modules, deinit=False):
        if home_modules:
            self.run_stow(os.environ["HOME"], MODULES_DIR, home_modules, deinit=deinit)
        if sys_modules:
            print("----------------------------------")
            print("System level modules detected in the module list")
            self.run_stow("/", SYS_MODULES_DIR, sys_modules, deinit=deinit, sudo=True)

    def main(self):
        self.ensure_persistent_files()

        if not os.path.isfile(MODULE_LIST_FILE):
            print("file module_list does not exist. Cannot initialize stow")
            print("Did you perhaps forget to rename it?")
            print()
            print("A template .module_list_template exists with the modules that should be loaded in stow")
            print("Copy and rename .module_list_template to module_list and optionally change which modules should get loaded.")
            print("This file will then get ignored by git.")
            sys.exit(0)

        # Load module list
        with open(MODULE_LIST_FILE) as f:
            modules = [line.strip() for line in f if line.strip() and not line.startswith("#")]
        home_modules = [m for m in modules if not m.startswith("sys/")]
        sys_modules = [m.removeprefix("sys/") for m in modules if m.startswith("sys/")]

        if self.args.restow:
            print("--- Unstowing ---")
            self.stow_all(home_modules, sys_modules, deinit=True)
            print("--- Stowing ---")
            self.stow_all(home_modules, sys_modules, deinit=False)
        else:
            self.stow_all(home_modules, sys_modules, deinit=self.args.deinit)

if __name__ == "__main__":
    StowHelper().main()
