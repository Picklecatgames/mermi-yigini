# TV spiker kayıtları

Kodla ses üretilmez; kayıtlar gelene kadar TV altyazı ve ekranla çalışır. Dosyalar `assets/sounds/tv/` altına `gunGG_SS.ogg` adıyla konur (GG gün, SS satır, iki haneli). `scripts/tv.gd` dosya varsa satır başladığında çalar, yoksa sessiz geçer; başka bir şey değiştirmek gerekmez. Metnin kaynağı `data/bultenler.json`. Satır ekranda en az 3,2 sn kalır; uzun kayıt gelirse `GameState.news_line_secs` kayıt süresine bağlanır.

## Sesler

- **A, resmî spiker:** yetişkin, düz, duygusuz, bülten okur gibi. Hiçbir şey olmamış gibi. 1-4, 9, 10. günler.
- **B, geçici yayıncı:** başka biri, spiker değil, kâğıttan okuyor. Yorgun, arada duraksar. 5-8, 12. günler. 8. günden sonra kendi sözleri.
- **C:** A'nın 1. gün kaydının aynısı, başa sarıyor. 11. günün 1, 2 ve 4. satırı `gun01_01`, `gun01_02`, `gun01_01` kopyası; 3. satır araya giren B.
- 13. ve 14. gün yalnız yazı, ses yok.

## Ortam sesleri (spikerden ayrı)

| Dosya | Ne | Süre |
|---|---|---|
| `assets/sounds/tv/tup_ugultu.ogg` | Tüplü TV'nin ince yüksek uğultusu, döngü | 20+ sn |
| `assets/sounds/tv/karincalanma.ogg` | Kanal boşken beyaz gürültü, döngü (14. gün ve sonrası) | 20+ sn |
| `assets/sounds/tv/kesinti.ogg` | Yayın kesilme çıtırtısı (5. ve 14. gün başı) | 1-2 sn |

Bu üçü için kod henüz yok; kayıtlar gelince `scripts/tv.gd`'ye bağlanır.

## Satırlar

Toplam 51 satır; demo için ilk beş gün yeter.


### 1. gün, A, resmî spiker
| Dosya | Metin |
|---|---|
| `gun01_01.ogg` | İyi günler. Sağlık Bakanlığı'nın bildirisini okuyorum. |
| `gun01_02.ogg` | Bugün yeni bir virüsün ilk günüdür. |
| `gun01_03.ogg` | Belirtiler: ateş, burun kanaması, ışığa bakamama. |
| `gun01_04.ogg` | Hastalar karanlık çöktükten sonra ağaçlık alanlardan çıkmaktadır. |
| `gun01_05.ogg` | Hastayı yalnız başına isabet durdurur. |
| `gun01_06.ogg` | Ses yapmayın. Evinizde kalın. |
| `gun01_07.ogg` | Bir sonraki bildiri yarın sabah okunacaktır. |

### 2. gün, A, resmî spiker
| Dosya | Metin |
|---|---|
| `gun02_01.ogg` | İyi günler. Durum kontrol altındadır. |
| `gun02_02.ogg` | Bazı hastaların koştuğu bildirilmiştir. |
| `gun02_03.ogg` | Koşan hastalar yürüyenlerden önce ulaşır. |
| `gun02_04.ogg` | Bu gece kapıya sırtınızı dönmeyin. |
| `gun02_05.ogg` | Yiyeceklerinizi saymanız önerilir. Paniğe gerek yoktur. |

### 3. gün, A, resmî spiker
| Dosya | Metin |
|---|---|
| `gun03_01.ogg` | İyi günler. Dünkü bildiri düzeltilmiştir. |
| `gun03_02.ogg` | Koşan hasta yoktur. Koşanlar hasta değildir. |
| `gun03_03.ogg` | Yerde sürünen kişilere yardım etmeyin. |
| `gun03_04.ogg` | Sürünenler göz hizasında görünmez. Yere bakın. |
| `gun03_05.ogg` | Sokağa çıkma yasağı devam etmektedir. |

### 4. gün, A, resmî spiker
| Dosya | Metin |
|---|---|
| `gun04_01.ogg` | İyi günler. Güvenlik görevlileri görevleri başındadır. |
| `gun04_02.ogg` | Üniformalı kişilere yaklaşmayın. |
| `gun04_03.ogg` | Yelekleri mermiyi tutmaktadır. Yalnız başa nişan alınız. |
| `gun04_04.ogg` | Tahliye otobüsleri yola çıkmıştır. |
| `gun04_05.ogg` | Tahliye yapılmayacaktır. Evinizde kalın. |

### 5. gün, B, geçici yayıncı
| Dosya | Metin |
|---|---|
| `gun05_01.ogg` | Bakanlıktan yayın yapılamamaktadır. Bu metni bana verdiler. |
| `gun05_02.ogg` | Bağıran bir hasta görürseniz önce onu vurun. |
| `gun05_03.ogg` | Bağırınca çevresindekiler hızlanıyor. |
| `gun05_04.ogg` | Bu gece gökyüzünde birden fazla ay görülebilir. Bakmayın. |
| `gun05_05.ogg` | Yarın bu saatte biri bunu okuyacaktır. |

### 6. gün, B, geçici yayıncı (taslak metin)
| Dosya | Metin |
|---|---|
| `gun06_01.ogg` | Dünkü metnin kaynağı bulunamamıştır. |
| `gun06_02.ogg` | Köpeklerinizi bağlayın. Bağlı olmayan köpeklerden kaçılamaz. |
| `gun06_03.ogg` | Koşmayın. Duvara sırtınızı verin, gelince vurun. |

### 7. gün, B, geçici yayıncı (taslak metin)
| Dosya | Metin |
|---|---|
| `gun07_01.ogg` | Şişmiş hastalar görülmektedir. |
| `gun07_02.ogg` | Vurulduklarında patlarlar. Uzaktan vurun. |
| `gun07_03.ogg` | Çamaşırlarınızı kaynatın. Bu bir talimat değildir. |

### 8. gün, B, geçici yayıncı (taslak metin)
| Dosya | Metin |
|---|---|
| `gun08_01.ogg` | Burada kimse kalmadı. Metni kendim yazıyorum. |
| `gun08_02.ogg` | Tulumlu olanlar var, maskeli. Kafaya sıkma, geçmiyor. |
| `gun08_03.ogg` | Gövdesine sık. Bakanlık bunu söylemedi. Ben söylüyorum. |

### 9. gün, A, resmî spiker (taslak metin)
| Dosya | Metin |
|---|---|
| `gun09_01.ogg` | İyi günler. Durum kontrol altındadır. |
| `gun09_02.ogg` | Son dört gün yayın kesintisi olmamıştır. Geçici yayın yapılmamıştır. |
| `gun09_03.ogg` | Yaralı hastalar iyileşmektedir. Bu sevindirici bir gelişmedir. |
| `gun09_04.ogg` | Yaraladığınız hastayı bırakmayın. |

### 10. gün, A, resmî spiker (taslak metin)
| Dosya | Metin |
|---|---|
| `gun10_01.ogg` | İyi günler. Durum kontrol altındadır. |
| `gun10_02.ogg` | Ses yapın. Evinizden çıkın. Kapılarınızı açık bırakın. |
| `gun10_03.ogg` | Çok iri bir hasta görülmüştür. Mermi saymayın. |
| `gun10_04.ogg` | Bu gece gökyüzüne yine bakmayın. |

### 11. gün, C, A'nın kaydı (taslak metin)
| Dosya | Metin |
|---|---|
| `gun11_01.ogg` | İyi günler. Sağlık Bakanlığı'nın bildirisini okuyorum. |
| `gun11_02.ogg` | Bugün yeni bir virüsün ilk günüdür. |
| `gun11_03.ogg` | Az kalan hasta öfkelenir, daha hızlı gelir. Bitirin. |
| `gun11_04.ogg` | İyi günler. Sağlık Bakanlığı'nın bildirisini okuyorum. |

### 12. gün, B, geçici yayıncı (taslak metin)
| Dosya | Metin |
|---|---|
| `gun12_01.ogg` | Hâlâ açıksanız dinleyin. Vericiyi ben açtım, kapatan olmadı. |
| `gun12_02.ogg` | Her gece daha kalabalık geliyorlar. |
| `gun12_03.ogg` | Benim kapım gitti. Sizin eviniz kaç kapılı? |

### 13. gün, ses yok (taslak metin)
Kayıt yok.

### 14. gün, ses yok (taslak metin)
Kayıt yok.
