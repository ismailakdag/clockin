# Wave v2 — planted legs

El sallama klibindeki kalça ve iki bacağın dönüş/konum kanalları, GLB inverse bind matrislerinden çıkarılan özgün model duruşunda sabitlendi. İnsan animasyonunun dizleri içe kapatması ve ayakları bükmesi giderildi. V1 önkol düzeltmesi korunur. Geometri, kaplama, iskelet ağırlıkları, koşma/yürüme/dinlenme klipleri değişmedi.

253 zaman örneğinde güçlü ayak ağırlıklı 340 vertex için kayma 0; özgün mesh konumundan en büyük fark 0.0000000853 m. Örneklenmiş el-kafa sınır kutusu çakışması 0. Bu test tüm vücudun sürekli çarpışma veya üretime hazır rig doğrulaması değildir. Ön ve yan açı görsel olarak incelendi.

Son dosya: animated-wave-v2.glb. Önceki dosyalar korunur. Önizleme: bu klasörde python3 -m http.server 8768 --bind 127.0.0.1 ve /legs.html. Yeniden üretim: numpy içeren Python ile fix_legs.py, ardından validate_legs.py. Canlı turuncu malzeme henüz aktarılmadı; uygulamaya entegrasyon yok.
