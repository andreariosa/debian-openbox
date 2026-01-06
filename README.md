A small, script-driven Debian post-install helper that sets up an Openbox-based
desktop environment with optional themes and helper components.

This repository provides a convenient, idempotent set of shell scripts to:

- configure basic system settings (locale, timezone, apt sources)
- install Openbox and optional components (display manager, GPU drivers, audio)
- apply user configuration themes (Openbox, polybar, picom)

## Highlights

- Intent: fast post-install setup for Debian systems using Openbox.
- Scripts live under `lib/` and are sourced by the top-level `install.sh`.
- Themes are kept in `theme/` (clean, dark, light). Theme files are copied into
  the invoking user's `~/.config/` directory when applying a theme.

## Quick start

Run on a Debian system as root (recommended via sudo). From the repo root:

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/andreariosa/debian-openbox.git
cd debian-openbox
chmod +x install.sh
sudo ./install.sh
```

Non-interactive (auto-yes) mode:

```bash
sudo ./install.sh --yes
```

Notes:

- The script expects to be run on Debian or a Debian-derivative where package
  names (e.g. `polybar`, `picom`) are available from apt.
- Some optional packages (e.g. `code`) require external repositories. Either
  add the repo first or remove those entries from `packages.conf`.
- Package categories are displayed in the same order as they appear in
  `packages.conf`. Duplicate package entries are ignored.

## Repository layout

- `install.sh` - main entrypoint and interactive menu
- `lib/` - scripts implementing actions and helpers
  - `utils.sh` - logging, prompts, and helper utilities
  - `base.sh` - system-level setup (apt sources, timezone, locale)
  - `components.sh` - optional components (DM, GPU, audio, snapshots)
  - `openbox.sh` - install Openbox and related packages
  - `packages.sh` - package-category parsing and theme application
- `theme/` - theme templates (clean, dark, light)
- `packages.conf` - optional package categories

## Themes & panel

This project ships minimal theme templates under `theme/`. The installer can
copy these templates into the invoking user's `~/.config/` directory when you
apply a theme via the interactive menu.

Note: the project uses `polybar` in place of `tint2` for the panel. The repo
does not ship a full `polybar` config; customize `~/.config/polybar/config` to
match your bar name and launch command.

## Customization

- To add a theme: create a `clean`, `dark`, or `light` subdirectory under
  `theme/` and add `openbox/`, `polybar/`, and `picom/` subfolders with files.
- To change packaged components, edit the apt commands in `lib/openbox.sh` or
  the related functions in `lib/components.sh`.
- Non-interactive automation: use `--yes` / `-y` when running `install.sh`.

## Troubleshooting

- If a package fails to install, check `/home/<invoker>/.postinstall/install.log`
  (the exact path is printed by the installer). The scripts log stdout/stderr
  for run commands into this log.
- If theme files are not applied, verify permissions and that `$INVOKER_HOME`
  is writable by the installer or adjusted afterward.
- If an optional package is missing, confirm the package exists in your Debian
  version or add the required external repo before running the installer.

## Contributing

Contributions are welcome. When modifying behavior or adding new themes:

1. Make changes in `lib/` and add theme files under `theme/`.
2. Test locally by running `sudo ./install.sh` on a disposable Debian VM.
3. Open a pull request with a clear description of changes and rationale.

## Notes & safety

- These scripts perform system modifications and install packages as root.
  Review the scripts before running on production systems.
- The project aims to be conservative about overwriting user files: the theme
  application backs up existing config files under `~/.postinstall/backups/`.
