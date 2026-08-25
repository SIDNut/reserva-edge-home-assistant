# Recovery and rollback

Read this before enabling the kiosk.

## Reach a console

The kiosk runs as `reserva-edge-kiosk.service` on virtual terminal 1. SSH is
the preferred recovery path. With a connected keyboard, switch to another
virtual terminal with `Ctrl+Alt+F2` and log in normally.

## Stop the kiosk

```sh
sudo systemctl disable --now reserva-edge-kiosk.service
sudo systemctl enable --now getty@tty1.service
```

## Hold TouchKio without stopping X11

```sh
touch ~/.config/reserva-edge/kiosk.hold
rm ~/.config/reserva-edge/kiosk.hold
```

The first command lets the current TouchKio process exit and prevents its
restart. Remove the marker to allow it to start again.

## Inspect logs

```sh
journalctl -u reserva-edge-kiosk.service -b --no-pager
journalctl -u reserva-edge-nfc-mqtt.service -b --no-pager
journalctl -u reserva-edge-led-mqtt.service -b --no-pager
```

Redact URLs, usernames, IP addresses, NFC identifiers and MQTT details before
sharing output.

## Remove the profile

```sh
sudo ./scripts/uninstall-profile.sh
```

By default, `/etc/reserva-edge/mqtt.env` is retained to avoid unexpectedly
destroying a credential. After confirming it is no longer needed:

```sh
sudo ./scripts/uninstall-profile.sh --purge-config
```

Neither command restores the factory Reserva operating system.

