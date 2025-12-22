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

    echo "Processing ${#packages[@]} KDE packages"

    local pkg
    for pkg in "${packages[@]}"; do
        echo "-> Now donwloading and installing: $pkg"
        apt-get install -y "$pkg" >/dev/null 2>&1
    done
    sleep .1
}

trap deinit-term exit
trap init-term winch
init-term

echo 'Preparing packages installation...'
local packages=(plasma-wayland-protocols kwin-wayland pipewire sddm dolphin konsole)
local len=${#packages[@]}
echo "Found $len packages to install"

local i
for ((i = 0; i < len; i += BATCHSIZE)); do
    progress-bar "$((i+1))" "$len"
    install-packages "${packages[@]:i:BATCHSIZE}"
done
progress-bar "$len" "$len"

deinit-term
