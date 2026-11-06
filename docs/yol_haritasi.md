# Yol haritası (2026-11-06, kısa)

Eski tam hâli (Faz 0-6, her adımın uzun uygulama notları): `docs/arsiv/yol_haritasi_2026-10-20.md`. Hedef ve kararlar `CLAUDE.md`'de: 5-6 saatlik tam oyun (2026-11-05, kullanıcı kararı), ondan kısa ~1 saatlik ücretsiz Steam demosu, 4 kişilik co-op.

**Sıra kuralı (2026-10-20):** co-op en başta kuruldu; her sistem iki pencereyle denenerek yapılır. Her sistemde: durumu yalnız host değiştirir (`request_*`), rastgelelik yalnız host'ta, aynı anda iki istek gelirse ilk gelen kazanır, ortada katılan oyuncu durumu bir kerede alır.

## Bitti
Faz 0-2 (toparlanma, co-op iskeleti: ağ, diğer oyuncular, host'a bağlama, ortak kasa, katılma/ayrılma; dükkân, yerleştirme, hile paneli) ve hurda dağı (2026-11-02). Açık alan, gece-gündüz, ev/TV ve ormandan zombiler yapıldı (ayrıntı `git log`).

## Kalan (sıra önerisi, kullanıcı kararı değil)
1. Öğütücü çalışır; malzeme → barut ya da kovan → mermi; yeni kovanlar ve mermi türleri (`docs/sistemler/hurdalik.md`).
2. Post-apokaliptik silahlar; eski tasarımın kalıntılarını temizle (`docs/sistemler/eski_tasarimdan_kalanlar.md`).
3. Otomasyon, bant, taret (`docs/otomasyon_hazirlik.md`), görev/pano sistemi (`docs/gorev_sistemi_plani.md`).
4. Dalga ve baygınlık sayılarının onayı, denge turu; çit level'a göre çeşitlenir (kullanıcı kararı); müzik.
5. Bitiş hedefi ve töreni (açık soru); co-op iletişimi: ping ve emote (konuşma animasyonu yok).
6. Steam: GodotSteam lobi, ana menü ve dünya oluşturma, kayıt, 60 dk denge (1/2/4 oyuncu), dışarıdan test, mağaza sayfası ve demo uygulaması.
