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

    # Calculate percentage and string length
    local perc_done=$((current * 100 / len))
    local suffix=" ($perc_done%)"
    local length=$((COLUMNS - ${#suffix} - 2))
    local num_bars=$((perc_done * length / 100))

    # Construct the bar string
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

install-packages() {
    local pkg
    for pkg in "$@"; do
        # first package gets a newline, the rest overwrite the same line
        if [[ $pkg == $1 ]]; then
            echo -e "-> Now downloading and installing: $pkg"
        else
            echo -ne "-> Now downloading and installing: $pkg\r"
        fi
        apt-get install -y "$pkg" >/dev/null
    done
    echo   # final newline after the last package
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
    trap 'init-term; progress-bar "$current" "$total"' WINCH
    init-term

    printf 'Preparing packages installation...\n\n'

    # calculate the total new packages
    local pkg_names=(plasma-workspace pipewire sddm dolphin konsole)
    local total
    total=$(echo "n" | apt-get install "${pkg_names[@]}" 2>&1 \
            | grep "newly installed" | awk '{print $3}')
    [[ $total =~ ^[0-9]+$ ]] || fatal "Cannot obtain package count (run as root?)"

    # build the *full* list that apt will really install
    mapfile -t packages < <(
        apt-get install --dry-run -o Debug::NoLocking=1 -qq "${pkg_names[@]}" 2>&1 |
        awk '/^Inst / {print $2}'
    )

    # installation loop
    local current=0
    for ((i = 0; i < ${#packages[@]}; i += BATCHSIZE)); do
        install-packages "${packages[@]:i:BATCHSIZE}"
        current=$((current + BATCHSIZE))
        progress-bar "$current" "$total"
    done

    progress-bar "$total" "$total"
    deinit-term
}

# run only when executed, not when sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
