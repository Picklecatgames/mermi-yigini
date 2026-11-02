# Açık alan ve atölye aset adayları (2026-11-02)

Açık arazi zemini ve önü açık, çatılı atölye için taranan asetler. **✔** işlenip projeye girdi, **○** aday olarak kaldı.
İşlenenler metre ölçeğinde, orijini tabanın ortasında, gerekenlerde `-convcolonly` dışbükey çarpışmalı `.gltf` (aynı setin parçaları dokuyu `doku_<set>/` klasöründen ortak okur).
Üçgen sayısı: işlenmiş / kaynak. Boyut: en × boy (yükseklik) × derinlik, m.

Yeniden üretmek: `tools/atolye/` (`fetch.py` indirir, `jobs.py` iş dosyalarını yazar, `process.py` Blender'da işler, `parts.py` kendi parçalarım, `tex.py` dokular ve HDRI). Görsel kontrol: `tools/atolye_shot.gd` (ekran dışı çekim, ölçü ve çarpışma sayısını da yazar).

## 1. Zemin ve arazi

### Zemin dokuları → `assets/env/acik_alan/dokular/<ad>/` (2K, `_diff`, `_nor_gl`, `_arm`; yanında dünya üçdüzlemli `ORMMaterial3D` `.tres`)

| | Ad | Kaynak | Lisans | Neden |
|---|---|---|---|---|
| ✔ | `dry_ground_rocks` | Poly Haven https://polyhaven.com/a/dry_ground_rocks | CC0 | Taşlı kuru toprak, ana arazi için en nötr seçenek |
| ✔ | `brown_mud_dry` | Poly Haven https://polyhaven.com/a/brown_mud_dry | CC0 | Kurumuş çamur, üs çevresi ve yol izleri |
| ✔ | `burned_ground_01` | Poly Haven https://polyhaven.com/a/burned_ground_01 | CC0 | Kül ve yanık toprak; ateş varilleri, savaş izleri |
| ✔ | `road_damaged` | Poly Haven https://polyhaven.com/a/road_damaged | CC0 | Çatlak, yamalı asfalt; eski yol şeritleri |
| ✔ | `gravelly_sand` | Poly Haven https://polyhaven.com/a/gravelly_sand | CC0 | Çakıllı kum, ikinci karışım katmanı |
| ✔ | `worn_concrete_floor` | Poly Haven https://polyhaven.com/a/worn_concrete_floor | CC0 | Atölye beton levhası |
| ✔ | `worn_corrugated_iron` | Poly Haven https://polyhaven.com/a/worn_corrugated_iron | CC0 | Düz düzleme oluklu sac görüntüsü (uzak çatılar, çit) |
| ✔ | `ground110` | ambientCG https://ambientcg.com/a/Ground110 | CC0 | Kuru kahverengi toprak, tekrarı az belli |
| ✔ | `asphalt026c` | ambientCG https://ambientcg.com/a/Asphalt026C | CC0 | Kırık asfalt, `road_damaged`'den daha bozuk |
| ✔ | `rubber004` | ambientCG https://ambientcg.com/a/Rubber004 | CC0 | Atölye kauçuk paspası |
| ○ | `mud_cracked_dry_03`, `dry_mud_field_001`, `rocky_gravel`, `gravel_ground_01` | Poly Haven | CC0 | Yedek: çatlak çamur ve çakıl |
| ○ | `Ground109`, `Ground105`, `Gravel023`, `Road015C` | ambientCG | CC0 | Yedek toprak, çakıl, çatlak yol |

Not: tek başına 3 m'de tekrar edince `dry_ground_rocks`'ta uzakta bant görünüyor; zeminde iki doku gürültüyle karıştırılırsa ya da büyük ölçekli renk dokusu üstüne binerse gizlenir.

### Gökyüzü → `assets/env/hdri/` (yalnız gök, yer yok)

| | Dosya | Kaynak | Lisans | Ne için |
|---|---|---|---|---|
| ✔ | `kloofendal_48d_partly_cloudy_puresky_4k.hdr` | https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky (Greg Zaal, Jarod Guest) | CC0 | Gündüz, parçalı bulutlu, sert güneş |
| ✔ | `mud_road_puresky_2k.hdr` | https://polyhaven.com/a/mud_road_puresky (Sergey Rudavin, Jarod Guest) | CC0 | Kapalı, kasvetli gündüz |
| ✔ | `wasteland_clouds_puresky_4k.hdr` | https://polyhaven.com/a/wasteland_clouds_puresky (Sergej Majboroda, Jarod Guest) | CC0 | Gün batımı, gece öncesi |
| ✔ | `kloppenheim_02_puresky_4k.hdr` | https://polyhaven.com/a/kloppenheim_02_puresky (Greg Zaal, Jarod Guest) | CC0 | Açık, yıldızlı gece |
| ✔ | `qwantani_moonrise_puresky_2k.hdr` | https://polyhaven.com/a/qwantani_moonrise_puresky (Greg Zaal, Jarod Guest) | CC0 | Ay doğarken gece |
| ○ | `industrial_sunset_02_puresky`, `qwantani_dusk_2_puresky`, `qwantani_night_puresky`, `kloofendal_overcast_puresky` | Poly Haven | CC0 | Yedek |
| – | `rogland_clear_night_4k.hdr` | zaten projede | CC0 | Gece |

### Kayalar → `assets/env/acik_alan/kayalar/`

| | Ad | Kaynak | Lisans | Üçgen | Boyut | Neden |
|---|---|---|---|---|---|---|
| ✔ | `kaya_buyuk` | Poly Haven namaqualand_boulder_04 | CC0 | 6.000 / 59.066 | 2,52 × 1,90 × 2,50 | Kuru, kızıl tarama kaya; ufka ve üs kenarına |
| ✔ | `kaya_yassi` | Poly Haven namaqualand_boulder_02 | CC0 | 5.000 / 97.964 | 2,52 × 0,88 × 1,23 | Alçak, üstünden bakılan kaya |
| ✔ | `kaya_kucuk` | Poly Haven namaqualand_boulder_05 | CC0 | 3.000 / 89.618 | 1,36 × 0,53 × 0,74 | Serpiştirmelik |
| ✔ | `kaya_sivri` | Poly Haven rock_07 (1,6 m'ye büyütüldü) | CC0 | 4.000 / 14.844 | 0,84 × 0,72 × 1,60 | Taş yığını gibi duran küme |
| ○ | namaqualand_boulder_03/06, namaqualand_rocks_01, moon_rock_02/03 | Poly Haven | CC0 | 6–200 bin | | Yedek |

### Bitkiler → `assets/env/acik_alan/bitkiler/` (çalı ve dallarda çarpışma yok, içinden geçilir)

| | Ad | Kaynak | Lisans | Üçgen | Boyut | Neden |
|---|---|---|---|---|---|---|
| ✔ | `devrik_kutuk` | Poly Haven dead_tree_trunk_02 | CC0 | 8.000 / 83.128 | 4,05 × 1,06 × 1,05 | Yere devrilmiş kuru gövde |
| ✔ | `olu_govde` | Poly Haven dead_quiver_trunk | CC0 | 6.000 / 17.978 | 0,31 × 2,00 × 0,27 | Ayakta kurumuş gövde, ufukta direk gibi |
| ✔ | `kutuk` | Poly Haven tree_stump_01 | CC0 | 6.000 / 41.046 | 1,42 × 0,57 × 1,59 | Kesik kütük |
| ✔ | `kuru_dal_a/b/c` | Poly Haven dry_branches_medium_01 | CC0 | 3.000'er | 0,8–1,3 m | Yere düşmüş kuru dal |
| ✔ | `kuru_cali_a…e` | Poly Haven wild_rooibos_bush (beşe bölündü, yaprak alfalı) | CC0 | 1.193–8.000 | 0,3–0,7 m | Koyu, kurumuş çalı |
| ○ | quiver_tree_02, othonna_cerarioides, searsia_lucida | Poly Haven | CC0 | 150 bin–1,4 M | | Canlı görünüyor, ağır |
| ○ | Tumbleweed (biggreenorange), Tumbleweed 5 (Doctor Jana) | Sketchfab | CC-BY 4.0 | 2–3 bin | | Çok stilize, gerçekçi PBR'a uymuyor |

### Ufuk siluetleri → `assets/env/acik_alan/ufuk/`

| | Ad | Kaynak | Lisans | Üçgen | Neden |
|---|---|---|---|---|---|
| SF | Ruined buildings pack | tobiasherbers https://sketchfab.com/3d-models/690edb7d64b84df7bfeee3b54746d6eb | CC-BY 4.0 | 85.578 (set) | Sisli uzak plan için yıkık bina siluetleri |
| SF | Telephone Poles | Caboose3d https://sketchfab.com/3d-models/a76b68b838424a89b7db8a38f4c3d546 | CC-BY 4.0 | 5.316 (set) | Ufka uzanan eğri telefon direkleri |
| SF | Abandoned Garage Block Rusty Ruined | olegolegperepelica https://sketchfab.com/3d-models/a1959927a98e4752bdb01b6e1f7f7d26 | CC-BY 4.0 | 8.369 | Yıkık tuğla garajlar, orta plan |
| ○ | Ruin Building | nermin https://sketchfab.com/3d-models/184d70cc473540749206cc7d8f9917b8 | CC-BY 4.0 | 33.384 | Roblox için yapılmış, yedek |
| ○ | Electric pole | DJMaesen https://sketchfab.com/3d-models/19be5e32d7a44fcf8c6eb4f83e17bd25 | CC-BY 4.0 | 1.718 | Tek direk, yedek |
| ○ | modular_electricity_poles, concrete_road_barrier_02 | Poly Haven | CC0 | 200 bin / 42 bin | Ağır ama CC0; yedek |

## 1b. Çöl wasteland (2026-11-02 kararı: atölye ve çevresi beton, dışarısı Mad Max tarzı seyrek ağaçlı çöl)

### Çöl ve beton dokuları → `assets/env/acik_alan/dokular/`

| | Ad | Kaynak | Lisans | Neden |
|---|---|---|---|---|
| ✔ | `ground097` | ambientCG https://ambientcg.com/a/Ground097 | CC0 | Sıcak renkli, rüzgâr dalgalı çöl kumu; kum tepelerinin dokusu |
| ✔ | `ground096a` | ambientCG https://ambientcg.com/a/Ground096A | CC0 | Açık renkli dalgalı kum |
| ✔ | `red_sand` | Poly Haven https://polyhaven.com/a/red_sand | CC0 | Kızıl çöl kumu |
| ✔ | `sandy_gravel_02` | Poly Haven https://polyhaven.com/a/sandy_gravel_02 | CC0 | Sıcak, düz kumlu toprak; kumla toprak arası geçiş |
| ✔ | `mud_cracked_dry_03` | Poly Haven https://polyhaven.com/a/mud_cracked_dry_03 | CC0 | Kurumuş, iri çatlaklı açık toprak |
| ✔ | `mud_cracked_dry_riverbed_002` | Poly Haven https://polyhaven.com/a/mud_cracked_dry_riverbed_002 | CC0 | Kurumuş dere yatağı, koyu ince çatlaklar |
| ✔ | `sandstone_cracks` | Poly Haven https://polyhaven.com/a/sandstone_cracks | CC0 | Sarı, çatlak sert toprak |
| ✔ | `cracked_concrete` | Poly Haven https://polyhaven.com/a/cracked_concrete | CC0 | Belirgin çatlaklı dış mekân betonu |
| ✔ | `concrete_floor_damaged_01` | Poly Haven https://polyhaven.com/a/concrete_floor_damaged_01 | CC0 | Lekeli, yamalı, 5 m'lik büyük levha |
| ✔ | `concrete_floor_02` | Poly Haven https://polyhaven.com/a/concrete_floor_02 | CC0 | Lekeli, aşınmış beton |
| ✔ | `damaged_concrete_floor_02` | Poly Haven https://polyhaven.com/a/damaged_concrete_floor_02 | CC0 | Koyu, kirli beton; atölyenin altı |
| ○ | `aerial_sand`, `coast_sand_04`, `cracked_red_ground`, `dry_mud_field_001`, `concrete_floor_worn_001`, `concrete_panels`, `damaged_concrete_floor` | Poly Haven | CC0 | Yedek |
| ○ | Ground096B, Ground093C, Ground095A | ambientCG | CC0 | Yedek kum |

### Çöl gökyüzü → `assets/env/hdri/`

| | Dosya | Kaynak | Lisans | Ne için |
|---|---|---|---|---|
| ✔ | `quarry_01_puresky_4k.hdr` | https://polyhaven.com/a/quarry_01_puresky (Sergej Majboroda, Jarod Guest) | CC0 | Açık, sıcak gün batımı |
| ✔ | `mpumalanga_veld_puresky_4k.hdr` | https://polyhaven.com/a/mpumalanga_veld_puresky (Greg Zaal, Jarod Guest) | CC0 | Bozkırda açık gün batımı |
| ✔ | `lonely_road_afternoon_puresky_4k.hdr` | https://polyhaven.com/a/lonely_road_afternoon_puresky (Dimitrios Savva, Jarod Guest) | CC0 | Sıcak öğleden sonra |
| ✔ | `qwantani_dusk_2_puresky_2k.hdr` | https://polyhaven.com/a/qwantani_dusk_2_puresky (Greg Zaal, Jarod Guest) | CC0 | Puslu alacakaranlık |
| ○ | `syferfontein_1d_clear_puresky`, `drakensberg_solitary_mountain_puresky`, `industrial_sunset_02_puresky` | Poly Haven | CC0 | Yedek |

Pure-sky HDRI'larda toz yok; tozlu hava sis ve hacim sisiyle verilmeli. En puslu olanlar `qwantani_dusk_2` ve `mud_road`.

### Kum tepeleri ve büyük kayalar → `assets/env/acik_alan/kum_tepeleri/`, `kayalar/`

| | Ad | Kaynak | Lisans | Üçgen | Boyut | Neden |
|---|---|---|---|---|---|---|
| ✔ | `kum_tepesi_kucuk/orta/buyuk/uzun` | kendi modelim (`wasteland.py`), doku Ground097 | CC0 | 10.368–18.432 | 24×2,5×18 – 80×10×60 m | Barkan biçimi: rüzgâr yüzü yatık, arkası dik, iki yana boynuzlu; kenarlar 5 cm yere gömülü |
| ✔ | `kaya_sirti_20m` | Poly Haven namaqualand_cliff_02 | CC0 | 16.000 / 194.080 | 20,2 × 7,2 × 6,6 | Ufukta kaya sırtı |
| ✔ | `kaya_kumesi_8m` | Poly Haven namaqualand_cliff_01 | CC0 | 12.000 / 94.369 | 8,3 × 5,0 × 4,4 | Üst üste binmiş kaya kümesi |
| ✔ | `kaya_yuksek` | Poly Haven namaqualand_boulder_03 | CC0 | 6.000 / 64.826 | 2,4 × 1,5 × 3,1 | |
| ✔ | `kaya_orta` | Poly Haven namaqualand_boulder_06 | CC0 | 3.000 / 109.114 | 0,7 × 0,65 × 1,2 | |

### Mad Max hurdası → `assets/env/acik_alan/yiginlar/`, `enkaz/`

| | Ad | Kaynak | Lisans | Üçgen | Boyut | Neden |
|---|---|---|---|---|---|---|
| ✔ | `varil_yesil`, `varil_pasli`, `varil_boyali` | kendi modelim (`wasteland.py`), dokular Poly Haven green_metal_rust, rust_coarse_01, rusty_painted_metal | CC0 | 768 | Ø 0,61 × 0,88 | 200 litrelik, çemberli, hafif ezik paslı varil (projedekiler mavi ve temiz) |
| ✔ | `varil_yigini`, `varil_sirasi` | aynı variller | CC0 | 3.840 / 2.304 | | Üst üste ve yatık variller |
| ✔ | `lastik_kulesi`, `lastik_yigini` | Poly Haven old_tyre (projede), dizilim benim | CC0 | 14.400 / 23.040 | | Beşli lastik kulesi; yayvan yığın ve yaslanmış lastik |
| SF | Abandoned Generic Sedan 1 / 2 | Rashad Ibrahimli https://sketchfab.com/3d-models/6a2169dafc254f399387a679305bb1bf, https://sketchfab.com/3d-models/db2df46c49f9441286c84c66208ef7ac | CC-BY 4.0 | 9.597 / 16.487 | | Markasız, paslı, tekerleksiz sedan enkazı |
| SF | Dead Trees Demo | Quadra3D https://sketchfab.com/3d-models/9bdd36641ef541adb51f0d01ddb07b2c | CC-BY 4.0 | 232.924 (40 ağaç) | | Seyrek ölü ağaçlar; birkaçı seçilip bölünecek |
| SF | Old tree | evolveduk https://sketchfab.com/3d-models/3cb4d59eb4844dc4802480e9ee53785e | CC-BY 4.0 | 8.107 | | Kurumuş yaşlı ağaç |
| SF | Desert tree Skeleton | iGauravRajput https://sketchfab.com/3d-models/b47825ecb8a049d78be9bd07f49a7d5d | CC-BY 4.0 | 1,3 M → 15 bin | | Çöl ağacı iskeleti |
| ○ | Old Rusty Yellow Cabriolet | PolarNick239 | CC-BY 4.0 | 832.970 | | Tarama, çok ağır, üstünde grafiti |
| ○ | PSX Dead Tree Pack, Dead Tree - PS1 | FlunkedPunk, Wersaus33 | CC-BY 4.0 | | | PS1 tarzı, gerçekçi değil |
| – | covered_car, rusted_wheel_rim_01/02, old_tyre | projede `assets/env/models/` | CC0 | | | Brandalı araba, jant, lastik |

## 2. Atölye yapısı → `assets/props/atolye/yapi/`

| | Ad | Kaynak | Lisans | Üçgen | Boyut | Neden |
|---|---|---|---|---|---|---|
| ✔ | `ahsap_direk_3m` | kendi modelim (`parts.py`), doku Poly Haven fine_grained_wood | CC0 | 12 | 0,12 × 3,00 × 0,12 | Çizimdeki dört direk |
| ✔ | `ahsap_kiris_4m`, `ahsap_asik_4m` | aynı | CC0 | 12 | 4 m; 8×16 ve 6×8 cm | Direk üstü kiriş ve çatı aşığı |
| ✔ | `celik_direk_3m` | kendi modelim, doku Poly Haven rusty_metal_02 | CC0 | 36 | 10 cm kare profil, taban/tepe plakalı | Çelik seçenek |
| ✔ | `celik_kare_profil_4m` | aynı | CC0 | 12 | 8 cm kare profil | Çelik kiriş/aşık |
| ✔ | `oluklu_sac_pasli_2x1m`, `_pasli_3x1m`, `_yesil_2x1m`, `_galvaniz_2x1m` | kendi modelim, dokular Poly Haven rust_coarse_01, green_metal_rust, rusty_metal_02 | CC0 | 416 | 76 mm adım, 18 mm dalga | Tek eğimli çatı sacları, gerçek dalga geometrisi |
| ✔ | `sac_cit_a/b/c` | kendi modelim (`wasteland.py`), dört pas dokusu + ahşap direk | CC0 | 7.800–9.100 | 2,9–3,7 × 2,3–2,6 m | Hurdadan çit: iki direğe dikilmiş, üst üste binen, eğri, her biri başka paslı sac |
| ✔ | `oluk_2m` | kendi modelim, doku rusty_metal_02 | CC0 | 84 | Ø 13 cm yarım boru | Çatı kenarı yağmur oluğu |
| ✔ | `palet` | kendi modelim, doku fine_grained_wood | CC0 | 204 | 1,20 × 0,144 × 0,80 (EUR) | Atölye zemini, istif |
| SF | Rusted corrugated panels | Sousinho https://sketchfab.com/3d-models/ea06568a9e304ecc806cb7cb0552e269 | CC-BY 4.0 | 6.732 (3 panel) | | Kırmızı, paslı, yeşil eğri büküntülü sac; hurdadan yama çatı ve duvar |
| SF | Construction steel beam | Cyril Demetrius https://sketchfab.com/3d-models/33f84d01ec834d8c98c39ee7251f8ff4 | CC-BY 4.0 | 25.956 → 2.500 | 4 m | Perçinli paslı H kiriş |
| SF | Wooden Pallets | YadroGames https://sketchfab.com/3d-models/dba5c00928cd400796d9f6fffdd724b3 | CC-BY 4.0 | 384 | | Taranmış görünümlü iki palet |
| ○ | Corrugated Metal Sheet Type 1/2/3 | Mareon | CC-BY 4.0 | 440–2.920 | | Temiz boyalı, pas yok |
| ○ | Worn Shed PBR | donnichols https://sketchfab.com/3d-models/be6edd62e55a4f9a99da940fc164a5b9 | CC-BY 4.0 | 2.086 | | Bütün ev; parça değil |
| ○ | Steelbeam | jkvarel | CC-BY 4.0 | 164 | | Dokusu zayıf |
| ○ | Rolled military tarp | Krisdian Hristov | CC-BY 4.0 | 8.450 | | Rulo branda, süs |
| – | `assets/env/shed/` (kolon, makas, aşık, çatı sacı) | projede, `tools/build_shed_meshes.py` | | | | Çelik hangar kiti hâlâ kullanılabilir |

## 3. Atölye içi → `assets/props/atolye/ic/`

| | Ad | Kaynak | Lisans | Üçgen | Boyut | Neden |
|---|---|---|---|---|---|---|
| ✔ | `cekmeceli_tezgah` | Poly Haven WoodenTable_03 | CC0 | 2.298 | 1,33 × 0,83 × 0,58 | Çekmeceli, metal köşeli ahşap tezgâh |
| ✔ | `tekerlekli_dolap` | Poly Haven industrial_storage_cart | CC0 | 8.000 / 18.902 | 1,60 × 1,38 × 1,10 | Yeşil boyalı, tekerlekli çelik dolap-tezgâh |
| ✔ | `mengene` | Poly Haven bench_vice_01 | CC0 | 2.863 | 0,20 × 0,29 × 0,40 | Tezgâh mengenesi |
| ✔ | `celik_raf` | Poly Haven steel_frame_shelves_02 | CC0 | 4.348 | 0,59 × 2,14 × 0,50 | Ahşap raflı çelik dikme |
| ✔ | `kaynak_arabasi` | Poly Haven portable_welding_cart | CC0 | 10.000 / 29.418 | 0,84 × 1,56 × 0,65 | Oksi-asetilen tüplü kaynak arabası |
| ✔ | `kompresor` | Poly Haven old_military_compressor | CC0 | 12.000 / 79.042 | 0,60 × 1,18 × 1,67 | Eski kompresör, jeneratör yanına |
| ✔ | `tup` | Poly Haven propane_tank | CC0 | 5.238 | 0,34 × 0,55 × 0,34 | Gaz tüpü |
| ✔ | `varil_kirmizi` | Poly Haven Barrel_01 | CC0 | 2.682 | 0,56 × 0,88 × 0,56 | Patlayıcı işaretli kırmızı varil |
| ✔ | `yag_tenekesi` | Poly Haven oil_tin | CC0 | 2.834 | 0,12 × 0,21 × 0,15 | Yağ tenekesi |
| ✔ | `yaglik` | Poly Haven small_oil_can_01 | CC0 | 4.000 / 16.746 | 0,27 × 0,24 × 0,10 | Uzun ağızlı yağdanlık |
| ✔ | `tabure` | Poly Haven metal_stool_02 | CC0 | 5.000 / 6.532 | 0,45 × 0,46 × 0,47 | Atölye taburesi |
| ✔ | `duvar_projektoru` | Poly Haven security_light | CC0 | 4.668 | 0,32 × 0,53 × 0,42 | Direğe vidalı projektör |
| ✔ | `el_projektoru` | Poly Haven portable_searchlight | CC0 | 6.000 / 18.802 | 0,17 × 0,19 × 0,25 | Masaya konan el feneri |
| ✔ | `boru_lamba` | Poly Haven industrial_pipe_lamp | CC0 | 8.000 / 8.626 | 0,18 × 0,36 × 0,26 | Borudan masa lambası |
| ✔ | `kablo_*` (7 parça) | Poly Haven modular_electric_cables | CC0 | 332–3.330 | | Direk boyunca giden kablo, priz, şalter, buat |
| SF | Old Work Bench | Oliver Triplett https://sketchfab.com/3d-models/9fbc30ba31a546fe9370e6de2dcc0707 | CC-BY 4.0 | 24.890 | | Ahşap tezgâh, delikli pano, takım dolabı, aletler |
| SF | Workbench | JJ Chalupnik https://sketchfab.com/3d-models/9634d6a81a494925a909512c8048f446 | CC-BY 4.0 | 8.335 | | Uzun çelik tezgâh, pano, takım çekmecesi |
| SF | Tool Storage Board | Sousinho https://sketchfab.com/3d-models/a298746adb5946b997cc19618cb110e5 | CC-BY 4.0 | 24 | | Paslı delikli takım panosu (doku ile) |
| SF | Industrial Work Light | denis_cliofas https://sketchfab.com/3d-models/ff0abe17dc64498191bb41c905d00ab0 | CC-BY 4.0 | 18.998 | | Sarı tripodlu çift projektör |
| SF | Flood light 02 | Chamod1999 https://sketchfab.com/3d-models/95ad365a60434015a8700efbdaa90893 | CC-BY 4.0 | 2.790 | | Hafif tripodlu projektör |
| SF | Cable Spool | wolfgar74 https://sketchfab.com/3d-models/22ddb8e02f944fb7b5662f14fdc50e5e | CC-BY 4.0 | 1.664 | | Ahşap kablo makarası (masa da olur) |
| SF | Anvil-Vise Combo | Steven Janes https://sketchfab.com/3d-models/2cc3a34bdd7f48799474878334673116 | CC-BY 4.0 | 6.414 | | Kütük üstünde örs-mengene |
| ○ | Repair / Modification Bench | Smokahontas | CC-BY 4.0 | 15.243 | | Yedek tezgâh |
| ○ | Workbench | Heroinfather https://sketchfab.com/3d-models/9903d3f3a9c94c478cca7eee8ba9e6ab | CC-BY 4.0 | 8.708 | | Yedek tezgâh |
| ○ | Workbench | Bársh | CC-BY 4.0 | 56.474 | | Garaj dioraması, ağır |
| ○ | Construction Site Light | Mark Peters | CC-BY 4.0 | 30.616 | | Yedek ışık |
| ○ | Cable reels | Lassi Kaukonen | CC-BY 4.0 | 330.628 | | Tarama, çok ağır |
| ○ | Industrial Asset Pack | vmatthew | CC-BY 4.0 | 22.658 | | Varil, tüp, teneke; Poly Haven karşılıkları yetti |
| ○ | PBR Anvil | NOT_Lonely | CC-BY 4.0 | 642 | | Yedek örs |
| – | portable_generator, metal_tool_chest, tool_cart, steel_frame_shelves_01, worn_metal_rack, Barrel_02, barrel_03, metal_jerrycan, power_box_01, twin_spot_light, hanging_industrial_lamp, caged_hanging_light, wooden_crate_01, old_military_crate | projede `assets/env/models/` | CC0 | | | Jeneratör, takım dolabı, raf, varil, bidon, sandık, lamba zaten var |

**SF** satırları: seçildi ama Sketchfab indirme ucu bu oturum boyunca 429 (çok istek) döndürdü; durumları aşağıda.
