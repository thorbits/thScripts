#!/usr/bin/env bash

# Must be run as root
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "\e[31mThis script must be run as root. Use sudo.\e[0m"
    exit 1
fi

# Welcome message / silent update
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
    # Parse command-line arguments if needed
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
    # Ensure LINES and COLUMNS are set
    (:)

    trap deinit-term exit
    trap init-term winch
    init-term

    echo 'Preparing package installation'
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
}

main "$@"
