# Architecture

```text
official Debian install (user-operated, destructive)
                    |
                    v
          read-only hardware preflight
                    |
                    v
      Reserva Edge post-install profile
       |             |              |
       v             v              v
 TouchKio kiosk   NFC bridge     LED bridge
       |             |              |
       +-------------+--------------+
                     |
              MQTT discovery
                     |
              Home Assistant
```

The profile owns only files whose names begin with `reserva-edge` plus
`/etc/reserva-edge`. It does not modify Home Assistant configuration. TouchKio
and the two optional bridges publish standard MQTT discovery messages, so no
custom Home Assistant integration is required.

The kiosk service conflicts with `getty@tty1` only while it is active. Recovery
re-enables the normal tty1 login. The installer refuses an enabled graphical
display manager unless the user removes or disables it first.

