#!/bin/sh


###################### Most useful things ######################


# Fuzzy-pick a bashmark (from ~/.sdirs) and open nvim there
proj() {
  if [ "$#" -ge 2 ]; then
    echo "proj: too many arguments" >&2
    return 1
  fi

  local entries
  entries=$(grep '^export DIR_' ~/.sdirs \
    | sed 's/export DIR_\([^=]*\)="\(.*\)"/\1\t\2/')

  if [ "$#" -eq 1 ]; then
    local exact
    exact=$(echo "$entries" | awk -F'\t' -v name="$1" '$1 == name {print $2}')
    if [ -n "$exact" ]; then
      cd "$(eval echo "$exact")" && nvim
      return
    fi
  fi

  local dir
  dir=$(echo "$entries" \
    | fzf --with-nth=1 ${1:+--query="$1"} \
    | cut -f2)
  [ -n "$dir" ] && cd "$(eval echo "$dir")" && nvim
}

_proj_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local bookmarks
  bookmarks=$(grep '^export DIR_' ~/.sdirs | sed 's/export DIR_\([^=]*\)=.*/\1/')
  COMPREPLY=($(compgen -W "$bookmarks" -- "$cur"))
}
complete -F _proj_complete proj


# Save the current working directory into a variable as a name so you can later cd $var_name to get back to it
# you can achieve this same behavior with the bashmarks extension though those paths last for more than one session
sd() {
    eval "$1='$(pwd)'"
}


DID_I_FUCKING_STUTTER() {
    local last_command
    last_command=$(fc -ln -1)
    sudo bash -c "$last_command"
}


myMount() {
    sudo mount "$1" /mnt/usb/
    cd /mnt/usb/
}

myUmount() {
    sudo umount /mnt/usb/
    sync
}

myCryptMount() {
    sudo cryptsetup open "$1" myusb
    sudo mount /dev/mapper/myusb /mnt/usb/
    cd /mnt/usb/
}

myCryptUmount() {
    sudo umount /mnt/usb/
    sudo cryptsetup close myusb
    sync
}


# Shutdown function (with help from ChatGPT)
# Shuts down the pc and you can specify the amount of seconds it waits before it shuts down with argument 1
# If no argument is given it will default to some amount of seconds (currently 6)
# You can press Ctrl C to cancel or close the terminal in which this script is executed (unless the process persists like in tmux)
myShutdown() {
    secs=${1:-30}
    while [ $secs -gt 0 ]; do
        echo -ne "$secs Seconds till shut down (type 'now' to skip waiting)\033[0K\r"
	sleep 1
        if read -t 1 -n 3 input; then
            # Check if the input is 'now'
            if [[ $input == "now" ]]; then
                echo -ne "\nShutting down now!\n"
                systemctl poweroff
            fi
        fi
	: $((secs--))
    done
    systemctl poweroff
}

myReboot() {
    secs=${1:-30}
    while [ $secs -gt 0 ]; do
        echo -ne "$secs Seconds till reboot (type 'now' to skip waiting)\033[0K\r"
	sleep 1
        if read -t 1 -n 3 input; then
            # Check if the input is 'now'
            if [[ $input == "now" ]]; then
                echo -ne "\nRebooting now!\n"
                systemctl reboot
            fi
        fi
	: $((secs--))
    done
    systemctl reboot
}

myHibernate() {
    # sudo echo ""
    mem_str="$(free -h | sed -n '2 p' | awk '{print $7}')"
    mem=${mem_str%Gi} # split the Gi from the number of free gigs
    # TODO right now disabling this check by just setting mem manually to 16
    mem=16

    if [ "$(echo "$mem >= 8" | bc -l)" -eq 1 ]; then
        # echo 0 | sudo tee /sys/power/image_size
        systemctl hibernate
    else
        echo "Warning: less than 8 Gigs of RAM available, hibernation could fail" && free -h && return 1
    fi
}






# TODO: move this to a better spot
prettyDf() { # Call df for viewing remaining and total space on harddisk but present it in an easily viewable way
    echo "Remaining Space on disk (might not be 100% accurate)"
    echo ""
    df -h --total | head -n 1
    df -h --total | tail -n 1
}


cw () {
    cd $1
    ls
}

myHibernateDropCachesIfTooLittleRAM() {
    sudo echo ""
    if ! myHibernate; then
        myDropCaches
        sleep 1
        myHibernate
    fi
}


# Testing this function
myDropCaches() {
    sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
}


myVeracryptMount() {
    if [ "$#" -ne 2 ]; then
        echo "$0 - 2 arguments required, container and mount point"
        return 1
    fi
    sudo veracrypt --text --pim=0 --keyfiles="" --protect-hidden=no --mount "$1" "$2" && cd "$2"
}

myVeracryptDismount() {
    sudo veracrypt --dismount
}
alias myVeracryptUmount=myVeracryptDismount

myVeracryptCreate() {
    if [ "$#" -ne 1 ]; then
        echo "$0 - 1 argument required, container name"
        return 1
    fi
    sudo veracrypt --text --create "$1"
}


mkcdir () {
    if [ "$#" -ne 1 ]; then
        echo "mkcdir - Error: 1 argument required, directory name"
        return 1
    fi
    mkdir -p -- "$1" &&
    builtin cd -P -- "$1"
}

prefix() {
    mv -i "$1" "$2$1"
}

# Show current dir's contents sorted by size (human readable).
# If an entry has a sidecar note file named "<entry>_<something>.md",
# show that note's name (minus .md) instead of the raw entry name.
duh() {
    du -h --max-depth=1 |
    sort -hr |
    while IFS=$'\t' read -r size path; do
        prefix=${path#./}

        if [ "$prefix" = "." ]; then
            printf '%s\t%s\n' "$size" "$path"
            continue
        fi

        sidecar=$(find . -maxdepth 1 -type f -name "${prefix}_*.md" -print -quit)

        if [ -n "$sidecar" ]; then
            name=${sidecar#./}
            name=${name%.md}
            printf '%s\t%s\n' "$size" "$name"
        else
            printf '%s\t%s\n' "$size" "$prefix"
        fi
    done
}

########################################################



# Quick-create the next numbered location in an "Everything" dir
# (~/Main/Everything/-style: entries named "<yy><seq>[-<suffix>]" plus a
# matching empty sidecar file "<entry>_<snake_case_description>[_@tag...].md",
# see duh() above).
#
# Must be run from inside an existing Everything dir. On first use in a given
# dir it asks once which suffix to use there (can be left blank) and
# remembers it in a hidden ".mynew-suffix" file in that dir from then on.
#
# Usage: mynew "description" [tag ...]
#   tags may be passed with or without a leading "@" (e.g. "ai" or "@ai").
mynew() {
    local suffix_file=".mynew-suffix"
    local entry_re='^[0-9]{6}(-[A-Za-z0-9]+)?$'

    if [ "$#" -lt 1 ]; then
        echo "mynew: 1 argument required, description (plus optional tags)" >&2
        return 1
    fi

    local description="$1"
    shift

    local entry max_id=0
    for entry in */; do
        entry=${entry%/}
        if [[ "$entry" =~ $entry_re ]]; then
            local id=$((10#${entry:0:6}))
            [ "$id" -gt "$max_id" ] && max_id=$id
        fi
    done

    if [ "$max_id" -eq 0 ]; then
        echo "mynew: no existing <yy><seq>[-suffix] entries found in $(pwd) - this doesn't look like an Everything dir, refusing" >&2
        return 1
    fi

    local suffix
    if [ ! -e "$suffix_file" ]; then
        echo "mynew: no suffix configured for $(pwd) yet."
        read -r -p "Suffix to use for new entries here (leave blank for none): " suffix
        printf '%s' "$suffix" > "$suffix_file"
    else
        suffix=$(cat "$suffix_file")
    fi

    local current_year max_year max_seq next_seq
    current_year=$(date +%y)
    max_year=${max_id:0:2}
    max_seq=$((10#${max_id:2:4}))

    if [ "$max_year" = "$current_year" ]; then
        next_seq=$((max_seq + 1))
    else
        echo "mynew: year prefix rolled over (highest existing entry is '$max_year', current year is '$current_year') - starting sequence over at 0001"
        next_seq=1
    fi

    local new_id
    new_id=$(printf '%s%04d' "$current_year" "$next_seq")

    local new_dirname="$new_id"
    [ -n "$suffix" ] && new_dirname="${new_id}-${suffix}"

    if [ -e "$new_dirname" ]; then
        echo "mynew: '$new_dirname' already exists, refusing to touch it" >&2
        return 1
    fi

    local snake_description
    snake_description=$(echo "$description" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')

    local tag_suffix="" tag
    for tag in "$@"; do
        tag=${tag#@}
        tag_suffix="${tag_suffix}_@${tag}"
    done

    local sidecar="${new_dirname}_${snake_description}${tag_suffix}.md"

    mkdir -- "$new_dirname" &&
    touch -- "$sidecar" &&
    cd -- "$new_dirname" &&
    echo "mynew: created '$new_dirname/' with sidecar '$sidecar'"
}


################## Cut copy and paste functions ########

# used for quickly cutting, copying and pasting files
# use cut or copy command to mark a file then go to
# a different dir and use the paste command to move or
# copy the input there
# Currently (07.07.2024) using the commands
# myCut   / mycut   / c
# myCopy  / mycopy  / y
# myPaste / mypaste / p
# source ~/Main/Scripts/CutCopyPaste/cutcopypaste_aliases.sh

########################################################


##### Mark directory and then move there functions #####

# TODO implement this again. I did have this but then I
#      deleted the script by accident
# Sort of the reverse of my custom cut copy and paste
# commands
# because with the cut copy and paste commands you first
# select a file to be cut or copied and then call the
# paste function in the target directory
#
# with the functions defined in here you mark a directory
# as the target directory then you can call functions to
# move or copy files and directories to that place
# source ~/.myTargetDirThenMoveFilesThere.sh

########################################################




