#!/usr/bin/env bash

#	_______
#	\_   _/
#	  |_|horbits 
#
#    eZkde for Arch / Debian / Fedora / OpenSuse
#    Automated KDE installation script
# ----------------------------------------------------------------
#    Install latest KDE 6.5.x (Wayland session) with audio support
#    (PipeWire) and a minimum of utilities.
# ----------------------------------------------------------------

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
KDE_GROUP[Fedora]="@kde-desktop"
#KDE_GROUP[Fedora]="plasma-desktop plasma-settings plasma-nm sddm-wayland-plasma kde-baseapps konsole kscreen sddm startplasma-wayland dolphin"
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
        `d$$'     ,$P"'   .    $$$:
        `d$$      d$'     ,    $$$P
        `$$:      $$.   -    ,d$$'
        `$$;      Y$b._   _,d$P'
        `Y$$.    `.`"Y$$$$P"'
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
            .',;:ccccccccccccc:;,'.
          .;ccccccccccccccccccccccc;.
        .;ccccccccccc;.:dddl:.;ccccccc;.
      .:cccccccccccc;OWMKOOXMWd;ccccccc:.
    .:ccccccccccccc;KMMc;cc;xMMc;ccccccc:.
    .:ccccccccccccc;MMM.;cc;;WW:;ccccccccc,
    .cccccccccccccc;MMM.;ccccccccccccccccc:
    .ccccccc;oxOOOo;MMM0OOk.;ccccccccccccc:
    .cccccc;0MMKxdd:;MMMkddc.;cccccccccccc;
    .cccc;XM0';cccc;MMM.;ccccccccccccccccc'
    .cccc;MMo;ccccc;MMW.;ccccccccccccccc;
    .cccc;0MNc.ccc.xMMd;ccccccccccccccc;
    .ccccc;dNMWXXXWM0:;ccccccccccccc:,.
    .cccccc;.::odl::.;cccccccccccc:,.
    ;cccccccccccccccccccccccc:;,.
    ;:cccccccccccccccccccc:;,.
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
    :oooooooooooooo.    .oo.
    .oo.                .oo.
     ;oo.               .oo.
        "ooc,',,,,,,,,,,:ooc,,,,,,,,,,,
           ':cooooooooooooooooooooooooool;.
                        .oo.             .oo;
                        .oo.                ooo.
                        .oo.    'ooooooooooo:col
                        .oo'    'oo          col
                         coo    'oo          oo'
                          coc   'oo        .lo,
                           `oo, 'oo      .:oo
                             'ooooc,, ,:lol
                                `''"clc"'      
ART
        ;;
esac

printf '\n\n Welcome %s, to eZkde for %s.\n\n' "$USER" "$DISTRO"
printf ' #---------------------------------------------------#\n'
printf ' # The latest version of KDE 6.5.x (Wayland session) #\n # will be installed with audio support (Pipewire)   #\n # and a minimum of utilities.                       #\n'
printf ' #---------------------------------------------------#\n\n'
while true; do
    printf '\r\033[2K Press Enter to continue or Ctrl+C to cancel.\n'
    read -n1 -s -r
    # check if User pressed Ctrl+C
    if (( $? != 0 )); then
        exit 1
    fi
    # check if user pressed Enter (empty input)
    if [[ -z "$REPLY" ]]; then
        break
    fi
done
# user pressed Enter, run the update.
eval "$UPDATE" || fatal " ERROR: no internet connection detected. Exiting."
printf '\n\n Preparing KDE packages for %s...\n\n' "$DISTRO"

create_swap() {
    local swap_file="/var/tmp/ezkde_swap"
    # create 1GB file
    if dd if=/dev/zero of="$swap_file" bs=1M count=1024 status=none 2>/dev/null; then
        chmod 600 "$swap_file"
        mkswap "$swap_file" >/dev/null 2>&1
        # forces the kernel to use this swap file
        if swapon "$swap_file" -p 100 >/dev/null 2>&1; then
            # swappiness 80 force the system to use swap sooner (default 60)
            sysctl -w vm.swappiness=80 >/dev/null 2>&1
            return 0
        else
            rm -f "$swap_file"
        fi
    fi
}

remove_swap() {
    local swap_file="/var/tmp/ezkde_swap"
    
    if [[ -f "$swap_file" ]]; then
        swapoff "$swap_file" >/dev/null 2>&1
        rm -f "$swap_file"
    fi
    # reset swappiness
    sysctl -w vm.swappiness=60 >/dev/null 2>&1
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

progress-bar() {
    local current=$1 len=$2
    # avoid division by zero
    if (( len == 0 )); then
        fatal " ."
        exit 1
    fi
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

recover_pacman() {
    rm -f /var/lib/pacman/db.lck >/dev/null
    pacman -Sy --noconfirm >/dev/null 2>&1 || true
}

recover_dpkg() {
    rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock  >/dev/null
    dpkg --configure -a >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -f -y
}

recover_rpm() {
    rm -f /var/lib/rpm/.rpm.lock /var/lib/rpm/__db.* >/dev/null
    rpm --rebuilddb >/dev/null 2>&1
    if [[ "$DISTRO" == "OpenSuse" ]]; then
        zypper verify --no-refresh >/dev/null 2>&1 || true
    fi
}

install_packages() {
    local pkg
    local ret=0
    local recover=""

    # Determine which recovery function to use
    case "$DISTRO" in
        Arch)            recover="recover_pacman" ;;
        Debian)          recover="recover_dpkg" ;;
        Fedora|OpenSuse) recover="recover_rpm" ;;
    esac
    
    for pkg in "$@"; do
        printf '\r%-*s' "$COLUMNS" " -> Now downloading and installing: $pkg"
        "${PM[@]}" "$pkg" >/dev/null
    done
}

enable_sddm() {
    systemctl is-enabled sddm &>/dev/null || rm -f /etc/systemd/system/display-manager.service && systemctl enable sddm &>/dev/null
}

prompt_reboot() {
    printf '\r\033[2K'
    read -n1 -s -r -p $' Reboot (r) or start KDE now (k)? [r/k] ' choice
}

end_install() {
    while true; do
        prompt_reboot
        # check if User pressed Ctrl+C
        if (( $? != 0 )); then
            exit 1
        fi

        case "${choice,,}" in
            k) printf '\n'; systemctl start sddm; break ;;
            r) printf '\n'; echo; (for ((i=5; i>0; i--)); do printf "\r Rebooting in %d...\033[0K" "$i"; sleep 1; done) && reboot; break ;;
            *) ;;
        esac
    done
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

    create_swap

    shopt -s globstar nullglob checkwinsize
    # ensure LINES and COLUMNS are set
    (:)

    trap deinit-term exit
    trap 'init-term; progress-bar "$current" "$total"' WINCH
    init-term

    # build exact list of packages that will be installed
    IFS=' ' read -r -a pkg_names <<< "${KDE_GROUP[$DISTRO]}"
    local packages=() total

    case "$DISTRO" in
        Arch)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                grep -v '^warning' || true
            )
            total=${#packages[@]}
            ;;
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
        Fedora)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '!/(^$|^=|---|Dependencies resolved|Transaction Summary|Running transaction|Total download size|^Package |^Arch |^Version |^Repository |^Size |Installing|Updating|Repositories|Total|Operation|Nothing|After|KDE)/ {print $1}'
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
    
    if (( total == 0 )); then
        printf ' Nothing to do – All packages are up to date.\n\n'
        enable_sddm
        end_install
    fi

    # array installation loop
    local current=0
    for ((i = 0; i < total; i += BATCHSIZE)); do
        install_packages "${packages[@]:i:BATCHSIZE}"
        current=$((current + BATCHSIZE))
        # clamp current to total for the progress bar
        if (( current > total )); then
            current=$total
        fi
        progress-bar "$current" "$total"
    done

    #progress-bar "$total" "$total"

    remove_swap
    enable_sddm
    printf '\n\n eZkde for %s installation successful.\n\n' "$DISTRO"
    end_install
    deinit-term
}

# run only when executed, not sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
