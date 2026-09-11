# Clockin iPhone: devir notu

Bu klasör Clockin'in iPhone sürümü için. Mac uygulaması üzerinde uzun bir
çalışma oturumundan ayrıldı; buradaki bilgiler bu oturumlarda doğrulandı.

## Durum: 11 Eylül 2026

İlk prototip `4413893`'te commit edildi. Aşağıdaki özelliklerin tamamı, kullanıcının
isteğiyle ara commit atılmadan, onu izleyen tek commit'te.

Özellikler (kim yazdı · nasıl doğrulandı):

- **Bugün:** sayaç (başlat, duraklat, clock out, iptal, geçen süreyle başlat),
  bugünkü süre ve kazanç, son 5 kayıt, geçmiş kayıt ekleme, clock out özeti.
  Claude · simülatörde denendi.
  USD kazançların altında TRY karşılığı ve Bugün kartından sonra USD/TRY kur
  kartı eklendi; kur açılışta ve oturum sayısı değişince yenilenir.
  Bu ekleme Codex (gpt-6-astra, medium) · simülatörde doğrulandı: canlı kur geldi,
  TL karşılıkları hesapla tuttu.
- **Geçmiş:** gün gün gruplu liste, gün toplamları, kaydırarak düzenle/sil.
  Codex · simülatörde denendi (gerçek Mac verisiyle).
- **Insights:** seviye/XP, seriler, hedefler, heatmap, haftalık/aylık/toplam
  özet, kilometre taşları. Codex · simülatörde denendi; XP, seviye ve seri
  veriden bağımsız hesapla birebir tuttu.
- **Ayarlar:** ücret, para birimi, ücret takvimi, tema, timecard içe aktarma,
  yedek paylaşma ve geri yükleme, sürüm. Ayarlar ekranı ve alt ekranlar Codex,
  bağlantılar Claude · geri yükleme, ücret dönemi ekleme/silme ve CSV inceleme
  adımı simülatörde denendi.
- **Live Activity / Dynamic Island:** adada saat:dakika (iOS 18+), kilit ekranında saniyeli sayaç, son güncelleme anındaki
  oturum kazancı (kompakt adada solda tam sayı, açık ada ve kilit ekranında
  kuruşlu), Pause/Resume ve Clock out düğmeleri. Kazanç uygulama açıldığında,
  arka plana geçtiğinde veya düğmeye basıldığında yenilenir.
  Claude + Codex · simülatörde denendi: kilit ekranından Pause veriye yazıldı,
  kazanç adada ve kilit ekranında göründü. Adadaki saat:dakikayı üç başarısız
  denemeden sonra Codex buldu (bkz. "iOS tarafında öğrenilenler"); adada
  02:45'ten 02:48'e kendi kendine ilerlediği görüldü.
  Kilit ekranındaki saatlik ücret kaldırıldı; boş olmayan not korundu ve USD
  kazancın altına mevcut kurla TRY karşılığı eklendi. Kur Activity içeriğinde
  isteğe bağlı taşınır (eski etkinlikler okunabilir); başarılı kur yenilemesi
  Live Activity'yi de günceller. Dynamic Island değiştirilmedi.
  Bu ekleme Codex (gpt-6-astra, medium) · kilit ekranında doğrulandı: süre, USD
  kazanç ve TL karşılığı görünüyor, saatlik ücret yok.
- **Ana ekran widget'ı:** bugünkü süre (çalışırken canlı sayar) ve kazanç;
  orta boyda Clock in/out düğmesi; kilit ekranı boyutu. Claude · orta boy
  simülatörde ana ekrana eklendi: sayaç Dynamic Island ile aynı saniyede
  sayıyor, widget'taki Clock out kaydı veriye yazdı, Live Activity kapandı ve
  widget "READY"e döndü. Kilit ekranı boyutu 12 Eylül'de denendi: kilit ekranına
  eklendi, boş/çalışıyor/mola üçünde de doğru okudu. İki kusur çıkıp düzeltildi:
  sayaç işlerken "Working" yazıp günün toplamını gösteriyordu (artık hep
  "Today", şimşek simgesi sayacı anlatıyor) ve tutar 15 dakika boyunca donuk
  kalıyordu (artık dakikalık girdiler üretiliyor, dokunmadan 75 saniyede
  $1,06'dan $1,47'ye ilerlediği görüldü).
- **Kısayollar:** Clock In, Clock Out, Pause or Resume (Siri, Kısayollar,
  Eylem düğmesi). Claude · üç kısayol Spotlight'ta görünüyor, ama simülatörde
  çalıştırılamadı: uygulama takım kimliği olmadan (`adhoc`) imzalı olduğu için
  `linkd` bağlantıyı reddediyor ("Unable to get teamId", "Couldn't find
  AppShortcutsProvider"). Kod ve meta veri doğru; takım kimliğiyle imzalı
  derlemede doğrulanmalı.
- **İkon:** Mac ikonunun çizim script'inden iOS için kenardan kenara, saydamsız
  1024 px sürüm.

### Yapı

```text
Clockin.xcodeproj   elle yazıldı; klasör senkronu. Hedefler: Clockin, ClockinWidgets
Clockin/            yalnızca uygulama: ekranlar, Kısayollar sağlayıcısı, ikon
  Views/            Bugün, Geçmiş, Ayarlar, sheet'ler
  Views/Insights/   Codex
  Views/Import/     Codex
  Intents/          AppShortcutsProvider
Shared/             iki hedef de derler
  Core/             Mac'ten kopya: Models, ClockStore, CSVImporter, PastedTextImporter, ImportComparison, ExchangeRates
  Theme/            Mac'ten kopya: Themes, ButtonStyles (iOS: PaletteEnvironment, ActionButtonStyles)
  Sync/             AppGroup, ClockinSnapshot, SharedStore, SessionMirror, ClockinActivityAttributes
  Intents/          ClockIn / ClockOut / TogglePause (LiveActivityIntent)
ClockinWidgets/     Bugün widget'ı ve Live Activity
Config/             entitlements, widget Info.plist
```

`Shared/Core` Mac'in `16514e5` commit'inden kopyalandı. `ClockStore` Mac'tekinden
yalnızca iki yerde farklı (`import AppKit` yok, sabitlenmiş pencere çağrısı yok).
`ExchangeRates.swift` sonradan mevcut Mac dosyasından bayt bayt aynı kopyalandı;
yukarıdaki commit referansı bu yeni dosya için geçerli değil.

Mac tarafında değişirse elle taşınmalı:

```bash
diff ../clockin-main/Sources/Clockin/ClockStore.swift Shared/Core/ClockStore.swift
```

### Veri akışı

- Veri App Group `group.com.erdmncdr.clockin` içinde `Clockin/clockin.json`.
  İlk sürüm veriyi uygulamanın kendi klasöründe tutuyordu; ilk açılışta bir kez
  kopyalanır, eski dosya silinmez.
- Tek `ClockStore` örneği: `SharedStore.clock`. Uygulama, Kısayollar ve Live
  Activity düğmeleri aynı örneği kullanır. Ayrı örnekler aynı dosyayı birbirinden
  habersiz yazardı.
- Tek kur mağazası `SharedStore.exchangeRates`; uygulama ortam nesnesi olarak
  paylaşır. Mac ile aynı önbellek ve yenileme akışı kullanılır. `SessionMirror`
  USD oturumlar için son kuru Activity içeriğine yazar; kur yenilemesi sonrası
  uygulama mirror'ı çağırır, kur mağazası mirror'a bağımlı değildir.
- `SessionMirror` mağaza değiştikçe `widget-snapshot.json` yazar, widget'ı
  yeniden yükletir ve Live Activity'yi başlatır, günceller ya da bitirir.
  Görünümlerde değil, çünkü Kısayollar uygulamayı arka planda açınca hiçbir
  ekran yüklenmez.
- Widget oturum listesini okumaz; ücret kuralları tek yerde, `ClockStore`'da
  hesaplanır ve özete yazılır.
- Intent'ler `LiveActivityIntent`: widget ya da kilit ekranından tetiklense de
  uygulamanın sürecinde çalışır. Widget hedefi `WIDGET_EXTENSION` koşuluyla
  derlenir; oradaki dal hiç çalışmaz, yalnızca düğmeler tiplere başvurabilsin diye.

### Derleme ve çalıştırma

```bash
xcodebuild -project Clockin.xcodeproj -scheme Clockin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData build
xcrun simctl install booted build/DerivedData/Build/Products/Debug-iphonesimulator/Clockin.app
xcrun simctl launch booted com.erdmncdr.clockin
```

#### Manuel snapshot testi

Repo kökünden, XCTest veya SwiftPM gerektirmeyen aritmetik ve JSON kontrolleri:

```bash
swiftc -swift-version 6 -strict-concurrency=complete Shared/Core/Models.swift Shared/Sync/ClockinSnapshot.swift Tests/manual/snapshot/main.swift -o /tmp/clockin-snapshot-tests && /tmp/clockin-snapshot-tests
```

Her kontrol `ok` veya `FAIL` yazdırır; hata varsa çıkış kodu sıfır değildir.
Dosya kontrolleri oluşturulup silinen geçici klasörü kullanır. `ClockStore` ve
`AppGroup` test taslaklarıdır; `init(store:at:)` kapsam dışıdır. 38 kontrolün
tamamı 12 Eylül 2026'da derlenip çalıştırıldı ve geçti; `isSameDay` kuralı
bozularak testlerin gerçekten yakaladığı doğrulandı. Rapor:
`Tests/manual/snapshot/REPORT.md`.

Ayarlar: iOS 17.0 hedef, Swift 6 dil modu, bundle id'ler `com.erdmncdr.clockin`
ve `com.erdmncdr.clockin.widgets`, yalnızca iPhone, dikey.

### Codex ile iş bölüşümü

- CLI: `/Applications/ChatGPT.app/Contents/Resources/codex`. PATH'te değil,
  ChatGPT hesabıyla oturum açık.
- İşe yarayan kalıp: arka planda
  `codex exec -m gpt-6-astra -c model_reasoning_effort="medium" -s workspace-write -C <klasör> -o <sonuç.md> - < prompt.md`.
  Aynı anda üç Codex çalıştı; her biri yalnızca yeni dosyalar oluşturdu, ortak
  bir prompt başlığı (kullanılacak parçalar, Mac tuzakları, stil) paylaşıldı.
  Ekranları uygulamaya bağlamak Claude'da kaldı, böylece dosyalar çakışmadı.
- `workspace-write` sandbox'ında Codex SwiftUI kodunu hiçbir şekilde
  doğrulayamıyor: `xcodebuild` CoreSimulator'a erişemiyor, simülatörsüz
  `swiftc -typecheck` de SwiftUI makro eklentisi engellendiği için düşüyor
  (`sandbox_apply: Operation not permitted`). Derleme ve simülatör denemesi
  Claude tarafında yapılmalı.
- Codex'in dört ekranı ilk derlemede hatasız çıktı. Denemede bulunanlar:
  heatmap yerleşimi, "25.0" biçimi, iç içe sheet renk şeması, silme uyarısı
  metni.

### Denenmeyenler

- Kısayolların çalışması (Spotlight, Siri, Kısayollar, Eylem düğmesi). Bu Mac'te
  imza kimliği yok ve projede `DEVELOPMENT_TEAM` tanımlı değil; Xcode'a Apple
  hesabıyla giriş yapılıp takım seçildikten sonra denenmeli.
- Ücret alanına yazma, para birimi ve tema değiştirme.
- Kendi iPhone'una kurulum. App Group ve Live Activity'nin ücretsiz Apple ID
  ile imzalanan uygulamada çalışıp çalışmadığı doğrulanmadı.

### Bilinen eksikler

- iCloud senkronizasyonu yok (11 Eylül'de "şimdilik yok" kararı).
- Widget ve Live Activity uygulamanın tema seçimini izlemiyor; Carbon sabit.
- Test hedefi yok.

## Kaynak proje

- Mac uygulaması: `../clockin-main`
- Upstream repo: `ismailakdag/clockin` (sahibi İsmail)
- Fork: `erdmncdr/clockin`, katkılar buradan PR olarak gidiyor
- Git kimliği: `erdmncdr` / `edolin67@gmail.com`

İsmail'in reposunun yapısı onun onayı olmadan değiştirilmemeli. Bu yüzden
iPhone işi bu ayrı klasörde.

## Ortam

- Xcode 26.6 kurulu ve seçili (`xcode-select` Xcode'u gösteriyor).
- iOS 26.5 SDK ve simülatörler var (iPhone 17 Pro, 17 Pro Max, 17e).
- Yalnızca Command Line Tools ile SwiftUI derlenmiyor (SwiftUI makro eklentisi
  Xcode ile geliyor). Xcode seçili kalmalı.
- XcodeGen ve Homebrew kurulu değil.
- Simülatörün klavye düzeni Türkçe: `text` ile yazılan "i" "ı", ":" "Ş" oluyor.
  Saat ya da İngilizce metin gereken denemelerde dosya yoluyla veri verilmeli.

## Bekleyen kararlar

1. **Senkronizasyon.** Şimdilik yok. İleride iCloud **ücretli Apple Developer
   hesabı** (99 $/yıl) ister ve Mac uygulamasında da değişiklik gerektirir.
2. **Dağıtım.** Simülatör ücretsiz. Ücretsiz Apple ID ile kendi iPhone'a kurulum
   7 günde bir yenilenmeli. Başkasıyla paylaşmak (TestFlight / App Store) ücretli
   hesap istiyor.
3. **İsmail.** Ortak `ClockinCore` modülü ve iOS hedefi upstream repoya girecekse
   önce onunla konuşulmalı.

## iOS tarafında öğrenilenler

- Live Activity kendi başına yalnızca zamanı ilerletebilir; kazanç gibi hesaplanan
  değerler ancak uygulama güncelleme gönderdiğinde değişir (veya sunucu ve ücretli
  hesap gerektiren push ile). iOS'un kendi ilerleyen saat:dakika biçimi yok:
  `SystemFormatStyle.Timer` ve `.Stopwatch` (iOS 18) `maxPrecision` dakikaya
  indirilince süreyi rakamla değil yazıyla ("1 hour, 15 minutes") gösteriyor.
  Saniyeli `Text(timerInterval:)`'ı görünmez bir "H:MM" yer tutucusunun üzerine
  bindirip kırpmak da Live Activity'de sayacı tamamen boş bırakıyor. Çalışan yol:
  iOS 18'de `Text(.durationOffset(to: start), format: Duration.TimeFormatStyle(pattern:
  .hourMinute(padHourToLength: 2, roundSeconds: .down)))` rakamla "02:45" gösterip
  kendi kendine ilerliyor.
- Aynı değeri gösteren kartlar tek bir `TimelineView`'dan okumalı; ayrı
  zamanlayıcılar farklı anlarda yenilenip bir sent farklı değer gösteriyordu.
- Onay isteyen kaydırarak silmede `role: .destructive` kullanılmamalı. List bu
  rolü görünce satırı veri silinmeden kaldırıyor. Kökteki tema `tint`'i de silme
  düğmesini yeşile boyuyordu. Doğrusu: rol yok, `.tint(.red)`.
- `preferredColorScheme` en yakın sunuma uygulanıyor; her sheet'te, iç içe
  olanlarda da, yeniden verilmeli.
- Genişliği verilmemiş `Color.clear` yatayda yayılıyor; heatmap'in gün etiketi
  sütunu satırın yarısını kaplayıp ızgarayı sağa sıkıştırıyordu.
- `Activity` Sendable değil; ana aktörden bir `Task`'a geçirilemiyor.
  Etkinlikler `nonisolated` bir yardımcıda alınıp kullanılıyor.
- `objectWillChange` değer yazılmadan önce geliyor; yeni değeri okumak için bir
  sonraki turda senkronlanmalı.
- Simülatör imzasında `codesign -d --entitlements` App Group'u göstermiyor;
  yetkinin çalıştığını `simctl get_app_container ... groups` ile doğrulamak gerekiyor.
- Takım kimliği olmayan (`adhoc`) simülatör derlemesinde App Shortcuts
  Spotlight'ta görünür ama çalışmaz: `linkd` kısayol servisine bağlanan
  uygulamayı `requiresValidBundle` ile reddeder. Widget ve Live Activity
  düğmeleri işlemi doğrudan çağırdığı için etkilenmez. Tanı için
  `log show --predicate 'process == "linkd" OR process == "Clockin"'`.
- Uygulama öndeyken iOS o uygulamanın kendi Live Activity'sini Dynamic Island'da
  göstermiyor; görmek için ana ekrana ya da kilit ekranına çıkmak gerekiyor.

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
- Commit mesajları İngilizce ve "neden" odaklı. Uygulama son haline gelene kadar
  ara commit yok.
- Kullanıcı arayüzü kendisi gözle kontrol ediyor; görsel doğrulama yapılamadıysa
  bu açıkça söylenmeli.
- İşin bir kısmı Codex'e verilmeli, uygun yerlerde yüklü skill'ler kullanılmalı
  (`swiftui-ui-patterns`, `swift-concurrency-pro`).
- Sistem izin soruları (Live Activity izni, pano izni gibi) kullanıcıya bırakılır.
