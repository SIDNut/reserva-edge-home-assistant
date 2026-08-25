# Third-party software

This repository does not vendor third-party binaries.

| Dependency | Purpose | Source and license |
| --- | --- | --- |
| Debian GNU/Linux | Base operating system installed by the user | [Debian copyright information](https://www.debian.org/legal/licenses/) |
| TouchKio | Home Assistant kiosk application | [leukipp/touchkio](https://github.com/leukipp/touchkio), MIT |
| Home Assistant | Dashboard and MQTT discovery consumer | [home-assistant/core](https://github.com/home-assistant/core), Apache-2.0 |
| neard | NFC D-Bus service | [linux-nfc/neard](https://github.com/linux-nfc/neard), GPL-2.0 |
| Eclipse Paho MQTT | Python MQTT client | [eclipse-paho/paho.mqtt.python](https://github.com/eclipse-paho/paho.mqtt.python), EPL-2.0 or EDL-1.0 |
| libgpiod | GPIO userspace interface | [brgl/libgpiod](https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/), LGPL-2.1 |

Package installation is performed from the user's configured Debian package
sources. Refer to the installed packages for exact copyright files and terms.

