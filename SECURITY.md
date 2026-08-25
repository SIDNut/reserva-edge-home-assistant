# Security policy

## Supported versions

Only the latest tagged release is supported. Until a stable release exists,
the project should be treated as pre-release software for owner-managed
devices on a trusted network.

## Reporting vulnerabilities

Use GitHub's private security-advisory reporting flow when enabled. Do not put
credentials, private hostnames, IP addresses, Home Assistant URLs, NFC tag
identifiers, browser profiles, factory images, or full diagnostic archives in
a public issue.

## Credential boundary

- `profile.env` must never contain passwords.
- MQTT credentials are installed to `/etc/reserva-edge/mqtt.env` with mode
  `0600` and are read only by root-run hardware bridge services.
- The project never reads TouchKio's argument or browser-profile files.
- The project never requests Home Assistant access tokens.
- Prefer a dedicated MQTT account with only the required topic permissions.

## Device boundary

The installer does not partition disks or access a former Reserva filesystem.
GPIO operations are limited to the three confirmed LED lines and the LED
bridge refuses to start unless the controller label matches `INT33FC:01`.

