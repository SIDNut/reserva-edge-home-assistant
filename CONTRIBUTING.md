# Contributing

Contributions should preserve the project's two boundaries:

1. Debian installation is an explicit user-operated prerequisite.
2. No Reserva software, factory image, vendor file, credential, or private
   deployment data may enter the repository.

Before opening a pull request:

```sh
python3 tests/test_project.py
python3 scripts/validate-repository.py
```

Run `shellcheck` on changed shell scripts when available. Hardware changes
must describe the exact DMI product, firmware architecture, operating-system
version and live validation performed. Do not infer devices from loaded kernel
modules alone, and do not probe unidentified GPIO, PWM or I2C addresses.

Bug reports should include redacted preflight and smoke-test output. Never
include MQTT configuration, NFC UIDs, browser profiles or factory backups.

