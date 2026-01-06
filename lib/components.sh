# lib/components.sh

# Prevent accidental standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "This script must be sourced, not executed directly."
    exit 1
fi

components_menu() {
    while true; do
        clear
        echo "=== Components & Hardware ==="
        echo "1) Display Manager"
        echo "2) GPU Drivers (NVIDIA/AMD/Intel/VirtualBox)"
        echo "3) Audio Stack (PipeWire/PulseAudio/ALSA)"
        echo "4) Timeshift snapshots"
        echo "0) Back"
        read -rp "> " c
        case "$c" in
            1) choose_display_manager; pause ;;
            2) gpu_drivers; pause ;;
            3) audio_stack; pause ;;
            4) system_snapshots; pause ;;
            0) break ;;
            *) echo "Invalid"; pause ;;
        esac
    done
}

choose_display_manager() {
    if $YES_MODE; then
        run apt-get install -y lightdm
        log "LightDM installed (auto)"
        return
    fi
    echo
    echo "Choose display manager:"
    echo "1) lightdm"
    echo "2) sddm"
    echo "3) skip"
    read -rp "> " DM_CHOICE
    case "$DM_CHOICE" in
        1) run apt-get install -y lightdm ;;
        2) run apt-get install -y sddm ;;
        *) log "Skipping DM installation" ;;
    esac
}

gpu_drivers() {
    if $YES_MODE; then
        log "Auto-mode: installing firmware-misc-nonfree"
        run apt-get install -y firmware-misc-nonfree
        return
    fi

    echo
    echo "GPU driver options:"
    echo "1) NVIDIA (nvidia-driver)"
    echo "2) AMD (firmware-amd-graphics)"
    echo "3) Intel (xserver-xorg-video-intel)"
    echo "4) VirtualBox Guest (virtualbox-guest-dkms, virtualbox-guest-x11, virtualbox-guest-utils)"
    echo "5) skip"
    read -rp "> " GPU_CHOICE
    case "$GPU_CHOICE" in
        1) run apt-get install -y nvidia-driver ;;
        2) run apt-get install -y firmware-amd-graphics ;;
        3) run apt-get install -y xserver-xorg-video-intel ;;
        4) 
            log "Installing VirtualBox guest packages (Debian repo)"
            run apt-get install -y virtualbox-guest-dkms virtualbox-guest-x11 virtualbox-guest-utils
            ;;
        *) log "Skipping GPU drivers" ;;
    esac
}

audio_stack() {
    if $YES_MODE; then
        log "Auto-mode: installing PipeWire stack"
        run apt-get install -y pipewire wireplumber pipewire-audio-client-libraries
        return
    fi

    echo
    echo "Audio options:"
    echo "1) PipeWire (recommended)"
    echo "2) PulseAudio"
    echo "3) ALSA only (skip daemons)"
    echo "4) skip"
    read -rp "> " AUDIO_CHOICE
    case "$AUDIO_CHOICE" in
        1) run apt-get install -y pipewire wireplumber pipewire-audio-client-libraries ;;
        2) run apt-get install -y pulseaudio pulseaudio-utils ;;
        3) log "ALSA only (no extra sound daemon installed)" ;;
        *) log "Skipping audio setup" ;;
    esac
}

system_snapshots() {
    if ask "Install Timeshift for system snapshots?"; then
        run apt-get install -y timeshift
        log "Timeshift installed; configure as needed"
    else
        log "Timeshift: skipped"
    fi
}
