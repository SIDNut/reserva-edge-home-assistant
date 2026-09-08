#!/usr/bin/env python3
from __future__ import annotations

import ast
import shutil
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ProjectTests(unittest.TestCase):
    def test_required_publication_files_exist(self):
        required = [
            "README.md",
            "LICENSE",
            "SECURITY.md",
            "CONTRIBUTING.md",
            "config/profile.env.example",
            "config/mqtt.env.example",
            "scripts/preflight.sh",
            "scripts/install-profile.sh",
            "scripts/configure-mqtt.sh",
            "scripts/uninstall-profile.sh",
            "scripts/smoke-test.sh",
            "docs/debian-install.md",
            "docs/recovery.md",
            "docs/hardware.md",
        ]
        for relative in required:
            with self.subTest(relative=relative):
                self.assertTrue((ROOT / relative).is_file())

    def test_python_payloads_parse(self):
        paths = list((ROOT / "scripts").glob("*.py"))
        paths += list((ROOT / "payload").rglob("*.py"))
        paths += [
            ROOT / "payload/usr/local/libexec/reserva-edge-nfc-mqtt",
            ROOT / "payload/usr/local/libexec/reserva-edge-led-mqtt",
        ]
        for path in paths:
            with self.subTest(path=path.relative_to(ROOT)):
                ast.parse(path.read_text(encoding="utf-8"), filename=str(path))

    def test_shell_scripts_parse_when_sh_is_available(self):
        shell = shutil.which("sh")
        if not shell:
            self.skipTest("sh is unavailable on this host")
        scripts = [
            path for path in ROOT.rglob("*")
            if path.is_file() and path.read_bytes().startswith(b"#!/bin/sh")
        ]
        for path in scripts:
            with self.subTest(path=path.relative_to(ROOT)):
                subprocess.run([shell, "-n", str(path)], check=True)

    def test_common_shell_parser_when_sh_is_available(self):
        shell = shutil.which("sh")
        if not shell:
            self.skipTest("sh is unavailable on this host")
        subprocess.run([shell, str(ROOT / "tests/test_common.sh")], check=True)

    def test_publication_guard(self):
        subprocess.run(
            [sys.executable, str(ROOT / "scripts/validate-repository.py")],
            cwd=ROOT,
            check=True,
        )

    def test_examples_are_placeholders(self):
        mqtt = (ROOT / "config/mqtt.env.example").read_text(encoding="utf-8")
        self.assertIn("MQTT_PASSWORD=replace-locally", mqtt)
        self.assertNotIn("MQTT_PASSWORD=\n", mqtt)
        profile = (ROOT / "config/profile.env.example").read_text(encoding="utf-8")
        self.assertIn("https://homeassistant.local:8123", profile)

    def test_no_custom_os_installer_or_partition_command(self):
        executable_files = list((ROOT / "scripts").glob("*"))
        executable_files += list((ROOT / "payload").rglob("*"))
        forbidden = ("parted ", "partman", "mkfs.", "dd if=", "wipefs", "debootstrap")
        for path in executable_files:
            if not path.is_file():
                continue
            content = path.read_text(encoding="utf-8", errors="ignore")
            for token in forbidden:
                with self.subTest(path=path.relative_to(ROOT), token=token):
                    self.assertNotIn(token, content)

    def test_generated_kiosk_unit_template_shape(self):
        template = (
            ROOT / "payload/etc/systemd/system/reserva-edge-kiosk.service"
        ).read_text(encoding="utf-8")
        rendered = template.replace("@PROFILE_USER@", "kiosk-test")
        rendered = rendered.replace("@PROFILE_HOME@", "/home/kiosk-test")
        self.assertIn("User=kiosk-test", rendered)
        self.assertIn("WorkingDirectory=/home/kiosk-test", rendered)
        self.assertNotIn("@PROFILE_", rendered)
        self.assertIn("Conflicts=getty@tty1.service", rendered)

    def test_nfc_auto_mode_is_package_aware(self):
        installer = (ROOT / "scripts/install-profile.sh").read_text(encoding="utf-8")
        self.assertIn("apt-cache policy neard", installer)
        self.assertIn("neard_candidate", installer)
        self.assertIn("neard_available", installer)
        self.assertIn("disabling the optional NFC bridge", installer)
        self.assertRegex(
            installer,
            r"(?s)if \[ \"\$ENABLE_NFC\" = auto \]; then.*?ENABLE_NFC=false",
        )

    def test_installer_creates_rootless_xorg_log_directory(self):
        installer = (ROOT / "scripts/install-profile.sh").read_text(encoding="utf-8")
        self.assertIn('$PROFILE_HOME/.local/share/xorg', installer)

    def test_installer_supports_default_mdns_dashboard_url(self):
        installer = (ROOT / "scripts/install-profile.sh").read_text(encoding="utf-8")
        self.assertIn("avahi-daemon", installer)
        self.assertIn("libnss-mdns", installer)

    def test_reapply_restarts_kiosk_with_new_configuration(self):
        installer = (ROOT / "scripts/install-profile.sh").read_text(encoding="utf-8")
        self.assertIn("systemctl enable reserva-edge-kiosk.service", installer)
        self.assertIn("systemctl restart reserva-edge-kiosk.service", installer)

    def test_onboard_kiosk_defaults(self):
        session = (
            ROOT / "payload/usr/local/bin/reserva-edge-touch-session"
        ).read_text(encoding="utf-8")
        self.assertIn("org.onboard.auto-show enabled true", session)
        self.assertIn("org.onboard.icon-palette in-use false", session)
        self.assertIn("/usr/share/onboard/layouts/Phone.onboard", session)
        self.assertIn("/usr/share/onboard/themes/Droid.theme", session)
        self.assertIn("org.onboard system-theme-tracking-enabled false", session)
        self.assertIn("org.onboard.window docking-enabled false", session)
        self.assertIn("org.onboard.window force-to-top true", session)


if __name__ == "__main__":
    unittest.main(verbosity=2)
