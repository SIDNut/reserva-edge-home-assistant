# Reserva Edge Home Assistant dashboard profile

Turn an owner-authorized ONELAN Reserva Edge 10T / ER5A0 into a dedicated
Home Assistant touch dashboard **after installing standard Debian**.

This project does not contain, copy, unlock, modify, or restore the original
Reserva operating system. It does not distribute Debian, TouchKio binaries,
vendor firmware, device images, browser profiles, or credentials.

> [!CAUTION]
> Installing Debian erases the device. Confirm that you own the device or are
> authorized to repurpose it, make any private backup you require, and use the
> official Debian installer. This project cannot restore the factory system.

## What this project does

The post-install profile configures:

- an X11/Openbox session dedicated to [TouchKio](https://github.com/leukipp/touchkio);
- portrait rotation and FTSC1000 touch alignment;
- a floating Onboard keyboard that appears above the fullscreen kiosk;
- safe idle dimming through the confirmed Intel backlight interface;
- optional NXP NFC events through Home Assistant MQTT discovery; and
- optional red/green/amber status and white LEDs through MQTT discovery.

TouchKio remains an upstream dependency and supplies its own Home Assistant
dashboard, device controls, and optional MQTT entities. This repository adds a
tested ER5A0 operating profile and hardware-specific bridges.

## Tested boundary

The profile targets this verified combination:

| Component | Tested value |
| --- | --- |
| Product/DMI | ER5A0 / Reserva Edge 10T |
| CPU/architecture | Intel Atom Z3735F, x86-64 |
| Firmware | 64-bit UEFI |
| Display/touch | 1280x800 eDP, FTSC1000 |
| Backlight | `/sys/class/backlight/intel_backlight` |
| NFC | NXP1002 via `nxp-nci_i2c` |
| LEDs | ACPI GPIO controller `INT33FC:01`, lines 15, 17 and 23 |
| Operating system | Debian 13 amd64 |
| Kiosk | TouchKio on X11/Openbox |

Run the read-only preflight on every unit. Hardware revisions outside this
matrix are unsupported until independently verified.

## Installation

### 1. Preserve anything you are entitled to keep

If required, make your own offline backup before erasing the eMMC. Do not post
factory images: they can contain organization configuration and credentials.
The project intentionally provides no extraction or factory-image tooling.

### 2. Install official Debian

Use the official [Debian 13 amd64 installation media](https://www.debian.org/CD/)
and [installation guide](https://www.debian.org/releases/trixie/amd64/).

Recommended choices:

- standard Debian system without a desktop environment;
- a normal non-root administrator account;
- wired DHCP for the first installation; and
- SSH server, if remote administration is required.

Disk selection and confirmation remain entirely inside Debian's installer.

### 3. Install TouchKio from upstream

Download the current x64 `.deb` from the official
[TouchKio releases](https://github.com/leukipp/touchkio/releases), inspect the
release, and install the local file:

```sh
sudo apt install ./touchkio_*_x64.deb
```

Do not run an unreviewed pipe-to-shell installer as root. The profile installer
will also accept a downloaded package with `--touchkio-deb /path/file.deb`.

### 4. Preflight and apply the profile

```sh
git clone https://github.com/SIDNut/reserva-edge-home-assistant.git
cd reserva-edge-home-assistant
./scripts/preflight.sh
cp config/profile.env.example profile.env
nano profile.env
sudo ./scripts/install-profile.sh --config ./profile.env
```

The installer prints its plan and requests confirmation. Use `--dry-run` to
inspect the plan without writing, or `--yes` only in reviewed automation.

### 5. Configure TouchKio and optional MQTT bridges

Run TouchKio's own setup as the configured profile user if its MQTT features
are wanted:

```sh
touchkio --setup
systemctl --user disable --now touchkio.service
```

The profile's system service owns kiosk autostart, so the upstream user service
must remain disabled. The NFC and LED bridges use a separate root-owned
credential file so they do
not decrypt, scrape, or duplicate TouchKio's private configuration:

```sh
cp config/mqtt.env.example mqtt.env
nano mqtt.env
sudo ./scripts/configure-mqtt.sh --config ./mqtt.env
```

Delete the local `mqtt.env` after successful installation. It is ignored by
Git but should not remain in a clone unnecessarily.

### 6. Validate

```sh
sudo ./scripts/smoke-test.sh
```

The smoke test is read-only. It does not scan I2C, activate NFC, toggle GPIO,
or publish test messages.

## Recovery and removal

See [recovery](docs/recovery.md) before installation. To remove this profile
without reinstalling Debian:

```sh
sudo ./scripts/uninstall-profile.sh
```

Removal disables the kiosk and hardware bridges and removes project-owned
files. It does not uninstall Debian packages, TouchKio, or restore Reserva.

## Support and community

Open an issue with the redacted output of `scripts/preflight.sh` and
`scripts/smoke-test.sh`. Never attach MQTT configuration, browser profiles,
factory backups, SSH keys, or unreviewed logs.

This independent community project is not affiliated with or endorsed by
ONELAN, Reserva, Tripleplay, Uniguest, Debian, Home Assistant, or TouchKio.
Product and project names are used only to identify compatibility.

## License

Original project code is MIT licensed. Dependencies retain their own licenses.
TouchKio is separately distributed under its upstream MIT license.
