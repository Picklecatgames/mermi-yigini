# Durum: Sketchfab zombileri (dal claude/sketchfab-zombi-00090b)

- **Bitti:** beş model girdi. Hazmat ve bloater Mixamo kütüphanesiyle; melty, köpek ve blob yaratık olarak kendi klipleriyle. `tools/zombie_body_check.gd` geçiyor, ekran dışı çekimlerle de bakıldı.
- **Dosyalar:**
  - `scripts/zombie_body.gd`: `CREATURES`, yeni türler `blob` ve `dog`, `_roll` düzeltmesi
  - `tools/sketchfab_zombies.py`: Blender dönüştürme aracı
  - `tools/build_zombies.gd`: glb okuma
  - `tools/zombie_body_check.gd`
  - `tools/zombie_shots.gd`
  - `assets/characters/zombies/{hazmat,bloater,melty,dog,blob}/`
  - `docs/ayrintilar.md`: aset listesi ve zombi bölümü
- **Kalan:** tür üyelikleri, boylar ve hızlar geçici, kullanıcı onaylamadı (docs'ta işaretli). Dalga kodu yeni türleri (`blob`, `dog`) henüz kullanmıyor.
- **Sıradaki adım:** dalı main'e birleştirmek. Dalga kodu oturumu ortak notlardaki `sketchfab-zombi.md`'yi okusun. Ham dosyalar (`raw/chars/*.glb`) git'te yok; yeniden kurmak için `tools/sketchfab_zombies.py` başındaki komutlara bak.
