#!/usr/bin/env bash

# Must be run as root
if [[ "$(id -u)" -ne 0 ]]; then
    printf "\e[31mThis script must be run as root. Use sudo.\e[0m\n"
    exit 1
fi

# Intro
clear
printf "\n\nWelcome %s, to eZkde for Debian.\n\n" "$USER"
printf "KDE 6.5.x (Wayland only) will be installed with audio support (Pipewire) and a minimum of utilities.\n\n"
printf "Press Enter to continue or Ctrl+C to cancel.\n"
read -rp '' && apt-get update -qq || {
    printf "\nConnection error! Exiting.\n\n"
    exit 1
}

# Progress bar
BATCHSIZE=1
BAR_CHAR='|'
EMPTY_CHAR=' '

fatal() {
    printf '[FATAL] %s\n' "$*" >&2
    exit 1
}

progress-bar() {
    local current=$1
    local len=$2

    local perc_done=$((current * 100 / len))

    # Modified to show only percentage
    local suffix=" $perc_done%"

    local length=$((COLUMNS - ${#suffix} - 2))
    local num_bars=$((perc_done * length / 100))

    local i
    local s='['
    for ((i = 0; i < num_bars; i++)); do
        s+=$BAR_CHAR
    done
    for ((i = num_bars; i < length; i++)); do
        s+=$EMPTY_CHAR
    done
    s+=']'
    s+=$suffix

    printf '\e7' # save the cursor location
    printf '\e[%d;%dH' "$LINES" 0 # move cursor to the bottom line
    printf '\e[0K' # clear the line
    printf '%s' "$s" # print the progress bar
    printf '\e8' # restore the cursor location
}

install-packages() {
    local packages=("$@")
    local total_installed=0

    printf "Installing batch of %d packages\n" "${#packages[@]}"

    local pkg
    for pkg in "${packages[@]}"; do
        printf "-> Installing %s\n" "$pkg"
        # Get the actual number of packages installed by this command
        local installed_count=$(apt-get install -y "$pkg" 2>&1 | grep -c "Setting up" || echo "1")
        total_installed=$((total_installed + installed_count))
        apt-get install -y "$pkg" >/dev/null 2>&1
    done

    # Return the total number of packages installed
    echo "$total_installed"
}

init-term() {
    printf '\n' # ensure we have space for the scrollbar
    printf '\e7' # save the cursor location
    printf '\e[%d;%dr' 0 "$((LINES - 1))" # set the scrollable region (margin)
    printf '\e8' # restore the cursor location
    printf '\e[1A' # move cursor up
}

deinit-term() {
    printf '\e7' # save the cursor location
    printf '\e[%d;%dr' 0 "$LINES" # reset the scrollable region (margin)
    printf '\e[%d;%dH' "$LINES" 0 # move cursor to the bottom line
    printf '\e[0K' # clear the line
    printf '\e8' # reset the cursor location
}

main() {
    local OPTARG OPTIND opt
    while getopts 'b:c:e:' opt; do
        case "$opt" in
            b) BATCHSIZE=$OPTARG;;
            c) BAR_CHAR=$OPTARG;;
            e) EMPTY_CHAR=$OPTARG;;
            *) fatal 'bad option';;
        esac
    done

    shopt -s globstar nullglob checkwinsize
    # this line is to ensure LINES and COLUMNS are set
    (:)

    trap deinit-term exit
    trap init-term winch
    init-term

    printf 'Preparing package installation...\n'
    local packages=(plasma-wayland-protocols kwin-wayland pipewire sddm dolphin konsole)
    printf "Found %d packages to install\n" "${#packages[@]}"

    # First pass to count actual packages
    local total_installed=$(install-packages "${packages[@]}")

    # Second pass with progress bar
    local i
    for ((i = 0; i < total_installed; i += BATCHSIZE)); do
        progress-bar "$((i+1))" "$total_installed"
        # Here you would need to implement the actual installation with progress tracking
        # This is a simplified version - a real implementation would need more complex tracking
    done
    progress-bar "$total_installed" "$total_installed"

    deinit-term
}

main "$@"
