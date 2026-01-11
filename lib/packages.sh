# lib/packages.sh
#
# Package configuration parsing and installation functions.
# Handles packages.conf reading, category selection, and multi-package installation with progress.

# Prevent accidental standalone execution.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "This script must be sourced, not executed directly."
    exit 1
fi

# Parse packages.conf and populate associative arrays for categories and packages.
# Args: $1 path to packages.conf, $2 output array for categories, $3 output array for keys.
load_packages_conf() {
    local conf="$1"
    local -n out_cats="$2"
    local -n out_keys="$3"
    local current=""

    out_cats=()
    out_keys=()

    if [[ ! -f "$conf" ]]; then
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"    # strip comments after #
        line="${line%"${line##*[![:space:]]}"}" # rstrip
        line="${line#"${line%%[![:space:]]*}"}" # lstrip
        if [[ -z "$line" ]]; then
            continue
        fi
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            current="${BASH_REMATCH[1]}"
            if [[ -z "${out_cats[$current]+_}" ]]; then
                out_keys+=("$current")
                out_cats["$current"]=""
            fi
        else
            if [[ -n "$current" ]]; then
                out_cats["$current"]+="$line "
            fi
        fi
    done <"$conf"

    return 0
}

# Build package list from user-selected category indices.
# Deduplicates packages and reports invalid selections.
select_packages_from_categories() {
    local -n cats_ref="$1"
    local -n keys_ref="$2"
    local sel="$3"
    local -n out_pkgs="$4"
    local -n out_invalid="$5"
    local -A seen_pkgs=()
    local IFS=$' \t\n'

    out_pkgs=()
    out_invalid=()

    for n in $sel; do
        if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#keys_ref[@]} )); then
            k="${keys_ref[$((n - 1))]}"
            PKS="${cats_ref[$k]}"
            for p in $PKS; do
                if [[ -z "${seen_pkgs[$p]+_}" ]]; then
                    out_pkgs+=("$p")
                    seen_pkgs["$p"]=1
                fi
            done
        else
            out_invalid+=("$n")
        fi
    done
}

# Ensure apt package index cache exists; update if missing.
# Returns 0 on success, 1 on error, 2 if indexes still missing after update.
ensure_apt_cache() {
    local has_lists=false
    if compgen -G "/var/lib/apt/lists/*_Packages" >/dev/null || \
       compgen -G "/var/lib/apt/lists/*_Packages.gz" >/dev/null || \
       compgen -G "/var/lib/apt/lists/*_Packages.xz" >/dev/null || \
       compgen -G "/var/lib/apt/lists/*_Packages.bz2" >/dev/null; then
        has_lists=true
    fi
    if ! $has_lists; then
        log "Apt cache missing; running apt-get update"
        if ! run apt-get update -y; then
            error "Failed to update apt cache"
            return 1
        fi
        if compgen -G "/var/lib/apt/lists/*_Packages" >/dev/null || \
           compgen -G "/var/lib/apt/lists/*_Packages.gz" >/dev/null || \
           compgen -G "/var/lib/apt/lists/*_Packages.xz" >/dev/null || \
           compgen -G "/var/lib/apt/lists/*_Packages.bz2" >/dev/null; then
            return 0
        fi
        warn "Apt package indexes still missing; skipping package validation"
        return 2
    fi
    return 0
}

# Install packages one at a time with progress counter.
# Reports failed packages at the end.
progress_install() {
    local pkgs=("$@")
    local total=${#pkgs[@]}
    local count=0
    local failed_pkgs=()

    ensure_apt_cache || true
    log "Package validation disabled; apt will report missing packages during install"

    total=${#pkgs[@]}
    for pkg in "${pkgs[@]}"; do
        count=$((count + 1))
        echo -ne "${BOLD}Installing $pkg (${count}/${total})...${RESET}\r"
        if ! apt_install "$pkg"; then
            error "Failed to install $pkg"
            failed_pkgs+=("$pkg")
        fi
    done

    echo
    if [[ ${#failed_pkgs[@]} -eq 0 ]]; then
        success "All selected packages installed successfully."
    else
        warn "Some packages failed to install: ${failed_pkgs[*]}"
        return 1
    fi
}

# packages.conf format:
# [category]
# pkg1
# pkg2
# blank lines and lines starting with # are ignored

# Parse packages.conf, present categories, and install user-selected packages.
parse_packages_conf() {
    local conf="$BASE_DIR/packages.conf"
    declare -A cats
    local -a keys
    if [[ ! -f "$conf" ]]; then
        log "No packages.conf to parse at $conf"
        return 1
    fi

    if ! load_packages_conf "$conf" cats keys; then
        log "No packages.conf to parse at $conf"
        return 1
    fi

    # Present categories
    echo
    echo "Optional package categories found:"
    if [[ ${#keys[@]} -eq 0 ]]; then
        log "packages.conf contains no categories"
        return 1
    fi

    for idx in "${!keys[@]}"; do
        echo "$((idx + 1))) ${keys[$idx]}"
    done
    echo "0) Cancel"

    read -rp "Enter category numbers to install (e.g. 1 3), blank to skip: " sel
    if [[ -z "$sel" ]]; then
        log "User skipped optional packages installation"
        return 0
    fi

    # Build package list
    local pkgs=()
    local invalid_entries=()
    select_packages_from_categories cats keys "$sel" pkgs invalid_entries

    if [[ ${#invalid_entries[@]} -gt 0 ]]; then
        warn "Ignored invalid selections: ${invalid_entries[*]}"
    fi

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        log "No packages selected"
        return 0
    fi

    # Install packages automatically with apt-get -y
    log "Installing selected optional packages: ${pkgs[*]}"
    # run "apt-get install -y ${pkgs[*]}"
    progress_install "${pkgs[@]}"
    return 0
}
