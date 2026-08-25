#!/bin/sh
set -eu

PURGE_CONFIG=false
case "${1:-}" in
    '') ;;
    --purge-config) PURGE_CONFIG=true ;;
    -h|--help) printf 'Usage: %s [--purge-config]\n' "$0"; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
esac

[ "$(id -u)" -eq 0 ] || { printf '%s\n' 'Run with sudo.' >&2; exit 1; }

for unit in reserva-edge-led-mqtt.service reserva-edge-nfc-mqtt.service reserva-edge-nfc-poll.service reserva-edge-neard.service reserva-edge-kiosk.service; do
    systemctl disable --now "$unit" 2>/dev/null || true
done

rm -f \
    /etc/systemd/system/reserva-edge-kiosk.service \
    /etc/systemd/system/reserva-edge-neard.service \
    /etc/systemd/system/reserva-edge-nfc-poll.service \
    /etc/systemd/system/reserva-edge-nfc-mqtt.service \
    /etc/systemd/system/reserva-edge-led-mqtt.service \
    /etc/sudoers.d/reserva-edge-profile \
    /usr/local/bin/reserva-edge-kiosk \
    /usr/local/bin/reserva-edge-touch-session \
    /usr/local/libexec/reserva-edge-idle-dim \
    /usr/local/libexec/reserva-edge-neard-start \
    /usr/local/libexec/reserva-edge-nfc-start \
    /usr/local/libexec/reserva-edge-nfc-mqtt \
    /usr/local/libexec/reserva-edge-led-mqtt \
    /usr/local/lib/reserva-edge/mqtt_common.py
rmdir /usr/local/lib/reserva-edge 2>/dev/null || true

if $PURGE_CONFIG; then
    rm -f /etc/reserva-edge/mqtt.env /etc/reserva-edge/profile.env
    rmdir /etc/reserva-edge 2>/dev/null || true
else
    rm -f /etc/reserva-edge/profile.env
    if [ -f /etc/reserva-edge/mqtt.env ]; then
        printf '%s\n' 'Retained /etc/reserva-edge/mqtt.env; use --purge-config to remove it.'
    fi
fi

systemctl daemon-reload
systemctl enable --now getty@tty1.service 2>/dev/null || true
printf '%s\n' 'Reserva Edge profile removed. Debian packages and TouchKio were left installed.'

