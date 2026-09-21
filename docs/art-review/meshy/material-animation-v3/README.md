# Animasyonlu maskot — malzeme ve mobil sürüm v3

Kaynak animation-v2/animated-wave-v2.glb. Turuncu için UV atlasından seçilen köşelere COLOR_0 uygulandı; doku tasarımı korunur. Roughness .8, normal scale .22, specular .55. Orijinal görseller ana sürümde birebir korunur.

- animated-material-v3.glb: 21.220.900 bayt, tam çözünürlük.
- animated-mobile-v3.glb: 6.140.596 bayt, 1024 px kaplamalar, renk JPEG kalite92 4:4:4, normal ve metal/roughness PNG.
- 31.105 üçgen. Pozisyonlar, normal, UV, skin ağırlıkları ve tüm animasyon örnekleri korunur. Meshy kaynaklı iki sıfır uzunluklu tangent, normaline dik birim vektöre düzeltildi.
- glTF Transform 4.5.0: dedup, prune, textureCompress. Draco/meshopt gerektirmez.
- glTF Validator: 0 hata, 1 kaynak hiyerarşi uyarısı (NODE_SKINNED_MESH_NON_ROOT). Native entegrasyonda root transform davranışı test edilmeli.
- El ve bacak düzeltmeleri el sallama klibinde korunur. Koşu/yürüyüş henüz kalite kontrolünden geçmedi.

Önizleme: material-animation.html renk öncesi/sonrası, mobile.html tam boyut/mobil. Yerel HTTP sunucusu gerektirir. Tarayıcıda görsel doğrulandı. iPhone performans testi ve native uygulama entegrasyonu yapılmadı; TestFlight değişmedi. GLB'nin native iOS yükleme/dönüştürme yolu ayrıca seçilmeli.

Betikler bu oturumun geçici çalışma yollarını içerir; farklı ortamda giriş/çıkış yollarını ve Sharp importunu ayarlayın.
