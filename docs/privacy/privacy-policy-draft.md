# Clockin for iPhone — Privacy Policy / Gizlilik Politikası

DRAFT — do not publish until owner.json is completed and the release matches this text.
Last updated / Son güncelleme: 20 September / Eylül 2026

## English

### Who is responsible
{{CONTROLLER_NAME}} operates Clockin for iPhone. For privacy questions or requests, contact {{CONTACT_EMAIL}}.

### Work records
Your work records, pay settings, earnings, session notes, companion settings and backups are stored on your device. They are not uploaded to the Clockin Live Activity server. Exported files go to the destination you choose and may be handled by that destination's provider. Device backups and Apple's system features are subject to your Apple settings.

### Optional Live Activity updates
Live earnings updates are off by default. When you choose to enable them in Settings → Privacy & Live Activity, Clockin sends a temporary Apple Live Activity push token, the Apple delivery environment, a protocol version and an expiry time to our service hosted by Netlify in the United States. The token addresses one Live Activity; it is not a Clockin account, email address or advertising identifier. It is nevertheless a routing identifier and we do not describe it as anonymous.

Our server sends time signals through Apple Push Notification service approximately once per minute. Clockin calculates earnings on your device using locally held values. The server does not receive your hourly rate, earnings, note, currency, exchange rate, theme or session start time. Apple controls notification delivery timing. Apple's system may show or mirror the activity on your other devices according to your settings.

We use the registration only to deliver the feature, secure the service and handle deletion. We do not use it for advertising, sell it, or combine it with advertising profiles.

### Choices and deletion
You can turn live updates off in Clockin's Settings. Clockin ends the remotely updated activity and requests removal of the routing token. Offline or failed removal requests are retained on your device and retried when Clockin next runs; the app shows when cleanup is pending. Pausing or ending an activity also requests removal.

A server registration expires no later than eight hours after creation. The scheduled cleanup removes expired records on its next successful run; service outages may delay physical removal, but expired records are not used for notifications. Successful removal replaces the record with a token-free stop marker until its original expiry, preventing delayed registration from restarting it. Internal lookup keys are SHA-256 hashes of the token; hashing is not encryption or a guarantee of anonymity. We cannot delete a specific registration by name or email because these are not collected with it. The in-app control provides the token needed to identify your registration.

Server application logs contain aggregate delivery counts and generic errors, not notification tokens or activity content. Netlify and its infrastructure providers process connection/security information such as IP addresses. Provider security logs and backups can have separate retention under their terms; the eight-hour registration limit is not a promise that every provider log or backup is erased within eight hours.

### Other network features
Currency conversion requests USD/TRY rates from Frankfurter (api.frankfurter.dev). Requests may include the date of the rate needed for a work record, but not its amount or note. Optional Focus Radio connects directly to Radio Paradise when you play a station. These services receive ordinary connection data, such as your IP address and the requested rate/date or radio stream. Opening external links also connects to the selected website. These providers have their own privacy practices.

### Security and international processing
Connections to the Live Activity service use HTTPS. The Apple signing key remains on the server and is not included in the app. Access controls, request limits and reduced data collection help protect information; no service can promise zero risk. Netlify processing currently takes place in its US region, and Apple and other providers may process data internationally.

### Requests and changes
Contact {{CONTACT_EMAIL}} to ask about access, correction, deletion or other applicable privacy rights. We may need information sufficient to locate the record and verify the request; do not send your pay history or notification tokens by email. This policy may change when the product's data handling changes. Material changes to the optional update feature will be explained before additional information is collected.

## Türkçe

### Veri sorumlusu
Clockin for iPhone'un işletmecisi {{CONTROLLER_NAME}}. Gizlilik soruları ve başvuruları için iletişim: {{CONTACT_EMAIL}}.

### Çalışma kayıtları
Çalışma geçmişi, ücret ayarları, kazanç, oturum notları, companion ayarları ve yedekler cihazınızda tutulur; Clockin Live Activity sunucusuna yüklenmez. Dışa aktardığınız dosya, seçtiğiniz konuma ve o hizmetin koşullarına tabidir. Cihaz yedekleri ve Apple'ın sistem özellikleri Apple ayarlarınıza bağlıdır.

### İsteğe bağlı canlı güncellemeler
Canlı kazanç güncellemeleri varsayılan olarak kapalıdır. Ayarlar → Privacy & Live Activity bölümünden açmayı seçtiğinizde, geçici Apple Live Activity bildirim adresi (token), Apple gönderim ortamı, protokol sürümü ve son geçerlilik zamanı ABD'deki Netlify altyapısında çalışan hizmetimize gönderilir. Bu adres tek bir canlı etkinlik içindir; Clockin hesabı, e-posta veya reklam kimliği değildir. Yine de yönlendirme tanımlayıcısı olduğundan tamamen anonim olarak nitelendirmiyoruz.

Sunucu, Apple Push Notification service üzerinden yaklaşık dakikada bir zaman sinyali gönderir. Kazanç hesabını cihazınız yerel bilgilerle yapar. Saatlik ücret, kazanç, not, para birimi, kur, tema ve oturum başlangıcı bu sunucuya gönderilmez. Bildirimin teslim zamanını Apple belirler. Apple'ın sistemi, ayarlarınıza göre etkinliği diğer cihazlarınızda gösterebilir veya yansıtabilir.

Geçici kayıt yalnızca bu özelliği sağlamak, hizmet güvenliği ve silme işlemleri için kullanılır. Reklam amacıyla kullanılmaz, satılmaz ve reklam profilleriyle birleştirilmez.

### Tercihler ve silme
Canlı güncellemeleri Clockin ayarlarından kapatabilirsiniz. Uygulama uzaktan güncellenen etkinliği sonlandırır ve sunucudaki bildirim adresinin kaldırılmasını ister. İnternet yoksa veya istek başarısız olursa silme isteği cihazda saklanır, Clockin yeniden çalıştığında tekrar denenir; bekleyen temizlik uygulamada gösterilir. Etkinliği duraklatmak veya bitirmek de kaldırma isteği oluşturur.

Bir kayıt oluşturulmasından en fazla sekiz saat sonra geçerliliğini kaybeder. Süresi dolan kayıt, zamanlanmış temizliğin sonraki başarılı çalışmasında kaldırılır. Hizmet kesintisi fiziksel silmeyi geciktirebilir; süresi dolmuş kayıtlar bildirim göndermek için kullanılmaz. Başarılı kaldırma, gecikmiş bir kayıt isteğinin özelliği yeniden başlatmasını engellemek için asıl süre sonuna kadar token içermeyen bir durdurma işareti bırakır. İç kayıt anahtarında tokenın SHA-256 özeti kullanılır; hash şifreleme veya anonimlik garantisi değildir. Kayıtla isim/e-posta tutulmadığından, belirli bir kaydı bu bilgilerle bulup silemeyiz; uygulamadaki kapatma seçeneği gerekli tokenla isteği yapar.

Uygulama sunucu loglarında yalnızca toplu gönderim sayıları ve genel hata mesajları yer alır; token ve oturum içeriği yazılmaz. Netlify ve altyapı sağlayıcıları IP adresi gibi bağlantı/güvenlik bilgilerini işler. Sağlayıcı logları ve yedeklerin kendi saklama süreleri olabilir; sekiz saatlik kayıt sınırı, tüm sağlayıcı loglarının ve yedeklerinin sekiz saatte silindiği anlamına gelmez.

### Diğer bağlantılar
Kur özelliği Frankfurter'dan (api.frankfurter.dev) USD/TRY verisi ister. İstek, çalışma kaydı için gereken kur tarihini içerebilir; kazanç veya not gönderilmez. İsteğe bağlı Focus Radio, istasyonu oynattığınızda doğrudan Radio Paradise'a bağlanır. Bu hizmetler IP adresi ve istenen kur/tarih veya radyo yayını gibi bağlantı bilgilerini alır. Dış bağlantılar seçilen sitenin gizlilik uygulamalarına tabidir.

### Güvenlik ve yurt dışı işleme
Live Activity bağlantısı HTTPS kullanır. Apple imzalama anahtarı sunucuda kalır; uygulamanın içinde bulunmaz. Erişim kontrolleri, istek sınırları ve az veri toplama riski azaltır; sıfır risk taahhüt edilmez. Netlify hizmeti şu an ABD bölgesindedir; Apple ve diğer sağlayıcılar da veriyi farklı ülkelerde işleyebilir.

### Başvurular ve değişiklikler
Bilgi alma, düzeltme, silme ve uygulanabilir diğer haklara ilişkin taleplerinizi {{CONTACT_EMAIL}} adresine iletebilirsiniz. Kaydı bulmak ve talebi doğrulamak için yeterli bilgi gerekebilir; ücret geçmişinizi veya bildirim tokenlarını e-posta ile göndermeyin. Veri işleme şekli değişirse bu metin güncellenir; ek veri toplamaya yol açan önemli değişiklikler önceden açıklanır.

---
Publisher checklist — not part of the published text:
- Complete owner.json and verify the controller's jurisdiction and applicable legal bases.
- Verify Netlify contractual/data-processing arrangements and applicable international-transfer safeguards. A policy or an app toggle alone does not establish KVKK/GDPR compliance.
- Confirm third-party provider log/back-up retention; do not invent a fixed provider retention period.
- Verify the v2 server is deployed, legacy financial records are scrubbed, and the privacy URL works before distributing this build.
- Review the App Store privacy labels against the actual final data flow, including identifiers, activity timing and provider security data.
