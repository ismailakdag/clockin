import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    print("ok: " + message)
}
let decoder = JSONDecoder()
let baseline = try decoder.decode(ClockinActivityState.self, from: Data(#"{"timerStart":400,"hourlyRate":60,"earnedAtUpdate":10,"updatedAt":1000,"usdTryRate":40,"note":"private note","theme":"Carbon"}"#.utf8))
let tick = try decoder.decode(ClockinActivityState.self, from: Data(#"{"remoteTick":true,"updatedAt":1060}"#.utf8))
let now = Date(timeIntervalSinceReferenceDate: 1060)
let updated = baseline.applyingTick(tick, expiresAt: now.addingTimeInterval(3600), now: now)
check(updated.earnedAtUpdate == 11, "one minute signal advances locally held earnings")
check(updated.note == "private note" && updated.hourlyRate == 60 && updated.usdTryRate == 40, "local content survives minimal remote payload")
check(updated.timerStart == baseline.timerStart && updated.theme == baseline.theme, "timer and theme never depend on server content")
let nextTick = try decoder.decode(ClockinActivityState.self, from: Data(#"{"remoteTick":true,"updatedAt":1180}"#.utf8))
check(baseline.applyingTick(nextTick, expiresAt: nil, now: now.addingTimeInterval(120)).earnedAtUpdate == 13, "missed ticks catch up without accumulating drift")
check(baseline.applyingTick(nextTick, expiresAt: nil, now: now).earnedAtUpdate == 11, "future server time cannot inflate earnings beyond local time")
check(baseline.applyingTick(nextTick, expiresAt: now, now: now.addingTimeInterval(120)).earnedAtUpdate == 11, "expired lifetime bounds calculation")
var paused = baseline; paused.pausedAt = now
check(paused.applyingTick(tick, expiresAt: nil, now: now) == paused, "remote ticks never resume a paused activity")
var older = tick; older.updatedAt = Date(timeIntervalSinceReferenceDate: 900)
check(baseline.applyingTick(older, expiresAt: nil, now: now) == baseline, "old ticks cannot roll back earnings")
let encoded = try JSONEncoder().encode(LiveActivityRegistration(environment: "production", expiresAt: 1790000000))
let wire = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
check(Set(wire.keys) == ["environment", "expiresAt", "protocol"], "registration contains no session content or financial values")
check(wire["protocol"] as? Int == 2, "registration opts into minimal protocol")
let suite = "clockin-liveactivity-privacy-tests-" + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defaults.set(true, forKey: "Clockin.RemoteActivityConsent")
check(!LiveActivityPrivacy.isEnabled(in: defaults), "fresh and legacy installations do not opt in silently")
defaults.set(true, forKey: LiveActivityPrivacy.consentKey)
check(LiveActivityPrivacy.isEnabled(in: defaults), "explicit current consent enables remote ticks")
defaults.set(false, forKey: LiveActivityPrivacy.consentKey)
check(!LiveActivityPrivacy.isEnabled(in: defaults), "withdrawal disables remote registration")
defaults.removePersistentDomain(forName: suite)
print("13 Live Activity privacy checks passed")
