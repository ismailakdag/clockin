import SwiftUI

/// Tamamlanmis bir kaydi elle ekler.
///
/// Sayaci calistirmayi unuttugun ya da baska bir yerde calistigin sureyi
/// gecmise yazmak icin. Sayaci gecmis bir sureden baslatan
/// `ManualStartView`'den farkli: bu, biten bir isi kaydeder.
struct ManualEntryView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    /// Verilirse ekran duzenleme kipinde acilir.
    var editing: WorkSession?

    @State private var day = Date()
    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var note = ""

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    /// Secilen gunun tarihini, secilen saatle birlestirir.
    private func combine(_ time: Date) -> Date {
        let calendar = Calendar.current
        let d = calendar.dateComponents([.year, .month, .day], from: day)
        let t = calendar.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = d.year; merged.month = d.month; merged.day = d.day
        merged.hour = t.hour; merged.minute = t.minute
        return calendar.date(from: merged) ?? day
    }

    private var resolvedStart: Date { combine(startTime) }

    /// Bitis baslangictan onceyse gece yarisi asilmis demektir. Kullanicinin
    /// verisinde 00:17-01:31 gibi kayitlar var, bu gercek bir durum.
    /// Kesin kucukluk: esitlikte gece yarisi asilmis saymak, ayni saati iki
    /// kez secen birine sessizce 24 saatlik bir kayit yazardi. Esitlikte sure
    /// sifir kalir ve dugme kapali olur.
    private var crossesMidnight: Bool { combine(endTime) < resolvedStart }

    private var resolvedEnd: Date {
        let end = combine(endTime)
        return crossesMidnight ? end.addingTimeInterval(86_400) : end
    }

    private var duration: TimeInterval { resolvedEnd.timeIntervalSince(resolvedStart) }
    private var earnings: Double {
        duration / 3600 * store.effectiveRate(at: resolvedStart, fallback: store.hourlyRate)
    }

    /// Kaydedilecek saatler. Seciciler saniyeyi dusurdugu icin hic dokunulmamis
    /// bir kayitta bile yeniden kurulan saat farkli cikiyor ve magaza saat
    /// degisti sanip calisilan sureyi yeniden hesapliyordu.
    private func savedTimes(for session: WorkSession) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let minute: (Date) -> Date = {
            calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0)) ?? $0
        }
        if resolvedStart == minute(session.start), resolvedEnd == minute(session.end) {
            return (session.start, session.end)
        }
        return (resolvedStart, resolvedEnd)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: S(16)) {
            VStack(alignment: .leading, spacing: S(4)) {
                Text(editing == nil ? "Add a past entry" : "Edit entry")
                    .font(.system(size: S(18), weight: .bold, design: .rounded))
                Text(editing == nil
                     ? "For work the timer missed. It lands in history like any other session."
                     : "Correct the times or the note. Earnings follow the new duration.")
                    .font(.system(size: S(11))).foregroundStyle(.secondary)
            }

            field("DAY") {
                DatePicker("", selection: $day, displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.compact)
            }

            HStack(spacing: S(12)) {
                field("START") {
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden().datePickerStyle(.compact)
                }
                field("END") {
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden().datePickerStyle(.compact)
                }
            }

            VStack(alignment: .leading, spacing: S(6)) {
                Text("NOTE (OPTIONAL)")
                    .font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
                TextField("What were you working on?", text: $note)
                    .textFieldStyle(.plain).padding(S(10))
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: S(9)))
            }

            HStack {
                VStack(alignment: .leading, spacing: S(3)) {
                    Text(DurationText.compact(duration))
                        .font(.system(size: S(15), weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.accent)
                    Text(crossesMidnight
                         ? "\(earnings.money(code: store.currencyCode)) • ends next day"
                         : earnings.money(code: store.currencyCode))
                        .font(.system(size: S(10))).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.hitTarget).foregroundStyle(.secondary)
                Button(editing == nil ? "Add entry" : "Save") {
                    let saved: Bool
                    if let editing {
                        let times = savedTimes(for: editing)
                        saved = store.updateSession(id: editing.id, start: times.start, end: times.end, note: note)
                    } else {
                        saved = store.addManualSession(start: resolvedStart, end: resolvedEnd, note: note)
                    }
                    if saved { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .foregroundStyle(.black)
                .disabled(duration <= 0)
            }
        }
        .padding(S(20))
        .frame(width: S(430), height: S(400))
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            guard let editing else { return }
            day = editing.start
            startTime = editing.start
            endTime = editing.end
            note = editing.note
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: S(6)) {
            Text(title)
                .font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
            content()
        }
    }
}
