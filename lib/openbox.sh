# lib/openbox.sh

# Prevent accidental standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "This script must be sourced, not executed directly."
    exit 1
fi

copy_theme_files() {
    local src_dir="$1"
    local target_dir="$2"
    local f
    local base
    local target
    local temp_file

    if [[ ! -d "$src_dir" ]]; then
        log "Theme directory not found, skipping: $src_dir"
        return 0
    fi

    shopt -s nullglob
    for f in "$src_dir"/*; do
        if [[ ! -f "$f" ]]; then
            warn "Skipping non-file item: $f"
            continue
        fi
        base="$(basename "$f")"
        # Strict filename validation
        if [[ ! "$base" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
            warn "Skipping file with invalid name: $base"
            continue
        fi
        target="$target_dir/$base"
        # Ensure target path is within allowed directory
        if [[ ! "$target" =~ ^"$target_dir"/[^/]+$ ]]; then
            warn "Invalid target path for: $base"
            continue
        fi
        # Create secure temporary file with restricted permissions
        temp_file="$(mktemp "${TMPDIR:-/tmp}/theme_config.XXXXXX")"
        if [[ ! -f "$temp_file" ]]; then
            warn "Failed to create temporary file"
            continue
        fi
        chmod 600 "$temp_file" || {
            warn "Failed to set temporary file permissions"
            rm -f "$temp_file"
            continue
        }
        if ! cp -f "$f" "$temp_file"; then
            warn "Failed to copy $f to temporary location"
            rm -f "$temp_file"
            continue
        fi
        # Set correct permissions before moving to final location
        if ! chmod 644 "$temp_file"; then
            warn "Failed to set permissions on $temp_file"
            rm -f "$temp_file"
            continue
        fi
        if [[ -f "$target" ]]; then
            if $YES_MODE || ask "Overwrite $target?"; then
                if ! mv -f "$temp_file" "$target"; then
                    warn "Failed to move $temp_file to $target"
                    rm -f "$temp_file"
                    continue
                fi
            else
                log "Skipped $target"
                rm -f "$temp_file"
            fi
        else
            if ! mv -f "$temp_file" "$target"; then
                warn "Failed to move $temp_file to $target"
                rm -f "$temp_file"
                continue
            fi
        fi
        if ! chown "$INVOKER":"$INVOKER" "$target" 2>/dev/null; then
            warn "Failed to set ownership of $target"
        fi
    done
    shopt -u nullglob
}

install_openbox() {
    log "Installing Openbox desktop and helpers..."
    run apt-get install -y openbox obconf polybar nitrogen picom lxappearance menu
    success "Openbox installed"
}

theme_menu() {
    clear
    echo "Choose configuration theme to apply - blank to skip"
    echo "1) Clean (minimal dummy template)"
    echo "2) Dark modern"
    echo "3) Light modern"
    read -rp "> " tchoice
    case "$tchoice" in
        1) apply_theme_configs clean; pause ;;
        2) apply_theme_configs dark; pause ;;
        3) apply_theme_configs light; pause ;;
        "") log "Theme: skipped"; pause ;;
        *) echo "Invalid"; pause ;;
    esac
}

apply_theme_configs() {
    # Apply selected config theme (copy to user's ~/.config)
    local theme="$1"   #clean/dark/light
    
    # Validate theme input
    if [[ ! "$theme" =~ ^(clean|dark|light)$ ]]; then
        error "Invalid theme selection: $theme"
        return 1
    fi
    
    # Sanitize paths
    local src
    src="$(realpath -q "$BASE_DIR/config/$theme" 2>/dev/null)"
    if [[ ! "$src" =~ ^"$BASE_DIR/config/"(clean|dark|light)$ ]]; then
        error "Invalid theme path"
        return 1
    fi

    if [[ ! -d "$src" ]]; then
        error "Theme '$theme' directory not found in $src"
        return 1
    fi

    # Create backup of existing configs
    local backup_dir="$BASE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
     if [[ -d "$INVOKER_HOME/.config/openbox" ]] || \
         [[ -d "$INVOKER_HOME/.config/polybar" ]] || \
         [[ -d "$INVOKER_HOME/.config/picom" ]]; then
        mkdir -p "$backup_dir"
        log "Creating backup of existing configs in $backup_dir"
        cp -r "$INVOKER_HOME/.config/openbox" "$backup_dir/" 2>/dev/null || true
        cp -r "$INVOKER_HOME/.config/polybar" "$backup_dir/" 2>/dev/null || true
        cp -r "$INVOKER_HOME/.config/picom" "$backup_dir/" 2>/dev/null || true
        chown -R "$INVOKER":"$INVOKER" "$backup_dir" 2>/dev/null || true
    fi

    log "Applying theme '$theme' configs to user $INVOKER"
    # Map typical locations
    local ob_dir="$INVOKER_HOME/.config/openbox"
    local polybar_dir="$INVOKER_HOME/.config/polybar"
    local picom_dir="$INVOKER_HOME/.config/picom"

    mkdir -p "$ob_dir" "$polybar_dir" "$picom_dir"
    chown -R "$INVOKER":"$INVOKER" "$ob_dir" "$polybar_dir" "$picom_dir" 2>/dev/null || true
    # Copy files but ask before overwriting (auto-yes allowed)
    copy_theme_files "$src/openbox" "$ob_dir"
    copy_theme_files "$src/polybar" "$polybar_dir"
    copy_theme_files "$src/picom" "$picom_dir"

    log "Theme '$theme' applied (files copied to $INVOKER_HOME/.config/...)"
    return 0
}
