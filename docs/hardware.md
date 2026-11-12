# Verified hardware profile

## Confirmed interfaces

| Function | Linux interface | Handling |
| --- | --- | --- |
| Display | Intel i915, eDP 1280x800 | X11 `xrandr` rotation |
| Touch | FTSC1000 `2808:5012` | XInput coordinate matrix |
| Backlight | `/sys/class/backlight/intel_backlight` | exact-path sudo rule |
| NFC | ACPI `NXP1002`, `nxp-nci_i2c`, `nfc0` | Optional neard D-Bus polling; requires an installable `neard` package or an existing enabled and running `neard.service` providing `org.neard` |
| Status LED | `INT33FC:01` GPIO lines 15 and 17 | red/green/amber output |
| White LED | `INT33FC:01` GPIO line 23 | on/off output |

The LED bridge accepts transient commands under `<TOPIC_ROOT>/led/`:

- `notification/set`: a JSON object with an `id`, optional `priority`,
  `status` (`off`, `red`, `green`, or `amber`), `white`, `pattern` (`solid`,
  `slow`, `medium`, or `fast`), `ttl` in seconds, and `wake`. Set `action`
  to `clear` with the same `id` to remove an alert. The highest priority
  wins, with the most recent alert breaking ties. A missing or zero TTL
  means the alert lasts until cleared or the bridge restarts.
- `chime/set`: `doorbell`, `laundry`, or `info`. The managed kiosk session
  plays the corresponding packaged sound. Send commands without MQTT retain.

`wake` prevents the managed idle dimmer from dimming the display while the
winning alert is active. These indicators supplement dedicated alarms.
| Audio | RT5645 family | PulseAudio-compatible session |

The chassis status light is bi-colour red/green, with amber produced by both
channels. It is not a continuously variable RGB light.

## Deliberately unsupported assumptions

No camera, battery, ambient-light, proximity, motion or room-temperature
sensor is assumed. Kernel modules alone are not evidence that a component is
installed. The tools do not scan I2C addresses or probe unidentified GPIO/PWM.

## Other revisions

Some Atom devices use 32-bit UEFI despite a 64-bit CPU. This profile requires
an installed amd64 Debian system booted through 64-bit UEFI. A failing
preflight is a stop condition, not an invitation to bypass hardware checks.

