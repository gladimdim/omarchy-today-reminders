# Today Ping (`gladimdim.today-ping`)

A today-only reminder plugin for the [Omarchy](https://omarchy.org/) bar. Click the bell in the center dock, say **when** to notify you and **what** to tell you, and get a quiet desktop ping at that time.

Reminders never roll into tomorrow. Once they ring — or you dismiss them — they are gone. Waiting pings for today are stored in `~/.local/state/omarchy/today-ping.json` and come back after a reboot.

## Use

- **Left click** the bell in the center of the bar. Type a time for today (`15:30`, `3:30pm`), Enter, then type the message and Enter again.
- **Right click** the bell → **Show reminders**. Today's waiting pings appear in a small popup. Click a row (or ✕) to dismiss it before it fires.
- At the chosen time: a notification plus a ding-dong (`assets/chime.wav`). The reminder is then deleted.

Times already in the past are rejected. Escape cancels the dialog.

## Install

From this checkout:

```bash
omarchy plugin add /home/$USER/GitHub/omarchy-today-ping --enable --yes
```

The widget lands in the center section by default. Move it with:

```bash
omarchy bar move gladimdim.today-ping --section center --after omarchy.clock
```

## Remove

```bash
omarchy plugin remove gladimdim.today-ping --yes
```

State lives at `~/.local/state/omarchy/today-ping.json`. Delete that file to reset.

## Files

- `manifest.json` — `service` + `overlay` + `bar-widget`, center by default
- `Service.qml` — fires due reminders once a second, plays `assets/chime.wav`, drops yesterday
- `CreateFlow.qml` — two-step overlay: "When to notify you" then "What to tell you"
- `BarWidget.qml` — center-bar bell, right-click menu, pending badge
- `ListPanel.qml` — today's list
- `TodayPing.js` — time parsing and today-only store

## License

MIT — see [LICENSE](LICENSE).
