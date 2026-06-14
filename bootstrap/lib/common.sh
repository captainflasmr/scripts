#!/usr/bin/env bash
# common.sh - shared helpers: logging, distro detection, prompts.
# Sourced by install.sh and refresh-usb.sh. Not meant to run on its own.

# --- pretty output --------------------------------------------------------
_c_reset=$'\033[0m'; _c_blue=$'\033[1;34m'; _c_green=$'\033[1;32m'
_c_yellow=$'\033[1;33m'; _c_red=$'\033[1;31m'; _c_dim=$'\033[2m'

section() { printf '\n%s========================================%s\n%s%s%s\n%s========================================%s\n' \
            "$_c_blue" "$_c_reset" "$_c_blue" "$*" "$_c_reset" "$_c_blue" "$_c_reset"; }
info()  { printf '%s•%s %s\n' "$_c_green"  "$_c_reset" "$*"; }
warn()  { printf '%s!%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }
err()   { printf '%s✗%s %s\n' "$_c_red"    "$_c_reset" "$*" >&2; }
die()   { err "$*"; exit 1; }

# confirm "Question?"  -> returns 0 on yes. Honours $ASSUME_YES.
confirm() {
    [[ ${ASSUME_YES:-0} == 1 ]] && return 0
    local reply
    read -r -p "$1 [y/N] " reply
    [[ $reply == [yY] || $reply == [yY][eE][sS] ]]
}

# --- distro detection -----------------------------------------------------
# Sets DISTRO to one of: arch | mint | debian | unknown
detect_distro() {
    local id id_like
    if [[ -r /etc/os-release ]]; then
        id=$(. /etc/os-release; echo "${ID:-}")
        id_like=$(. /etc/os-release; echo "${ID_LIKE:-}")
    fi
    case "$id" in
        arch|endeavouros|garuda|manjaro|cachyos) DISTRO=arch ;;
        linuxmint|mint)                          DISTRO=mint ;;
        ubuntu|debian|pop)                       DISTRO=mint ;;  # apt family
        *)
            case "$id_like" in
                *arch*)   DISTRO=arch ;;
                *debian*|*ubuntu*) DISTRO=mint ;;
                *)        DISTRO=unknown ;;
            esac ;;
    esac
    export DISTRO
}

# require a command, else die with install hint
require_cmd() { command -v "$1" &>/dev/null || die "Required command '$1' not found. $2"; }

# keep sudo alive for the duration of the run
sudo_keepalive() {
    sudo -v || die "sudo authentication failed"
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
}
