var maxMessage = 280
var maxReminders = 50
var maxScanReminders = 100
var stateMaxBytes = 65536
var stateFileName = "today-ping.json"

function pad2(n) {
  n = Number(n)
  return n < 10 ? "0" + n : String(n)
}

function todayKey(d) {
  d = d || new Date()
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function stateDir(home, stateHome) {
  var base = String(stateHome || "")
  if (!base) base = String(home || "") + "/.local/state"
  return base + "/omarchy"
}

function statePath(home, stateHome) {
  return stateDir(home, stateHome) + "/" + stateFileName
}

function emptyState(now) {
  return { date: todayKey(now), reminders: [] }
}

function newId(now) {
  now = now || new Date()
  return now.getTime().toString(36) + "-" + Math.floor(Math.random() * 1e9).toString(36)
}

function formatTime(hour, minute) {
  return pad2(hour) + ":" + pad2(minute)
}

function suggestedWhen(now) {
  now = now || new Date()
  var at = new Date(now.getTime() + 15 * 60 * 1000)
  if (todayKey(at) !== todayKey(now)) {
    at = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 0, 0)
    if (at.getTime() <= now.getTime()) return ""
  }
  return formatTime(at.getHours(), at.getMinutes())
}

var reminderPhrases = [
  "Stand up and stretch",
  "Drink some water",
  "Look away from the screen",
  "Check the oven",
  "Put the kettle on",
  "Take a breath",
  "Lock the door",
  "Feed the cat",
  "Time to wrap up",
  "Call back",
  "Water the plants",
  "Grab a snack"
]

function randomPhrase() {
  return reminderPhrases[Math.floor(Math.random() * reminderPhrases.length)]
}

function parseWhen(text, now) {
  now = now || new Date()
  var raw = String(text || "").trim().toLowerCase()
  if (!raw) return { ok: false, error: "Enter a time for today" }

  var ampm = ""
  var ampmMatch = raw.match(/\s*(a\.?m\.?|p\.?m\.?)\s*$/)
  if (ampmMatch) {
    ampm = ampmMatch[1].charAt(0)
    raw = raw.slice(0, raw.length - ampmMatch[0].length).trim()
  }

  var hour
  var minute = 0
  var hm = raw.match(/^(\d{1,2})[:.h](\d{2})$/)
  if (hm) {
    hour = Number(hm[1])
    minute = Number(hm[2])
  } else if (/^\d{3,4}$/.test(raw)) {
    if (raw.length === 3) {
      hour = Number(raw.charAt(0))
      minute = Number(raw.slice(1))
    } else {
      hour = Number(raw.slice(0, 2))
      minute = Number(raw.slice(2))
    }
  } else if (/^\d{1,2}$/.test(raw)) {
    hour = Number(raw)
    minute = 0
  } else {
    return { ok: false, error: "Try 15:30 or 3:30pm" }
  }

  if (minute < 0 || minute > 59) return { ok: false, error: "Minutes must be 00–59" }

  if (ampm) {
    if (hour < 1 || hour > 12) return { ok: false, error: "Hour must be 1–12 with am/pm" }
    if (ampm === "a") hour = hour === 12 ? 0 : hour
    else hour = hour === 12 ? 12 : hour + 12
  } else if (hour < 0 || hour > 23) {
    return { ok: false, error: "Hour must be 0–23" }
  }

  var at = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0, 0)
  if (at.getTime() <= now.getTime()) {
    return { ok: false, error: "That time has already passed today" }
  }

  return {
    ok: true,
    hour: hour,
    minute: minute,
    atMs: at.getTime(),
    atLabel: formatTime(hour, minute),
    date: todayKey(now)
  }
}

function sanitizeMessage(text) {
  var message = String(text || "")
  message = message.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "")
  message = message.replace(/\s+/g, " ").trim()
  if (message.length > maxMessage) message = message.slice(0, maxMessage)
  return message
}

function sanitizeId(value) {
  var id = String(value || "").slice(0, 64)
  if (!/^[A-Za-z0-9._-]+$/.test(id)) return ""
  return id
}

function notifySafeText(value) {
  var text = String(value || "")
  if (text.charAt(0) === "-") return " " + text
  return text
}

function sanitizeReminder(item, today) {
  if (!item || typeof item !== "object") return null
  var id = sanitizeId(item.id)
  var atMs = Number(item.atMs)
  var message = sanitizeMessage(item.message)
  if (!id || !isFinite(atMs) || atMs <= 0 || !message) return null
  var atLabel = String(item.atLabel || "")
  if (!/^\d{2}:\d{2}$/.test(atLabel)) {
    var at = new Date(atMs)
    atLabel = formatTime(at.getHours(), at.getMinutes())
  }
  return {
    id: id,
    atMs: atMs,
    atLabel: atLabel,
    message: message,
    date: today
  }
}

function parseState(raw) {
  if (!raw) return null
  if (typeof raw === "string" && raw.length > stateMaxBytes) return null
  try {
    var parsed = typeof raw === "string" ? JSON.parse(raw) : raw
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null
    return parsed
  } catch (e) {
    return null
  }
}

function sortReminders(items) {
  items.sort(function (a, b) {
    if (a.atMs !== b.atMs) return a.atMs - b.atMs
    return String(a.id).localeCompare(String(b.id))
  })
  return items
}

function reconcile(raw, now) {
  now = now || new Date()
  var today = todayKey(now)
  var parsed = parseState(raw)
  var due = []
  var pending = []
  var changed = false

  if (!parsed || parsed.date !== today) {
    changed = true
    parsed = emptyState(now)
  }

  var items = Array.isArray(parsed.reminders) ? parsed.reminders : []
  if (items.length > maxScanReminders) {
    items = items.slice(0, maxScanReminders)
    changed = true
  }
  for (var i = 0; i < items.length; i++) {
    var reminder = sanitizeReminder(items[i], today)
    if (!reminder) {
      changed = true
      continue
    }
    if (reminder.atMs <= now.getTime()) due.push(reminder)
    else pending.push(reminder)
  }

  if (due.length > 0) changed = true
  if (pending.length > maxReminders) {
    pending = pending.slice(0, maxReminders)
    changed = true
  }

  return {
    state: { date: today, reminders: sortReminders(pending) },
    due: due,
    changed: changed
  }
}

function addReminder(raw, whenText, messageText, now) {
  now = now || new Date()
  var when = parseWhen(whenText, now)
  if (!when.ok) return { ok: false, error: when.error }

  var message = sanitizeMessage(messageText)
  if (!message) return { ok: false, error: "Say what to tell you" }

  var current = reconcile(raw, now)
  if (current.state.reminders.length >= maxReminders) {
    return { ok: false, error: "That's enough reminders for today" }
  }

  var reminder = {
    id: newId(now),
    atMs: when.atMs,
    atLabel: when.atLabel,
    message: message,
    date: when.date
  }
  current.state.reminders.push(reminder)
  sortReminders(current.state.reminders)

  return { ok: true, state: current.state, reminder: reminder }
}

function removeReminder(raw, id, now) {
  now = now || new Date()
  var current = reconcile(raw, now)
  var next = []
  var removed = null
  for (var i = 0; i < current.state.reminders.length; i++) {
    if (current.state.reminders[i].id === String(id)) {
      removed = current.state.reminders[i]
      continue
    }
    next.push(current.state.reminders[i])
  }
  current.state.reminders = next
  return { ok: !!removed, state: current.state, reminder: removed }
}

function encode(state) {
  return JSON.stringify(state || emptyState(), null, 2) + "\n"
}

var toastExpireMs = 15000

function toastForReminder(reminder) {
  return {
    title: notifySafeText((reminder && reminder.atLabel) || "Today Reminders"),
    body: notifySafeText((reminder && reminder.message) || "")
  }
}

function tooltipFor(reminders) {
  var items = Array.isArray(reminders) ? reminders : []
  if (items.length === 0) return "Today Reminders — click to set"
  var lines = []
  for (var i = 0; i < items.length; i++) {
    var r = items[i]
    if (!r) continue
    var time = String(r.atLabel || "")
    var message = String(r.message || "")
    if (time && message) lines.push(time + "  " + message)
    else if (time) lines.push(time)
    else if (message) lines.push(message)
  }
  return lines.length ? lines.join("\n") : "Today Reminders — click to set"
}

if (typeof module !== "undefined") {
  module.exports = {
    todayKey: todayKey,
    statePath: statePath,
    emptyState: emptyState,
    parseWhen: parseWhen,
    suggestedWhen: suggestedWhen,
    randomPhrase: randomPhrase,
    sanitizeMessage: sanitizeMessage,
    reconcile: reconcile,
    addReminder: addReminder,
    removeReminder: removeReminder,
    encode: encode,
    sanitizeId: sanitizeId,
    notifySafeText: notifySafeText,
    stateMaxBytes: stateMaxBytes,
    toastExpireMs: toastExpireMs,
    toastForReminder: toastForReminder,
    tooltipFor: tooltipFor
  }
}
