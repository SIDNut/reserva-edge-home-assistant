#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT_DIR=$ROOT/scripts
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

SUDO_USER=$(id -un)
export SUDO_USER
load_profile_config "$ROOT/config/profile.env.example"

[ "$PROJECT_ROOT" = "$ROOT" ]
[ "$HA_URL" = https://homeassistant.local:8123 ]
[ "$SCREEN_ROTATION" = right ]
[ "$PROFILE_USER" = "$SUDO_USER" ]

temporary=$(mktemp)
trap 'rm -f "$temporary"' EXIT HUP INT TERM
write_profile_config "$temporary"
sh -n "$temporary"
generated_url=$(sh -c '. "$1"; printf "%s" "$HA_URL"' sh "$temporary")
[ "$generated_url" = "$HA_URL" ]

printf '%s\n' 'Common profile parser test passed'
