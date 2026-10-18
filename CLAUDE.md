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
- **Modifiyeler gold'u çarpar, yığını değil.** Mermiyi yoktan var eden (bölünen mermi gibi) mekanik yok.
- **Tempo tablosu baştan planlanır.** Örnek: finalde saniyede 50 bin mermi harcanırsa 100M yaklaşık 33 dakikada biter. Oyuncu son saatte yığının gözle görülür şekilde küçüldüğünü görmeli.
- **Orta oyunda oyuncunun aktif bir işi kalmalı:** manuel ateş bonusu, yerleşim optimizasyonu, HP'li zırhlı dummy'ler.
- **Bantlar basit:** grid üzerinde, tek yönlü, splitter yok, oran hesabı yok.
- **Konuşma/ağız animasyonu yok.** İletişim ping ve emote ikonlarıyla.

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
- **Viewmodel:** Demoda **kol yok**, silah havada durur. Geri tepme, sürgü, kovan, namlu alevi, şarjör değiştirme, sallanma (bob/sway) ve silah değiştirme hareketleri kodla (`Tween`) yapılır ve parçacık sistemleriyle desteklenir. Viewmodel ayrı bir kamera katmanında çizilir, böylece duvarın içine girmez.
- **İnşa modu:** Satisfactory tarzı; raycast ile yerleştirme, saydam önizleme, döndürme.
- **Ses:** `AudioStreamRandomizer` kullanılır ve aynı anda çalan ses sayısı sınırlanır (`max_polyphony`). Taret sayısı arttığında tekil atış sesleri sürekli bir "fabrika uğultusuna" geçer.
- **Co-op mimarisi (ilk günden kurulur):**
  - Tüm durum tek bir `GameState` autoload'unda tutulur.
  - Oyuncunun her eylemi bir komut fonksiyonudur (`request_buy_upgrade(id)`, `request_place_belt(pos)`). Tek kişilik modda komut doğrudan çalışır, co-op'ta host'a gider.
  - Host otoriterdir: durumu yalnızca host değiştirir.
  - Ağdan yalnızca sayılar, pozisyonlar, nişan yönü, durum (`idle/walking/reloading/shooting`) ve olaylar gönderilir. Mermi görselleri ve animasyonlar her makinede yerel oynatılır.
  - Steam bağlantısı için GodotSteam kullanılır. Host göçü yapılmaz.
  - **Ekonomi:** Yığın ve dünya ortak, gold kişisel. Büyük yapılar için ortak bir kasa var.
- **Hile/hızlandırma menüsü:** x10 hız, gold ekleme, aşama atlama. Denge testi için şart.
- **Ekip çalışması:** Her `.tscn` sahnesinin tek bir sahibi olur, git çakışmasını önlemek için.
- **Commit mesajları:** Türkçe, birinci tekil şahıs, samimi insan ağzıyla; ne fark edildi, ne yapıldı. Örnek: "Mermiler çok fazla gold kazandırıyordu, çarpanı yarıya indirdim." Robotik "Add X / Fix Y" kalıbı kullanılmaz. `Co-Authored-By: Claude` ve benzeri AI imza satırları **eklenmez** (commit ve PR açıklamalarında).

## Plan

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
