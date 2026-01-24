_A small, script-driven Debian post-install helper that sets up an Openbox-based desktop environment with optional themes and helper components._

## Scope

- Configure system locale, timezone, and package sources.
- Install and configure Openbox with minimal dependencies.
- Deploy optional components (display manager, GPU drivers, audio stack).
- Apply user configuration themes (Openbox, Picom, Polybar, Rofi).
- Provide idempotent, reusable shell library for automation.

## Non-goals

- Heavy desktop environment setup or feature bloat.
- Graphical package manager or advanced configuration tools.
- Distribution of binary packages or rolling releases.
- Support for non-Debian systems (though derivatives may work).

## Overview

The installation consists of idempotent shell scripts located in `lib/`, sourced by the main `install.sh` entry point. User themes are stored in `theme/` and copied to `~/.config/` when applied via the interactive menu.

## Installation

### Prerequisites

- Debian system (or compatible derivative) with sudo access.
- Minimal system installation (excluding pre-installed desktop environments).
- Git.

### Quick Start

Clone the repository and execute the installation script:

```bash
git clone https://github.com/andreariosa/debian-openbox
cd debian-openbox
chmod +x install.sh
sudo ./install.sh
```

The installer will present an interactive menu. To automate responses:

```bash
sudo ./install.sh --yes
```

### Recommended Base System

Begin with a fresh Debian minimal installation:

1. Boot the Debian netinstall image.
2. During installation, deselect `Debian desktop environment` and select only `standard system utilities`.
3. After first boot, grant sudo privileges to your user:

```bash
su -
apt install -y sudo
usermod -aG sudo <username>
reboot
```

4. Install git and clone the repository:

```bash
sudo apt install -y git
```

### Usage Notes

- Scripts assume Debian or compatible derivatives with standard package naming (e.g., `picom`, `polybar` available via apt).
- Optional packages requiring external repositories (e.g., `code`) must have those repos added beforehand, or entries removed from `packages.conf`.
- Package categories are processed in `packages.conf` order; duplicates are silently ignored.
- The main menu includes a "Session defaults" option to set Openbox as the default session.

## Directory Structure

```
.
├── install.sh           Main entry point and interactive menu
├── packages.conf        Package category configuration
├── README.md            This file
├── lib/                 Library scripts
│   ├── base.sh          System configuration (apt sources, timezone, locale)
│   ├── components.sh    Optional components (display manager, GPU, audio)
│   ├── openbox.sh       Openbox and desktop stack installation
│   ├── packages.sh      Package parsing and theme deployment
│   └── utils.sh         Utilities (logging, prompts, helpers)
└── theme/               Theme templates
    └── clean/           Clean theme (default)
        ├── openbox/     Openbox configuration
        ├── picom/       Compositor configuration
        ├── polybar/     Status bar configuration
        └── rofi/        Application launcher configuration
```

## Package Reference

Regarding VirtualBox guest drivers and utilities, refer to the official manual: [https://www.virtualbox.org/manual/ch04.html](https://www.virtualbox.org/manual/ch04.html)

| Section    | Subsection       | Option | Package Name(s)                                                                                                                                                                                                                                              | Purpose                                                  | Rationale                                                                                       |
| ---------- | ---------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Base       | Configure Locale | 1 [1]  | [`locales`](https://packages.debian.org/search?keywords=locales)                                                                                                                                                                                             | Manages system language, timezone, and regional settings | Required on minimal Debian installs; keeps system properly localized without extra dependencies |
| Components | Display Manager  | 1 [2]  | [`lightdm`](https://packages.debian.org/search?keywords=lightdm)                                                                                                                                                                                             | Lightweight graphical login manager                      | Very fast, low memory usage, and commonly paired with Openbox                                   |
| Components | Display Manager  | 2 [2]  | [`sddm`](https://packages.debian.org/search?keywords=sddm)                                                                                                                                                                                                   | Qt-based graphical login manager                         | Alternative DM, useful if Qt-based environments or themes are preferred                         |
| Components | GPU Drivers      | 1 [5]  | [`firmware-misc-nonfree`](https://packages.debian.org/search?keywords=firmware-misc-nonfree)                                                                                                                                                                 | Non-free firmware for various GPUs                       | Improves hardware compatibility on real machines                                                |
| Components | GPU Drivers      | 2 [5]  | [`nvidia-driver`](https://packages.debian.org/search?keywords=nvidia-driver)                                                                                                                                                                                 | Official NVIDIA proprietary driver                       | Best performance and stability for NVIDIA GPUs                                                  |
| Components | GPU Drivers      | 3 [5]  | [`firmware-amd-graphics`](https://packages.debian.org/search?keywords=firmware-amd-graphics)                                                                                                                                                                 | AMD GPU firmware                                         | Required for modern AMD GPUs on Debian                                                          |
| Components | GPU Drivers      | 4 [5]  | [`xserver-xorg-video-intel`](https://packages.debian.org/search?keywords=xserver-xorg-video-intel)                                                                                                                                                           | Intel Xorg video driver                                  | Ensures proper acceleration on Intel iGPUs                                                      |
| Components | GPU Drivers      | 5 [5]  | `virtualbox-guest-dkms` `virtualbox-guest-x11` `virtualbox-guest-utils`                                                                                                                                                                                      | VirtualBox guest drivers and utilities                   | Enables graphics acceleration, clipboard, and screen resizing in VirtualBox                     |
| Components | Audio Stack      | 1 [2]  | [`pipewire`](https://packages.debian.org/search?keywords=pipewire) [`wireplumber`](https://packages.debian.org/search?keywords=wireplumber) [`pipewire-audio-client-libraries`](https://packages.debian.org/search?keywords=pipewire-audio-client-libraries) | Modern audio and media server                            | Replaces PulseAudio with lower latency and better flexibility                                   |
| Components | Audio Stack      | 2 [2]  | [`pulseaudio`](https://packages.debian.org/search?keywords=pulseaudio) [`pulseaudio-utils`](https://packages.debian.org/search?keywords=pulseaudio-utils)                                                                                                    | Legacy audio server and tools                            | Kept as a stable fallback for maximum compatibility                                             |
| Components | Timeshift        | 1 [1]  | [`timeshift`](https://packages.debian.org/search?keywords=timeshift)                                                                                                                                                                                         | System snapshot and restore utility                      | Adds safety to a minimal system without affecting performance                                   |

### Openbox Desktop Stack

Packages are listed in installation and dependency order.

| Subsection     | Package Name(s)                                                                                                                   | Purpose                                 | Rationale                                                          |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------ |
| X Server       | [`xorg`](https://packages.debian.org/search?keywords=xorg)                                                                        | Core X11 windowing system               | Mandatory graphical foundation for Openbox                         |
| X Utilities    | [`x11-xserver-utils`](https://packages.debian.org/search?keywords=x11-xserver-utils)                                              | X11 helper tools (xset, xrandr, etc.)   | Required for display, input, and power management                  |
| Window Manager | [`openbox`](https://packages.debian.org/search?keywords=openbox)                                                                  | Lightweight window manager              | Core of the desktop; minimal, fast, and highly configurable        |
| Configuration  | [`obconf`](https://packages.debian.org/search?keywords=obconf)                                                                    | GUI tool to configure Openbox           | Simplifies Openbox configuration without heavy dependencies        |
| Launcher       | [`rofi`](https://packages.debian.org/search?keywords=rofi) [`fonts-noto`](https://packages.debian.org/search?keywords=fonts-noto) | Application launcher and dynamic menus  | Lightweight launcher, integrates well with Openbox and user themes |
| Wallpaper      | [`nitrogen`](https://packages.debian.org/search?keywords=nitrogen)                                                                | Wallpaper manager                       | Simple, lightweight, and Openbox-friendly                          |
| Compositor     | [`picom`](https://packages.debian.org/search?keywords=picom)                                                                      | Compositor for transparency and effects | Adds modern visuals without impacting performance                  |
| Panel          | [`polybar`](https://packages.debian.org/search?keywords=polybar)                                                                  | Status bar and system panel             | Highly customizable replacement for traditional panels             |

**Note:** GTK theme managers (e.g., `lxappearance`) are intentionally excluded. The installer automatically generates GTK configuration files, which can be edited manually as needed.

## Themes

Minimal theme templates are provided in `theme/`. When a theme is selected via the interactive menu, the installer copies templates into the invoking user's `~/.config/` directory.

The default theme is `clean`. Additional themes can be created by adding subdirectories with `openbox/`, `picom/`, `polybar/` and `rofi/` configuration subdirectories.

**Panel:** The project uses `polybar` instead of `tint2`. No complete `polybar` configuration is shipped; users should customize `~/.config/polybar/config` with appropriate module names and launch commands.

## Configuration

### Adding Themes

Create a theme subdirectory under `theme/` (e.g., `dark`, `light`) containing:

```
theme/
└── dark/
    ├── openbox/
    │   ├── rc.xml
    │   ├── menu.xml
    │   └── autostart
    ├── picom/
    │   └── picom.conf
    ├── polybar/
    │   └── config.ini
    ├── rofi/
    │   └── config.rasi
    ├── .Xresources (Optional)
    └── .themes/ (Optional)
        └── (Openbox theme directories)
```

- **openbox/, picom/, polybar/, rofi/**: Configuration directories for each component. Files in these directories are copied to the corresponding `~/.config/` directories.
- **.Xresources**: Optional X11 resource configuration file. If present, it will be installed to `~/.Xresources` in the user's home directory with user confirmation (automatically accepted in `--yes` mode).
- **.themes/**: Optional directory containing Openbox theme directories. If present, the entire `.themes` folder will be copied to `~/.themes` in the user's home directory with user confirmation (automatically accepted in `--yes` mode). This allows bundling Openbox themes with your configuration.

### Modifying Components

Edit package lists in `lib/openbox.sh` and component functions in `lib/components.sh` to add or remove packages.

### Non-interactive Mode

Use the `--yes` / `-y` flag to bypass all prompts:

```bash
sudo ./install.sh -y
```

## Troubleshooting

### Installation Failures

The installer logs all commands to `~/.postinstall/install.log` (exact path printed during execution). Review this log for package or command failures:

```bash
tail -f ~/.postinstall/install.log
```

### Theme Application Issues

If theme files are not copied to `~/.config/`, verify:

- Invoking user has write permissions to `~/.config/`.
- `$INVOKER_HOME` is correctly set in the environment.
- Theme directory structure matches expectations.

### Missing Packages

Confirm the package exists in your Debian release with `apt search <package>`. For packages requiring external repositories, add the repository before running the installer or remove the entry from `packages.conf`.

## Contributing

Contributions are welcome. When proposing changes:

1. Modify scripts in `lib/` or add theme templates to `theme/`.
2. Test thoroughly on a disposable Debian system.
3. Submit a pull request with clear description and rationale.

### Future Improvements

- Improve the`Dark modern` and `Light modern` themes by porting and adapting the [`Arc-Dark`](https://github.com/dglava/arc-openbox/tree/master/Arc-Dark/openbox-3) and [`Arc`](https://github.com/dglava/arc-openbox/tree/master/Arc/openbox-3) Openbox themes (dglava/arc-openbox), including Openbox files (rc.xml, themerc) and associated assets to produce polished dark and light variants that match the installer's defaults.
- Add concise markdown documentation linking to external Openbox, Picom, Polybar, Rofi and X11 theming references to help users design and maintain custom themes.
- Introduce optional graphical automation for X11-based sessions using tools such as `wmctrl` and `xdotool` to enable reproducible session layouts and scripted desktop workflows.

## Security Considerations

- These scripts perform system modifications with root privileges. **Review all scripts before executing on production systems.**
- The installer creates backups of existing configuration files in `~/.postinstall/backups/` before applying themes.
- All logging occurs in `~/.postinstall/install.log` for auditability.
