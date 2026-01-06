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
    apt_install_progress xorg openbox obconf menu polybar nitrogen picom lxappearance x11-xserver-utils
    configure_display_resolution || warn "Resolution configuration skipped"
    success "Openbox installed"
}

configure_display_resolution() {
    if $YES_MODE; then
        log "Non-interactive mode: skipping resolution selection."
        return 0
    fi

    if ! ask "Configure display resolution for Openbox autostart?"; then
        log "Resolution: skipped"
        return 0
    fi

    if command -v xrandr >/dev/null 2>&1; then
        echo "Available display outputs and modes:"
        if ! xrandr --query | awk '
/ connected/ {out=$1; print out ":"; next}
/^[0-9]+x[0-9]+/ {print "  " $1}
'; then
            warn "Failed to read display modes via xrandr"
        fi
    else
        warn "xrandr not found; available outputs/modes cannot be listed"
    fi

    local output
    local mode
    local rate
    read -rp "Enter display output name (e.g. HDMI-1) - blank to skip: " output
    if [[ -z "$output" ]]; then
        log "Resolution: skipped"
        return 0
    fi
    if [[ ! "$output" =~ ^[A-Za-z0-9._-]+$ ]]; then
        warn "Invalid output name: $output"
        return 0
    fi

    read -rp "Enter resolution (e.g. 1920x1080) - blank to skip: " mode
    if [[ -z "$mode" ]]; then
        log "Resolution: skipped"
        return 0
    fi
    if [[ ! "$mode" =~ ^[0-9]+x[0-9]+$ ]]; then
        warn "Invalid resolution: $mode"
        return 0
    fi

    read -rp "Enter refresh rate (e.g. 60) - blank for default: " rate
    if [[ -n "$rate" ]] && [[ ! "$rate" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        warn "Invalid refresh rate: $rate"
        return 0
    fi

    local ob_dir="$INVOKER_HOME/.config/openbox"
    local res_file="$ob_dir/resolution.sh"
    mkdir -p "$ob_dir"
    {
        echo "#!/bin/sh"
        if [[ -n "$rate" ]]; then
            printf 'xrandr --output "%s" --mode "%s" --rate "%s"\n' "$output" "$mode" "$rate"
        else
            printf 'xrandr --output "%s" --mode "%s"\n' "$output" "$mode"
        fi
    } > "$res_file"
    chown "$INVOKER":"$INVOKER" "$res_file" 2>/dev/null || true
    chmod 755 "$res_file" 2>/dev/null || true
    success "Resolution config saved to $res_file"
    return 0
}

session_menu() {
    while true; do
        clear
        echo "=== Session Defaults ==="
        echo "1) Set Openbox as default session"
        echo "2) Restore previous session defaults"
        echo "0) Back"
        read -rp "> " c
        case "$c" in
            1) set_openbox_default_session; pause ;;
            2) restore_previous_session; pause ;;
            0) break ;;
            *) echo "Invalid"; pause ;;
        esac
    done
}

set_openbox_default_session() {
    local ob_session
    ob_session="$(command -v openbox-session || true)"
    if [[ -z "$ob_session" ]]; then
        error "openbox-session not found. Install Openbox first."
        return 1
    fi

    if command -v update-alternatives >/dev/null 2>&1; then
        local prev
        prev="$(update-alternatives --query x-session-manager 2>/dev/null | awk -F': ' '/^Value:/{print $2; exit}')"
        if [[ -n "$prev" ]]; then
            echo "$prev" > "$BASE_DIR/x-session-manager.prev"
        fi
        run update-alternatives --set x-session-manager "$ob_session"
    fi

    if [[ -d /var/lib/AccountsService/users ]]; then
        local as_file="/var/lib/AccountsService/users/$INVOKER"
        if [[ -f "$as_file" ]]; then
            cp -a "$as_file" "$BASE_DIR/AccountsService.$INVOKER.bak" || true
        fi
        if grep -q '^\[User\]' "$as_file" 2>/dev/null; then
            if grep -q '^XSession=' "$as_file" 2>/dev/null; then
                sed -i -E 's/^XSession=.*/XSession=openbox/' "$as_file"
            else
                sed -i -E '/^\[User\]/a XSession=openbox' "$as_file"
            fi
        else
            {
                echo "[User]"
                echo "XSession=openbox"
            } > "$as_file"
        fi
    fi

    if [[ -f /etc/lightdm/lightdm.conf ]]; then
        cp -a /etc/lightdm/lightdm.conf "$BASE_DIR/lightdm.conf.bak" || true
        if grep -q '^\[Seat:\*\]' /etc/lightdm/lightdm.conf; then
            if grep -q '^user-session=' /etc/lightdm/lightdm.conf; then
                sed -i -E 's/^user-session=.*/user-session=openbox/' /etc/lightdm/lightdm.conf
            else
                sed -i -E '/^\[Seat:\*\]/a user-session=openbox' /etc/lightdm/lightdm.conf
            fi
        else
            {
                echo
                echo "[Seat:*]"
                echo "user-session=openbox"
            } >> /etc/lightdm/lightdm.conf
        fi
    fi

    if [[ ! -f /etc/X11/default-display-manager ]]; then
        log "No display manager detected; enabling startx fallback"
        echo "exec openbox-session" > "$INVOKER_HOME/.xinitrc"
        chown "$INVOKER":"$INVOKER" "$INVOKER_HOME/.xinitrc" 2>/dev/null || true
        chmod 644 "$INVOKER_HOME/.xinitrc" 2>/dev/null || true
    fi

    success "Default session set to Openbox"
}

restore_previous_session() {
    if [[ -f "$BASE_DIR/x-session-manager.prev" ]] && command -v update-alternatives >/dev/null 2>&1; then
        local prev
        prev="$(cat "$BASE_DIR/x-session-manager.prev")"
        if [[ -n "$prev" ]]; then
            run update-alternatives --set x-session-manager "$prev"
        fi
    fi

    if [[ -f "$BASE_DIR/AccountsService.$INVOKER.bak" ]]; then
        cp -a "$BASE_DIR/AccountsService.$INVOKER.bak" "/var/lib/AccountsService/users/$INVOKER" || true
    fi

    if [[ -f "$BASE_DIR/lightdm.conf.bak" ]]; then
        cp -a "$BASE_DIR/lightdm.conf.bak" /etc/lightdm/lightdm.conf || true
    fi

    success "Previous session defaults restored (if backups existed)"
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
