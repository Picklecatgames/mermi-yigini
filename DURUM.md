# Durum: stil sıralaması (claude/stil-sirasi-db59e8)

- **Bitti:** ekranın solunda D…SSS stil sıralaması, `scripts/style_rank.gd`, HUD'a `scripts/hud.gd`'de iki satırla bağlı. Puan, bayatlama, erime, tier atlama ve düşme efektleri, yalnız yerel oyuncu.
- **Asetler:** `assets/ui/style/` (Dino0040 grunge CC0 + Kenney Particle Pack CC0), `assets/fonts/RubikWetPaint-*` (OFL); `docs/ayrintilar.md`'ye yazıldı.
- **Kontroller:** `tools/style_rank_check.gd` geçiyor; `tools/style_shot.gd` ile her tier ekran dışı çekimle görüldü.
- **Bağımlılık:** zombi öldürmeleri `waves.gd`'nin `zombie_killed(peer, kind, weak, at, gun)` sinyalinden geliyor (dalga dalı `claude/dalga-kodu-704193`). `waves` grubundaki düğüm bulununca bağlanıyor; dal birleşmeden sıralama yalnız hedef isabetleriyle doluyor.
- **Kalan:** birleştirmeden sonra `tools/hud_check.gd` yeniden çalıştırılmalı (bu oturumda başarı satırı görülmedi). Ses kayıtları `assets/sounds/style/rank_up_0..6` ve `rank_down` (ogg/wav) adlarıyla konacak. Sayılar ilk tahmin, kullanıcı onaylamadı.
- **Bilinen:** 720p'de sıralama büyük duruyor (`UiStyle.fit_screen` arayüzü küçültmüyor), soldaki işaret okuyla üst üste binebiliyor.
