# Mermi Yığını — proje bağlamı

Bu dosya, Claude ile yapılan planlama konuşmasının (2026-10-18) özetidir. Claude Code bu klasörde açıldığında dosyayı otomatik okur.

## Oyun fikri

"10 milyon X topla" türünde bir incremental oyun. Ortada 10M–100M mermilik dev bir yığın var. Hedef: yığını bitirmek.

- **Başlangıç:** Yığından elle 1 mermi alınır, tabancaya konur, dummy'ye ateş edilir. Her isabet +1 gold.
- **Upgrade'ler:** taşıma kapasitesi, ateş hızı, gold çarpanı.
- **Silah sırası:** tek atımlık tabanca → 6'lık revolver → Uzi → AK (30'luk).
- **Otomasyon:** taretler, mermi taşıyan bantlar, taşıyıcı robotlar, yeni dummy'ler.
- **Bant modifiyeleri:** Bandın üstüne konan bir karo, oradan geçen mermiyi dönüştürür. Örnek: seken mermi, 2–3 dummy arasında seker.

### Tasarım kuralları

- **Yığın hem hedef hem yakıt.** Ateş edilen her mermi ilerleme sayılır ve gold'a dönüşür.
- **Modifiyeler gold'u çarpar, yığını değil.** Yığına ya da envantere mermi ekleyen mekanik yok. Bölünen mermi serbest: yığından yine 1 mermi düşer, ikinci parça yalnızca ek isabet (gold) demek.
- **Tempo tablosu baştan planlanır.** Örnek: finalde saniyede 50 bin mermi harcanırsa 100M yaklaşık 33 dakikada biter. Oyuncu son saatte yığının gözle görülür şekilde küçüldüğünü görmeli.
- **Orta oyunda oyuncunun aktif bir işi kalmalı:** manuel ateş bonusu, yerleşim optimizasyonu, HP'li zırhlı dummy'ler.
- **Bantlar basit:** grid üzerinde, tek yönlü, splitter yok, oran hesabı yok.
- **Konuşma/ağız animasyonu yok.** İletişim ping ve emote ikonlarıyla.

### Anahtar, kasa, kovan (2026-10-19, Find the Needle'dan uyarlandı)

Referans oyun: Find the Needle (Steam 5160800). Saman yığınında iğne arama; bizde mermi yığınında anahtar.

- **Anahtarlar (yapıldı 2026-10-20):** 10 anahtar (`scripts/key_cache.gd`, sahnede `Keys` düğümü), modeller `assets/props/keys/key_01..10.glb` (`tools/build_keys.py`: 640-2.500 üçgen, sıradan 8 cm, nadir 10 cm, efsanevi 13 cm). Sıra (sıradan → efsanevi): 1 Kapı Anahtarı, 2 Paslı, 3 Kahve Halka, 4 Madalyonlu (sıradan); 5 Pirinç, 6 Kara Baklava, 7 Demir İskelet, 8 Viktorya (nadir); 9 Rulmanlı, 10 Altın Düğüm (efsanevi, ör. minigun). Hangi anahtarın hangi kasayı açtığı kasalarla birlikte belirlenecek.
  - **Gömme:** Her oyunda rastgele konum, ama derinlik sıraya bağlı (`DEPTHS`: sıradan 4-8,5 cm, nadir 45-70 cm, efsanevi 1,6-2,1 m, ±%8). Derin anahtarlar yalnızca yığının kalın olduğu yere düşer, aralarında 1,5 m.
  - **Neden erken bulunamaz:** Yığın 30°'de kaydığı için D derinliğe inmek en az π·D³ m³ kazı ister (`min_bullets`); gerçek yığında tam üstünden kazmak bunun birkaç katı (eğimde çok daha fazla, yukarıdan kayan mermi doldurur). Ölçüm (`tools/keys_check.gd`): sıradan anahtar ~birkaç bin, nadir ~0,2-0,5 milyon, efsanevi milyonlarca mermi. İlk 15 dk elle toplam ~1.500 mermi alınıyor: 10. dakikada minigun fiziksel olarak imkânsız.
  - **Açığa çıkma ve toplama:** Yüzey anahtara inince fırlar, döner, kademe renginde parlar (beyaz/mavi/altın), yüzeyle birlikte iner; üstünden yürüyen alır (`GameState.request_reveal_key/request_take_key`, `key_states`, `PlayerState.keys`). Ekranda bildirim ve sol altta "Anahtarlar: n/10" (HUD anahtar düğümünde; `player.gd`'ye dokunulmadı). Ses yuvaları boş: `reveal_sound`, `take_sound`.
  - **Henüz yok:** tarayıcı (yaklaştıkça sinyal), kasalar ve anahtar-kasa eşleşmesi.
- **Kasalar (güncellendi 2026-10-20):** 6–10 kasa (sayı henüz kesin değil), her anahtara bir kasa, her kasanın bir işlevi var. İçerik: **mermi tipleri** (seken, delici, patlayıcı, yanıcı, tracer), **unique silahlar** (ör. minigun, çok nadir bir anahtarla) ve **özel dummy'ler** (hangileri sonra). Hareket hızı/stamina gibi düz statlar kasadan çıktı. Açılan şey sonra parayla upgrade edilir. Co-op'ta kasayı açan oyuncu o özelliği kendisi için açar.
- **Kullanıcı kararları (2026-10-20):** Raylı dummy ve silüet demodan çıktı (dosyalar duruyor). Kombo yazısı **zincir sayısını** gösterir. Hedefler **ortak kasadan** alınır. **Dummy yıpranması yok**; kurşun izleri kalır, dummy deliklerinden çıkan duman azaltıldı (4 iplik, opaklık 0,2, 1,4 sn). Çelik rafın titremesi kapalı (`shiver = false`).
- **Benzersiz silahlar (2026-10-20):** Satın alınan silah sırasının dışında, yalnızca kasadan çıkan iki silah. **Son silah (12. anahtar, Dişli Anahtar): minigun**, oyunun "delire delire sıkma" finali; yığın gözle görülür hızla erir. bumstrum serisinde aynı kollarla minigun var. Orta oyun silahı 6. anahtardan (Kum Adamı) çıkar, silahın kendisi henüz seçilmedi. 12 anahtar: 4 sıradan, 5 nadir, 3 efsanevi. Tracer mermi tasarımı (mor, hızlı; vurduktan sonra hedefin sağ arkasında ışık olarak belirip tekrar vurur, yankı vuruş sayısı upgrade ağacı) mermi tipleri yapılırken uygulanacak.
- **Kovanlar:** Atılan her mermi kovan bırakır. Kovan toplanır, **fırında eritilir, metal külçe** olur. Külçe taret geliştirme ve yapı malzemesi. İlk 1–1,5 saatte ana para dolar (dummy isabeti); taret açmak dolarla, taret geliştirmek külçeyle.
- **Atış becerisi (yapıldı):** Zayıf nokta = `weak_spot` grubundaki çarpışma şekli (dummy'nin kafası), ×2, altın renkli "+$" ve hit marker. Kombo zinciri: önceki isabetten sonraki 1,5 sn (`COMBO_WINDOW`) içinde gelen her para veren isabet zinciri 1 artırır; ekrandaki xN zincirdir (taramalıda x100'e çıkabilir). **Ödenen çarpan = min(zincir, 1 + zincirdeki farklı hedef türü)** (`combo_pay`, hedeflerin `kind`'ı; en fazla tür sayısı + 1): yalnız dummy ×2'de takılır, her yeni tür tavanı 1 açar. "Neden başka hedefe vurulsun" sorusunun cevabı bu. Süre dolarsa ya da ıska olursa zincir ve tür kümesi sıfırlanır (`_break_chain`). Taret/bant/robot zinciri büyütmeyecek. Görsel (`scripts/combo_meter.gd`): dummy'nin kafasının yanında "x5" yazısı ve altında 1,5 sn'de boşalan cam bar; yazı bar boşaldıkça solar. Her isabette yazı sıçrar; boyutu logaritmik büyür (x2'de 30 px, x100'de ~57 px), rengi beyazdan altına, sonra kırmızıya döner. Kontrol: `tools/combo_check.gd` (headless).
- **Oyun kritiği (2026-10-19):** Dört ajanın (ekonomi, tasarım, görsel, QA) iki turluk incelemesi ve uzlaştıkları öneriler: `docs/oyun_kritigi_2026-10-19.md` (ayrıntılar `docs/ajan_kritik/`). Uygulananlar (2026-10-20): kombo çeşit tavanı, ödemeler, sessiz hedeflere ses, QA hataları (efekt havuzu silinen hedefe dayanıklı, yıldızda iz doğru plakada, `hit_gold`'u olmayan hedef çökertmez, hattın ötesindeki hedef de şart, sayılmayan isabet popper/köstebek/yıldızı tüketmez, hedef zamanlayıcıları gerçek saatle sayar, T yalnız debug build'de ve kapatınca şarjörü eski hâline döndürür). Kalanlar: dükkân kilitleri, yerleştirme modu, his/görünürlük, co-op'ta hedef durumunun host'tan gelmesi.
- **Atış hattı (2026-10-19):** Bütün hedefler arka (doğu) duvar boyunca dizili, önlerinde x = 14'te duvardan duvara sarı çelik korkuluk (`tools/build_arena.gd` `_firing_line`). Korkuluğun çarpışması yalnız `FENCE_LAYER` (4) katmanında: oyuncuyu durdurur, mermiler geçer. Oyuncu korkuluğu yalnız **yerleştirme modunda** geçer (şimdilik **B**, HUD'da "YERLEŞTİRME MODU"; inşa modu gelince oradan açılacak). Mod öbür tarafta kapanırsa oyuncu geri çıkabilir ama giremez. Suistimale karşı: `FIRING_LINE_X`'in ötesinden atılan mermi para ve kombo vermez (host `request_fire`'da namlu konumuna bakar). Doğu duvarındaki beton bariyerler kaldırıldı. Dizilim (güneyden kuzeye, hepsi -X'e bakar): raylı dummy z 15–20, gong 10, silüet 5, dummy 0, popper'lar -5/-7, sallanan raf -11,5, köstebek rafı -16,5, Texas Star -21,5 (yıldız ~2 sn'de bir tur).
- **Hedef çeşitleri:** Hepsi `main.tscn` içinde `LockedTargets` altında; ses/animasyon denemesi için **şimdilik açık** (kilitlemek: düğüme `visible = false` + `process_mode = 4`). Neden vurulacakları ve hangi sırayla açılacakları henüz tasarlanmadı (öneri: dummy yıpranır, hedefler Q menüsünde parayla sırayla açılır); konumlar geçici. Para veren her şey `target` grubunda, kendi `hit_gold`'u var. **Ödeme kuralı: küçük, hareketli ve zamanlı hedef daha çok verir** (ekonomi ajanının simülasyonuyla): dummy $1 (kafa ×2), gong $2, sallanan çelik raf $4 (`hanging_steel.gd`), popper $3 (kafa ×2), köstebek plaka rafı $7 (`UP_MIN` 0,9 sn), Texas Star $12. Sesler: popper heavy, köstebek ve yıldız light (`assets/props/steel_targets/sounds/`). HP'li zırhlı dummy, patlayan varil taretle birlikte gelecek.
  - **Shooting Target Set** (HippoStance) hedefleri `tools/build_targets.py` (Blender) ile parça parça `assets/props/targets/*.gltf` olarak ayrıldı (ortak 2K dokular `textures/`, pivotlar sanatçınınki; gongun diski ve zincirleri bölgeyle kesildi). Ortak yardımcılar `scripts/target_kit.gd`: hareketli parçaya convex çarpışma, ayağa trimesh (vurulursa kıvılcım, para yok, kombo bozulur), menteşe dönüşü. Hepsi +Z'ye bakar.
  - **Popper** (`scenes/popper_target.tscn`): vurulunca geriye yatar, düşerken isabet almaz, 2–3,5 sn sonra yaylanarak kalkar; yuvarlak kafası zayıf nokta (`is_weak(at)`).
  - **Köstebek plaka rafı** (`scenes/plate_rack.tscn`): 6 plaka yatık, sırayla biri kalkar (aynısı üst üste gelmez). Vurulursa çarparak düşer, sıradaki 0,3 sn sonra gelir ve her isabet kalkık kalma süresini %8 kısaltır (1,6 → 0,75 sn). Kaçırılan plaka yavaşça iner, tempo sıfırlanır.
  - **Texas Star** (`scenes/texas_star.tscn`): yıldız saat yönünde, gerçekten nişan aldıracak hızda döner (~2 sn'de bir tur). Vurulan plaka koparak yere düşer, yıldız bir an hızlanır, plaka 1,5 sn sonra yerinde büyüyerek geri gelir (her plaka kendi sayacıyla).
  - Ses yuvaları boş: popper ve raf `hit_sound` + `rise_sound`, yıldız `hit_sound` + `reset_sound`. Kontrol: `tools/combo_check.gd`.
  - Setteki kullanılmayanlar (sonra): kâğıt hedef (halka bölgeli ödeme için), rehine çeliği (yanlış yere ceza), düello ağacı, dönen plaka rafı, statik çelikler; ayrıca kovan toplayıcı, süpürge, faraş ve atış masaları (2. aşama için, zip'te).
- **Otomasyon:** Şarjör dolduran robot kol, taşıyıcı drone, jeneratör yarıçapı (kablo yok), kovan süpürgesi, sipariş tahtası.
- **His:** Çığ (dipten kazınca mermi saçılır), kilometre taşları (90M/50M/10M/1M), co-op'ta son mermi töreni, yığın bitince daha büyüğü (tam oyun).
- **Alınmayanlar:** Ürün zinciri, kablolama, 300'lük tech tree, idle ağırlık.

## Kararlar

- **Motor:** Godot 4
- **Tür:** **3D FPS.** Kullanıcının kararı; ilk öneri olan 2D top-down reddedildi.
- **Co-op:** 4 kişilik
- **Ekip:** 2 kişi, her biri ayrı bir Claude hesabı kullanıyor
- **Hedef:** Oynanabilir, yaklaşık 1 saatlik demo
- **Tahmini süre (tam zamana yakın çalışmayla):** tek kişilik demo 6–8 hafta, co-op dahil 9–12 hafta

## Teknik yaklaşım

- **Mermiler mantıkta yalnızca bir sayı** (`pile -= 1`). Ekranda temsilî tracer'lar gösterilir; çizim için `MultiMeshInstance3D` ve pooling kullanılır. Mermi başına node ya da fizik yok.
- **Yığın görseli:** Hacmi kalan sayıya göre küçülen tek bir mesh.
- **Viewmodel (güncellendi 2026-10-18):** Eldivenli kollar + hazır animasyonlu silah; bumstrum (DJMaesen) Sketchfab serisi (tabanca, revolver, SMG, AK, minigun aynı kollarla). Her modelin tek bir `allanims` klibi var; `scripts/viewmodel.gd` bunu `play_section` ile bölümler halinde oynatır (fire, reload, fire_last, reload_empty, draw, inspect). Modelin idle klibi **kullanılmaz** (fazla hızlı sallanıyor); bölümler dinlenme pozunda biter, üstüne kodla yavaş nefes, sway ve bob eklenir. Namlu alevi, duman, kovan (havuzlanmış `RigidBody3D`, katman 1), sesler ve kamera tepmesi koddadır. Viewmodel `SubViewport` içinde ayrı kamerayla, render katmanı 2'de çizilir; duvara girmez. Eldiven dokusu modelin el dokusuna script'le boyandı (3. şahıs karakterin eldiven rengi): `arms_gloved_*.png`.
- **3. şahıs karakter:** bumstrum "3rd person model" (`assets/characters/operator/`, iskeletli, animasyonsuz). FP kollarıyla aynı eldiven ve kazak; FP'de kol deri ceket, 3. şahısta kazak (küçük fark, şimdilik kabul).
- **Ses:** Kullanıcı gerçek sesleri kendisi bulup verecek; kodla ses üretilmez. `assets/weapons/heavy_pistol/sounds/` içindekiler Freesound'dan gerçek kayıtlar; ffmpeg ile kesilip mono yapıldı, EQ ve seviye ayarlandı. Yankı dosyada değil, `default_bus_layout.tres` içindeki "Dunya" bus'ının reverb'ünde; Master'da -1 dB limiter var.
- **İnşa modu:** Satisfactory tarzı; raycast ile yerleştirme, saydam önizleme, döndürme.
- **Ses:** `AudioStreamRandomizer` kullanılır ve aynı anda çalan ses sayısı sınırlanır (`max_polyphony`). Taret sayısı arttığında tekil atış sesleri sürekli bir "fabrika uğultusuna" geçer.
- **Co-op mimarisi (ilk günden kurulur):**
  - Tüm durum tek bir `GameState` autoload'unda tutulur.
  - Oyuncunun her eylemi bir komut fonksiyonudur (`request_buy_upgrade(id)`, `request_place_belt(pos)`). Tek kişilik modda komut doğrudan çalışır, co-op'ta host'a gider.
  - Host otoriterdir: durumu yalnızca host değiştirir.
  - Ağdan yalnızca sayılar, pozisyonlar, nişan yönü, durum (`idle/walking/reloading/shooting`) ve olaylar gönderilir. Mermi görselleri ve animasyonlar her makinede yerel oynatılır.
  - Steam bağlantısı için GodotSteam kullanılır. Host göçü yapılmaz.
  - **Ekonomi:** Yığın ve dünya ortak, gold kişisel. `GameState` oyuncu başına `PlayerState` tutar (el, şarjör, gold, upgrade'ler, peer id ile); istekler isteğe bağlı `peer` alır (0 = yerel). `fired(peer, from, dir)` herkese gider; yerel atışın efekti tahminle anında oynar, başkalarınınki dünyada oynatılacak. Büyük yapılar için ortak bir kasa var.
- **Hile/hızlandırma menüsü:** x10 hız, gold ekleme, aşama atlama. Denge testi için şart.
- **Ekonomi (2026-10-19):** Para birimi dolar (yeşil `$`). Dummy isabeti $1, ıska $0. Ateş hızı **upgrade değil**, sabit 0,42 sn (sürgü döngüsü ve tepme yayı tam oturuyor); tetik basılı tutulunca bu hızla atar. Tabancanın tek upgrade'i **Kapasite** 1→7 (ağır tabancanın şarjörü 7): hem eldeki hem şarjördeki mermi; fiyatlar $8/20/45/90/160/280. Q upgrade ekranı (`scripts/upgrade_menu.gd`), G mermi fırlatma. Atışı host izler (`request_fire` ışın atar), sonucu `shot_landed` olayıyla yayar; dummy tepkisi, isabet efektleri (`scripts/impacts.gd`) ve hit marker bunu dinler.
- **Dummy:** `scenes/dummy.tscn`, Level 1 dummy, poligonda (23, 0, 0), atış hattının arkasında, doğu duvarı önünde. Kaide sabit, gövde yaylı direkte sallanır (Blender'da ikiye bölündü, dokular 2K'ya indirildi). İsabet: sallanma/dönme, beyaz parlama, sıkışma, çuval tozu + saman, kumaşta delik (gövdeyle sallanır), "+$1" yazısı, delikten 3,5 sn tüten duman. İsabet sesi: `assets/props/dummy/sounds/hit.tres`, 6 vuruştan 18 varyantlı `AudioStreamRandomizer`. Varyantlar yalnızca EQ ile ayrışır (doğal, koyu, parlak; bas +2–4 dB, lowpass 4,5–8 kHz kırpılma sertliğini yumuşatır). **Perde kaydırma ve kompresör kullanılmaz**, bozuyordu; randomizer perdesi yalnızca ±%2, ses ±1,5 dB. `HitSound` +2 dB, `unit_size` 14. Kaynak kayıt ağır clip'li (vuruş başına ~60 ms düz tepe); daha temiz ses için düşük kazançla yeniden kayıt gerekir. Kontrol: `tools/hit_sound_check.gd` (headless).
- **Çelik hedefler (2026-10-19):** `scenes/steel_rack.tscn` (5 küçük plaka, light ses), `steel_gong.tscn` ve `steel_silhouette.tscn` (heavy ses); hepsi `scripts/hanging_steel.gd`. Her plaka menteşesinde sarkaç: vuruş itkisi × menteşeye kol uzunluğu açısal hız ekler (alçak vuruş daha çok savurur, silüetin kafası ters yöne), merkez dışı vuruş burar, açı sınırsız (hafif plaka art arda vurulunca çubuğun üstünden takla atar). Ayar: `plate_mass`, `kick`, `twist`. Çerçeve trimesh çarpışmalı, kıvılcım verir. Kontrol: `tools/steel_check.tscn` (headless sahne olarak; autoload gerekir). Eski kodla çizilen `steel_plate.gd` silindi. Karton silüet ve kutular, sesleri gelince eklenecek.
- **Çelik raf (düzeltme):** Raf plakaları kaynaklı menteşe gibi yalnız ileri geri döner (`steel_rack.tscn` içinde `twist = 0`). Kirişin ortasındaki kelepçe 3. plakanın askısının içinden geçiyordu; plaka 7 cm yana kaydırıldı (`build_steel_targets.py` içinde `NUDGE`, glb'ye de uygulandı).
- **Kurşun izleri (2026-10-19):** Yumuşak gradyan lekeler yerine çizilmiş izler: beton (koyu çukur, kırık açık halka, kılcal çatlaklar, toz halesi), çuval (yırtık delik, kavrulmuş halka), çelik (gri kurşun diski, koyu merkez, ince sıçrama çizgileri, damlacıklar). Her yüzey için 4 varyant, rastgele seçilip döndürülür. `tools/draw_bullet_marks.gd` çizip `materials/env/decals/bullet_mark_<tür>_<varyant>.png` olarak kaydeder (çalışma anında çizmek 1,2 sn sürüyordu); `impacts.gd` yükler. Boyut: beton 9 cm, çuval 6,5 cm, çelik 12 cm.
- **Duman (2026-10-19):** Hedef referans **sigara dumanı** gibi ince, kıvrılan iplik. Reddedilenler: billboard puf parçacıkları, gürültü shader'ı, hazır flipbook (Unity Labs) ve Blender Mantaflow simülasyonu (zaman yiyor). Kullanılan yöntem, oyunlarda standart olan **şerit (trail) parçacıkları**: `scenes/smoke_trail.tscn` (`GPUParticles3D` + `RibbonTrailMesh` çapraz şerit, türbülans etkisi ömre göre artar, ölçek ömre göre büyür) + `materials/trail_smoke.gdshader` (kesitte yumuşak Gauss, boyunca gürültüyle parçalanma, uçlarda solma). Namlu tütmesi (`Wisp`, referans: tabancadan yükselen çok iplikli, yarı saydam olgun duman) **dünya koordinatında**: silah sallanınca iplikler geride kalıp kıvrılır, 36 ince şerit, 3,5 sn'de söner. Dummy deliği: ışın gövde mesh'ine (`TriangleMesh`, `dummy.cloth_hit`) yeniden atılır, duman tam kumaştaki delikten, 8 kıl inceliğinde soluk iplik, 2,5 sn (yanık kumaş tütmesi, ateş değil). Havuzlu emitter'larda `interpolate = false` + `restart()`: yoksa delikten deliğe atlarken arada duman bırakıyordu. Atış başına ayrıca alev, kıvılcım ve barut tanecikleri. Mermi izi: `materials/bullet_trail.gdshader`. Ölü dosyalar (silinemedi, kullanılmıyor): `scripts/smoke_sprite.gd`, `materials/flipbook_smoke.gdshader`, `assets/vfx/smoke/`.
- **Nişan alma (2026-10-20):** Sağ tık basılıyken (`aim` eylemi) 0,18 sn'de nişangaha geçer, bırakınca çıkar. Arka gez çentiği ve arpacık tepesi mesh'ten okundu (`REAR_SIGHT`, `FRONT_SIGHT`); silah, bu çizgi kameranın bakış eksenine (ekran ortası, atışın gittiği yer) oturacak ve gez yatay kalacak şekilde döndürülüp konur, gez gözden 22 cm (`ADS_EYE`). Yalnız dinlenme pozunda (boşta, atış) olur; şarjör değişimi ve çekişte düşer, basılı tutuluyorsa sonra geri gelir. Görüş ×1,25 yakınlaşır, fare hassasiyeti aynı oranda düşer, crosshair söner, koşu kapanır; sallanma/bob/nefes %20, tepme %70. Kontrol: `tools/ads_check.gd` (headless; her klip sonunda nişangah eksenden en fazla 0,17 mm sapıyor).
- **Test modu:** **T** sınırsız mermi (`GameState.infinite_ammo`), HUD'da "SINIRSIZ MERMİ" yazar.
- **Ekip çalışması:** Her `.tscn` sahnesinin tek bir sahibi olur, git çakışmasını önlemek için.
- **Commit mesajları:** Türkçe, birinci tekil şahıs, samimi insan ağzıyla; ne fark edildi, ne yapıldı. Örnek: "Mermiler çok fazla gold kazandırıyordu, çarpanı yarıya indirdim." Robotik "Add X / Fix Y" kalıbı kullanılmaz. `Co-Authored-By: Claude` ve benzeri AI imza satırları **eklenmez** (commit ve PR açıklamalarında).

## Plan

**Güncel sıra (2026-10-20): `docs/yol_haritasi.md`.** Fazlar halinde, adım adım gidilir; aşağıdaki haftalık plan ilk taslaktır.

1. **1. hafta:** Çekirdek döngü (yığın, tabanca, dummy, gold, 5–6 upgrade, `GameState` ve komut yapısı). **Haftanın sonunda "eğlenceli mi?" testi.**
2. Silahlar, reload ve his (juice), ilk taret.
3. Bantlar, robot taşıyıcı, 1 modifiye (seken mermi), 2–3 dummy türü.
4. 60 dakikalık denge, UI, kayıt, ses, sanat geçişi.
5. Tek kişilik demoyu dışarıdan 3–5 kişiye oynatma, ardından co-op ve Steam.

## Seçilen ve aday asetler

**Güncelleme (2026-10-18):** Low-poly set **kullanılmayacak**; hedef daha gerçekçi görünüm (PBR). Aşağıdaki liste yalnızca referans. Beton zemin: `materials/concrete.tres` (Poly Haven taraması, world-space shader, 4 m plaka derzleri; her plakada doku rastgele kaydırılıp döndürülür).

**Kullanılan asetler (jenerikte isim verilecekler):**
- `assets/bullet/bullet_9mm.glb`: "Bullet 9 mm", Y2JHBK, CC-BY-4.0, https://sketchfab.com/3d-models/bullet-9-mm-4cc75b7ef1bc474392c319a47fd97348
- `materials/concrete/`: "Concrete Floor Worn 001", Poly Haven (Dimitrios Savva, Rico Cilliers), CC0, https://polyhaven.com/a/concrete_floor_worn_001
- `assets/weapons/heavy_pistol/`: "heavy pistol animated", DJMaesen (bumstrum), CC-BY-4.0, https://sketchfab.com/3d-models/heavy-pistol-animated-b7c78c533ced40cd986c44594b778ed6 (el dokusuna eldiven boyandı)
- `assets/bullet/bullets_3x/`: "Bullets 3x", firstAttempt, Sketchfab Standard lisansı, https://sketchfab.com/3d-models/bullets-3x-88552c9cd6c24481bd566661fc146834 (atılan kovan: `.45` boş kovan, `assets/bullet/shell_45.res`)
- `assets/weapons/heavy_pistol/sounds/shot.wav`: kullanıcının kendi kaydı (`projeler/ses/ateş.wav`); kesilmiş tepeleri `adeclip` ile onarıldı
- `assets/weapons/heavy_pistol/sounds/mag_*.wav`: "Pistol Reload", HunterOfTheMist, CC-BY-4.0, https://freesound.org/s/846695/ (kesik tepe onarıldı, mono; çıkarma, yuvaya girme ve oturma olarak üçe bölündü; `MagSound` silahın sağ altında, `panning_strength` 2,5)
- `assets/weapons/heavy_pistol/sounds/slide_*.wav`: "Glock19_reload.wav", fr3yr, CC-BY-3.0, https://freesound.org/s/100804/
- `assets/props/dummy/sounds/hit_*.wav`: kullanıcının kendi kaydı (`projeler/ses/dummy1 hit.wav`); ağır clipping onarıldı, 6 vuruşa bölündü
- `assets/weapons/heavy_pistol/sounds/dry.wav`: "Trigger with hammer fall.wav", nanashi, CC0, https://freesound.org/s/104412/
- `assets/weapons/heavy_pistol/sounds/shell_*.wav`: "Object_Bullet_Shell_Concrete.wav", Nox_Sound, CC0, https://freesound.org/s/490309/
- `assets/env/`: Poly Haven (CC0, isim zorunlu değil): concrete_slab_wall, corrugated_iron_02, metal_plate_02 dokuları; hanging_industrial_lamp, concrete_road_barrier, Barrel_01, wooden_crate_01, steel_frame_shelves_01, ammo_box, old_military_crate, industrial_storage_cart, cardboard_box_01, portable_generator, metal_jerrycan, plastic_crate_03, Barrel_02, korean_fire_extinguisher_01, WetFloorSign_01, modular_chainlink_fence modelleri; gravel_floor_02, dry_ground_01 dış zemin dokuları; kloofendal_48d_partly_cloudy_puresky HDRI
- `assets/characters/operator/`: "3rd person model", DJMaesen (bumstrum), CC-BY-4.0, https://sketchfab.com/3d-models/3rd-person-model-0634f275b68747b79f6f2925a8c26a0f
- `assets/props/steel_targets/`: "Steel Targets Pack", linx_567, CC-BY-4.0, https://sketchfab.com/3d-models/steel-targets-pack-9ef775068616406aa38bf431e58db342 (`tools/build_steel_targets.py` ile 3 montaja bölündü, ×0,5 ölçek, dokular 1K)
- `assets/props/steel_targets/sounds/`: kullanıcının verdiği `light.mp3` ve `heavy.mp3` (kaynak/lisans henüz yazılmadı); yalnızca kesildi, mono, seviye; rastgele perde ±%2
- `assets/props/keys/` (hepsi CC-BY-4.0, ayrıntı `licenses.txt`): "Door Key", GUIBEL; "Keys", aruspice (4 anahtar); "key", yomans; "Key", eucocker; "Key", caior; "Medieval Gold Key", KneeKnow; "Victorian Key", cnseto (Sketchfab; üçgen sayısı indirildi, dokular küçültüldü)
- `assets/props/targets/`: "Shooting Target Set", HippoStance, CC-BY-4.0, https://sketchfab.com/3d-models/shooting-target-set-ba8282fc05e044a187f556ef14c3ee26 (hedeflere ayrıldı, dokular 2K)
- `assets/props/keys/key_NN.glb` (hepsi Sketchfab, CC-BY-4.0; `tools/build_keys.py`, numara yaygından nadire, `scripts/key_cache.gd` sırası; 6. anahtar orta oyun silahını, 12. minigun'u açar; önizleme `docs/keys_lineup.png`):
  - 01 "Door Key", GUIBEL, https://sketchfab.com/3d-models/door-key-6538a6a21f5545e0b1dcf22bee5741a1
  - 02, 04, 05, 07 "Keys", aruspice, https://sketchfab.com/3d-models/keys-16d847c5b8f24bcfb8cb32ab8ff8cebd (4 anahtarlık paket, ayrıldı)
  - 03 "key", yomans, https://sketchfab.com/3d-models/key-dccd0d629d704cc2bde905572b0947da
  - 06 "Sandman key", Blascool, https://sketchfab.com/3d-models/sandman-key-b592e9af729d4ea49ef658433b7253af
  - 08 "Key", eucocker, https://sketchfab.com/3d-models/key-bedeea90f698425f93ee7d15c284d24b
  - 09 "Victorian Key", cnseto, https://sketchfab.com/3d-models/victorian-key-8260e2b3b9314b9aa7ef4002398ace2a
  - 10 "Key", caior, https://sketchfab.com/3d-models/key-7a0f6aaffe604d65bb560955990ce68b
  - 11 "Medieval Gold Key", KneeKnow, https://sketchfab.com/3d-models/medieval-gold-key-64b9661b76e84a769a5e7dd432f535bc
  - 12 "Old key", luizgu3d, https://sketchfab.com/3d-models/old-key-088dd8b9507243759fc2dee4812d91f7
- `assets/props/dummy/`: "Medieval Combat Dummy", CaptainHC, CC-BY-4.0, https://sketchfab.com/3d-models/medieval-combat-dummy-0b3ab64360374a0e9ee3a5923c437995 (kaide/gövde ayrıldı, ölçeklendi, dokular 2K)
- `assets/vfx/smoke/`: Unity Labs "Free VFX image sequences and flipbooks" (CandleSmoke01, WispySmoke03), CC0, https://unity.com/blog/engine-platform/free-vfx-image-sequences-flipbooks. Aynı sette 26 duman/ateş/patlama flipbook'u daha var.

**Ortam (2026-10-19):** `scenes/arena.tscn`, `tools/build_arena.gd` ile üretilir (elle düzenleme; betiği değiştirip yeniden çalıştır). Parça mesh'leri `tools/build_shed_meshes.py` (Blender 5.2, arka planda) üretir: her kenar pahlı + weighted normal, jilet kenar yok. Açık yanlı sanayi sundurması: 4 m prefabrik beton panel (her panele bir döküm plakası), H kolonlar 7 m arayla, 56 m açıklıklı Pratt kafes kirişler, aşıklar, 6° eğimli oluklu çatı, süt beyazı ışıklık şeritleri, alınlık kaplaması, 35 sarkıt lamba (SpotLight, gölgesiz). Işık: HDRI gökyüzü, güneş yönü HDRI'daki güneş pikselinden hesaplanır, SDFGI + SSIL + SSAO + hacimsel sis + glow, AgX. Viewmodel kamerasının ortam kopyasında SDFGI/sis/glow kapalı. Sundurmanın etrafı: çakıl avlu, 44 m'de tel örgü çit (MultiMesh, gölgesiz), ötesi kuru arazi (`materials/ground.gdshader`, tekrar kırıcı karışım), mesafe sisi. Yerde aşınmış sarı boya (yığın çevresinde halka, duvar boyu yürüyüş çizgileri, 4 doğma kutusu) ve yağ lekeleri: script'le çizilen decal dokuları (`materials/env/decals/`, silinirse yeniden çizilir). Tek ReflectionProbe (bir kez yakalanır). 4 co-op doğma noktası: `spawn` grubundaki Marker3D'ler.
**Akıcılık ve performans (2026-10-19):** Fizik interpolasyonu açık. Oyuncunun kafası `top_level`; her karede interpolasyonlu gövde konumu + fare bakışıyla yerleştirilir (60 Hz fizik yüksek Hz ekranda titretmez). Kamera tepmesi kritik sönümlü yay. Viewmodel SubViewport'u `own_world_3d` (silah sesleri o dünyada çaldığı için `audio_listener_enable_3d = true` şart, yoksa ateş/şarjör sesleri susar): güneş gölgesi iki kez çizilmiyor; silah dünyasında gölgesiz güneş kopyası, oyuncu gölgedeyken (ışın testi) söner; namlu alevi dünyayı ayrı bir OmniLight ile aydınlatır. Yığın ve dökülen mermiler 140 üçgenlik `bullet_9mm_lod.glb` kullanır (`tools/build_bullet_lod.py`, orijinal 1.600); eldeki mermi orijinal. Ele uçan mermiler havuzlu. Yığın shader'ı bir önceki fizik adımının yükseklik dokusuyla şimdikini interpolasyon kesriyle karıştırır; kaymalar 60 Hz basamakla değil akarak görünür.
**Mekan:** 56×56 m poligon, 4 m prefabrik beton duvar; duvarların iç yüzü 4 m plaka derzine oturur. Ortada yığın: 100M mermi ≈ 380 m³ → 30° koni, r ≈ 8.6 m, h ≈ 4.9 m (`scripts/pile.gd`). Yığın gerçek bir yükseklik alanı: her alım alındığı noktadan hacim çıkarır, 30°'yi aşan eğim kayar. Alımlar `request_take_bullets(count, at)` ile yapılır; co-op'ta ağdan yalnızca `bullets_taken(at, count)` olayı gider. Yığındaki mermiler tek tip, yalnızca sayı; sekme/hasar/gold çarpanı gibi özellikler mermi yığından alındıktan sonra (şarjör, bant) tip olarak taşınır.

Eski öneri (low-poly, toplam yaklaşık 20 $):

- **Silahlar:** [Chilly Durango Low Poly Firearms](https://chilly-durango.itch.io/low-poly-firearms)
  - CC0, revolver, 1911, UZI ve AK dahil 16 silah, sürgü ve şarjör ayrı parça
  - `.blend` formatında; Blender'dan GLB olarak dışa aktarılacak
  - Çok düşük poligonlu (AK 270 üçgen), retro görünüm
- **Alternatif silahlar:**
  - [JustCreate3D Low Poly FPS Weapons Pack](https://justcreate3d.itch.io/low-poly-fps-weapons-pack): 9,99 $, FBX ve GLB, parçalar ayrı
  - [Low Poly Animated Weapons](https://arms-dealer.itch.io/lowpolyweapons): 29 $, animasyonlu, lisansı belirsiz
- **Karakterler:** [Quaternius Universal Base Characters](https://quaternius.itch.io/universal-base-characters) (CC0)
- **Animasyonlar:** [Quaternius Universal Animation Library](https://quaternius.itch.io/universal-animation-library), [Animation Library 2](https://quaternius.itch.io/universal-animation-library-2), [Mixamo](https://www.mixamo.com)
- **Bantlar:** [Kenney Conveyor Kit](https://kenney-assets.itch.io/conveyor-kit) (CC0)
- **Taretler:** [Sci-Fi Gun Turret Set x4 (CGTrader)](https://www.cgtrader.com/3d-models/military/gun/sci-fi-gun-turret-set-x4-game-ready-pbr-low-poly), [Modular Turrets Pack (Fab)](https://www.fab.com/listings/00ee214e-3a05-4279-a5a9-45843148ac07)
- **Dummy:** [Practice Dummy (CGTrader)](https://www.cgtrader.com/3d-models/various/various-models/practice-dummy-pbr-game-ready), 5 $, GLB
- **Ses:** [Sonniss GDC Bundle](https://sonniss.com/gameaudiogdc)
- **Godot başlangıç kodu (MIT):** [Simple FPS Weapon System](https://github.com/Jeh3no/Godot-Simple-FPS-Weapon-System-Asset), [chafmere Godot4-FPS-Template](https://github.com/chafmere/Godot4-FPS-Template)

### Aset kuralları

- **Lisans:** CC0 tercih edilir. CC-BY ise jenerikte isim verilir. NC ve ND lisanslar ile "personal use only" asetler kullanılmaz.
- **Format:** Yalnızca Unreal'a özel (`.uasset`) paketler alınmaz; FBX, GLB ya da glTF aranır.
- **Lyra kaynaklı sesler kullanılmaz,** çünkü Unreal'a özel lisanslıdır.
- **Poligon:** Silah başına 50 binin altında.
- **İsimler:** Gerçek silah marka isimleri (Glock vb.) ve logolar kullanılmaz; genel isimler tercih edilir.

## Araçlar

- **Açık:** godot, disciplines, context7, ponytail, session-report, i-have-adhd (yanıtı eylemle başlatır, adımları numaralar; `/i-have-adhd`) plugin'leri; godot MCP (yerel); **Beckett MCP** (editör eklentisi, `addons/beckett`; yalnızca Godot editörü açıkken çalışır, oyunu editör içinde çalıştırıp ekran görüntüsü alır — Godot'u ayrı pencerede açan `run_project` yerine bunu kullan; `.mcp.json` gizli token içerir, git'e girmez); `.claude/agents/` içinde 8 agent (Godot, tasarım, QA). Graphify, superpowers, caveman ve watch/video kapalı.
- **Kural:** Bir görev kapalı bir araca ihtiyaç duyarsa (video analizi, sprite üretimi vb.) o aracı kullanmaya çalışma. Hangi aracın neden gerektiğini ve nasıl açılacağını söyle.
- **Kural:** Çoklu agent, büyük klasör taraması ya da uzun süren bir işten önce maliyetini söyleyip onay iste.
