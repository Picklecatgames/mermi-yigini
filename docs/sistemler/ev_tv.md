# Ev ve televizyon

> **Özet (2026-11-06):**
> Kullanıcı kararı (2026-11-05): dağ başındaki adamın evi hissi veren ev; içinde eski tüplü TV'de her gün haberler.
> Ev modeli kullanıcının seçtiği "Post-Apocalyptic | House | Dirty | Old | Wooden" (CC-BY, jenerikte isim zorunlu).
> Yerleşim ve ölçüler (ana oda 6,9 x 10,8 m, yan oda atölye, tek dış kapı) yazarın seçimi, kural değil.
> Tam eski belge: `docs/arsiv/ayrintilar_tam_2026-11-06.md`. Dizin: `docs/sistemler/README.md`.

### Ev ve televizyon (2026-11-05, kullanıcı kararı)

Kullanıcının sözü: "Şimdi evimiz çok kötü olmuş, birkaç odalı ya da tek bir hol olan bir ev yapmak, bulmak lazım, dağ başındaki adamın evi hissi verecek. Ayrıca TV koyacağım, eski bir tüplü TV, her gün haberler olacak; işte bugün virüsün ilk günü, belirtiler şöyle, ses yapmayın, evde kalın falan; her gün TV'ye bakılacak haberler için."

Aşağıdaki yerleşim, ölçü ve metinler benim seçimim, kural değil.

- **Ev (2026-11-05, kullanıcının indirip seçtiği model; "tamam bu evi oyuna doğru şekilde kur, camlarından dışarıyı görebilecek şekilde yap"):** "Post-Apocalyptic | House | Dirty | Old | Wooden" (yadrogames, CC-BY). Daha önce denediğim köy evi, ek kulübe ve serpiştirdiğim eşyalar kullanıcı kararıyla silindi. `tools/build_house.py` modeli `assets/props/house/source/` içinden alır: malzemeleri temel renk dokusuna bağlar, zemin plakasını siler, kapıyı açık durdurur, pencereleri dolduran parçaları siler, yerlerine yarı saydam kirli cam koyar, 1,65 kat büyütür, zemine oturtur. Duvarlar, döşeme ve tavan modelin kendisi; `tools/build_world.gd` `_house` yalnız görünmez çarpışma ekler. `scenes/world.tscn` elle düzenlenmez.
- **Yerleşim (ölçüler benim seçimim):** ana oda 6,9 x 10,8 m, yan oda (atölye) 3,4 x 5,2 m. Tek dış kapı var (güney), odalar arası kapı 1,2 m. İki pencere dağa, biri yan odadan sundurmaya bakar; pencereden yürünemez, atış çarpışması yok.
- **İçinde:** yalnız oyunun gerektirdiği: TV dağ pencerelerinin arasında, tabanca sandığı doğuşların önünde, atölyede tezgâh, pres, huni, radyo. `GameState.MELTER_POS` ve `PRESS_POS` buraya alındı (eskiden salonun koordinatıydı). Her odada bir çıplak ampul. Başka eşya kullanıcı isteyince eklenir.
- **TV etkileşimi:** E yalnız ekranın önünde (yönünden yaklaşık 40° içinde) ve TV'ye bakarken çıkar.
- **TV:** `scripts/tv.gd`, Poly Haven Television_01. Ekran `materials/tv_screen.gdshader`: 160x120 kart, tarama çizgisi, karlanma, kayan bant, yırtılma, 15 bit. Hep açık, gün kartını gösterir; okunurken satır ekranda ve altyazıda.
- **Bültenler:** `data/bultenler.json`, 14 gün; ilk beşi demo için tamam, kalanı taslak. Her biri o günün yeni zombi türünü söyler (`waves.gd` `TYPES` `from`; bir gece bir dalga varsayımıyla), 5. ve 10. gün patron ayını. 1-4 resmî spiker, 5-8 geçici yayıncı ve korsan, 9-10 resmî spiker geri döner ve önceki günleri inkâr eder, 11 kayıt başa sarar, 13 yalnız yazı, 14 yayın kesilir. "Ses yapmayın" havadır, oyunda sesle çekme yok.
- **Co-op:** yeni gün sabah host'ta (`_clock`, `news_day = nights + 1`), `news_changed`. E (`request_watch_news`, 3,2 m içinden) okumayı baştan başlatır; bitene kadar kimse yeniden başlatamaz. Satırları host ilerletir, `news_line`. Ortada katılan o günü ve satırı alır. Altyazı 10 m içindekilere çıkar. Kontrol: `tools/tv_check.gd`.
- **Ses:** spiker kayıtları kullanıcıdan gelecek, liste `docs/tv_ses_listesi.md`. Dosya `assets/sounds/tv/gunGG_SS.ogg` adıyla konunca kendiliğinden çalar.
