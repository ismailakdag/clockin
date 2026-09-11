# iOS genel kontrol — 11 Eylül 2026

İncelenen commit: `25f4776`. Uygulama kaynakları değiştirilmedi.

## Bulgular

### P1 — Not düzenlemek kayıtlı çalışma süresini ve kazancı değiştiriyor

`Shared/Core/ClockStore.swift:371–374` ve `Clockin/Views/ManualEntryView.swift:109`.

09:00–12:00 arasında bir saat duraklatılmış kaydın çalışma süresi 2 saattir.
Başlangıç ve bitişi değiştirmeden yalnızca not kaydedildiğinde `updateSession`
süreyi yeniden `end - start` olarak hesaplıyor; kayıt 3 saate çıkıyor. İçe
aktarılan ve süresi saat aralığından farklı olan kayıtlar da etkilenir.
Sadece not değiştiğinde mevcut süre korunmalı; zaman değişikliklerinin çalışma
süresine etkisi ayrıca ele alınmalı. Editörün tarih/saniye normalizasyonu da
bu korumayı yanlışlıkla devre dışı bırakmamalı.

Doğrulama: gerçek model ve mağaza kaynaklarıyla geçici dosyalarda çalışan
Swift programı. Önce 7200 saniye kaydedildi ve diskten aynı değer okundu;
yalnızca not güncellendiğinde sonuç 10800 saniye oldu.

**Durum:** düzeltildi (Claude). `updateSession` saatler aynıysa süreyi korur, saatler
değiştiyse mola payını korur; moladan kısa aralık reddedilir. İki editör alanlara
dokunulmadıysa kaydın kendi saatlerini geçirir. Mac'teki `Tests/manual/store`
testi eski `ClockStore` ile kırılıyor, yeni kodla geçiyor.

### P1 — Okuma hatası mevcut veri dosyasının boş veriyle değiştirilmesine yol açıyor

`Shared/Core/ClockStore.swift:44–55`.

Dosyanın bulunmaması ile okunamaması/JSON çözülememesi aynı dala giriyor.
Boş `ClockinData` oluşturuluyor, ücret geçişi tetikleniyor ve `save()` mevcut
dosyanın üzerine yazıyor. Kullanıcıya yükleme hatası gösterilmiyor.
Otomatik yedek bazı durumlarda önceki dosyayı koruyabilir; fakat bu davranış
ana dosyanın sessizce değiştirilmesini önlemiyor.

Doğrulama: bozuk JSON içeren geçici dosya `ClockStore(fileURL:)` ile açıldı;
başlangıç dosyası boş mağaza JSON'u ile değiştirildi. Dosya yoksa ilk kurulum
yapılmalı, mevcut dosya okunamıyorsa korunmalı ve kurtarma yolu gösterilmeli.

**Durum:** düzeltildi (Claude). Okunamayan dosya önce `clockin-unreadable-<ms>.json`
olarak kenara kopyalanır ve kullanıcıya mesaj gösterilir; kopya alınamazsa dosyanın
üzerine hiç yazılmaz. Test eski kodla kırılıyor, yeni kodla geçiyor.

### P2 — Para birimi değişince açık Live Activity eski birimde kalıyor

`Shared/Sync/SessionMirror.swift:57–65` ve
`ClockinWidgets/ClockinLiveActivity.swift:12`.

Para birimi yalnızca Activity oluşturulurken sabit attributes içine yazılıyor.
Mevcut Activity güncellemeleri sadece ContentState gönderiyor; kilit ekranı ve
Dynamic Island biçimlendirmeyi attributes.currencyCode üzerinden yapıyor.
Ayarlar'da USD → EUR değişimi uygulamayı/widget özetini güncellese de mevcut
Activity'nin etiketi USD kalır. Birim değişiminde Activity yeniden oluşturulmalı
veya birim güncellenebilir duruma taşınmalı.

Bu bulgu kod akışından doğrulandı; para birimi değişimi bu kontrolde UI'dan
uygulanmadı.

**Durum:** düzeltildi (Claude). `SessionMirror`, etkinliğin birimi mağazanınkinden
farklıysa etkinliği kapatıp yeni birimle yeniden başlatır; yeniden kurulum sürerken
gelen senkronlar atlanır.

## Yapılan doğrulamalar

- `xcodebuild -project Clockin.xcodeproj -scheme Clockin -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/clockin-review-derived build`: **BUILD SUCCEEDED**, hata/uyarı bulunmadı. Sandbox içinde ilk girişim makro erişiminde durdu; gerekli erişimle yeniden derleme başarılı oldu.
- Yeni derleme açık iPhone 17 / iOS 26.5 simülatörüne kuruldu ve açıldı.
- Today, History, Insights ve Settings ekranları açıldı; Today, Insights ve Settings görsel olarak incelendi. Veri seti boştu; dolu geçmiş ve büyük veri performansı doğrulanmadı.
- Today ekranında canlı USD/TRY değeri ve başarılı API kontrolü görüldü.
- Geçici Swift kontrolünde pause/resume molayı dışarıda tuttu ve diskten yeniden yükleme doğruydu.
- İki bitişik dış kaydın tek yerel kayıtla karşılaştırılıp içe aktarılması denendi: 2 kayıt ve doğru 4 saat toplamı oluştu.
- Geçici test kaynakları: `/tmp/clockin-review-tests/ReviewChecks.swift`. Model/mağaza dosyaları değiştirilmeden birleştirildi; macOS üzerinde derlemek için Combine ve CoreData importları eklendi. Bunlar XCTest/iOS UI testleri değildir.
- Derleme günlüğü: `/tmp/clockin-review-build.log`.

## Kapsam dışı / açık kalan doğrulamalar

Gerçek iPhone kurulumu, takım kimliğiyle imzalı Kısayollar/Siri,
kilit ekranı widget'ı, arka planda uzun süre çalışma ve Activity güncelleme
sıralaması bu kontrolde doğrulanmadı. Projede otomatik test hedefi yok.
Commit veya push yapılmadı.
