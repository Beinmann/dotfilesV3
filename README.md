# dotfilesV3

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Each tool or concern lives in its own module — only the modules you activate get symlinked into your home directory.

## What is this?

A modular dotfiles setup for a Linux desktop running i3. The core idea is that every piece of configuration belongs to a specific module. Activating a module symlinks its files into `$HOME` using stow; deactivating removes them. This makes it easy to maintain different configurations across machines (e.g. with or without laptop-specific tweaks, with or without AI tooling).

---

## Setup

### Prerequisites

Install required packages (i3, stow, neovim, tilix, rofi, i3blocks, picom, and others):

```bash
bash Scripts/Initialization_and_Saving_State_Scripts/apt_install_programs.sh
```

### Initialize submodules

```bash
git submodule update --init --recursive
```

This pulls in the nvim config, RAM monitor script, and i3blocks-contrib scripts.

### Resolve conflicts first

Stow creates symlinks from this repo into your home directory. If files like `~/.bashrc` or `~/.profile` already exist (as they do on a fresh Debian/Ubuntu install), stow will refuse to overwrite them. You need to **remove or back up any conflicting files before stowing**.

Common conflicts to check:
- `~/.bashrc`
- `~/.bash_profile`
- `~/.profile`

### Configure which modules to activate

Copy the template module list and edit it for your machine:

```bash
cp .module_list_template .module_list
```

The `.module_list` file is gitignored — it's per-machine. Uncomment or add the modules you want. See the Modules section below.

### Stow

```bash
python3 init_or_deinit_stow.py
```

Other options:
```bash
python3 init_or_deinit_stow.py -D   # unstow everything (remove all symlinks)
python3 init_or_deinit_stow.py -R   # restow (unstow then stow again, useful after moving files)
```

---

## Modules

| Module | Description |
|---|---|
| `base` | Core shell setup: `.bashrc`, shell settings, aliases, functions, plugins. The foundation — should always be active. |
| `i3` | Full i3 window manager configuration including i3blocks status bar, workspace scripts, and the i3blocks-contrib scripts as a submodule. |
| `nvim` | Neovim configuration (submodule pointing to a separate nvim config repo). |
| `vim` | Vim configuration for when neovim isn't available. |
| `scripts` | Miscellaneous helper scripts (RAM monitor etc.) managed as submodules. |
| `services` | Systemd user services. |
| `ai` | AI tooling — Claude usage monitor script and shell alias. Opt-in: only activate on machines where you use Claude. |
| `laptop_adaptations` | Laptop-specific tweaks (touchpad natural scrolling, tapping). Opt-in: activate on laptops instead of or alongside `base`. |

### Module conventions

Shell aliases, functions, and plugin/tool integrations that are module-specific live under:

```
~/.config/bash_dotfiles/
  aliases.d/      # one .sh file per module
  functions.d/    # one .sh file per module
  plugins.d/      # one .sh file per module
  settings.d/     # one .sh file per module
```

These directories are glob-sourced by `.bashrc` at shell startup. If a module isn't stowed, its file doesn't exist and nothing is loaded — no conditionals needed.

---

## Repository structure

```
dotfilesV3/
├── modules/               # one directory per module, stowed to $HOME
├── sys_modules/           # modules stowed to / (requires sudo stow)
├── Scripts/               # repo-level utility scripts (not stowed)
├── init_or_deinit_stow.py # stow helper
├── .module_list_template  # template for per-machine module selection
└── .module_list           # your active modules (gitignored)
```

`sys_modules` works the same as `modules` but targets `/` as the stow target instead of `$HOME`. Use it for system-wide config files (e.g. under `/etc`). Activate these by prefixing the module name with `sys/` in `.module_list`, e.g. `sys/base`.
