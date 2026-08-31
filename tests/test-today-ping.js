const assert = require("assert")
const TodayPing = require("../TodayPing.js")

function at(h, m, y, mo, d) {
  return new Date(y || 2026, (mo || 8) - 1, d || 31, h, m, 0, 0)
}

function testParseWhen() {
  const now = at(14, 0)
  assert.strictEqual(TodayPing.parseWhen("15:30", now).atLabel, "15:30")
  assert.strictEqual(TodayPing.parseWhen("3:30pm", now).atLabel, "15:30")
  assert.strictEqual(TodayPing.parseWhen("3.30 PM", now).atLabel, "15:30")
  assert.strictEqual(TodayPing.parseWhen("1530", now).atLabel, "15:30")
  assert.strictEqual(TodayPing.parseWhen("5pm", now).hour, 17)
  assert.ok(!TodayPing.parseWhen("13:00", now).ok)
  assert.ok(!TodayPing.parseWhen("nope", now).ok)
  assert.ok(!TodayPing.parseWhen("", now).ok)
}

function testTodayOnlyAndAck() {
  const now = at(10, 0)
  const added = TodayPing.addReminder("", "11:00", "Tea", now)
  assert.ok(added.ok)
  assert.strictEqual(added.state.reminders.length, 1)

  const laterSameDay = TodayPing.reconcile(TodayPing.encode(added.state), at(11, 0))
  assert.strictEqual(laterSameDay.due.length, 1)
  assert.strictEqual(laterSameDay.state.reminders.length, 0)

  const nextDay = TodayPing.reconcile(TodayPing.encode(added.state), at(9, 0, 2026, 9, 1))
  assert.strictEqual(nextDay.state.date, "2026-09-01")
  assert.strictEqual(nextDay.state.reminders.length, 0)
  assert.strictEqual(nextDay.due.length, 0)
}

function testRemove() {
  const now = at(10, 0)
  const added = TodayPing.addReminder("", "16:00", "Walk", now)
  const removed = TodayPing.removeReminder(TodayPing.encode(added.state), added.reminder.id, now)
  assert.ok(removed.ok)
  assert.strictEqual(removed.state.reminders.length, 0)
}

function testSuggestedWhen() {
  assert.strictEqual(TodayPing.suggestedWhen(at(14, 0)), "14:15")
  assert.strictEqual(TodayPing.suggestedWhen(at(14, 50)), "15:05")
  assert.strictEqual(TodayPing.suggestedWhen(at(23, 50)), "23:59")
}

function testRandomPhrase() {
  const phrase = TodayPing.randomPhrase()
  assert.ok(typeof phrase === "string" && phrase.length > 0)
}

testParseWhen()
testTodayOnlyAndAck()
testRemove()
testSuggestedWhen()
testRandomPhrase()
console.log("ok")
