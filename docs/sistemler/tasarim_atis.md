# Tasarım kuralları, anahtarlar, atış

> **Özet (2026-11-06):**
> Konuşma/ağız animasyonu yok, iletişim ping ve emote ile. 12 anahtar hurda dağına gömülü (`scripts/key_cache.gd`).
> Atış becerisi: zayıf nokta x2, kombo penceresi 1,5 sn. Atış hattı korkuluğu eski salona ait.
> Kullanıcı kararı (2026-10-31): dummy'ler, hedef çeşitleri ve teçhizat hedefleri kaldırıldı.
> Tam eski belge: `docs/arsiv/ayrintilar_tam_2026-11-06.md`. Dizin: `docs/sistemler/README.md`.

### Tasarım kuralları

- **Konuşma/ağız animasyonu yok.** İletişim ping ve emote ikonlarıyla.

### Anahtarlar ve atış

- **Anahtarlar:** 12 anahtar (`scripts/key_cache.gd`, modeller `assets/props/keys/key_NN.glb`, `tools/build_keys.py`; sıradan, nadir, efsanevi), hurda dağına gömülü (yöntem yukarıda "Hurda dağı" → "Anahtarlar"). Yüzey anahtara inince fırlar, döner, kademe renginde parlar; üstünden yürüyen alır (`request_reveal_key` / `request_take_key`). Ne açtıkları açık soru: kasalar yuvasız, kasanın yerini görevler aldı (aşağıda "Görev ağacı").
- **Atış becerisi (yapıldı):** Zayıf nokta = `weak_spot` grubundaki çarpışma şekli (zombinin kafası; 2026-10-31'e kadar dummy'nin), ×2, altın renkli "+$" ve hit marker. Kombo zinciri: önceki isabetten sonraki 1,5 sn (`COMBO_WINDOW`) içinde gelen her para veren isabet zinciri 1 artırır; ekrandaki xN zincirdir (en fazla x20). **Ödenen çarpan = zincir, en fazla ×20** (tavan Kombo Tavanı upgrade'i, başta x2, en fazla `COMBO_MAX`): x3 parayı 3 ile, x4 4 ile çarpar. **Kafa (zayıf nokta) ve gövde ayrı zincir tutar** (`combo` / `weak_combo`): gövdeden biriken zincir kafaya geçmez, yoksa gövdede biriktirip kafaya vurmak ekonomiyi patlatıyordu. Zincir hedefler arasında sürer; hedef türü çarpanı etkilemez. (2026-10-20, kullanıcı kararı: önceki min(zincir, 1 + tür) ve log2 kuralları çarpanı x2–x3'te tutuyordu, kaldırıldı.) Süre dolan zincir tek başına sıfırlanır, ıska iki zinciri de sıfırlar (`_break_chain`). Taret/bant/robot zinciri büyütmeyecek. Görsel (`scripts/combo_meter.gd`): dummy'nin kafasının yanında "x5" yazısı ve altında 1,5 sn'de boşalan cam bar; yazı bar boşaldıkça solar. Her isabette yazı sıçrar; boyutu logaritmik büyür (x2'de 30 px, x20'de ~57 px), rengi beyazdan altına, sonra kırmızıya döner. Kontrol: `tools/combo_check.gd` (headless).
- **Atış hattı:** x = 14'te duvardan duvara sarı çelik korkuluk (`tools/build_arena.gd` `_firing_line`; 2026-10-31'den beri 20 bölmeli çit, yukarıda "Çit: bölmeler"). Oyuncuyu durduran duvar `FENCE_LAYER` (4), mermiyi durduran direk ve borular `GameState.RAIL_LAYER` (6); mermi ışını (`SHOT_MASK`) aradaki boşluklardan geçer. Oyuncu korkuluğu hiç geçmez. Suistimale karşı: `FIRING_LINE_X`'in ötesinden atılan mermi para ve kombo vermez (host `request_fire`'da namlu konumuna bakar).
- **Kaldırıldı (2026-10-31, kullanıcı: dummyleri kaldır, B ve Teçhizat da gitsin): hedef çeşitleri ve teçhizat hedefleri.** Popper, köstebek plaka rafı, Texas Star, çelik raf ve gong, test_range'in altı sabit hedefi ve tezgâhta satılan 12 teçhizat hedefi (saman kukla, popper, plaka dizisi, köstebek rafı, Texas Star, patlayan varil, yanan korkuluk, zırhlı kukla, sarkaç, çift gong, altın kukla, sekme plakası) sahneleri, betikleri ve asetleriyle silindi. Vurulan tek şey zombi (`waves.gd`, `target` grubu): isabet $1 × zincir × yüzde bonusları, kafa ×2 (`weak_spot`). Hedeflere hizmet eden altyapı da gitti: `hit_gold_at`/`hit_gold`, `is_weak`, `bonus_paid`/`pay_bonus`, `target_cue`/`cue_target`, sekme (`MAX_BOUNCES`, `RICOCHET_MULT`, stil sırasındaki "bounce"), `fire_fx.gd`, `payout_pop.gd` ("+$" yazısı), `target_kit.gd`, kukla kumaşının deliği ve dumanı (`impacts.gd`).
- **Alınmayanlar:** Ürün zinciri, kablolama, 300'lük tech tree, idle ağırlık.
