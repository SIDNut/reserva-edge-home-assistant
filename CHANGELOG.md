# Changelog

## Unreleased

- Make NFC auto-detection package-aware so Debian 13 continues with the core
  kiosk when its official repositories do not provide `neard`.
- Clarify that the tested minimal base requires regular Debian Installer media,
  preferably netinst, rather than a desktop Live ISO.
- Establish the project as a Debian post-install hardware profile.
- Add read-only ER5A0 preflight and smoke tests.
- Add TouchKio/Openbox/Onboard kiosk configuration and idle dimming.
- Add optional NFC and GPIO LED MQTT discovery bridges.
- Add recovery, uninstall, credential isolation and publication guards.

