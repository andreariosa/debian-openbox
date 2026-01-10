# lib/openbox.sh
#
# Openbox desktop installation, configuration, and theme deployment functions.
# Handles Openbox and related components (compositor, panel, window manager utilities).

# Prevent accidental standalone execution.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "This script must be sourced, not executed directly."
    exit 1
fi

# Copy theme configuration files with validation and safe permissions handling.
# Args: $1 source directory, $2 target directory.
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

# Install Openbox window manager, desktop stack (X11, utilities), and optional components
# (compositor, panel, wallpaper manager). Optionally configure display resolution.
install_openbox() {
    log "Installing Openbox desktop and helpers..."
    apt_install_progress xorg x11-xserver-utils openbox obconf rofi nitrogen picom polybar
    configure_display_resolution || warn "Resolution configuration skipped"
    success "Openbox installed"
}

# Optionally configure display resolution via xrandr in Openbox autostart.
# Generates a resolution.sh script in ~/.config/openbox for later invocation.
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
        if ! xrandr --query | awk '/ connected/ {print $1, $2, $3, $4}'; then
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

# Display session defaults submenu for managing X session manager configuration.
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

# Configure Openbox as the default X session via update-alternatives,
# LightDM preferences, and AccountsService. Backup existing settings.
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

# Restore previous X session defaults from backups created during installation.
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

# Display theme selection menu for Openbox, polybar, and picom configuration templates.
theme_menu() {
    clear
    echo "Choose configuration theme to apply - blank to skip"
    echo "1) Clean (minimal dummy template)"
    echo "2) Dark modern"
    echo "3) Light modern"
    echo "4) Customize GTK settings"
    read -rp "> " tchoice
    case "$tchoice" in
        1) apply_theme_configs clean; pause ;;
        2) apply_theme_configs dark; pause ;;
        3) apply_theme_configs light; pause ;;
        4) customize_gtk_configs; pause ;;
        "") log "Theme: skipped"; pause ;;
        *) echo "Invalid"; pause ;;
    esac
}

# Apply selected theme (clean/dark/light) by copying configuration templates to ~/.config/.
# Backs up existing configs before overwriting. Automatically generates GTK settings.
apply_theme_configs() {
    local theme="$1"   # clean|dark|light

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
        [[ -d "$INVOKER_HOME/.config/picom" ]] || \
        [[ -d "$INVOKER_HOME/.config/polybar" ]] || \
        [[ -d "$INVOKER_HOME/.config/rofi" ]]; then
        mkdir -p "$backup_dir"
        log "Creating backup of existing configs in $backup_dir"
        cp -r "$INVOKER_HOME/.config/openbox" "$backup_dir/" 2>/dev/null || true
        cp -r "$INVOKER_HOME/.config/picom" "$backup_dir/" 2>/dev/null || true
        cp -r "$INVOKER_HOME/.config/polybar" "$backup_dir/" 2>/dev/null || true
        cp -r "$INVOKER_HOME/.config/rofi" "$backup_dir/" 2>/dev/null || true
        chown -R "$INVOKER":"$INVOKER" "$backup_dir" 2>/dev/null || true
    fi

    log "Applying theme '$theme' configs to user $INVOKER"

    # Map typical locations
    local ob_dir="$INVOKER_HOME/.config/openbox"
    local picom_dir="$INVOKER_HOME/.config/picom"
    local polybar_dir="$INVOKER_HOME/.config/polybar"
    local rofi_dir="$INVOKER_HOME/.config/rofi"

    mkdir -p "$ob_dir" "$picom_dir" "$polybar_dir" "$rofi_dir"
    chown -R "$INVOKER":"$INVOKER" "$ob_dir" "$picom_dir" "$polybar_dir" "$rofi_dir" 2>/dev/null || true

    # Copy files but ask before overwriting (auto-yes allowed)
    copy_theme_files "$src/openbox" "$ob_dir"
    copy_theme_files "$src/picom" "$picom_dir"
    copy_theme_files "$src/polybar" "$polybar_dir"
    copy_theme_files "$src/rofi" "$rofi_dir"

    # Generate GTK configuration files automatically so lxappearance isn't required
    generate_gtk_configs "$theme"

    # Generate helper scripts for rofi (power/exit menu)
    generate_rofi_actions "$rofi_dir"

    log "Theme '$theme' applied (files copied to $INVOKER_HOME/.config/...)"
    return 0
}

# Auto-generate GTK2/3/4 configuration files based on selected theme.
# Applies theme-specific defaults (Adwaita/Adwaita-dark) without external managers.
generate_gtk_configs() {
    local theme="$1"

    # Define defaults per theme choice (Debian base-friendly values)
    local gtk_theme="Adwaita"
    local icon_theme="hicolor"
    local cursor_theme="DMZ-White"
    local font_name="Sans 10"

    case "$theme" in
        dark)
            gtk_theme="Adwaita-dark"
            ;;
        light)
            gtk_theme="Adwaita"
            ;;
        clean)
            gtk_theme="Adwaita"
            icon_theme="hicolor"
            ;;
        *)
            ;;
    esac

    # GTK3/GTK4 settings.ini content
    local gtk3_dir="$INVOKER_HOME/.config/gtk-3.0"
    local gtk4_dir="$INVOKER_HOME/.config/gtk-4.0"
    mkdir -p "$gtk3_dir" "$gtk4_dir"

    local gtk_settings="[Settings]\n"
    gtk_settings+="gtk-theme-name = $gtk_theme\n"
    gtk_settings+="gtk-icon-theme-name = $icon_theme\n"
    gtk_settings+="gtk-font-name = $font_name\n"
    gtk_settings+="gtk-cursor-theme-name = $cursor_theme\n"
    gtk_settings+="gtk-cursor-theme-size = 24\n"

    printf "%b" "$gtk_settings" > "$gtk3_dir/settings.ini"
    printf "%b" "$gtk_settings" > "$gtk4_dir/settings.ini"
    chmod 644 "$gtk3_dir/settings.ini" "$gtk4_dir/settings.ini" 2>/dev/null || true
    chown -R "$INVOKER":"$INVOKER" "$gtk3_dir" "$gtk4_dir" 2>/dev/null || true

    # GTK2 legacy file
    local gtk2_file="$INVOKER_HOME/.gtkrc-2.0"
    {
        printf 'gtk-theme-name="%s"\n' "$gtk_theme"
        printf 'gtk-icon-theme-name="%s"\n' "$icon_theme"
        printf 'gtk-font-name="%s"\n' "$font_name"
    } > "$gtk2_file"
    chmod 644 "$gtk2_file" 2>/dev/null || true
    chown "$INVOKER":"$INVOKER" "$gtk2_file" 2>/dev/null || true

    log "GTK configs generated: $gtk3_dir/settings.ini, $gtk4_dir/settings.ini, $gtk2_file"
    return 0
}


# Create a small rofi actions script for power/exit options.
# Args: $1 = target rofi config dir (e.g. ~/.config/rofi)
generate_rofi_actions() {
    local rofi_dir="$1"
    if [[ -z "$rofi_dir" ]]; then
        warn "No rofi directory provided to generate_rofi_actions"
        return 1
    fi
    mkdir -p "$rofi_dir"
    local actions_file="$rofi_dir/actions.sh"
    cat > "$actions_file" <<'EOF'
#!/bin/sh

options="⏻ Power off
🗘 Reboot
⏸ Suspend
⏾ Hibernate
🗙 Logout
🗝 Lock session"

execute() {
    case "$1" in
        *Power\ off) systemctl poweroff ;;
        *Reboot) systemctl reboot ;;
        *Suspend) systemctl suspend ;;
        *Hibernate) systemctl hibernate ;;
        *Logout) command -v openbox >/dev/null && openbox --exit ;;
        *Lock\ session)
            command -v xlock >/dev/null && xlock ||
            command -v loginctl >/dev/null && loginctl lock-session
            ;;
    esac
}

[ $# -eq 0 ] && printf '%s\n' "$options" && exit
[ "$1" = "show" ] && execute=$(printf '%s\n' "$options" | rofi -dmenu -i -p "Select Action") && [ -n "$execute" ] && execute "$execute" && exit
execute "$1"
EOF
    chmod 755 "$actions_file" 2>/dev/null || true
    chown "$INVOKER":"$INVOKER" "$actions_file" 2>/dev/null || true
    log "Generated rofi actions script: $actions_file"
    return 0
}

# Interactive customization of GTK theme, icon theme, font, and cursor theme.
# Scans system for available themes and allows user selection, with sensible fallbacks.
customize_gtk_configs() {
    local home="$INVOKER_HOME"
    if $YES_MODE; then
        log "Non-interactive mode: applying GTK customization from env vars or defaults"
        local gtk_theme_val="${GTK_THEME:-Adwaita}"
        local icon_theme_val="${ICON_THEME:-hicolor}"
        local cursor_theme_val="${CURSOR_THEME:-DMZ-White}"
        local font_val="${GTK_FONT:-Sans 10}"

        # Persist settings (GTK3/GTK4)
        local gtk3_dir="$home/.config/gtk-3.0"
        local gtk4_dir="$home/.config/gtk-4.0"
        mkdir -p "$gtk3_dir" "$gtk4_dir"
        {
            echo "[Settings]"
            echo "gtk-theme-name = $gtk_theme_val"
            echo "gtk-icon-theme-name = $icon_theme_val"
            echo "gtk-font-name = $font_val"
            echo "gtk-cursor-theme-name = $cursor_theme_val"
            echo "gtk-cursor-theme-size = 24"
        } > "$gtk3_dir/settings.ini"
        cp -f "$gtk3_dir/settings.ini" "$gtk4_dir/settings.ini" 2>/dev/null || true
        chmod 644 "$gtk3_dir/settings.ini" "$gtk4_dir/settings.ini" 2>/dev/null || true
        chown -R "$INVOKER":"$INVOKER" "$gtk3_dir" "$gtk4_dir" 2>/dev/null || true

        # GTK2
        local gtk2_file="$home/.gtkrc-2.0"
        {
            printf 'gtk-theme-name="%s"\n' "$gtk_theme_val"
            printf 'gtk-icon-theme-name="%s"\n' "$icon_theme_val"
            printf 'gtk-font-name="%s"\n' "$font_val"
        } > "$gtk2_file"
        chmod 644 "$gtk2_file" 2>/dev/null || true
        chown "$INVOKER":"$INVOKER" "$gtk2_file" 2>/dev/null || true

        log "GTK customization saved (non-interactive): theme=$gtk_theme_val icon=$icon_theme_val font=$font_val cursor=$cursor_theme_val"
        return 0
    fi
    local -a gtk_dirs=("/usr/share/themes" "$home/.themes" "$home/.local/share/themes")
    local -a icon_dirs=("/usr/share/icons" "$home/.icons" "$home/.local/share/icons")
    local -a gtk_opts=()
    local -a icon_opts=()
    local -a cursor_opts=()
    local -a font_opts=()

    # Gather GTK themes
    for d in "${gtk_dirs[@]}"; do
        if [[ -d "$d" ]]; then
            for t in "$d"/*; do
                [[ -d "$t" ]] && gtk_opts+=("$(basename "$t")")
            done
        fi
    done
    # Gather icon themes
    for d in "${icon_dirs[@]}"; do
        if [[ -d "$d" ]]; then
            for i in "$d"/*; do
                [[ -d "$i" ]] && icon_opts+=("$(basename "$i")")
            done
        fi
    done
    # Cursor themes: use icon theme names that contain a cursors subdir
    for i in "${icon_opts[@]}"; do
        if [[ -d "/usr/share/icons/$i/cursors" ]] || [[ -d "$home/.icons/$i/cursors" ]]; then
            cursor_opts+=("$i")
        fi
    done
    # Fonts: use fc-list if available
    if command -v fc-list >/dev/null 2>&1; then
        mapfile -t font_opts < <(fc-list : family | sed -E 's/\{.*\}//g' | sed -E 's/,.*$//' | sed '/^$/d' | sort -u)
    fi

    # Helper to present a numbered list and read a selection.
    # Usage: choose <array-name> <prompt-text> [out-var]
    # If [out-var] is provided the chosen value is written to that variable and the prompts are printed to the terminal (not captured).
    # If no [out-var] is provided the chosen value is printed to stdout (legacy behavior).
    choose() {
        local -n _arr=$1
        local prompt_text="$2"
        local outvar="$3"

        if [[ ${#_arr[@]} -eq 0 ]]; then
            echo "No options available for: $prompt_text" >&2
            return 1
        fi

        echo "Select $prompt_text (blank = skip):" >&2
        local i=1
        for v in "${_arr[@]}"; do
            printf "%3d) %s\n" "$i" "$v" >&2
            i=$((i+1))
        done

        local sel
        # Prompt shown on stderr so it is visible even if caller captures stdout
        read -rp "> " sel
        if [[ -z "$sel" ]]; then
            return 2
        fi
        if [[ ! "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 )) || (( sel > ${#_arr[@]} )); then
            echo "Invalid selection" >&2
            return 1
        fi

        local selected="${_arr[$((sel-1))]}"
        if [[ -n "$outvar" ]]; then
            printf -v "$outvar" '%s' "$selected"
        else
            printf '%s' "$selected"
        fi
        return 0
    }

    local chosen_theme="" chosen_icon="" chosen_cursor="" chosen_font=""

    choose gtk_opts "GTK theme" chosen_theme || true
    choose icon_opts "icon theme" chosen_icon || true
    choose cursor_opts "cursor theme" chosen_cursor || true
    choose font_opts "font (family)" chosen_font || true

    # Fall back to defaults from generate_gtk_configs when empty
    local gtk_theme_val="${chosen_theme:-Adwaita}"
    local icon_theme_val="${chosen_icon:-hicolor}"
    local cursor_theme_val="${chosen_cursor:-DMZ-White}"
    local font_val="${chosen_font:-Sans 10}"

    # Persist settings (GTK3/GTK4)
    local gtk3_dir="$home/.config/gtk-3.0"
    local gtk4_dir="$home/.config/gtk-4.0"
    mkdir -p "$gtk3_dir" "$gtk4_dir"
    {
        echo "[Settings]"
        echo "gtk-theme-name = $gtk_theme_val"
        echo "gtk-icon-theme-name = $icon_theme_val"
        echo "gtk-font-name = $font_val"
        echo "gtk-cursor-theme-name = $cursor_theme_val"
        echo "gtk-cursor-theme-size = 24"
    } > "$gtk3_dir/settings.ini"
    cp -f "$gtk3_dir/settings.ini" "$gtk4_dir/settings.ini" 2>/dev/null || true
    chmod 644 "$gtk3_dir/settings.ini" "$gtk4_dir/settings.ini" 2>/dev/null || true
    chown -R "$INVOKER":"$INVOKER" "$gtk3_dir" "$gtk4_dir" 2>/dev/null || true

    # GTK2
    local gtk2_file="$home/.gtkrc-2.0"
    {
        printf 'gtk-theme-name="%s"\n' "$gtk_theme_val"
        printf 'gtk-icon-theme-name="%s"\n' "$icon_theme_val"
        printf 'gtk-font-name="%s"\n' "$font_val"
    } > "$gtk2_file"
    chmod 644 "$gtk2_file" 2>/dev/null || true
    chown "$INVOKER":"$INVOKER" "$gtk2_file" 2>/dev/null || true

    log "GTK customization saved: theme=$gtk_theme_val icon=$icon_theme_val font=$font_val cursor=$cursor_theme_val"
    return 0
}
