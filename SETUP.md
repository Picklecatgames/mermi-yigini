# Claude Code kurulumu (ikinci hesap / ekip arkadaşı)

## Önce bilin

Plugin'ler, skill'ler ve MCP ayarları **hesaba değil bilgisayara** kayıtlıdır (`~/.claude`). Aynı bilgisayarda hesap değiştirirseniz hepsi zaten kurulu gelir. Bu listeyi yalnızca **başka bir bilgisayarda** uygulayın.

## Kurulacaklar

Komutları Claude Code içinde sırayla yazın.

### 1. Godot skill'leri (şart)

GDScript, sahneler, fizik, multiplayer, shader ve export için Godot 4.x rehberleri. Yalnızca ilgili konu açıldığında yüklenir, bu yüzden kota maliyeti düşük.

```
/plugin marketplace add gamedev-skills/awesome-gamedev-agent-skills
/plugin install godot@awesome-gamedev-agent-skills
```

### 2. Context7 (şart)

Güncel Godot ve GodotSteam dokümantasyonu sağlar. Claude'un eski API'ye göre kod yazmasını önler.

```
/plugin install context7@claude-plugins-official
```

### 3. Ponytail (önerilir)

Claude'u gereksiz kod ve soyutlama yazmamaya zorlar. Daha kısa kod, daha az token.

```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail
```

### 4. Godot MCP (önerilir)

Claude oyunu kendisi çalıştırabilir ve hata çıktısını okuyabilir; böylece "çalıştır, hatayı kopyala, yapıştır" döngüsü ortadan kalkar. Kaynak: https://github.com/Coding-Solo/godot-mcp

Bunu normal bir terminalde (Claude Code'un dışında) çalıştırın, Godot yolunu kendi sisteminize göre düzeltin:

```
claude mcp add godot -e GODOT_PATH="C:/Godot/Godot_v4.x-stable_win64.exe" -- npx @coding-solo/godot-mcp
```

Node.js kurulu olmalı.

### 4b. i-have-adhd (önerilir)

Yanıtları eylemle başlatır, adımları numaralar, laf kalabalığını keser. Proje ayarlarında zaten açık; sadece marketplace'i ekleyin:

```
/plugin marketplace add ayghri/i-have-adhd
/plugin install i-have-adhd@i-have-adhd
```

### 5. PixelLab MCP (isteğe bağlı)

Sprite, ikon ve VFX üretimi için. Ayrı bir PixelLab aboneliği ve API anahtarı gerekir. Kurulum: https://pixellab.ai

### 6. Agent paketleri (seçerek kurun)

- **Claude Code Game Studios** (Donchitos, MIT): yaklaşık 48 oyun geliştirme agent'ı (tasarımcı, QA, godot-specialist vb.). `/plugin marketplace add Donchitos/claude-code-game-studios`
- **VoltAgent awesome-claude-code-subagents**: 150'den fazla agent, kategori başına ayrı plugin. **Yalnızca ihtiyaç duyduğunuz kategoriyi kurun.**

Her kurulu agent'ın açıklaması her oturumda bağlama yüklenir. Kullanılan her agent da sıfırdan başlayıp yeniden bağlam okur. 150 agent kurmak daha iyi kod demek değil, daha hızlı biten kota demek.

### 7. Test

- **GUT (Godot Unit Test)** ile ekonomi, upgrade ve `GameState` mantığı test edilir. Testler `godot --headless` ile çalışır; kurulu Godot skill'lerindeki `godot-gdscript-headless-testing` bunu anlatır.
- **Denge simülasyonu:** 60 dakikalık oyunu saniyeler içinde simüle eden headless bir script. Bir incremental oyun için en değerli "test agent'ı" budur.
- **Godot MCP** (madde 4): Claude oyunu çalıştırıp hata çıktısını okur.
- **Beckett MCP:** Claude oyunun ekran görüntüsünü görebilir; otomatik playtest özelliği ücretli sürümde.

## Kurmayın ya da kapalı tutun

- **graphify:** Bu kullanıcıda GDScript projesinde haftalık kotanın yaklaşık %35'ini tek seferde yaktı.
- **superpowers:** Uzun talimatlar yükler, kotayı hızlı tüketir.
- **watch / video plugin'leri:** Yalnızca video analizi gerektiğinde açın.
- **caveman:** Yanıtları çok kısaltır. Tasarım tartışmalarında ve Türkçe açıklamalarda zarar verebilir. Kendi ölçümlerine göre bile toplam tasarruf oturum başına yaklaşık %4–15.

## Kota tasarrufu: plugin'den daha etkili alışkanlıklar

1. **Her yeni görevde `/clear`.** Uzun sohbet geçmişi, her mesajda yeniden okunur ve en büyük gizli maliyettir.
2. **Model seçimi:** Rutin kod işleri için Sonnet, mimari kararlar ve zor hatalar için Opus.
3. **`CLAUDE.md`'yi kısa tutun.** Her oturumda baştan okunur. Bu dosya (`SETUP.md`) bu yüzden ayrı tutuldu.
4. **Dosyayı adıyla isteyin.** "`player.gd`'deki ateş fonksiyonuna bak" demek, "projeyi incele" demekten çok daha ucuzdur.
5. **Büyük klasörleri okumaya kapatın.** `.claude/settings.json` içinde `.godot/` önbelleği ve 3D/ses dosyaları zaten engellendi.
6. **Çoklu agent ve büyük taramalardan önce düşünün.** Gerekirse önce kota maliyetini sorun.
