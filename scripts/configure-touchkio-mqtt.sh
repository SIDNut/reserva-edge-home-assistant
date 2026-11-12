#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

[ "$(id -u)" -ne 0 ] || die "Run this as the configured kiosk user, not root"
[ -r /etc/reserva-edge/profile.env ] || die "Install the core profile first"
# Root-owned, installer-generated, non-secret configuration.
# shellcheck disable=SC1091
. /etc/reserva-edge/profile.env
[ "$(id -un)" = "$PROFILE_USER" ] || die "Run this as the configured kiosk user: $PROFILE_USER"
command -v touchkio >/dev/null 2>&1 || die "TouchKio is not installed"

state_dir=$PROFILE_HOME/.config/reserva-edge
hold_file=$state_dir/kiosk.hold
arguments_file=$PROFILE_HOME/.config/touchkio/Arguments.json
mkdir -p "$state_dir"

cleanup() {
    if [ -f "$arguments_file" ]; then
        chmod 0600 "$arguments_file"
    fi
    rm -f "$hold_file"
}
trap cleanup EXIT HUP INT TERM

touch "$hold_file"
if pgrep -u "$(id -u)" -x touchkio >/dev/null 2>&1; then
    pkill -TERM -u "$(id -u)" -x touchkio
fi

attempt=0
while pgrep -u "$(id -u)" -x touchkio >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 30 ] || die "TouchKio did not stop within 15 seconds"
    sleep 0.5
done

export DISPLAY=${DISPLAY:-:0}
info "Starting TouchKio's supported interactive setup on DISPLAY=$DISPLAY"
printf '%s\n' \
    'Enter the MQTT broker details locally; do not paste them into an issue or chat.' \
    'The profile launcher remains authoritative for dashboard URL, theme, zoom and widget settings.' \
    'After setup opens the temporary kiosk window, press Ctrl+C here to finish and resume the managed kiosk.'

touchkio --setup

