# zmod_dualweb

> **Parts:** the printers, boards, readers and other gear that go with this project are listed at [projects.die-hard.net/gear](https://projects.die-hard.net/gear) (Amazon affiliate links).

Run **Fluidd and Mainsail at the same time** on a **Zmod** printer (Flashforge
AD5X, Creator 5, AD5M). Zmod normally serves one web interface on port 80 and
its `WEB` macro switches between them. With this plugin:

| Port | Interface |
|------|-----------|
| 80   | the one Zmod is set to (Fluidd by default) |
| 81   | the other one |

`WEB` now **swaps** the two between ports 80 and 81 instead of turning one off.

```
WEB              swap Fluidd and Mainsail between ports 80 and 81
DUALWEB          show which interface is on which port
DUALWEB STOP=1   stop port 81 until the next Klipper start
```

After `WEB`, press Ctrl + F5 in the browser so the page is reloaded.

## How it works

Port 81 is a second nginx, built from Zmod's own nginx template, so it proxies
Moonraker, the webcam (`/webcam/`) and the screen view (`/screen/`) the same
way port 80 does. It uses its own copy of Zmod's nginx binary, so Zmod
restarting its web server (`killall nginx`) does not take port 81 down. Zmod's
files are not changed.

- Klipper starts port 81 five seconds after it starts (and after every
  `RESTART`).
- `WEB` runs Zmod's own switch for port 80, then restarts port 81 with the
  other interface.
- Log: `mod_data/log/zmod_dualweb.log`.

## Install

Add this to `mod_data/user.moonraker.conf`:

```ini
[update_manager zmod_dualweb]
type: git_repo
channel: stable
path: /root/printer_data/config/mod_data/plugins/zmod_dualweb
origin: https://github.com/DIEHARDave/zmod_dualweb.git
is_system_service: False
primary_branch: main
```

Then run `ENABLE_PLUGIN name=zmod_dualweb` in the console. Port 81 starts
right away.

## Uninstall

Run `DISABLE_PLUGIN name=zmod_dualweb`. Port 81 stops and Zmod's own `WEB`
comes back after the Klipper restart.

## License

GPL-3.0, see [LICENSE](LICENSE).
