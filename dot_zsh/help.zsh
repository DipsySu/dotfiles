# =================================================================
# myhelp / cheatsheet
# =================================================================

myhelp() {
    local C_TITLE=$'\033[1;36m'
    local C_GROUP=$'\033[1;33m'
    local C_CMD=$'\033[1;32m'
    local C_DESC=$'\033[0;37m'
    local C_R=$'\033[0m'

    if [[ -n "$1" ]]; then
        myhelp | grep -iE --color=auto "$1|^$|━━"
        return
    fi

    print -P ""
    print -P "${C_TITLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_R}"
    print -P "${C_TITLE} Dipsy command cheatsheet (myhelp <keyword> filters)${C_R}"
    print -P "${C_TITLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_R}"
    print -P ""
    print -P "${C_GROUP}macOS${C_R}"
    print -P "  ${C_CMD}mac_check${C_R}     ${C_DESC}system snapshot: load, memory, disk, hot processes${C_R}"
    print -P ""
    print -P "${C_GROUP}Git${C_R}"
    print -P "  ${C_CMD}gs gd ga gp gl gco gcb gcm gst gstp glog${C_R}  ${C_DESC}common git aliases${C_R}"
    print -P "  ${C_CMD}git lg${C_R}        ${C_DESC}graph log${C_R}"
    print -P ""
    print -P "${C_GROUP}Docker / OrbStack${C_R}"
    print -P "  ${C_CMD}dps dpsa dlogs dprune${C_R} ${C_DESC}container shortcuts${C_R}"
    print -P ""
    print -P "${C_GROUP}Network${C_R}"
    print -P "  ${C_CMD}ports myip localip${C_R} ${C_DESC}local ports and IP helpers${C_R}"
    print -P ""
    print -P "${C_GROUP}Navigation${C_R}"
    print -P "  ${C_CMD}dev dl dt cd <part>${C_R} ${C_DESC}quick jumps and zoxide${C_R}"
    print -P ""
    print -P "${C_TITLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_R}"
    print -P ""
}

alias '?'='myhelp'
alias '??'='myhelp'
alias cheat='myhelp'
