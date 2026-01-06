#!/usr/bin/env bash

#	_______
#	\_   _/
#	  |_|horbits 
#
#	eZkde for Arch / Debian / Fedora / OpenSuse
#	Automated KDE installation script
# ------------------------------------------------------------
# Installs latest KDE 6.5.x (Wayland only) with audio support
# (PipeWire) and a minimum of utilities.
# ------------------------------------------------------------

# must be run as root
if [[ "$(id -u)" -ne 0 ]]; then
    printf " This script must be run as root. Use sudo.\n"
    exit 1
fi

set -euo pipefail

# Default tunables
BATCHSIZE=${BATCHSIZE:-1}
BAR_CHAR=${BAR_CHAR:-'|'}
EMPTY_CHAR=${EMPTY_CHAR:-' '}

fatal() {
    printf '[FATAL] %s\n' "$*" >&2
    exit 1
}

if command -v pacman &>/dev/null; then
    DISTRO=Arch
    PM=(pacman -S --needed --noconfirm)
    UPDATE="pacman -Sy >/dev/null 2>&1"
    LIST_CMD=(pacman -Sp --print-format '%n')

elif command -v apt-get &>/dev/null; then
    DISTRO=Debian
    PM=(apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold")
    UPDATE="apt-get update -qq"
    LIST_CMD=(apt-get install --dry-run -qq)

elif command -v dnf &>/dev/null; then
    DISTRO=Fedora
    PM=(dnf install -y)
    UPDATE="dnf makecache >/dev/null 2>&1"
    LIST_CMD=(dnf install --assumeno)

elif command -v zypper &>/dev/null; then
    DISTRO=OpenSuse
    PM=(zypper install -y)
    UPDATE="zypper --quiet ref"
    LIST_CMD=(zypper install -y --dry-run)

else
    fatal "No supported package manager found (apt-get, pacman, dnf, zypper)."
fi

# map each distro to its native KDE/plasma packages
declare -A KDE_GROUP
KDE_GROUP[Arch]="plasma-meta dolphin konsole"
KDE_GROUP[Debian]="plasma-workspace pipewire sddm dolphin konsole"
KDE_GROUP[Fedora]="dolphin plasma-desktop plasma-settings plasma-nm sddm-wayland-plasma kde-baseapps konsole kscreen sddm startplasma-wayland"
KDE_GROUP[OpenSuse]="patterns-kde-kde_plasma plasma6-desktop discover6 dolphin sddm-config-wayland"

# intro (now $DISTRO and $UPDATE are set)
clear
echo
case "$DISTRO" in
        Arch)
            cat << 'ART'
                        -`
                      .o+`
                     `ooo/
                    `+oooo:
                   `+oooooo:
                   -+oooooo+:
                 `/:-:++oooo+:
                `/++++/+++++++:
               `/++++++++++++++:
              `/+++ooooooooooooo/`
             ./ooosssso++osssssso+`
            .oossssso-````/ossssss+`
           -osssssso.      :ssssssso.
          :osssssss/        osssso+++.
         /ossssssss/        +ssssooo/-
       `/ossssso+/:-        -:/+osssso+-
      `+sso+:-`                 `.-/+oso:
     `++:.                           `-/+/
     .`                                 `/
ART
        ;;
        Debian)
            cat << 'ART'
               _,met$$$$$gg.
            ,g$$$$$$$$$$$$$$$P.
          ,g$$P"        "\""Y$$.".
         ,$$$P'              `$$$:
        'd$$P       ,ggs.     `$$b:
        `d$$'     ,$P"'   .    $$$
         $$P      d$'     ,    $$P
         $$:      $$.   -    ,d$$'
         $$;      Y$b._   _,d$P'
         Y$$.    `.`"Y$$$$P"'
         `$$b      "-.__ 
          `Y$$
           `Y$$.
             `$$b.
               `Y$$b.
                  `"Y$b.
                      `"\""
ART
        ;;
        Fedora)
            cat << 'ART'
                 .',;::::;,'.
             .';:cccccccccccc:;,.
          .;cccccccccccccccccccccc;.
        .:cccccccccccccccccccccccccc:.
      .;ccccccccccccc;.:dddl:.;ccccccc;.
     .:ccccccccccccc;OWMKOOXMWd;ccccccc:.
    .:ccccccccccccc;KMMc;cc;xMMc;ccccccc:.
    ,cccccccccccccc;MMM.;cc;;WW:;cccccccc,
    :cccccccccccccc;MMM.;cccccccccccccccc:
    :ccccccc;oxOOOo;MMM0OOk.;cccccccccccc:
    cccccc;0MMKxdd:;MMMkddc.;cccccccccccc;
    ccccc;XM0';cccc;MMM.;cccccccccccccccc'
    ccccc;MMo;ccccc;MMW.;ccccccccccccccc;
    ccccc;0MNc.ccc.xMMd;ccccccccccccccc;
    cccccc;dNMWXXXWM0:;cccccccccccccc:,
    cccccccc;.:odl:.;cccccccccccccc:,.
    :cccccccccccccccccccccccccccc:'.
    .:cccccccccccccccccccccc:;,..
      '::cccccccccccccc::;,.
ART
        ;;
        OpenSuse)
            cat << 'ART'
               ,...,                                 
         .,:lloooooc;.
       ,ool'     oo,;oo:
     .lo'        oo.   oo:
    .oo.         oo.    oo:
    :ol          oo.    'oo
    :oo         .oo.    .oo.
    .oooooooooooooo.    .oo.
     ;oo.               .oo.
        "ooc,',,,,,,,,,,:ooc,,,,,,,,,,,
           ':cooooooooooooooooooooooooool;.
                        .oo.             .oo;
                        .oo.    'oooooooooo:ooo.
                        .oo.    'oo.         col
                        .oo'    'oo          col
                         coo    'oo          oo'
                          coc   'oo        .lo,
                           `oo, 'oo      .:oo
                             'ooooc,, ,:lol
                                `''"clc"'      
ART
        ;;
esac

printf ' ##############################################'
printf '\n\n # Welcome %s, to eZkde for %s. #\n\n' "$USER" "$DISTRO"
printf ' # __________________________________________ #\n'
printf ' # The latest version of KDE 6.5.x (Wayland session) #\n will be installed with audio support (Pipewire) #\n and a minimum of utilities. #\n\n'
printf ' # __________________________________________ #'
printf ' # Press Enter to continue or Ctrl+C to cancel. #\n'
printf ' ##############################################'
read -rp '' && eval "$UPDATE" || fatal " ERROR: no internet connection detected. Exiting."

progress-bar() {
    local current=$1 len=$2
    # calculate percentage and string length
    local perc_done=$((current * 100 / len))
    local suffix=" ($perc_done%)"
    local length=$((COLUMNS - ${#suffix} - 4))
    local num_bars=$((perc_done * length / 100))

    # construct the bar string
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

install_packages() {
        local pkg
        for pkg in "$@"; do
            printf '\r%-*s' "$COLUMNS" " -> Now downloading and installing: $pkg"
            "${PM[@]}" "$pkg" >/dev/null
        done
}

enable_sddm() {
    if ! systemctl is-enabled sddm &>/dev/null; then
        systemctl enable sddm >/dev/null 2>&1
    fi
}

end_install() {
printf '\n eZkde for %s installation successful.\n\n' "$DISTRO"
read -rp $' Reboot (r) or start KDE now (k)? [r/k] ' choice
case "${choice,,}" in
    #k) eval "${SRV_START[@]}" && eval "${SRV_TARGET[@]}" ;;
    k) systemctl start sddm ;;
    r) echo; (for ((i=5;i>0;i--)); do printf "\r Rebooting in %d...\033[0K" $i; sleep 1; done) && reboot ;;
esac
}

main() {
    local OPTARG OPTIND opt
    while getopts 'b:c:e:' opt; do
        case "$opt" in
            b) BATCHSIZE=$OPTARG;;
            c) BAR_CHAR=$OPTARG;;
            e) EMPTY_CHAR=$OPTARG;;
            *) fatal 'Usage: ezkde_noarch [-b batchsize] [-c bar_char] [-e empty_char]';;
        esac
    done

    shopt -s globstar nullglob checkwinsize
    # this line is to ensure LINES and COLUMNS are set
    (:)

    trap deinit-term exit
    trap 'init-term; progress-bar "$current" "$total"' WINCH
    init-term

    printf ' Preparing KDE packages for %s...\n\n' "$DISTRO"
    
    # build exact list of packages that will be installed
    IFS=' ' read -r -a pkg_names <<< "${KDE_GROUP[$DISTRO]}"
    local packages=() total

    case "$DISTRO" in
        Debian)
            # inherit the user’s current locale 
            current_locale=${LC_ALL:-${LANG:-C.UTF-8}}
            current_locale=${current_locale%%.*}.UTF-8
            echo "locales locales/default_environment_locale select $current_locale" | debconf-set-selections
            echo "locales locales/locales_to_be_generated multiselect $current_locale UTF-8" | debconf-set-selections
            export DEBIAN_FRONTEND=noninteractive
            
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '/^Inst / {print $2}'
            )
            total=${#packages[@]}
            ;;
        Arch)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                grep -v '^warning' || true
            )
            total=${#packages[@]}
            ;;
        Fedora)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk 'NF>=5 && $1 != "Package" {printf $1}' | head -n -3
            )
            total=${#packages[@]}
            ;;
        OpenSuse)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '/new/ {for(i=1;i<=NF;i++) if ($i ~ /^[a-zA-Z0-9.-]+$/) print $i}' | head -n -5                
            )
            total=${#packages[@]}
            ;;
    esac
    
    (( total )) || {
    #deinit-term
    printf ' Nothing to do – All packages are up to date.\n\n'
    enable_sddm
    end_install
    return 0
    }

    # batch installation loop
    local current=0
    for ((i = 0; i < total; i += BATCHSIZE)); do
        install_packages "${packages[@]:i:BATCHSIZE}"
        current=$((current + BATCHSIZE))
        progress-bar "$current" "$total"
    done
    progress-bar "$total" "$total"

    enable_sddm
    end_install
    deinit-term
}

# run only when executed, not sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
