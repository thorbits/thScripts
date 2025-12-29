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
	echo '[FATAL]' "$@" >&2
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
    local packages=("$@")
    local pkg
    local count=0
    local output

    for pkg in "${packages[@]}"; do
        # First package - print with newline
        if [[ "$pkg" == "${packages[0]}" ]]; then
            echo -e "-> Now downloading and installing: $pkg"
        else
            # Subsequent packages - overwrite previous line
            echo -ne "-> Now downloading and installing: $pkg\r"
        fi

        # Capture output to count packages
        output=$(apt-get install -y "$pkg" 2>&1)
        
        # Count how many packages were actually set up
        local total_installed
        total_installed=$(echo "$output" | grep -c "Setting up" || echo "0")
        
        # Add to the local batch counter
        count=$((count + total_installed))
    done
    echo
    
    # Return the total count of packages installed
    echo "$count"
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
    local packages=(plasma-workspace pipewire sddm dolphin konsole)
    
    # 1. Estimate the real total packages (dependencies)
    local len
    len=$(apt-get install -y --simulate "${packages[@]}" 2>&1 | grep -c "Setting up")
    
    # Fallback to meta-package count if estimation fails
    if [[ "$len" -eq 0 ]]; then
        len=${#packages[@]}
    fi
    printf "Estimated %d packages to install\n" "$len"

    # 2. Loop with progress tracking
    local current_progress=0
    local i
    local batch_count

    for ((i = 0; i < ${#packages[@]}; i += BATCHSIZE)); do
        # Capture the count from install-packages function
        batch_count=$(install-packages "${packages[@]:i:BATCHSIZE}")
        
        # Update the progress
        current_progress=$((current_progress + batch_count))
        
        # Update the visual progress bar
        progress-bar "$current_progress" "$len"
    done
    
    # Ensure 100% completion is shown
    progress-bar "$current_progress" "$len"

    deinit-term
}

main "$@"
