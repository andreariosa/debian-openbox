# lib/base.sh
#
# System configuration functions: apt sources management, timezone and locale.

# Prevent accidental standalone execution.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "This script must be sourced, not executed directly."
    exit 1
fi

# Display system configuration submenu and handle user selections.
system_config_menu() {
    while true; do
        clear
        echo "=== System Configuration (submenu) ==="
        echo "1) Enable contrib/non-free & apt-get update"
        echo "2) System upgrade (apt-get upgrade)"
        echo "3) Configure timezone"
        echo "4) Configure locale"
        echo "0) Back"
        read -rp "> " c
        case "$c" in
            1) update_sources; pause ;;
            2) system_upgrade; pause ;;
            3) configure_timezone; pause ;;
            4) configure_locale; pause ;;
            0) break ;;
            *) echo "Invalid"; pause ;;
        esac
    done
}

# Update a traditional /etc/apt/sources.list format file.
# Ensures contrib, non-free, and non-free-firmware components are present.
update_sources_list_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    cp -a "$file" "$file.bak.$(date +%s)" || true
    awk '
    function has(arr, n, val,  i){for(i=1;i<=n;i++) if(arr[i]==val) return 1; return 0}
    /^[[:space:]]*deb(-src)?[[:space:]]+/{
        if ($0 !~ /(deb\.debian\.org|security\.debian\.org|ftp\.debian\.org)/) { print; next }
        n=split($0, f, /[[:space:]]+/)
        if (f[2] ~ /^\[/) {
            opt_end=2
            while (opt_end<=n && f[opt_end] !~ /\]$/) opt_end++
            idx=opt_end+1
        } else {
            idx=2
        }
        comp_start=idx+2
        if (comp_start>n) { print; next }
        split("", comps); ccount=0
        for(i=comp_start;i<=n;i++){ ccount++; comps[ccount]=f[i] }
        if (!has(comps, ccount, "contrib")) { ccount++; comps[ccount]="contrib" }
        if (!has(comps, ccount, "non-free")) { ccount++; comps[ccount]="non-free" }
        if (!has(comps, ccount, "non-free-firmware")) { ccount++; comps[ccount]="non-free-firmware" }
        out=""
        for(i=1;i<comp_start;i++){ out=out f[i] " " }
        for(i=1;i<=ccount;i++){ out=out comps[i] (i<ccount?" ":"") }
        print out
        next
    }
    { print }
    ' "$file" > "$file.tmp" && mv -f "$file.tmp" "$file"
}

# Update a DEB822 format /etc/apt/sources.list.d/*.sources file.
# Ensures contrib, non-free, and non-free-firmware components are present.
update_sources_deb822_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    cp -a "$file" "$file.bak.$(date +%s)" || true
    awk '
    function has(arr, n, val,  i){for(i=1;i<=n;i++) if(arr[i]==val) return 1; return 0}
    BEGIN { RS=""; ORS="\n\n" }
    {
        n=split($0, lines, /\n/)
        in_debian=0
        for (i=1;i<=n;i++) {
            if (lines[i] ~ /^[[:space:]]*URIs:[[:space:]]*/) {
                line=lines[i]
                sub(/^[[:space:]]*URIs:[[:space:]]*/, "", line)
                if (line ~ /(deb\.debian\.org|security\.debian\.org|ftp\.debian\.org)/) {
                    in_debian=1
                }
            }
        }
        if (in_debian) {
            for (i=1;i<=n;i++) {
                if (lines[i] ~ /^[[:space:]]*Components:[[:space:]]*/) {
                    line=lines[i]
                    sub(/^[[:space:]]*Components:[[:space:]]*/, "", line)
                    ccount=split(line, comps, /[[:space:]]+/)
                    if (!has(comps, ccount, "contrib")) { comps[++ccount]="contrib" }
                    if (!has(comps, ccount, "non-free")) { comps[++ccount]="non-free" }
                    if (!has(comps, ccount, "non-free-firmware")) { comps[++ccount]="non-free-firmware" }
                    out="Components:"
                    for (j=1;j<=ccount;j++) { out=out " " comps[j] }
                    lines[i]=out
                }
            }
        }
        out=""
        for (i=1;i<=n;i++) { out=out lines[i] (i<n ? "\n" : "") }
        print out
    }
    ' "$file" > "$file.tmp" && mv -f "$file.tmp" "$file"
}

# Enable contrib/non-free/non-free-firmware in apt sources and refresh cache.
update_sources() {
    local codename
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    log "Updating apt sources... (codename: $codename)"
    log "Ensuring contrib/non-free & non-free-firmware in apt source files"

    if [[ -f /etc/apt/sources.list ]]; then
        update_sources_list_file /etc/apt/sources.list
    fi

    if compgen -G "/etc/apt/sources.list.d/*.list" >/dev/null; then
        for f in /etc/apt/sources.list.d/*.list; do
            update_sources_list_file "$f"
        done
    fi

    if compgen -G "/etc/apt/sources.list.d/*.sources" >/dev/null; then
        for f in /etc/apt/sources.list.d/*.sources; do
            update_sources_deb822_file "$f"
        done
    fi

    run apt-get update -y
}

# Update apt cache and upgrade all packages.
system_upgrade() {
    log "Upgrading system..."
    run apt-get update -y
    run apt-get upgrade -y
}

# Configure system timezone interactively or via AUTO mode with sensible defaults.
configure_timezone() {
    if $YES_MODE; then
        log "Auto-mode: skipping interactive timezone (user can set later)"
        return
    fi
    echo
    while true; do
        read -rp "Enter your timezone (example: Europe/Rome or America/New_York) - blank to skip: " TZ_CHOICE
        if [[ -z "$TZ_CHOICE" ]]; then
            log "Timezone: skipped"
            break
        elif [[ -f "/usr/share/zoneinfo/$TZ_CHOICE" ]]; then
            run timedatectl set-timezone "$TZ_CHOICE"
            log "Timezone set to $TZ_CHOICE"
            break
        else
            warn "Invalid timezone. Please check /usr/share/zoneinfo/ for valid options."
        fi
    done
    run timedatectl set-ntp true
}

# Configure system locale interactively or auto-select en_US.UTF-8 in non-interactive mode.
configure_locale() {
    local ret=0

    if $YES_MODE; then
        log "Auto-mode: enabling en_US.UTF-8"
        if ! run apt-get install -y locales; then
            error "Failed to install locales package"
            return 1
        fi

        # Create backup of locale.gen
        local locale_backup=""
        if [[ -f /etc/locale.gen ]]; then
            locale_backup="/etc/locale.gen.bak.$(date +%s)"
            cp -f /etc/locale.gen "$locale_backup" || {
                error "Failed to backup locale.gen"
                return 1
            }
        fi

        if ! grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen 2>/dev/null; then
            if ! echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen; then
                error "Failed to add en_US.UTF-8 to locale.gen"
                # Try to restore backup if it exists
                if [[ -n "$locale_backup" ]] && [[ -f "$locale_backup" ]]; then
                    mv -f "$locale_backup" /etc/locale.gen
                fi
                return 1
            fi
        fi

        if ! run locale-gen; then
            error "Failed to generate locales"
            ret=1
        fi

        if ! run update-locale LANG=en_US.UTF-8; then
            error "Failed to update default locale"
            ret=1
        fi

        if ((ret != 0)); then
            error "Locale configuration failed. System may be in inconsistent state."
            return 1
        fi
        return 0
    fi

    echo
    while true; do
        read -rp "Enter one or more locales (e.g. en_US.UTF-8 it_IT.UTF-8) - blank to skip: " LOCALES
        if [[ -z "$LOCALES" ]]; then
            log "Locales: skipped"
            return
        fi

        local valid=true
        for locale in $LOCALES; do
            if ! grep -q "^#\?[[:space:]]*${locale}[[:space:]]*UTF-8" /usr/share/i18n/SUPPORTED 2>/dev/null; then
                warn "Invalid locale: $locale"
                valid=false
                break
            fi
        done

        if $valid; then
            break
        fi
    done

    run apt-get install -y locales
    for L in $LOCALES; do
        if ! grep -q "^$L UTF-8" /etc/locale.gen 2>/dev/null; then
            echo "$L UTF-8" >> /etc/locale.gen
        fi
    done
    run locale-gen
    PRIMARY_LOCALE="$(echo "$LOCALES" | awk '{print $1}')"
    run update-locale LANG="$PRIMARY_LOCALE"
    log "Locale configured; default: $PRIMARY_LOCALE"
}
