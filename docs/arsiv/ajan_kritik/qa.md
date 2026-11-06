# QA raporu: hata avı (qa ajanı, 2026-10-19)

Yöntem: kod okuma ve headless Godot 4.7.2 betikleri. Geçici betikler `tools/agent_qa_check.gd` ve `tools/agent_qa_probe2.gd` iş bitince silindi. Kopyaları karalama klasöründe: `scratchpad/agents/qa/`. Bulguların yanındaki **[D✓]** işareti headless betikle doğrulandığını, **[K]** yalnızca kod okumayla gerekçelendirildiğini, **[?]** ise doğrulanmadığını gösterir.

Mevcut kontroller:
- `tools/combo_check.gd` → **combo_check OK** (tüm assert'ler geçti).
- `tools/steel_check.tscn` → **steel_check OK**. Tek isabet: plaka 37°, gong 7°. Üç alçak isabette plaka takla attı. 25 sn sonra plaka 0,1°, gong −0,1°.

## Özet (5 madde)

1. **Texas Star'da isabet izi yanlış plakaya yapışıyor [D✓].** `texas_star.gd` vurulan plakayı `_on`'dan düşürdükten sonra Impacts `decal_parent()` çağırıyor. `_nearest()` yalnızca takılı plakalara baktığı için iz komşu plakaya (test: Plate1 vuruldu, iz Plate5'e gitti) bağlanıyor.
2. **Hedef silinirse Impacts havuzu kırılıyor [D✓].** Delikler ve dumanlar hedefin içine taşınıyor. Hedef silinince bu havuz girdileri de onunla birlikte siliniyor. Sonraki her bez isabetinde `impacts.gd:157` script hatası veriyor ve efekt/iz çıkmıyor. Bugün hiçbir şey hedef silmiyor ama yerleştirme modu bunu getirecek.
3. **Hedef zamanlayıcıları `minf(delta, 0.05)` ile kısılıyor [D✓].** x10 hızda ve 60 FPS'te popper 3,46 sn yerine **11,8 sn (oyun zamanı)** yerde kalıyor. Kombo penceresi ise kısılmamış delta ile sayılıyor. Bu yüzden x10 denge testleri ve 20 FPS altı oyun yanlış tempo ölçer.
4. **Hattın ötesinden atış para vermiyor ama hedefi tüketiyor [D✓].** Popper yatıyor, köstebek rafı "isabet" sayıp hızlanıyor (`_up_time` 1,6 → 1,472) ve kalkan plaka iniyor. Co-op'ta yerleştirme modundaki oyuncu, hattaki arkadaşının hedefini ve kombosunu bozar.
5. **Sağlam olanlar [D✓]:** Aynı karede iki peer aynı plakaya/poppera ateş edince yalnızca ilki ödeniyor (şekil anında kapanıyor). Korkuluk maskesi sıkışma yaratmıyor. Kilitli (`PROCESS_MODE_DISABLED`) hedefler isabet almıyor.

## İyi, kalsın

- **Aynı kare çift isabet koruması [D✓]:** `popper_target.gd:70`, `plate_rack.gd:103` ve `texas_star.gd:91`, şekli sinyal içinde anında kapatıyor. İki peer aynı karede aynı plakaya ateş etti: peer2 $5, peer3 $0 aldı. Popper'da $6 ve $0. Jolt sorgusu değişikliği aynı karede görüyor.
- **Korkuluk mantığı (`player.gd:194`) [D✓]:**
  - Yerleştirme kapalıyken doğuya yürüyen oyuncu x = 13,50'de duruyor.
  - Mod açıkken 18,5'e geçiyor.
  - Hattın ötesinde mod kapatılırsa batıya geri yürünebiliyor (8,15).
  - Korkuluğun içinde kapatılırsa merkez x < 14 için batıya itiliyor (13,70 ve 13,95 → 13,50), merkez x ≥ 14 için doğuda kalıyor.
  - Sıkışma yok. Kural simetrik: "kısa yöne it" her zaman batıyı seçiyor.
- **Kilitli hedefler [D✓ combo_check]:** `DISABLE_MODE_REMOVE` gövdeyi fizikten çıkarıyor. Sinyal dinleyicileri çalışmaya devam ediyor ama `target != self` olduğu için bir şey yapmıyor.
- **`request_fire` soğuma süresi** oyun zamanıyla sayılıyor ve aynı karede ikinci atışı engelliyor. Sınırsız mermi (T) aynı karede birden çok mermi üretmiyor.
- **Asılı çelik** `_physics_process` + 4 alt adım kullanıyor. Sabit fizik adımında olduğu için düşük FPS'ten etkilenmiyor. steel_check temiz.
- **Diğer sağlam noktalar:** `combo_meter` silinen hedefi (`is_instance_valid`) ve kamera arkasındaki hedefi (`is_position_behind`) doğru eliyor. `payout_pop` havuzu eski tween'i öldürüyor.

## Kötü, düzelsin

### 1. Texas Star izi yanlış plakada — O, 10 dk [D✓]
- **Yer:** `texas_star.gd:70-83` (`decal_parent` → `_nearest`), `impacts.gd:135`.
- **Yeniden üretme:** `plate_center(0)`'a önden ateş et, ardından `Impacts._holes[i].get_parent()` değerine bak. Sonuç `Plate5` çıkıyor, `Plate1` olmalı.
- **Neden:** Sinyal sırası. Hedefler `_ready`'de Impacts'ten önce bağlanıyor. Yıldızın işleyicisi `_on[i] = false` yapıyor, ardından Impacts `_nearest` çağırıyor ve vurulan plaka artık aday değil.
- **Sonuç:** İz, havada komşu plakaya bağlı duruyor. O komşu da vurulup düşünce iz onunla birlikte yere düşüyor ve zemine/kaideye yansıyor. Bütün plakalar düşmüşken `_nearest` 0 döndürüyor (kapalı plaka).
- **Öneri:** `decal_parent` `_on` filtresi olmadan en yakın plakayı seçsin. `plate_rack.gd:89`'daki `_nearest` gibi tüm plakalara bakmak yeterli: işleyici yalnızca hız verdiği için vurulan plaka o karede hâlâ yerinde. Böylece iz plakayla birlikte düşer. İsteğe bağlı olarak `_put_back`'te plakanın çocuk Decal'ları gizlensin (yeniden çıkan plaka temiz gelsin).

### 2. Silinen hedef Impacts havuzunu bozuyor — O (yerleştirme modu gelince Y), 15 dk [D✓]
- **Yer:** `impacts.gd:136-137`, `157-158` ve `191`.
- **Yeniden üretme:** RailDummy'ye 3 atış yap, sonra `free()` et. 3 delik ve 3 smolder onunla birlikte silindi. Sonraki 60 atışta 21 kez `Cannot call method 'get_parent' on a previously freed instance` (`_smolder`), 3 kez aynı hata (`_on_shot_landed:136`) ve `_process:191`'de `amount_ratio` hatası alındı.
- **Etkisi:** Her hata işleyiciyi yarıda kesiyor, yani o isabette kıvılcım/iz/duman yok.
- **Öneri:** En kısa yol, havuzdan alırken `if not is_instance_valid(d): d = _new_hole(); _holes[i] = d` yapmak (smolder için de aynısı) ve `_process`'te geçersiz girdiyi atlamak. Alternatif: ilk reparent'ta `parent.tree_exiting`'e bağlanıp çocukları Impacts'e geri taşımak.

### 3. Hedef zamanlayıcıları kısılmış delta ile sayılıyor — O, 20 dk [D✓]
- **Yer:** `popper_target.gd:77-79`, `plate_rack.gd:113-123`, `texas_star.gd:105-122`, `dummy.gd:87` (dummy yalnızca fizik, sorun değil).
- **Yeniden üretme:** `--fixed-fps 60` ve `Engine.time_scale = 10` ile popper'ı devir. Beklenen süre 3,46 sn oyun zamanı (≈20 kare), gerçekleşen 71 kare = 11,8 sn oyun zamanı. Doğrudan `popper._process(1.0)` çağrısı `_down_left`'i yalnızca 0,05 düşürüyor. Yıldız 1 sn'lik karede 3,0 rad yerine 0,15 rad dönüyor.
- **Neden:** Kombo penceresi (`game_state.gd:127`) kısılmamış delta ile sayılıyor. Hedefler ise 20 FPS altında ya da x4 üstü hızda ağır çekime giriyor. CLAUDE.md'ye göre x10 hile menüsü denge testi için şart; bu hâliyle ölçülen gelir yanlış çıkar.
- **Öneri:** Zamanlayıcılar (`_down_left`, `_up_left`, `_gap`, `_back_in`, `_angle`) ham `delta` ile düşsün. Yalnızca yay integrasyonu kısılsın; ya da alt adım sayısı `ceili(delta / 0.0125)` olsun. Kararlılık tamam: x10'da h = 0,042 ve ω ≈ 16 için h·ω ≈ 0,67.

### 4. Hat ötesinden atış hedefi "tüketiyor" — O (co-op'ta Y), 15 dk [D✓]
- **Yer:** `game_state.gd:245-256` her durumda `target` ile `shot_landed` yayıyor. Etkilenen işleyiciler: `popper_target.gd:64`, `plate_rack.gd:97`, `texas_star.gd:86`.
- **Yeniden üretme:** PopperSouth'a 3 m'den ateş et → paid = 0, knocked = true, combo = 0. Köstebek rafına 3 m'den ateş et → paid = 0, `_up_time` 1,600 → 1,472, `up_plate` = −1.
- **Beklenen:** Para yok ve zincir yok (bu kısım doğru). Ama hedef de tüketilmemeli.
- **Öneri:** Sayılan isabette `combo ≥ 1`, sayılmayanda 0. Hedefler bu bilgiyi zaten alıyor. `plate_rack` ve `texas_star`, `combo == 0` iken yalnızca ses/kıvılcım versin, plakayı indirmesin/düşürmesin, tempoyu değiştirmesin. Popper için de aynısı. Daha kısa bir alternatif: `request_fire` başında `if p.placing: return false` (yerleştirmede silah inik). Ama bu, mod hattın ötesinde kapatılan oyuncuyu kapsamaz; o yüzden ikisi birlikte.

### 5. Sabit dönüşüm/interpolasyon uyumsuzluğu — D, 10 dk [?]
- **Yer:** Bu düğümler `_process`'te taşınıyor ama `physics_interpolation_mode` miras (AÇIK): `texas_star.gd:108` (`_arm`), `popper_target.gd:95`, `plate_rack.gd:144`, `dummy.gd:100`, `payout_pop.gd` etiketleri.
- **Ölçüm:** Yıldız kolu için `get_global_transform_interpolated()` set edilen dönüşümden 0,014-0,021 rad sapıyor. Plaka yarıçapı ≈ 0,5 m ile görünen plaka ve isabet kutusu ≈ 1 cm ayrık. Hitbox `KIT.follow` ile interpolasyonsuz pozu kullanıyor.
- **Doğrulanmadı:** Yüksek Hz ekranda titreme yapıp yapmadığını görmek için Beckett ile görsel test gerekiyor.
- **Öneri:** Player ve Impacts'te zaten yapıldığı gibi `_process`'te taşınan bu düğümlere `PHYSICS_INTERPOLATION_MODE_OFF` verilsin.

### 6. T aç/kapa bedava mermi veriyor — D, 2 dk [D✓]
- **Yer:** `game_state.gd:217-222`.
- **Yeniden üretme:** loaded 0 iken T'ye iki kez bas → loaded = 1, yığın değişmiyor. Kapasite 7'de her aç/kapa 7 mermi demek ve "yığın hem hedef hem yakıt" kuralını deliyor.
- **Öneri:** Kapatırken `_set_loaded(peer, 0)` ya da eski değere dön. Test modu olduğu için düşük öncelik.

### 7. `hit_gold` olmayan bir "target" atışı yarıda kesiyor — D, 2 dk [D✓ kısmi]
- **Yer:** `game_state.gd:250`, `int(target.get("hit_gold"))`.
- **Kanıt:** `int(null)` Godot 4.7'de `Nonexistent 'int' constructor` hatası veriyor (headless denendi). Bugünkü bütün hedeflerde `hit_gold` var. Ama yeni bir hedef bunu unutursa `combo++` olur, mermi harcanır, `shot_landed` hiç yayılmaz ve efekt/para çıkmaz.
- **Öneri:** `int(target.get("hit_gold")) if "hit_gold" in target else 0`.

### 8. Popper, köstebek rafı ve Texas Star'ın sesi yok — D, 10 dk [K]
- **Yer:** `scenes/popper_target.tscn`, `plate_rack.tscn` ve `texas_star.tscn`'de `hit_sound`/`rise_sound`/`reset_sound` atanmamış. `KIT.play` stream yoksa sessiz kalıyor. Asılı çeliklerde ses var.
- **Öneri:** Çelik "tink" sesi bu üçüne de bağlansın. CLAUDE.md'de yalnızca dummy'nin `HitSound`'u boş diye yazıyor, bunlar listede yok.

### 9. Co-op: atış hattı istemcinin gönderdiği `from` ile kontrol ediliyor — D (co-op gelince O), 15 dk [K]
- **Yer:** `game_state.gd:245`, `from.x <= FIRING_LINE_X`. Ayrıca `player(peer)` (`:100`) ağdan gelen her peer id için yeni bir PlayerState yaratıyor.
- **Neden:** Host otoriter olacaksa `from`'u istemciden almamalı. Hile yapan bir istemci `from.x = 13` yazıp hedefin dibinden ateş eder.
- **Öneri:** Host, `from`'u peer'ın sunucudaki gövde pozisyonundan türetsin (± 0,5 m tolerans). Bilinmeyen peer'lar reddedilsin.

### 10. combo_meter gizlenen hedefin üstünde "xN" çiziyor — D, 3 dk [K]
- **Yer:** `combo_meter.gd:47`.
- **Neden:** Hedef kilitlenir/gizlenirse 1,5 sn boyunca görünmez bir hedefin üstünde yazı kalır.
- **Öneri:** `or not _target.is_visible_in_tree()`.

## Eklensin

- **Hat ötesi testi (Y, 10 dk):** `combo_check.gd`'ye "hat ötesi atış plakayı tüketmez" assert'i (madde 4 düzeltilince).
- **x10 testi (O, 10 dk):** `combo_check.gd`'ye `Engine.time_scale = 10` ile popper'ın yerde kalma süresi testi; `--fixed-fps 60` ile çalıştırılsın.
- **Silinen hedef testi (O, 10 dk):** Yerleştirme modu gelmeden önce bir hedefi `free()` edip 60 atış daha atan bir regresyon testi (madde 2).
- **Texas Star iz testi (D, 5 dk):** Plakaya ateş edilince deliğin ebeveyni vurulan plaka olmalı.

## Çıkarılsın

- **`main.tscn` (D):** `LockedTargets` sahnede hiçbir zaman kilitli değil. Script, `process_mode` ya da `visible` ayarı yok; bütün hedefler ilk saniyeden ödüyor. "Kilitli" yalnızca test betiğinde var. Ya isim değişsin ya da kilit mekanizması gelsin. Aksi hâlde yeni gelen biri bunun çalıştığını sanar.
- **CLAUDE.md (D):** Dummy konumu "(17, 0, 6)" yazıyor, `main.tscn`'de (23, 0, 0). Bilgi bayat.

## Sayılar

- **Kombo tavanı (O):** Sınırlı mermiyle zincir pratikte 7-14 isabette kırılıyor. Tetikleyiciler: 1,37 sn'lik reload + settle ≈ 1,4-1,75 sn, yani `COMBO_WINDOW` 1,5 sn sınırında; yığına gidiş ise kesin kırıyor. Sınırsız mermide (T) gelir karesel büyüyor: dakikada 143 atış, dummy'de 1 dakikada ≈ $10 bin. Yalnızca test modunda, şimdilik sorun değil. Hızlı silahlar gelince denge ajanına: tavan x20 öner.
- **Interpolasyon kaynaklı isabet kutusu sapması:** Yıldız plakasında ≈ 1 cm, 15 cm'lik plakaya göre ihmal edilebilir. Öncelik D kalsın.
- **Korkuluk:** Kalınlık 0,3 m + kapsül yarıçapı 0,35 m. Normal modda en ileri merkez x = 13,50, yerleştirme modunda 14,0'a kadar hâlâ ödeme var. 0,5 m'lik bu fark önemsiz, değiştirme.

## Diğer ajanlara sorular

- **Tasarım:** Hat ötesinden vurulan hedef fiziksel tepki versin mi (ses/kıvılcım) ama "tüketilmesin" mi, yoksa yerleştirme modunda silah tamamen mi insin?
- **Ekonomi:** Kombo silahlar arası taşınacaksa (Uzi, AK) tavan ve pencere silaha göre mi olacak?
- **Co-op:** Kombo kişisel; aynı plakaya iki oyuncunun yarışında ilk gelen ödeniyor (doğrulandı). Yarışan oyuncunun ıskası zincirini kırıyor. Ortak kombo istenir mi?

## 2. tur: tartışma

Okunanlar: `ekonomi.md`, `tasarim.md`, `gorsel.md`. Yeni ölçüm için geçici bir `tools/agent_qa_r2.gd` yazdım, `--fixed-fps 60` ve `--fixed-fps 144` ile headless çalıştırdım, sonra sildim.

Kullanıcının sınırları:
- Kombo 1,5 sn'lik zincir olarak kalacak ve büyüyecek (taramalı silahta ×100).
- Texas Star hızlı dönecek.
- Hedefler ilerledikçe açılacak.

Önerileri bu sınırların içinde değerlendirdim. **[D✓]** headless betikle doğrulandı, **[K]** kod okumayla gerekçelendirildi demek.

### Önerilerin riskleri

**1. Ekonominin kademeli tavanı (×1,1,2,2,3,3,4)**
- **Kullanıcıyla çelişkisi:** ×4 tavanı "×100'e büyüyen zincir" kararıyla çelişiyor. Ama altındaki risk gerçek.
- **Bugün neden patlamıyor [K]:** Zincir yalnızca reload pencereden uzun olduğu için kırılıyor.
  - Boş şarjör reload'u 2,48 sn (ekonominin ölçümü doğru).
  - Taktik reload yaklaşık 2,15 sn: önce `fire` klibinin bitmesi gerekiyor (0,433), sonra `reload` (1,367) ve `settle` (0,35).
- **×100'e nasıl ulaşılır:** Ya şarjör ≥ 100 mermi olacak ya da zincir reload'dan sağ çıkacak. İkinci durumda, yani reload hızı upgrade'i ya da pencereyi tazeleyen bir şey gelirse, gelir zincirin karesiyle sınırsız büyür. Taretli/beslemeli düzende bu dakikada $1,8M demek.
- **Çözüm:** Gösterilen zincir ile para çarpanını ayırmak. Zincir ×100'e kadar büyür ve görünür. Para `combo_mult(zincir)` ile ayrı bir eğriden gelir (tavanlı ya da logaritmik).
  - Kullanıcının istediği his korunur, ekonominin istediği sınır da sağlanır.
  - Değişen tek satır `game_state.gd:250`.
- **Taret, bant ve robot isabetleri:** `request_fire`'dan ayrı bir istekle gelsin ve `PlayerState.combo`'ya hiç dokunmasın. Ekonomi de bunu istiyor, co-op'ta host otoritesiyle de uyumlu. Bu ayrım **taret gelmeden önce şart.**
- **Ekonominin T önerisi (T açıkken `gold = 0`):** Tehlikeli. `infinite_ammo` tüm oyuncular için tek anahtar (`game_state.gd:213-214`). Co-op'ta bir oyuncu T'ye basınca herkesin geliri sıfırlanır. T, `OS.is_debug_build()` arkasına alınsın ya da oyuncu başına olsun.

**2. Tasarımın çeşit çarpanı (son 5 sn'de vurulan farklı tür sayısı)**
- **"Tür" kimliği nereden gelir:** Her hedef kökünde `@export var kind: StringName` olmalı.
  - `hanging_steel` plakaları ayrı `StaticBody3D`; `hit_gold` gibi `setup()`'ta `_target.kind`'ı kopyalamalı.
  - `request_fire` bugün `hit_gold`'u `target.get()` ile okuyor. `kind` eksik bir hedefte de aynı sessiz hata riski var: `int(null)` script hatası verir, atış yarıda kalır [D✓]. Eksik `kind` için güvenli bir varsayılan (`&"other"`) şart.
- **Aynı türden iki hedef:** Bilerek aynı sayılıyor, bu doğru. İki popper ya da ek dummy'ler V'yi artırmaz; ayrıştırmak için örnek id'si gerekmez.
- **Suistimal:** Yerleştirme serbest ve taşıma bedava. Altı tür 0,3 m arayla tek kümeye konup SMG ile süpürülürse V = 6 bir saniyede dolar ve sürekli tutulur.
- **Asıl tehlike çarpımda:** Çeşit, zincirle **çarpılırsa** (30 × 6 = ×180) ekonomi zincirin bugünkü hâlinden de hızlı patlar.
- **Kullanıcı zinciri tuttuğuna göre önerim:** Çeşit ya hiç eklenmesin ya da yalnızca toplanan bir bonus olsun. Örnek: farklı türe geçişte zincire +1 ek. Asla çarpan olmasın.
- **Co-op:** `last_hit` kayıtları host'taki PlayerState'te tutulmalı ve oyun zamanıyla sayılmalı (x10 için). `Time.get_ticks_msec` kullanılmamalı.

**3. Görselin Texas Star rezonans çözümü**
- **Rezonans iddiası ölçümde tutmadı [D✓].** Yıldızın ilk plakasına sabit nişan alıp aralıksız ateş ettim (20 sn, tek nokta):
  - 60 FPS'te (0,433 sn aralık) **4 isabet / 47 atış**.
  - 144 FPS'te (0,424 sn aralık) **2 isabet / 48 atış**.
  - Sebebi: Vurulan plaka düşüyor ve `LURCH` (+1,2 rad/s) dönüş hızını değiştiriyor, bu da faz kilidini her isabette bozuyor. Hepsi tek tek ödendi; zincir kurulmadı.
  - Görselin 3 × 0,42 = 72° hesabı doğru, ama sonuç "her atışta bir plaka" değil.
- **SPIN'i 1,8'e düşürmek:** Kullanıcının "hızlı dönecek" kararıyla çelişiyor ve gerekçesi ölçümde yok. Dokunulmasın.
- **Dengesizlik modeli (dolu yıldız durur):** Aynı sebeple çelişiyor.
- **Yine de pay bırakmak istenirse:** `SPIN` = 4,5 rad/s, ateş aralığında yarım plaka kaydırır (rezonanstan en uzak nokta) ve daha hızlıdır.
- **Görselin plaka ölçüsü:** "0,20 yuvarlak" değil, ölçüm 0,20 × 0,28 m. Ekonominin "Ø0,28"i de tam değil.
- **E1 önerisi (`KIT.play` içinde `await` ile ses gecikmesi):** `target_kit.gd` statik ve `RefCounted`. Beklerken hedef silinirse "freed instance" hatası verir. Gecikme `AudioStreamPlayer3D`'nin kendi tarafında, bir zamanlayıcıyla yapılsın; bekleyiş oynatıcının ömrüne bağlansın.

**4. Tasarımın yerleştirme modu (serbest, 0,5 m grid, x 18–26,5, taşıma bedava)**

Açılan hata ve suistimal kapıları:
- **a) Silme/taşıma benim Y bulgumu tetikler [D✓].** Hedef silinirse Impacts'in deliği ve dumanı hedefle birlikte siliniyor; sonraki her bez isabetinde `impacts.gd:157` hatası çıkıyor ve efekt kayboluyor.
  - Taşıma "eskiyi sil, yenisini örnekle" diye yazılırsa aynı hata çıkar. Yeniden ebeveyn değiştirme ya da konum değiştirme ise güvenli.
  - **Yerleştirmeden önce** Impacts havuzu silinmeye dayanıklı olmalı.
- **b) Sinyal sırası kırılgan [D✓ + K].** Sahnedeki hedefler `shot_landed`'e Impacts'ten **önce** bağlanıyor; Texas Star iz hatası bu yüzden çıkıyor.
  - Çalışma anında yerleştirilen hedefler Impacts'ten **sonra** bağlanacak, yani aynı hedef konduğu yere göre farklı davranacak.
  - `decal_parent` işleyici sırasından bağımsız olmalı. Texas'ta `_on` filtresi kalksın.
- **c) Elde taşınan önizleme canlı kalırsa ateşe açık [K].** Ödeme kuralı yalnızca atıcının x'ine bakıyor, hedefin yerine bakmıyor (`game_state.gd:245`). x = 13'te önizlemeyi tutan oyuncu onu dipten vurur ve parasını alır.
  - Çözüm: Önizleme fizikten çıkmalı (`process_mode = DISABLED` gövdeyi fizikten çıkarıyor) [D✓ combo_check].
  - Ek savunma: `request_fire`'da `target.global_position.x >= PLACE_MIN_X` kontrolü.
- **d) Bant bedeli hedefin kökünden ölçülsün.** Yıldızın düşen plakaları ve köstebeğin plakaları kökten 0,7–1,5 m uzakta. Bant isabet noktasından ölçülürse x = 22 sınırında aynı hedef iki farklı bedel öder.
- **e) Co-op:**
  - Hedef id'si host'ta verilmeli. `@StaticBody3D@123` gibi otomatik isimler peer'lar arasında farklı çıkar.
  - Bir hedefi aynı anda yalnızca bir oyuncu taşıyabilmeli (kilit). Bedava taşıma, arkadaşının nişan aldığı hedefi çekip almak demek; sahiplik yoksa taciz kapısı.
  - `request_move_target` host'ta taban izini ve bölgeyi yeniden doğrulamalı.
- **f) Hareket hâlindeki hedefi taşımak:**
  - Düşmüş yıldız plakası, yıldızın kendi çocuğu; yıldızla birlikte ışınlanır, havada asılı kalabilir. Yer yüksekliği her karede `global_position.y`'den hesaplandığı için kendini toparlar, ama `reset_physics_interpolation()` çağrılmazsa bir karelik kayma görünür.
  - Düşmüş popper ve köstebek durum makineleri taşınmadan etkilenmez.
- **g) Hat ötesi atış:** Yerleştirme raycast'le hattın gerisinden yapılırsa B ile hattı geçmeye gerek kalmaz. Benim 4. bulgum (hat ötesinden atışın hedefi tüketmesi) da büyük ölçüde ortadan kalkar. Önerim: yerleştirmede silah insin, hattı geçme iznini kaldıralım.

**5. Ekonominin dükkân kilidi (`visible = false` + `process_mode = 4`, satın alma `UPGRADES` üzerinden)**
- **Risk 1 [K]:** `request_debug_level_up` seviyeyi `% size` ile başa sarıyor. Debug tuşu açılmış bir hedefi yeniden kilitler.
- **Risk 2 [K]:** Kilitlenen hedefin üstünde `combo_meter` 1,5 sn "xN" çizer.
- **Uyumlu olan [D✓]:** Kilitli gövde fizikten çıkıyor, sinyal dinleyicileri zararsız.
- **Co-op:** Kilit dünya durumu. Kişisel `levels` içinde tutulursa her peer'da farklı hedefler açık olur. Ortak kasaya ya da ayrı bir `world_unlocks` yapısına taşınmalı.

### Diğer raporlardaki iddiaların kontrolü

| İddia | Kimden | Sonuç |
|---|---|---|
| Boş şarjör reload'u 2,48 sn | ekonomi | **Doğru** [K]: 0,467 + 1,23 + 0,783. Taktik reload ~2,15 sn; ikisi de pencereden uzun. |
| `LockedTargets` fiilen kilitsiz | ekonomi, tasarım | **Doğru** [K]: `main.tscn:29`'da script, `process_mode` ya da `visible` ayarı yok. |
| Dummy'nin sesi var, CLAUDE.md bayat | görsel | **Doğru** [K]: `dummy.tscn:51-52` `hit.tres`'i atıyor. |
| Popper, köstebek ve yıldız sessiz | görsel | **Doğru** [K]: üç `.tscn`'de de ses yuvası boş. |
| Kaide ve direk isabeti $1 ödüyor ve zinciri sürdürüyor | ekonomi | **Doğru** [K]: `dummy.tscn:31` Base ve `:35` Pole, `target` gövdesinin şekilleri. |
| Yıldız rezonansı "park et, basılı tut" stratejisi | görsel | **Ölçümde tutmadı** [D✓]: 4/47 (60 FPS), 2/48 (144 FPS). |
| Plaka ölçüleri | görsel, ekonomi | **Kısmen doğru** [D✓]: yıldız 0,20×0,28, köstebek 0,20×0,26, popper 0,20×0,71 m. Görselin "yuvarlak 0,20"si ve ekonominin "Ø0,28"i tam değil. |
| `texas_star.gd:157-165 _put_back`, `hanging_steel.gd:34 SHIVER` | görsel | **Satır numaraları yanlış:** dosya 138 satır, `_put_back` 128-138. `SHIVER` 37. satırda. |
| Kıvılcım rengi 1,0 olduğu için glow tetiklenmiyor (eşik 1,3) | görsel | **Doğrulanmadı.** |
| Atış hattı kuralı istemcinin `from`'una güveniyor | ekonomi | **Doğru**, benim 9. bulgumla aynı. |

### Ek öneriler (koordinatörün iletisi)

**Tasarımın yeni formülü: ödenen çarpan = min(zincir, 1 + zincirdeki farklı tür sayısı)**
- **Kullanıcıyla uyumlu.** Zincir 1,5 sn penceresiyle kalıyor ve gösterimde ×100'e büyüyebiliyor. Ödeme ise sahip olunan tür sayısıyla sınırlı (demoda en fazla ~8). Ekonominin tavan isteğini, karesel patlamaya izin vermeden karşılıyor. 1. maddede önerdiğim "gösterilen zincir ≠ ödenen çarpan" ayrımının iyi bir hâli; bunu benimsiyorum.
- **Riskler:**
  - (a) `kind` her hedefte olmalı, `hanging_steel` plakaları da dahil. Eksik `kind` güvenli bir varsayılana düşmeli; yoksa `null` anahtarı "tek tür" sayılır ya da `int(null)` hatası verir.
  - (b) Tür kümesi (`Dictionary`, PlayerState içinde, host'ta) zincir kırıldığı **her yerde** temizlenmeli: ıska, çerçeve, hat ötesi, pencerenin dolması. Bugün sıfırlama üç ayrı yerde (`game_state.gd:129`, `:239`, `:255`); biri unutulursa tavan kalıcı yüksek kalır. Sıfırlama tek bir yardımcı fonksiyona alınsın.
  - (c) Tek hedefte oynayan oyuncu ×2'de kalır (min(n, 2)). Bu niyet edilen davranış, ama `combo_check` beklentileri değişir.
  - (d) Taret isabetleri bu kümeye dokunmamalı.
  - (e) Yerleştirmede kümelenmiş türler ile SMG taraması tavana hızla ulaşır. Tavan sınırlı olduğu için suistimal değil.

**Görselin Texas Star önerisi: ortalama 3 rad/s ± %25 sinüs (3,7 sn) ve 3+ plaka düşünce dengesizlik salınımı**
- **Hızla ilgili kararla uyumlu:** Ortalama hız korunuyor, faz kilidi zaten ölçümde yoktu. Bu öneri onu kesin olarak bitirir.
- **Risk 1 [K]:** Sinüsün zamanı oyun zamanı olmalı ve `_process`'teki `minf(delta, 0.05)` kısıtı kalkmalı. Aksi hâlde x10'da ya da düşük FPS'te periyot uzar (5. madde).
- **Risk 2, co-op ve asıl önemli olan [K]:**
  - Yıldızın açısı her makinede yerel olarak, kendi `_ready` anından itibaren integre ediliyor. Atışı ise host, **kendi** yıldızına karşı izliyor.
  - Sonradan katılan ya da gecikmeli bir istemcinin gördüğü faz host'unkinden farklı. Oyuncu ekranda plakaya nişan alır, host'ta ıska olur.
  - Sinüs ve dengesizlik salınımı (düşen plakaya ve olayın geliş zamanına bağlı) bu sapmayı büyütür.
  - Çözüm: Açı, host'un yayınladığı ortak bir saatin ve plaka olaylarının deterministik fonksiyonu olsun, ya da host periyodik olarak açıyı göndersin.
- **Aynı sorunun diğer örnekleri [K]:**
  - `plate_rack.gd:117` sonraki plakayı `randi()` ile seçiyor. Her peer farklı plakayı kaldırır ve istemcinin vurduğu plaka host'ta kapalıdır.
  - `popper_target.gd:69` yatma süresini `randf_range` ile seçiyor; ayrışma aynı.
  - Bu rastgele seçimler host'ta yapılmalı ve olay olarak yayılmalı. **Co-op öncesi Y.**

**Görselin "hattın ötesinden vurulan hedef düşmesin" önerisi**
- Benim 4. bulgumla aynı. Uygulama kolay: geçerli isabette `combo ≥ 1`, sayılmayanda `combo == 0` geliyor. Tasarımın yeni formülünde de zincir ≥ 1 kalır.
- **Risk 1:** Mermi düşmeyen poppera çarpar ve şekil açık kalır. Bu doğru davranış. Ama aynı karede gelen ikinci geçerli atış onu düşürür, sorun yok [D✓ aynı-kare testi].
- **Risk 2:** Asılı çelik fiziksel olarak sallanmaya devam etmeli. Yalnızca "tüketen" hedefler (popper, köstebek, yıldız) muaf tutulsun.

### Ortak öneri (düzeltme sırası)

1. **Impacts'i silinmeye ve sinyal sırasına dayanıklı yap** (Y, 25 dk). Havuz girdisi silinmişse yenisi yaratılsın. Texas Star'ın `decal_parent`'ında `_on` filtresi kalksın. Yerleştirme modu ve dükkân kilidi bundan önce gelemez.
2. **`request_fire`'ı sağlamlaştır** (Y, 30 dk).
   - `hit_gold`/`kind` yoksa güvenli varsayılan kullanılsın.
   - Hedef bölgesi kontrolü (`target.x >= 18`) eklensin.
   - Elde taşınan önizleme fizikten çıksın.
   - Co-op gelince `from` host'taki gövde konumundan doğrulansın.
3. **Para çarpanını gösterilen zincirden ayır** (Y, 1-2 sa).
   - Zincir 1,5 sn penceresiyle kalır ve ×100'e büyür.
   - Para `min(zincir, 1 + zincirdeki farklı tür)` ile gelir (tasarımın formülü).
   - `kind` her hedefte olsun, eksikse güvenli varsayılana düşsün.
   - Zincir ve tür kümesinin sıfırlanması tek bir yardımcı fonksiyonda toplansın.
   - Taret, bant ve robot isabetleri ayrı istekle gelsin ve zincire dokunmasın.
   - T `OS.is_debug_build()` arkasına alınsın (global `gold = 0` yapılmasın).
   - Bu madde SMG ve taretten önce bitmeli.
4. **Sayılmayan isabet hedefi tüketmesin** (O, 15 dk). `combo == 0` gelen isabette yalnızca ses ve kıvılcım olsun. Yerleştirme modunda silah insin, B ile hattı geçme kaldırılsın.
5. **Hedef zamanlayıcıları ham `delta` ile sayılsın** (O, 20 dk). x10 hile menüsüyle denge testinden önce; aksi hâlde ölçülen tempo 3,4 kat yanlış çıkar.
6. **Dükkân kilidi** (Y, 3 sa).
   - Kilit `process_mode = DISABLED` + `visible = false` ile yapılsın ve dünya düzeyinde (ortak) tutulsun.
   - `combo_meter` görünürlük kontrolü eklensin.
   - Debug seviye atlama açılmış kilidi geri kapatmasın.
   - `combo_check`'e "kilitli hedef isabet almaz / açılınca alır" assert'i eklensin.
7. **Ucuz ve bağımsız düzeltmeler** (O, 15 dk).
   - Popper, köstebek ve yıldıza `light.tres`/`heavy.tres` bağlansın.
   - `_process`'te taşınan hedef parçalarına `PHYSICS_INTERPOLATION_MODE_OFF` verilsin.
   - CLAUDE.md'deki dummy sesi notu ve dummy konumu düzeltilsin.
8. **Co-op'tan önce hedef durumunu host'tan türet** (Y, 2-3 sa).
   - Yıldızın açısı ortak saatin ve olayların deterministik fonksiyonu olsun. Görselin 3 rad/s ± %25 sinüs ve dengesizlik önerisi bunun üstüne güvenle kurulur.
   - Köstebeğin `randi()` ve popper'ın `randf_range` seçimleri host'ta yapılıp olay olarak yayılsın.
   - Texas Star hızına rezonans gerekçesiyle dokunulmasın; ölçümde suistimal çıkmadı.
