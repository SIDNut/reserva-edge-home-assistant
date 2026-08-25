#!/bin/sh
set -eu

# Used by callers after this library is sourced.
# shellcheck disable=SC2034
PROJECT_ROOT=$(CDPATH='' cd -- "${SCRIPT_DIR:-$(dirname -- "$0")}/.." && pwd)

info() {
    printf '%s\n' "INFO: $*"
}

warn() {
    printf '%s\n' "WARN: $*" >&2
}

die() {
    printf '%s\n' "ERROR: $*" >&2
    exit 1
}

require_root() {
    [ "$(id -u)" -eq 0 ] || die "Run this command with sudo."
}

is_true() {
    [ "$1" = "true" ]
}

validate_boolean_or_auto() {
    case "$1" in
        true|false|auto) return 0 ;;
        *) return 1 ;;
    esac
}

trim_value() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

unquote_value() {
    value=$1
    case "$value" in
        \"*\") value=${value#\"}; value=${value%\"} ;;
        \'*\') value=${value#\'}; value=${value%\'} ;;
    esac
    printf '%s' "$value"
}

load_profile_config() {
    config_path=$1
    [ -f "$config_path" ] || die "Profile config not found: $config_path"

    PROFILE_USER=
    HA_URL=
    SCREEN_ROTATION=right
    TOUCHKIO_THEME=dark
    TOUCHKIO_ZOOM=1.0
    TOUCHKIO_WIDGET=true
    ONBOARD_WIDTH=800
    ONBOARD_HEIGHT=260
    ONBOARD_X=0
    ONBOARD_Y=1020
    IDLE_DIM_SECONDS=600
    ENABLE_NFC=auto
    ENABLE_LED=auto
    ALLOW_UNVERIFIED_HARDWARE=false

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line=$(trim_value "$raw_line")
        case "$line" in ''|'#'*) continue ;; esac
        case "$line" in *=*) ;; *) die "Invalid config line: $raw_line" ;; esac
        key=$(trim_value "${line%%=*}")
        value=$(unquote_value "$(trim_value "${line#*=}")")
        case "$key" in
            PROFILE_USER) PROFILE_USER=$value ;;
            HA_URL) HA_URL=$value ;;
            SCREEN_ROTATION) SCREEN_ROTATION=$value ;;
            TOUCHKIO_THEME) TOUCHKIO_THEME=$value ;;
            TOUCHKIO_ZOOM) TOUCHKIO_ZOOM=$value ;;
            TOUCHKIO_WIDGET) TOUCHKIO_WIDGET=$value ;;
            ONBOARD_WIDTH) ONBOARD_WIDTH=$value ;;
            ONBOARD_HEIGHT) ONBOARD_HEIGHT=$value ;;
            ONBOARD_X) ONBOARD_X=$value ;;
            ONBOARD_Y) ONBOARD_Y=$value ;;
            IDLE_DIM_SECONDS) IDLE_DIM_SECONDS=$value ;;
            ENABLE_NFC) ENABLE_NFC=$value ;;
            ENABLE_LED) ENABLE_LED=$value ;;
            ALLOW_UNVERIFIED_HARDWARE) ALLOW_UNVERIFIED_HARDWARE=$value ;;
            *) die "Unknown profile config key: $key" ;;
        esac
    done < "$config_path"

    case "$HA_URL" in http://*|https://*) ;; *) die "HA_URL must start with http:// or https://" ;; esac
    case "$HA_URL" in *\'*|*[[:space:]]*) die "HA_URL must not contain quotes or whitespace" ;; esac
    case "$SCREEN_ROTATION" in normal|left|right|inverted) ;; *) die "Invalid SCREEN_ROTATION" ;; esac
    case "$TOUCHKIO_THEME" in light|dark) ;; *) die "TOUCHKIO_THEME must be light or dark" ;; esac
    case "$TOUCHKIO_WIDGET" in true|false) ;; *) die "TOUCHKIO_WIDGET must be true or false" ;; esac
    validate_boolean_or_auto "$ENABLE_NFC" || die "ENABLE_NFC must be true, false, or auto"
    validate_boolean_or_auto "$ENABLE_LED" || die "ENABLE_LED must be true, false, or auto"
    case "$ALLOW_UNVERIFIED_HARDWARE" in true|false) ;; *) die "ALLOW_UNVERIFIED_HARDWARE must be true or false" ;; esac
    printf '%s' "$TOUCHKIO_ZOOM" | grep -Eq '^[0-9]+([.][0-9]+)?$' || die "TOUCHKIO_ZOOM must be numeric"
    for number in "$ONBOARD_WIDTH" "$ONBOARD_HEIGHT" "$ONBOARD_X" "$ONBOARD_Y" "$IDLE_DIM_SECONDS"; do
        case "$number" in ''|*[!0-9]*) die "Geometry and idle values must be non-negative integers" ;; esac
    done

    if [ -z "$PROFILE_USER" ]; then
        PROFILE_USER=${SUDO_USER:-}
    fi
    [ -n "$PROFILE_USER" ] || die "Set PROFILE_USER when SUDO_USER is unavailable"
    case "$PROFILE_USER" in *[!a-zA-Z0-9_-]*) die "PROFILE_USER contains unsupported characters" ;; esac
    id "$PROFILE_USER" >/dev/null 2>&1 || die "Debian user does not exist: $PROFILE_USER"
    PROFILE_HOME=$(getent passwd "$PROFILE_USER" | cut -d: -f6)
    [ -d "$PROFILE_HOME" ] || die "Home directory does not exist: $PROFILE_HOME"
    case "$PROFILE_HOME" in *[!a-zA-Z0-9_./-]*) die "PROFILE_HOME contains unsupported characters" ;; esac
}

shell_quote() {
    escaped=$(printf '%s' "$1" | sed "s/'/'\\\\''/g")
    printf "'%s'" "$escaped"
}

write_profile_config() {
    destination=$1
    umask 022
    {
        printf 'PROFILE_USER=%s\n' "$(shell_quote "$PROFILE_USER")"
        printf 'PROFILE_HOME=%s\n' "$(shell_quote "$PROFILE_HOME")"
        printf 'HA_URL=%s\n' "$(shell_quote "$HA_URL")"
        printf 'SCREEN_ROTATION=%s\n' "$(shell_quote "$SCREEN_ROTATION")"
        printf 'TOUCHKIO_THEME=%s\n' "$(shell_quote "$TOUCHKIO_THEME")"
        printf 'TOUCHKIO_ZOOM=%s\n' "$(shell_quote "$TOUCHKIO_ZOOM")"
        printf 'TOUCHKIO_WIDGET=%s\n' "$(shell_quote "$TOUCHKIO_WIDGET")"
        printf 'ONBOARD_WIDTH=%s\n' "$(shell_quote "$ONBOARD_WIDTH")"
        printf 'ONBOARD_HEIGHT=%s\n' "$(shell_quote "$ONBOARD_HEIGHT")"
        printf 'ONBOARD_X=%s\n' "$(shell_quote "$ONBOARD_X")"
        printf 'ONBOARD_Y=%s\n' "$(shell_quote "$ONBOARD_Y")"
        printf 'IDLE_DIM_SECONDS=%s\n' "$(shell_quote "$IDLE_DIM_SECONDS")"
        printf 'ENABLE_NFC=%s\n' "$(shell_quote "$ENABLE_NFC")"
        printf 'ENABLE_LED=%s\n' "$(shell_quote "$ENABLE_LED")"
    } > "$destination"
    chmod 0644 "$destination"
}
