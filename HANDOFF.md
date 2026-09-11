# Clockin iPhone — devir notu

Bu klasör Clockin'in iPhone sürümü için. Mac uygulaması üzerinde uzun bir
çalışma oturumundan ayrıldı; buradaki bilgiler o oturumda doğrulandı.

## Durum — 11 Eylül 2026

Prototip derleniyor ve iPhone 17 Pro simülatöründe denendi:

- **Bugün:** sayaç (başlat, duraklat, clock out, iptal), bugünkü süre ve kazanç,
  son 5 kayıt (dokun: düzenle; basılı tut: düzenle/sil), + ile geçmiş kayıt
  ekleme, clock out sonrası özet.
- **Geçmiş:** gün gün gruplu liste, gün toplamları, kaydırarak düzenle/sil.
  Codex yazdı; derleme ve simülatör denemesi Claude tarafında yapıldı.
- **Veri:** uygulamanın kendi Application Support klasöründe
  `Clockin/clockin.json`, Mac ile aynı biçim. Mac ile paylaşılmıyor.

### Yapı

```text
Clockin.xcodeproj   elle yazıldı; Xcode 16+ klasör senkronu, dosya eklerken projeye dokunmak gerekmiyor
Clockin/
  Core/    Mac'ten kopya: Models, ClockStore, CSVImporter, PastedTextImporter, ImportComparison
  Theme/   Mac'ten kopya: Themes, ButtonStyles — iOS: PaletteEnvironment, ActionButtonStyles
  Views/   iOS'a özel ekranlar
```

Kopyalar Mac'in `16514e5` commit'inden alındı. `ClockStore` Mac'tekinden
yalnızca iki yerde farklı: `import AppKit` yok, `setPinned` sabitlenmiş pencereyi
çağırmıyor. Diğer kopyalar birebir aynı. Mac tarafında bu dosyalar değişirse elle
taşınmalı. Kontrol:

```bash
diff ../clockin-main/Sources/Clockin/ClockStore.swift Clockin/Core/ClockStore.swift
```

### Derleme ve çalıştırma

```bash
xcodebuild -project Clockin.xcodeproj -scheme Clockin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData build
xcrun simctl install booted build/DerivedData/Build/Products/Debug-iphonesimulator/Clockin.app
xcrun simctl launch booted com.erdmncdr.clockin
```

Ya da `open Clockin.xcodeproj` ile Xcode'da Run.

Ayarlar: iOS 17.0 hedef, Swift 6 dil modu, bundle id `com.erdmncdr.clockin`,
yalnızca iPhone, dikey.

### Codex ile iş bölüşümü

- CLI: `/Applications/ChatGPT.app/Contents/Resources/codex`. PATH'te değil,
  ChatGPT hesabıyla oturum açık.
- İşe yarayan kalıp: arka planda
  `codex exec -s workspace-write -C <klasör> -o <sonuç.md> - < prompt.md`.
  Görev tek dosyayla sınırlı, commit yok, kullanılacak ortak parçalar prompt'ta
  adıyla verildi.
- `workspace-write` sandbox'ı CoreSimulator'a erişemiyor, bu yüzden Codex iOS
  derlemesini doğrulayamıyor. Derleme ve simülatör denemesi Claude tarafında
  yapılmalı. Codex bunu raporunda açıkça belirtti.

### Bilinen eksikler

- Uygulama ikonu yok (`AppIcon` boş).
- Ayarlar ekranı yok. Ücret 25 USD varsayılanıyla başlıyor, tema Carbon'da sabit.
- "Geçen süreyle başlat" (`ManualStartView`) taşınmadı.
- Test hedefi yok.

## Kaynak proje

- Mac uygulaması: `../clockin-main`
- Upstream repo: `ismailakdag/clockin` (sahibi İsmail)
- Fork: `erdmncdr/clockin` — katkılar buradan PR olarak gidiyor
- Git kimliği: `erdmncdr` / `edolin67@gmail.com`

İsmail'in reposunun yapısı onun onayı olmadan değiştirilmemeli. Bu yüzden
iPhone işi şimdilik bu ayrı klasörde.

## Taşınabilirlik (Mac kodu üzerinde yapılan tarama)

26 Swift dosyasının 20'si AppKit / pencere / menü çubuğu API'si kullanmıyor:

`Models`, `CSVImporter`, `PastedTextImporter`, `ImportComparison`,
`ExchangeRates`, `RadioController`, `Themes`, `ButtonStyles`, `MainTabBar`,
`HistoryView`, `HeatmapView`, `ProgressView`, `ManualEntryView`,
`ManualStartView`, `RateScheduleView`, `ImportComparisonView`,
`SessionSummaryView`, `GuideView`, `UIScale`, `UpdateChecker`

Bu listeden `Models`, `CSVImporter`, `PastedTextImporter`, `ImportComparison`,
`Themes` ve `ButtonStyles` iOS'ta değiştirilmeden derlendi. Görünümler Mac'te
`S()` ölçekleme fonksiyonuna bağlı olduğu için kopyalanmadı, iOS için yeniden
yazıldı. Listedeki diğer dosyalar hâlâ yalnızca sembol taramasıyla doğrulanmış
durumda.

iOS'ta anlamı olmayanlar: `UIScale` (iOS'ta Dynamic Type kullanılır),
`UpdateChecker` (App Store / TestFlight kurulumunda gereksiz).

- macOS'a özel, yeniden yazılması gerekenler: `ClockinApp` (menü çubuğu),
  `MainWindow`, `PinnedWindow`, `KeyboardShortcuts`, `FocusChime` (NSSound),
  `MascotAsset` (NSImage), panel/pano kullanan kısımlar (`PasteImportView`,
  `SettingsView`, `ShareStatsView`).

## Ortam

- Xcode 26.6 kurulu ve seçili (`xcode-select` Xcode'u gösteriyor).
- iOS 26.5 SDK ve simülatörler var (iPhone 17 Pro, 17 Pro Max, 17e).
- Yalnızca Command Line Tools ile SwiftUI derlenmiyor (SwiftUI makro eklentisi
  Xcode ile geliyor). Xcode seçili kalmalı.
- XcodeGen ve Homebrew kurulu değil.

## Bekleyen kararlar

1. **Senkronizasyon.** Mac verisi yerel JSON:
   `~/Library/Application Support/Clockin/clockin.json`. iPhone ayrı dosya
   tutarsa iki ayrı kayıt olur (telefonda başlayan sayacı Mac bilmez, toplamlar
   ayrışır). Gerçekçi çözüm iCloud, ama iCloud yetkisi **ücretli Apple Developer
   hesabı** (99 $/yıl) istiyor; ücretsiz Apple ID ile imzalanan uygulama
   iCloud kullanamıyor.
2. **Dağıtım.** Simülatör ücretsiz. Ücretsiz Apple ID ile kendi iPhone'a kurulum
   7 günde bir yenilenmeli. Başkasıyla paylaşmak (TestFlight / App Store) ücretli
   hesap istiyor.
3. **İsmail.** Ortak `ClockinCore` modülü ve iOS hedefi upstream repoya girecekse
   önce onunla konuşulmalı.

## Plan

1. ~~Prototip: taşınabilir kodu kopyala, SwiftUI iOS uygulaması, yerel veri.~~
   Yapıldı.
2. ~~Simülatörde çalıştırıp dene.~~ Yapıldı.
3. Karar sonrası: iCloud senkronizasyonu, Live Activity / Dynamic Island
   (çalışan sayaç ve kazanç), ana ekran widget'ı, App Intents / Shortcuts ile
   clock in. CSV içe aktarma, heatmap, ücret takvimi başta Mac'te kalabilir.

## iOS tarafında öğrenilenler

- Aynı değeri gösteren kartlar tek bir `TimelineView`'dan okumalı. Sayaç ve
  Bugün kartı ayrı `TimelineView` kullanırken farklı anlarda yenileniyordu;
  kazanç iki kartta bir sent farklı görünüyordu.
- Onay isteyen kaydırarak silmede `role: .destructive` kullanılmamalı. List bu
  rolü görünce satırı veri silinmeden kaldırıyor; onay uyarısı açıkken satır
  kayboluyordu. Ayrıca kökteki `.tint(palette.accent)` kaydırma düğmelerine de
  iniyor ve Delete yeşil görünüyordu. Doğrusu: rol yok, `.tint(.red)`.
- `preferredColorScheme` en yakın sunuma uygulanıyor. Sheet ayrı bir sunum
  olduğu için içinde tekrar verilmesi gerekiyor (`SessionSheets.swift`).

## Mac tarafında öğrenilen tuzaklar

- `money()` `FormatStyle` kullanıyor; `maxFractionDigits: 0` ile
  `.fractionLength(2...0)` geçersiz aralık oluşturup çöküyordu. Doğrusu
  `minimum = min(2, maximum)`. Regresyon testi `Tests/manual/main.swift`'te.
- Picker seçimini `Double` eşitliğine bağlamak kırılgan (32 bit float ile yazılan
  1.2999999523 hiçbir etiketle eşleşmiyor, Picker boş görünüyor). Tam sayı kullan.
- `.buttonStyle(.plain)` tıklama alanını çizilen piksellere indiriyor;
  `contentShape(Rectangle())` gerekli.
- Görünüm gövdesinde tekrar tekrar okunan hesaplanmış özellikler her okumada
  baştan hesaplanıyor; toplamlar ve günlük değerler mağazada önbelleklenmeli.
- Kayıtları gün bazında birleştirme; CSV tekilleştirmesi başlangıç + bitiş + süre
  üçlüsüne dayanıyor.

## Çalışma tarzı

- Kullanıcı Türkçe yazıyor.
- Commit mesajları İngilizce ve "neden" odaklı.
- Kullanıcı arayüzü kendisi gözle kontrol ediyor; görsel doğrulama yapılamadıysa
  bu açıkça söylenmeli.
- İşin bir kısmı Codex'e verilmeli, uygun yerlerde yüklü skill'ler kullanılmalı
  (bu oturumda `swiftui-ui-patterns`, `swift-concurrency-pro`).
