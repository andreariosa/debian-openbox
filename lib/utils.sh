# lib/utils.sh
#
# Utility functions: logging, command execution, user prompts,
# package operations, and repository file management.

# Prevent accidental standalone execution.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "This script must be sourced, not executed directly."
    exit 1
fi

# Color codes for terminal output.
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
BOLD="\033[1m"
RESET="\033[0m"

# === Logging Helpers ===

# Log message with [LOG] prefix in blue.
log() { echo -e "${BLUE}[LOG]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*"; }

# Log message with timestamp to $LOG_FILE and echo to stdout.
log_file() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*" | tee -a "$LOG_FILE"
}

# === Command Execution ===

# Execute command with environment variables, capture output to $LOG_FILE.
# Supports leading VAR=value arguments. Reports errors with tail of log.
run() {
    if [[ $# -eq 0 ]]; then
        error "run: missing command"
        return 1
    fi
    local cmd_display=""
    local part
    for part in "$@"; do
        cmd_display+="$(printf '%q ' "$part")"
    done
    cmd_display="${cmd_display% }"
    log "CMD: $cmd_display"
    local -a env_kv=()
    local -a cmd=()
    local arg
    for arg in "$@"; do
        if [[ ${#cmd[@]} -eq 0 ]] && [[ "$arg" == *=* ]]; then
            env_kv+=("$arg")
        else
            cmd+=("$arg")
        fi
    done
    if [[ ${#cmd[@]} -eq 0 ]]; then
        error "run: missing command"
        return 1
    fi
    if [[ ${#env_kv[@]} -gt 0 ]]; then
        if ! env "${env_kv[@]}" "${cmd[@]}" >>"$LOG_FILE" 2>&1; then
            error "Command failed: $cmd_display"
            tail -n 5 "$LOG_FILE" || true
            return 1
        fi
        return 0
    fi
    if ! "${cmd[@]}" >>"$LOG_FILE" 2>&1; then
        error "Command failed: $cmd_display"
        tail -n 5 "$LOG_FILE" || true
        return 1
    fi
    return 0
}

# Execute command with output displayed to terminal and logged to $LOG_FILE.
# Supports environment variables. Useful for interactive commands.
run_with_output() {
    if [[ $# -eq 0 ]]; then
        error "run_with_output: missing command"
        return 1
    fi
    local cmd_display=""
    local part
    for part in "$@"; do
        cmd_display+="$(printf '%q ' "$part")"
    done
    cmd_display="${cmd_display% }"
    log "CMD: $cmd_display"
    local -a env_kv=()
    local -a cmd=()
    local arg
    for arg in "$@"; do
        if [[ ${#cmd[@]} -eq 0 ]] && [[ "$arg" == *=* ]]; then
            env_kv+=("$arg")
        else
            cmd+=("$arg")
        fi
    done
    if [[ ${#cmd[@]} -eq 0 ]]; then
        error "run_with_output: missing command"
        return 1
    fi
    if [[ ${#env_kv[@]} -gt 0 ]]; then
        if ! env "${env_kv[@]}" "${cmd[@]}" 2>&1 | tee -a "$LOG_FILE"; then
            error "Command failed: $cmd_display"
            tail -n 5 "$LOG_FILE" || true
            return 1
        fi
        return 0
    fi
    if ! "${cmd[@]}" 2>&1 | tee -a "$LOG_FILE"; then
        error "Command failed: $cmd_display"
        tail -n 5 "$LOG_FILE" || true
        return 1
    fi
    return 0
}

# Execute command with live terminal logging via `script` command if available.
# Preserves interactive behavior and TTY for password prompts.
run_with_tty_log() {
    if [[ $# -eq 0 ]]; then
        error "run_with_tty_log: missing command"
        return 1
    fi
    local cmd_display=""
    local part
    for part in "$@"; do
        cmd_display+="$(printf '%q ' "$part")"
    done
    cmd_display="${cmd_display% }"
    log "CMD: $cmd_display"
    if command -v script >/dev/null 2>&1; then
        local cmd_str=""
        for part in "$@"; do
            cmd_str+="$(printf '%q ' "$part")"
        done
        cmd_str="${cmd_str% }"
        if ! script -q -a -f -c "$cmd_str" "$LOG_FILE"; then
            error "Command failed: $cmd_display"
            tail -n 5 "$LOG_FILE" || true
            return 1
        fi
        return 0
    fi
    warn "script not found; running without live log"
    if ! "$@"; then
        error "Command failed: $cmd_display"
        return 1
    fi
    return 0
}

# === Package Installation ===

# Install packages via apt-get in non-interactive or interactive mode.
apt_install() {
    if $YES_MODE; then
        run env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical \
            apt-get install -y -o Dpkg::Use-Pty=0 "$@"
    else
        run_with_tty_log apt-get install "$@"
    fi
}

# Install packages with visual progress indicator. Prefers interactive TTY mode.
apt_install_progress() {
    if $YES_MODE; then
        if ! run_with_output env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical \
            apt-get install -y --show-progress -o Dpkg::Use-Pty=0 "$@"; then
            run env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical \
                apt-get install -y -o Dpkg::Use-Pty=0 "$@"
        fi
    else
        run_with_tty_log apt-get install --show-progress "$@"
    fi
}

# Check if package is available in apt cache.
package_available() {
    local pkg="$1"
    local candidate
    candidate="$(LC_ALL=C apt-cache policy "$pkg" 2>/dev/null | awk '/^Candidate:/ {print $2; exit}')"
    [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

# === User Prompts & Interaction ===

# Wait for user to press ENTER.
pause() {
    read -rp "$(echo -e ${BOLD}Press ENTER to continue...${RESET})";
}

# Ask yes/no question. In YES_MODE, always returns 0 (yes).
ask() {
    local q="$1"
    if $YES_MODE; then
        log "[auto-yes] $q"
        return 0
    fi
    read -rp "$q [y/N]: " ans
    case "$ans" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# === Repository File Management ===

# Set up repository files in ~/.postinstall: packages.conf, theme templates.
# Handles backup creation, permission management, and ownership transfers.
ensure_repo_files() {
    local errors=0

    # Create BASE_DIR with proper permissions
    if ! mkdir -p "$BASE_DIR"; then
        error "Failed to create $BASE_DIR"
        return 1
    fi

    if ! chmod 755 "$BASE_DIR"; then
        error "Failed to set permissions on $BASE_DIR"
        return 1
    fi

    # Copy packages.conf if it exists
    if [[ -f "$PACKAGES_FILE" ]]; then
        if ! cp -f "$PACKAGES_FILE" "$BASE_DIR/packages.conf.tmp"; then
            error "Failed to copy packages.conf"
            return 1
        fi

        if ! mv -f "$BASE_DIR/packages.conf.tmp" "$BASE_DIR/packages.conf"; then
            error "Failed to move packages.conf into place"
            rm -f "$BASE_DIR/packages.conf.tmp"
            return 1
        fi

        if ! chown "$INVOKER":"$INVOKER" "$BASE_DIR/packages.conf" 2>/dev/null; then
            warn "Failed to set ownership of packages.conf"
            ((errors++))
        fi

        if ! chmod 644 "$BASE_DIR/packages.conf"; then
            warn "Failed to set permissions on packages.conf"
            ((errors++))
        fi

        log "Copied packages.conf to $BASE_DIR/packages.conf"
    else
        log "No packages.conf found in repo ($PACKAGES_FILE)"
    fi

    # Copy theme configurations
    if [[ -d "$THEME_DIR" ]]; then
        if ! mkdir -p "$BASE_DIR/config"; then
            error "Failed to create config directory"
            return 1
        fi

        if ! chmod 755 "$BASE_DIR/config"; then
            warn "Failed to set permissions on config directory"
            ((errors++))
        fi

        # Copy theme folders if present
        for t in clean dark light; do
            if [[ -d "$THEME_DIR/$t" ]]; then
                if [[ -d "$BASE_DIR/config/$t" ]]; then
                    log "Theme $t already exists in $BASE_DIR/config/$t; skipping copy"
                    continue
                fi
                if ! cp -r "$THEME_DIR/$t" "$BASE_DIR/config/"; then
                    warn "Failed to copy theme $t"
                    ((errors++))
                    continue
                fi

                if ! chown -R "$INVOKER":"$INVOKER" "$BASE_DIR/config/$t" 2>/dev/null; then
                    warn "Failed to set ownership of theme $t"
                    ((errors++))
                fi

                if ! chmod -R u=rwX,g=rX,o=rX "$BASE_DIR/config/$t"; then
                    warn "Failed to set permissions on theme $t"
                    ((errors++))
                fi
            fi
        done
        log "Copied config themes (if present) into $BASE_DIR/config/"
    else
        log "No config/ directory found in repo ($THEME_DIR)"
    fi

    if ((errors > 0)); then
        warn "Completed with $errors non-fatal errors"
    fi

    return 0
}
