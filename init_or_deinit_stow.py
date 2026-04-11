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

    parser.add_argument(
        "-D", "--deinit",
        action="store_true",
        help="Instead of stowing the dotfiles it will unstow them (remove all links)"
    )

    args = parser.parse_args()

    return args

class StowHelper:
    def __init__(self):
        self.args = parse_args()

    def run_stow(self, target, directory, modules, sudo=False):
        """Run stow for the given target and module directory."""
        if not modules:
            print(f"No modules to stow in {directory}")
            return
        cmd = ["stow", "-t", target, "-d", directory] + modules
        if self.args.deinit:
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


    def main(self):
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

        # Stow home modules
        if home_modules:
            self.run_stow(os.environ["HOME"], MODULES_DIR, home_modules)

        # Stow system modules (requires sudo)
        if sys_modules:
            print("----------------------------------")
            print("System level modules detected in the module list")
            self.run_stow("/", SYS_MODULES_DIR, sys_modules, sudo=True)

if __name__ == "__main__":
    StowHelper().main()
