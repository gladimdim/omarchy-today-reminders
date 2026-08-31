# Today Reminders (`gladimdim.today-ping`)

A reminder widget for [Omarchy](https://omarchy.org/). Click the bell in the center dock, pick a time later today, say what to tell you, and get a notification when it fires.

Reminders never roll into tomorrow. Once they ring — or you dismiss them — they are gone. Waiting pings for today are stored in `~/.local/state/omarchy/today-ping.json` and come back after a reboot.

## Use

- **Left click** the bell in the center of the bar. Type a time for today (`15:30`, `3:30pm`), Enter, then type the message and Enter again.
- **Right click** the bell → **Show reminders**. Today's waiting pings appear in a small popup. Click a row (or ✕) to dismiss it before it fires.
- At the chosen time: a notification plus a ding-dong (`assets/chime.wav`). The reminder is then deleted.

Times already in the past are rejected. Escape cancels the dialog.

## Install

```bash
omarchy plugin add https://github.com/gladimdim/omarchy-today-reminders.git --enable --yes
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
- `CreateFlow.qml` — two-step overlay: "When to notify" then "What to notify"
- `BarWidget.qml` — center-bar bell, right-click menu, pending badge
- `ListPanel.qml` — today's list
- `TodayPing.js` — time parsing and today-only store

## License

MIT — see [LICENSE](LICENSE).
