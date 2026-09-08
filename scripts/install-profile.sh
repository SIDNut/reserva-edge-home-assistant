#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

CONFIG=
TOUCHKIO_DEB=
DRY_RUN=false
ASSUME_YES=false

usage() {
    printf 'Usage: %s --config FILE [--touchkio-deb FILE] [--dry-run] [--yes]\n' "$0"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config) [ "$#" -ge 2 ] || die "--config requires a file"; CONFIG=$2; shift 2 ;;
        --touchkio-deb) [ "$#" -ge 2 ] || die "--touchkio-deb requires a file"; TOUCHKIO_DEB=$2; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --yes) ASSUME_YES=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1" ;;
    esac
done

[ -n "$CONFIG" ] || die "--config is required"
load_profile_config "$CONFIG"

preflight_arg=
is_true "$ALLOW_UNVERIFIED_HARDWARE" && preflight_arg=--allow-unsupported
"$SCRIPT_DIR/preflight.sh" $preflight_arg

if [ "$ENABLE_NFC" = auto ]; then
    if [ -e /sys/class/nfc/nfc0 ]; then
        if apt-cache show neard >/dev/null 2>&1; then
            ENABLE_NFC=true
        else
            warn "NFC hardware is present, but Debian has no 'neard' package candidate; disabling the optional NFC bridge"
            ENABLE_NFC=false
        fi
    else
        ENABLE_NFC=false
    fi
fi
if [ "$ENABLE_LED" = auto ]; then
    dmi=$(cat /sys/class/dmi/id/product_name /sys/class/dmi/id/board_name 2>/dev/null || true)
    case "$dmi" in *ER5A0*) ENABLE_LED=true ;; *) ENABLE_LED=false ;; esac
fi

printf '%s\n' 'Planned changes:'
printf '  kiosk user: %s\n  dashboard: %s\n  rotation: %s\n' "$PROFILE_USER" "$HA_URL" "$SCREEN_ROTATION"
printf '  optional NFC bridge: %s\n  optional LED bridge: %s\n' "$ENABLE_NFC" "$ENABLE_LED"
printf '%s\n' '  install project-owned files under /etc, /usr/local and systemd'
printf '%s\n' '  install Debian packages and enable reserva-edge-kiosk.service'
printf '%s\n' '  no disk partitioning, factory filesystem access, or Home Assistant changes'

if $DRY_RUN; then
    info "Dry run complete; no changes were made."
    exit 0
fi

require_root

if ! $ASSUME_YES; then
    printf 'Apply this post-install profile? [y/N] '
    read -r answer
    case "$answer" in y|Y|yes|YES) ;; *) die "Cancelled" ;; esac
fi

if [ -n "$TOUCHKIO_DEB" ]; then
    [ -f "$TOUCHKIO_DEB" ] || die "TouchKio package not found: $TOUCHKIO_DEB"
fi

base_packages='xserver-xorg-core xserver-xorg-input-libinput xinit x11-xserver-utils xinput openbox unclutter-xfixes onboard at-spi2-core libglib2.0-bin pulseaudio pulseaudio-utils alsa-ucm-conf xprintidle util-linux sudo ca-certificates python3'
nfc_packages='neard python3-dbus python3-paho-mqtt'
led_packages='gpiod python3-libgpiod python3-paho-mqtt'

info "Refreshing Debian package metadata"
apt-get update
# Intentional splitting of reviewed package-name constants.
# shellcheck disable=SC2086
DEBIAN_FRONTEND=noninteractive apt-get install -y $base_packages
if is_true "$ENABLE_NFC"; then
    apt-cache show neard >/dev/null 2>&1 || die "Debian package 'neard' is unavailable; disable NFC or resolve the package source"
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get install -y $nfc_packages
fi
if is_true "$ENABLE_LED"; then
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get install -y $led_packages
fi

if [ -n "$TOUCHKIO_DEB" ]; then
    apt-get install -y "$TOUCHKIO_DEB"
fi
command -v touchkio >/dev/null 2>&1 || die "TouchKio is not installed; install its official x64 .deb or use --touchkio-deb"

if [ -e "$PROFILE_HOME/.config/systemd/user/default.target.wants/touchkio.service" ]; then
    warn "TouchKio's user service appears enabled; disable it as $PROFILE_USER to avoid two kiosk instances"
fi

install -d -o root -g root -m 0755 /etc/reserva-edge /usr/local/lib/reserva-edge
write_profile_config /etc/reserva-edge/profile.env

install -o root -g root -m 0755 "$PROJECT_ROOT/payload/usr/local/bin/reserva-edge-kiosk" /usr/local/bin/reserva-edge-kiosk
install -o root -g root -m 0755 "$PROJECT_ROOT/payload/usr/local/bin/reserva-edge-touch-session" /usr/local/bin/reserva-edge-touch-session
install -o root -g root -m 0755 "$PROJECT_ROOT/payload/usr/local/libexec/reserva-edge-idle-dim" /usr/local/libexec/reserva-edge-idle-dim
install -o root -g root -m 0755 "$PROJECT_ROOT/payload/usr/local/libexec/reserva-edge-neard-start" /usr/local/libexec/reserva-edge-neard-start
install -o root -g root -m 0755 "$PROJECT_ROOT/payload/usr/local/libexec/reserva-edge-nfc-start" /usr/local/libexec/reserva-edge-nfc-start
install -o root -g root -m 0755 "$PROJECT_ROOT/payload/usr/local/libexec/reserva-edge-nfc-mqtt" /usr/local/libexec/reserva-edge-nfc-mqtt
install -o root -g root -m 0755 "$PROJECT_ROOT/payload/usr/local/libexec/reserva-edge-led-mqtt" /usr/local/libexec/reserva-edge-led-mqtt
install -o root -g root -m 0644 "$PROJECT_ROOT/payload/usr/local/lib/reserva-edge/mqtt_common.py" /usr/local/lib/reserva-edge/mqtt_common.py

for unit in reserva-edge-kiosk.service reserva-edge-neard.service reserva-edge-nfc-poll.service reserva-edge-nfc-mqtt.service reserva-edge-led-mqtt.service; do
    install -o root -g root -m 0644 "$PROJECT_ROOT/payload/etc/systemd/system/$unit" "/etc/systemd/system/$unit"
done

temporary=$(mktemp)
trap 'rm -f "$temporary"' EXIT HUP INT TERM
sed -e "s|@PROFILE_USER@|$PROFILE_USER|g" -e "s|@PROFILE_HOME@|$PROFILE_HOME|g" \
    "$PROJECT_ROOT/payload/etc/systemd/system/reserva-edge-kiosk.service" > "$temporary"
install -o root -g root -m 0644 "$temporary" /etc/systemd/system/reserva-edge-kiosk.service

sed "s|@PROFILE_USER@|$PROFILE_USER|g" "$PROJECT_ROOT/payload/etc/sudoers.d/reserva-edge-profile" > "$temporary"
visudo -cf "$temporary"
install -o root -g root -m 0440 "$temporary" /etc/sudoers.d/reserva-edge-profile

install -d -o "$PROFILE_USER" -g "$PROFILE_USER" -m 0700 "$PROFILE_HOME/.config/reserva-edge" "$PROFILE_HOME/.local/state"
for group in audio video input render; do
    getent group "$group" >/dev/null 2>&1 && usermod -aG "$group" "$PROFILE_USER"
done

systemctl daemon-reload
systemctl disable --now getty@tty1.service 2>/dev/null || true
systemctl enable --now reserva-edge-kiosk.service

info "Core profile installed. Optional MQTT bridges remain disabled until configure-mqtt.sh installs credentials."
info "Run: sudo $SCRIPT_DIR/smoke-test.sh"
