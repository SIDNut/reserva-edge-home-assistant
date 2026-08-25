#!/bin/sh
set -u

ALLOW_UNSUPPORTED=false
if [ "${1:-}" = "--allow-unsupported" ]; then
    ALLOW_UNSUPPORTED=true
elif [ "$#" -ne 0 ]; then
    printf 'Usage: %s [--allow-unsupported]\n' "$0" >&2
    exit 2
fi

failures=0

pass() { printf 'PASS  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }

read_first() {
    if [ -r "$1" ]; then
        head -n 1 "$1" 2>/dev/null || true
    fi
}

printf '%s\n' 'Reserva Edge profile preflight (read-only)'

if [ -r /etc/os-release ]; then
    # The file belongs to the installed operating system.
    # shellcheck disable=SC1091
    . /etc/os-release
    if [ "${ID:-}" = debian ] && [ "${VERSION_ID:-}" = 13 ]; then
        pass "Debian 13 detected"
    else
        fail "Expected Debian 13; found ${PRETTY_NAME:-unknown}"
    fi
else
    fail "/etc/os-release is unavailable"
fi

arch=$(uname -m 2>/dev/null || true)
if [ "$arch" = x86_64 ]; then
    pass "x86-64 architecture"
else
    fail "Expected x86_64; found ${arch:-unknown}"
fi

product=$(read_first /sys/class/dmi/id/product_name)
board=$(read_first /sys/class/dmi/id/board_name)
case "$product $board" in
    *ER5A0*) pass "ER5A0 DMI identity: product=$product board=$board" ;;
    *) fail "ER5A0 DMI identity not found: product=${product:-unknown} board=${board:-unknown}" ;;
esac

firmware_bits=$(read_first /sys/firmware/efi/fw_platform_size)
if [ "$firmware_bits" = 64 ]; then
    pass "64-bit UEFI"
else
    fail "Expected 64-bit UEFI; found ${firmware_bits:-not-booted-via-UEFI}"
fi

if [ -r /sys/class/backlight/intel_backlight/max_brightness ]; then
    pass "Intel backlight interface"
else
    fail "Missing /sys/class/backlight/intel_backlight"
fi

if [ -r /proc/bus/input/devices ] && grep -q 'FTSC1000' /proc/bus/input/devices; then
    pass "FTSC1000 touchscreen"
else
    fail "FTSC1000 touchscreen not detected"
fi

emmc_found=false
for removable in /sys/block/mmcblk*/removable; do
    [ -r "$removable" ] || continue
    if [ "$(read_first "$removable")" = 0 ]; then emmc_found=true; break; fi
done
if $emmc_found; then
    pass "non-removable eMMC present"
else
    warn "no non-removable mmcblk device detected"
fi

if [ -e /sys/class/nfc/nfc0 ]; then
    pass "optional NXP NFC interface"
else
    warn "optional NFC interface not detected"
fi

if command -v gpiodetect >/dev/null 2>&1 && gpiodetect 2>/dev/null | grep -q '\[INT33FC:01\]'; then
    pass "optional verified LED GPIO controller"
else
    warn "LED controller not confirmed yet (gpiod tools may not be installed)"
fi

if [ -L /etc/systemd/system/display-manager.service ]; then
    fail "a graphical display manager is enabled; use a minimal Debian install or disable it first"
else
    pass "no graphical display manager enabled"
fi

if [ "$failures" -gt 0 ]; then
    if $ALLOW_UNSUPPORTED; then
        warn "$failures required check(s) failed; override requested"
        exit 0
    fi
    printf '%s\n' "$failures required check(s) failed. No changes were made." >&2
    exit 1
fi

printf '%s\n' 'Preflight passed. No changes were made.'
