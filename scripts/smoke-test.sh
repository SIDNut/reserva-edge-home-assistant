#!/bin/sh
set -u

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }

printf '%s\n' 'Reserva Edge profile smoke test (read-only)'

for path in \
    /etc/reserva-edge/profile.env \
    /usr/local/bin/reserva-edge-kiosk \
    /usr/local/bin/reserva-edge-touch-session \
    /etc/systemd/system/reserva-edge-kiosk.service; do
    [ -e "$path" ] && pass "$path" || fail "missing $path"
done

command -v touchkio >/dev/null 2>&1 && pass "TouchKio executable" || fail "TouchKio executable missing"
systemctl is-enabled --quiet reserva-edge-kiosk.service && pass "kiosk enabled" || fail "kiosk not enabled"
systemctl is-active --quiet reserva-edge-kiosk.service && pass "kiosk active" || fail "kiosk not active"

if [ -f /etc/reserva-edge/mqtt.env ]; then
    mode=$(stat -c '%a' /etc/reserva-edge/mqtt.env 2>/dev/null || true)
    [ "$mode" = 600 ] && pass "MQTT config mode 0600" || fail "MQTT config mode is ${mode:-unknown}, expected 600"
else
    warn "MQTT config not installed; optional bridges are expected to be disabled"
fi

for unit in reserva-edge-nfc-mqtt.service reserva-edge-led-mqtt.service; do
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        systemctl is-active --quiet "$unit" && pass "$unit active" || fail "$unit enabled but inactive"
    else
        warn "$unit disabled"
    fi
done

[ -r /sys/class/backlight/intel_backlight/max_brightness ] && pass "backlight readable" || fail "backlight missing"
[ -r /proc/bus/input/devices ] && grep -q FTSC1000 /proc/bus/input/devices && pass "touchscreen present" || fail "touchscreen missing"

if [ "$failures" -gt 0 ]; then
    printf '%s\n' "$failures smoke-test check(s) failed." >&2
    exit 1
fi
printf '%s\n' 'Smoke test passed. No hardware was activated.'

