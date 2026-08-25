# Clean Debian installation on an ER5A0

This checklist deliberately keeps operating-system installation in the
official Debian Installer. The project does not provide a modified image,
partitioning script, unattended installer, factory image, or vendor software.

> [!CAUTION]
> This process erases the selected disk. Confirm ownership or authorization,
> keep any private recovery image you require, and identify the internal eMMC
> from current hardware evidence before confirming partition changes.

## 1. Boot official media in 64-bit UEFI mode

Use an official Debian 13 amd64 netinst image, or select the Debian Installer
entry from official Debian live media. Do not launch Calamares from the live
desktop for this tested path; it installs the live desktop environment.

At an installer shell or live shell, these read-only checks should identify an
ER5A0 and 64-bit UEFI firmware:

```sh
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/board_name
cat /sys/firmware/efi/fw_platform_size
lsblk -e7 -o NAME,PATH,SIZE,RO,RM,TYPE,FSTYPE,LABEL,MODEL,SERIAL,TRAN,MOUNTPOINTS
```

Expected identity is `ER5A0` and firmware size is `64`. Identify the internal
eMMC by its non-removable status and approximately 14.6 GiB size. Device names
can vary with kernel and boot media; never select a disk solely because an
example calls it `/dev/mmcblk1`.

If a previously imaged eMMC is unexpectedly marked read-only, stop and confirm
the DMI identity and block-device list again. Only after confirming the exact
non-removable target, a transient kernel flag can be cleared from a live shell:

```sh
sudo blockdev --setrw /dev/mmcblk1
sudo blockdev --getro /dev/mmcblk1
```

The final command must print `0`. If it remains read-only or the kernel reports
MMC/I/O errors, do not install; investigate the media first.

## 2. Debian Installer choices

Use the normal guided installer flow:

1. Configure locale, keyboard and wired networking for the deployment.
2. Set a unique hostname and leave the domain blank unless the network uses one.
3. Create a normal non-root administrator account; leaving the root password
   blank disables direct root login and enables sudo for that account.
4. Select guided partitioning on the verified internal eMMC, not the removable
   USB installer. A single filesystem is suitable for the small eMMC.
5. Use a Debian mirror when prompted.
6. At software selection, select only **SSH server** and **standard system
   utilities**. Clear **Debian desktop environment** and every desktop choice.
7. Complete the bootloader installation, remove the installation media, and
   boot from the internal eMMC.

Disk selection and the final destructive confirmation remain entirely inside
the official Debian Installer.

## 3. Verify the clean base

After the first boot, log in as the administrator account and run:

```sh
cat /etc/os-release
uname -m
test "$(cat /sys/firmware/efi/fw_platform_size)" = 64
systemctl is-enabled display-manager.service 2>/dev/null && exit 1 || true
```

The expected base is Debian 13, `x86_64`, 64-bit UEFI, and no enabled display
manager. Install `git` if the installer did not include it, then return to the
README and clone this public repository. The project preflight is read-only and
must pass before the profile installer is run.
