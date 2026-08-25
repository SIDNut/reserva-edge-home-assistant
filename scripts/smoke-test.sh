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
    if [ -e "$path" ]; then
        pass "$path"
    else
        fail "missing $path"
    fi
done

if command -v touchkio >/dev/null 2>&1; then
    pass "TouchKio executable"
else
    fail "TouchKio executable missing"
fi
if systemctl is-enabled --quiet reserva-edge-kiosk.service; then
    pass "kiosk enabled"
else
    fail "kiosk not enabled"
fi
if systemctl is-active --quiet reserva-edge-kiosk.service; then
    pass "kiosk active"
else
    fail "kiosk not active"
fi

if [ -f /etc/reserva-edge/mqtt.env ]; then
    mode=$(stat -c '%a' /etc/reserva-edge/mqtt.env 2>/dev/null || true)
    if [ "$mode" = 600 ]; then
        pass "MQTT config mode 0600"
    else
        fail "MQTT config mode is ${mode:-unknown}, expected 600"
    fi
else
    warn "MQTT config not installed; optional bridges are expected to be disabled"
fi

for unit in reserva-edge-nfc-mqtt.service reserva-edge-led-mqtt.service; do
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        if systemctl is-active --quiet "$unit"; then
            pass "$unit active"
        else
            fail "$unit enabled but inactive"
        fi
    else
        warn "$unit disabled"
    fi
done

if [ -r /sys/class/backlight/intel_backlight/max_brightness ]; then
    pass "backlight readable"
else
    fail "backlight missing"
fi
if [ -r /proc/bus/input/devices ] && grep -q FTSC1000 /proc/bus/input/devices; then
    pass "touchscreen present"
else
    fail "touchscreen missing"
fi

if [ "$failures" -gt 0 ]; then
    printf '%s\n' "$failures smoke-test check(s) failed." >&2
    exit 1
fi
printf '%s\n' 'Smoke test passed. No hardware was activated.'
