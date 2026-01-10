A small, script-driven Debian post-install helper that sets up an Openbox-based desktop environment with optional themes and helper components.

This repository provides a convenient, idempotent set of shell scripts to:

- Configure basic system settings (locale, timezone, apt sources).
- Install Openbox and optional components (display manager, GPU drivers, audio).
- Apply user configuration themes (Openbox, polybar, picom).

## Highlights

- Intent: fast post-install setup for Debian systems using Openbox.
- Scripts live under `lib/` and are sourced by the top-level `install.sh`.
- Themes are kept in `theme/` (clean, dark, light). Theme files are copied into the invoking user's `~/.config/` directory when applying a theme.

## Quick start

Run on a Debian system as root (recommended via sudo). From the repo root, make the installation script executable:

```bash
chmod +x install.sh
```

Interactive mode:

```bash
sudo ./install.sh
```

Non-interactive (auto-yes) mode:

```bash
sudo ./install.sh --yes
```

## Install Debian and prerequisites

Recommended configuration for a minimal Debian setup:

1. Install Debian netinstall image.
2. During install, do not select `Debian desktop environment`; only select `standard system utilities`.
3. After the first boot, add your user to sudo, then reboot:

```bash
su -
apt install -y sudo
usermod -aG sudo <username>
reboot
```

4. Install git and clone the repo:

```bash
sudo apt install -y git
git clone https://github.com/andreariosa/debian-openbox
cd debian-openbox
```

Notes:

- The script expects to be run on Debian or a Debian-derivative where package names (e.g. `polybar`, `picom`) are available from apt.
- Some optional packages (e.g. `code`) require external repositories. Either add the repo first or remove those entries from `packages.conf`.
- Package categories are displayed in the same order as they appear in `packages.conf`. Duplicate package entries are ignored.
- The main menu includes "Session defaults (Openbox)" to set Openbox as the default session or restore the previous default.

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

## Available Packages and Components

| Section    | Subsection       | Option | Package Name(s)                                                                                                                                                                                                                                              | Purpose                                                  | Rationale                                                                                       |
| ---------- | ---------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Base       | Configure Locale | 1 [1]  | [`locales`](https://packages.debian.org/search?keywords=locales)                                                                                                                                                                                             | Manages system language, timezone, and regional settings | Required on minimal Debian installs; keeps system properly localized without extra dependencies |
| Components | Display Manager  | 1 [2]  | [`lightdm`](https://packages.debian.org/search?keywords=lightdm)                                                                                                                                                                                             | Lightweight graphical login manager                      | Very fast, low memory usage, and commonly paired with Openbox                                   |
| Components | Display Manager  | 2 [2]  | [`sddm`](https://packages.debian.org/search?keywords=sddm)                                                                                                                                                                                                   | Qt-based graphical login manager                         | Alternative DM, useful if Qt-based environments or themes are preferred                         |
| Components | GPU Drivers      | 1 [5]  | [`firmware-misc-nonfree`](https://packages.debian.org/search?keywords=firmware-misc-nonfree)                                                                                                                                                                 | Non-free firmware for various GPUs                       | Improves hardware compatibility on real machines                                                |
| Components | GPU Drivers      | 2 [5]  | [`nvidia-driver`](https://packages.debian.org/search?keywords=nvidia-driver)                                                                                                                                                                                 | Official NVIDIA proprietary driver                       | Best performance and stability for NVIDIA GPUs                                                  |
| Components | GPU Drivers      | 3 [5]  | [`firmware-amd-graphics`](https://packages.debian.org/search?keywords=firmware-amd-graphics)                                                                                                                                                                 | AMD GPU firmware                                         | Required for modern AMD GPUs on Debian                                                          |
| Components | GPU Drivers      | 4 [5]  | [`xserver-xorg-video-intel`](https://packages.debian.org/search?keywords=xserver-xorg-video-intel)                                                                                                                                                           | Intel Xorg video driver                                  | Ensures proper acceleration on Intel iGPUs                                                      |
| Components | GPU Drivers      | 5 [5]  | [`virtualbox-guest-dkms` `virtualbox-guest-x11` `virtualbox-guest-utils`](https://www.virtualbox.org/manual/ch04.html)                                                                                                                                       | VirtualBox guest drivers and utilities                   | Enables graphics acceleration, clipboard, and screen resizing in VirtualBox                     |
| Components | Audio Stack      | 1 [2]  | [`pipewire`](https://packages.debian.org/search?keywords=pipewire) [`wireplumber`](https://packages.debian.org/search?keywords=wireplumber) [`pipewire-audio-client-libraries`](https://packages.debian.org/search?keywords=pipewire-audio-client-libraries) | Modern audio and media server                            | Replaces PulseAudio with lower latency and better flexibility                                   |
| Components | Audio Stack      | 2 [2]  | [`pulseaudio`](https://packages.debian.org/search?keywords=pulseaudio) [`pulseaudio-utils`](https://packages.debian.org/search?keywords=pulseaudio-utils)                                                                                                    | Legacy audio server and tools                            | Kept as a stable fallback for maximum compatibility                                             |
| Components | Timeshift        | 1 [1]  | [`timeshift`](https://packages.debian.org/search?keywords=timeshift)                                                                                                                                                                                         | System snapshot and restore utility                      | Adds safety to a minimal system without affecting performance                                   |

### Openbox Desktop Stack

Packages are listed in installation and dependency **order**.

| Subsection     | Package Name(s)                                                                      | Purpose                                 | Rationale                                                   |
| -------------- | ------------------------------------------------------------------------------------ | --------------------------------------- | ----------------------------------------------------------- |
| X Server       | [`xorg`](https://packages.debian.org/search?keywords=xorg)                           | Core X11 windowing system               | Mandatory graphical foundation for Openbox                  |
| X Utilities    | [`x11-xserver-utils`](https://packages.debian.org/search?keywords=x11-xserver-utils) | X11 helper tools (xset, xrandr, etc.)   | Required for display, input, and power management           |
| Window Manager | [`openbox`](https://packages.debian.org/search?keywords=openbox)                     | Lightweight window manager              | Core of the desktop; minimal, fast, and highly configurable |
| Configuration  | [`obconf`](https://packages.debian.org/search?keywords=obconf)                       | GUI tool to configure Openbox           | Simplifies Openbox configuration without heavy dependencies |
| Menu           | [`menu`](https://packages.debian.org/search?keywords=menu)                           | Generates dynamic application menus     | Integrates cleanly with Openbox and Debian package system   |
| Wallpaper      | [`nitrogen`](https://packages.debian.org/search?keywords=nitrogen)                   | Wallpaper manager                       | Simple, lightweight, and Openbox-friendly                   |
| Compositor     | [`picom`](https://packages.debian.org/search?keywords=picom)                         | Compositor for transparency and effects | Adds modern visuals without impacting performance           |
| Panel          | [`polybar`](https://packages.debian.org/search?keywords=polybar)                     | Status bar and system panel             | Highly customizable replacement for traditional panels      |

Notes: **GTK theme managers** (e.g. `lxappearance`) are intentionally not installed. The script automatically generates GTK configuration files, which can later be manually edited if needed.

## Themes & panel

This project ships minimal theme templates under `theme/`. The installer can copy these templates into the invoking user's `~/.config/` directory when you apply a theme via the interactive menu.

Note: the project uses `polybar` in place of `tint2` for the panel. The repo does not ship a full `polybar` config; customize `~/.config/polybar/config` to match your bar name and launch command.

## Customization

- To add a theme: create a `clean`, `dark`, or `light` subdirectory under `theme/` and add `openbox/`, `polybar/`, and `picom/` subfolders with files.
- To change packaged components, edit the apt commands in `lib/openbox.sh` or the related functions in `lib/components.sh`.
- Non-interactive automation: use `--yes` / `-y` when running `install.sh`.

## Troubleshooting

- If a package fails to install, check `/home/<invoker>/.postinstall/install.log` (the exact path is printed by the installer). The scripts log stdout/stderr for run commands into this log.
- If theme files are not applied, verify permissions and that `$INVOKER_HOME` is writable by the installer or adjusted afterward.
- If an optional package is missing, confirm the package exists in your Debian version or add the required external repo before running the installer.

## Contributing

Contributions are welcome. When modifying behavior or adding new themes:

1. Make changes in `lib/` and add theme files under `theme/`.
2. Test locally by running `sudo ./install.sh` on a disposable Debian VM.
3. Open a pull request with a clear description of changes and rationale.

## Notes & safety

- These scripts perform system modifications and install packages as root. Review the scripts before running on production systems.
- The project aims to be conservative about overwriting user files: the theme application backs up existing config files under `~/.postinstall/backups/`.
