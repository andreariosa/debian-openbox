#!/usr/bin/env bash
# install.sh - Debian minimal post-install helper
#
# This script helps configure a minimal Debian installation with Openbox.
# It provides a menu-driven interface for system configuration, package
# installation, and theme application.
#
# Requires: bash 4.0+, sudo, apt
# Usage: sudo ./install.sh [--yes] [--help]

# shellcheck disable=SC1090  # Don't follow source
# shellcheck disable=SC1091  # Don't follow source
# shellcheck enable=require-variable-braces
# shellcheck enable=check-unassigned-uppercase

set -euo pipefail
IFS=$'\n\t'

# Check if running with sudo and validate user
if [[ -n "${SUDO_USER:-}" ]]; then
    INVOKER="$SUDO_USER"
    if ! id "$INVOKER" >/dev/null 2>&1; then
        echo "Invalid user: $INVOKER"
        exit 1
    fi
    INVOKER_HOME="$(getent passwd "$INVOKER" | cut -d: -f6)"
    if [[ ! -d "$INVOKER_HOME" ]] || [[ "$(stat -c %U "$INVOKER_HOME")" != "$INVOKER" ]]; then
        echo "Invalid or inaccessible home directory for user: $INVOKER"
        exit 1
    fi
else
    echo "Please run this script with sudo: sudo ./install.sh"
    exit 1
fi

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directories, files and flags
BASE_DIR="$INVOKER_HOME/.postinstall"
THEME_DIR="$SCRIPT_DIR/theme"
PACKAGES_FILE="$SCRIPT_DIR/packages.conf"
LOG_FILE="$BASE_DIR/install.log"
FIRST_RUN_FLAG="$BASE_DIR/.first_run_done"
YES_MODE=false

mkdir -p "$BASE_DIR"
touch "$LOG_FILE"
chown "$INVOKER":"$INVOKER" "$LOG_FILE" 2>/dev/null || true

# Load modules
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/base.sh"
source "$SCRIPT_DIR/lib/components.sh"
source "$SCRIPT_DIR/lib/openbox.sh"
source "$SCRIPT_DIR/lib/packages.sh"

# Handle args
for a in "$@"; do
    case "$a" in
        -y|--yes|--non-interactive) YES_MODE=true ;;
        -h|--help)
            cat <<EOF
install.sh - Debian minimal post-install helper

Usage:
  sudo ./install.sh         Interactive menu (but package installs automatic - apt-get -y)
  sudo ./install.sh --yes   Auto-yes mode for confirmation prompts in menus
EOF
            exit 0
            ;;
    esac
done

# Copy repo files into ~/.postinstall (non-destructive)
ensure_repo_files

# First-run auto flow
if [[ ! -f "$FIRST_RUN_FLAG" ]]; then
    log "Running first-time system setup..."
    update_sources
    system_upgrade
    configure_timezone
    configure_locale
    touch "$FIRST_RUN_FLAG"
    chown "$INVOKER":"$INVOKER" "$FIRST_RUN_FLAG" 2>/dev/null || true
    if $YES_MODE; then
        log "Non-interactive mode: initial setup complete."
        exit 0
    fi
    pause
else
    if $YES_MODE; then
        log "Non-interactive mode: no menu. Run without --yes to use the interactive menu."
        exit 0
    fi
fi

# Display the main menu and handle user input
# Returns: 0 on success, 1 on error
main_menu() {
    local choice

    while true; do
        clear
        echo -e "${BOLD}=== Debian Post-Install ===${RESET}"
        echo "1) System configuration (submenu)"
        echo "2) Components & Hardware (submenu)"
        echo "3) Install Openbox"
        echo "4) Apply Openbox theme"
        echo "5) Install optional packages"
        echo "6) Show install log ($LOG_FILE)"
        echo "0) Exit"
        
        if ! read -r -p "> " choice; then
            error "Failed to read user input"
            return 1
        fi

        # Validate input is a single digit
        if [[ ! "$choice" =~ ^[0-6]$ ]]; then
            warn "Invalid choice: $choice"
            pause
            continue
        fi

        case "$choice" in
            1) 
                if ! system_config_menu; then
                    error "System configuration failed"
                fi 
                ;;
            2) 
                if ! components_menu; then
                    error "Component configuration failed"
                fi 
                ;;
            3) 
                if ! install_openbox; then
                    error "Openbox installation failed"
                fi
                pause 
                ;;
            4) 
                if ! theme_menu; then
                    error "Theme application failed"
                fi 
                ;;
            5) 
                if ! parse_packages_conf; then
                    error "Package installation failed"
                fi
                pause 
                ;;
            6)
                if [[ ! -f "$LOG_FILE" ]]; then
                    error "Log file not found: $LOG_FILE"
                    pause
                    continue
                fi
                if ! less "$LOG_FILE"; then
                    warn "Failed to display log file"
                fi 
                ;;
            0) 
                log "Exiting normally"
                return 0 
                ;;
        esac
    done
}

log "Interactive menu started (base dir: $BASE_DIR)"
main_menu
