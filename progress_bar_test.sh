#!/usr/bin/env bash

BATCHSIZE=1
BAR_CHAR='|'
EMPTY_CHAR=' '

fatal() {
    echo '[FATAL]' "$@" >&2
    exit 1
}

progress-bar() {
    local current=$1
    local len=$2

    local perc_done=$((current * 100 / len))

    local suffix=" $current/$len ($perc_done%)"

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
    local total_available=0

    # First pass: Count total available packages (including dependencies)
    for pkg in "${packages[@]}"; do
        local count=$(apt-cache depends "$pkg" | grep -c '^ ' || echo "1")
        total_available=$((total_available + count))
    done

    # Second pass: Install packages and track progress
    local installed_count=0
    for pkg in "${packages[@]}"; do
        echo "-> Installing $pkg"

        # Check if package is already installed
        if dpkg -l "$pkg" &>/dev/null; then
            echo "  Already installed"
            installed_count=$((installed_count + 1))
            progress-bar "$installed_count" "$total_available"
            continue
        fi

        # Install package and count new packages
        local new_packages=$(apt-get install -y "$pkg" 2>&1 | grep -c "Setting up" || echo "1")
        installed_count=$((installed_count + new_packages))
        progress-bar "$installed_count" "$total_available"
    done
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

    echo 'Preparing package installation'
    local packages=(plasma-wayland-protocols kwin-wayland pipewire sddm dolphin konsole)
    local len=${#packages[@]}
    echo "Found $len packages to install"

    install-packages "${packages[@]}"

    deinit-term
}

main "$@"
