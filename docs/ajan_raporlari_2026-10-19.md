# Ajan raporları (2026-10-19)

Dört ajan kodu yalnızca okuyup raporladı; düzeltmeleri ana oturum yaptı. Aşağıda **düzeltilenler** ve **sonraya kalanlar** var.

## Düzeltilenler

| Bulgu | Kaynak | Düzeltme |
|---|---|---|
| Atılan mermiler 2.200'ü geçince Jolt gövde sınırı (10.240) doluyor, mermiler çarpışmasız kalıyordu | performans | `max_bodies` 65.536, `max_body_pairs`, `max_contact_constraints`, geçici bellek 64 MB |
| Hızlı ateşte ikinci atış animasyonu yeniden başlamıyordu (sürgü/horoz yalnızca ilk atışta) | hata | `_play` aynı bölümü `seek` ile baştan başlatıyor |
| Fareyi tekrar yakalayan tık aynı anda ateş ediyordu | hata | Ateş, ancak fare bir önceki karede de yakalıysa kabul ediliyor |
| Atış/oturma sırasında basılan R kayboluyordu | hata + QA | 0.6 s'lik reload tamponu |
| Bilinmeyen upgrade id'si script hatası veriyordu (co-op'ta host'u çökertebilir) | hata + QA | `UPGRADES.has(id)` kontrolü |
| Silah `time_scale`'e uyuyor, GameState gerçek saate bakıyordu (x10 hile menüsü bozulurdu) | QA | GameState ateş bekleme süresi oyun zamanıyla sayılıyor |
| Düşük FPS'te/takılmada tepme yayı sonsuza kaçıyordu | QA + hata | Kare süresi sınırlı, alt adım sayısı yay sertliğine göre |
| Elde gösterilen mermiler fırlatma/reload sonrası eski sayıda kalıyordu | hata | El sayısı `carried`'ı aşamıyor |
| Silah dünyaya havada süzülen bir gölge düşürüyordu | performans | Viewmodel mesh'leri gölge atmıyor |
| Dökülen 8.000 mermi (her biri 1.600 üçgen) her gölge kademesinde yeniden çiziliyordu | performans | Spill MultiMesh gölge atmıyor |
| MSAA 2x ve TAA birlikte açıktı (çift maliyet, küçük mermilerde hayalet) | performans | TAA kapalı, MSAA 2x + FXAA |

## Sonraya kalanlar (öncelik sırasıyla)

1. **Dummy + isabet → gold yok; döngü kapanmıyor.** `fired` sinyalini dinleyen yok, `gold` hiç artmıyor, satın alma arayüzü yok. Tasarım ajanının önerisi: `request_fire` içinde host tarafında raycast, "dummy" grubuna isabette gold; HUD'da gold ve uçan "+1"; Tab ile açılan upgrade paneli; `debug_carry`/`debug_mag` kapatılınca taşıma/şarjör upgrade'leri anlam kazanır. Tahmini 8-10 saat.
2. **Efektler `fired` sinyalinden oynamıyor** (alev, kovan, ses yalnızca yerel `fire()` içinde). Co-op kuralı gereği `GameState.fired` dinleyicisine taşınmalı.
3. **Yığın simülasyonu tek dikdörtgen üzerinden çalışıyor.** Birbirinden uzak iki kazı tüm yığını kapsayan bir kutuya birleşiyor; 20 noktadan kazıda kare başına ~24 ms (zirve 37 ms). 16×16'lık karolar halinde aktiflik takibi gerekiyor. Taret/bant gelmeden önce şart.
4. **Yığın/spill mermi mesh'i 1.600 üçgen** (23.000 kopya ≈ 37M üçgen). 40-100 üçgenlik bir LOD mermisi en büyük GPU kazancı.
5. **Viewmodel SubViewport ana dünyayı paylaşıyor**, güneş gölgesi iki kez çiziliyor. `own_world_3d` + ayrı ışık.
6. **Yığın shader'ı `discard` + 32 adımlı parallax**; gölge geçişlerinde de çalışıyor. Gölge için ucuz ikinci kopya.
7. **Açılışta 0.64 s iş** (doku renk ayarı, 15.000 mermi yerleştirme). Offline'a alınabilir.
8. Gevşek mermiler ve elde uçan mermiler her seferinde yeni node + yeni şekil/materyal oluşturuyor; havuzlanmalı.
9. Kazılan yığının üstünde duran kovan/mermiler uyanmıyor, havada kalıyor.
10. Çıkışta ses kaynakları sızıntısı (yalnızca kapanışta, düşük öncelik).
11. Fiyat sırası: şarjör 1 iken ateş hızı upgrade'i hiçbir şey kazandırmıyor; `fire_rate` şarjör ≥ 3'e kadar kilitli olmalı.
12. Tempo: 100M'yi 60 dakikada bitirmek ortalama 27.8 bin mermi/s demek; yığın gözle ancak son 10-15 dakikada küçülüyor. Tasarım ajanının ilk tempo tablosu aşağıda.

## Tasarım ajanının ilk tempo tablosu (taslak)

| Dakika | Mermi/s | Açılan |
|---|---|---|
| 0-5 | 0.5-1 | taşıma, şarjör 3, gold x2 |
| 5-10 | 4 | revolver, ateş hızı |
| 10-15 | 15 | Uzi, manuel ateş bonusu |
| 15-20 | 80 | ilk taret, 2. dummy türü |
| 20-25 | 500 | bant, robot taşıyıcı |
| 25-30 | 3k | AK, seken mermi |
| 30-40 | 10-25k | zırhlı dummy, ortak kasa |
| 40-50 | 45-70k | minigun taret, 3. kademe |
| 50-60 | 90-100k | final |

Hızlı juice önerileri: isabet işareti (crosshair büyüyüp beyazlaşır + tık), dummy sallanması, gold sayacı zıplaması, ıska için duvar/zemin izi, son mermide kırmızı şarjör yazısı, upgrade alındığında ortada büyük yazı.
