# Üretim ağacı: taşıma, pres, otomasyon (2026-10-28, taslak)

Kullanıcı isteği (2026-10-28): tezgâh ve pres açılınca oyuncu ham mermiyi eliyle (kapasitesi kadar) prese götürür, **2 ham mermi 1 klon mermiye** dönüşür. Klon mermilerle ateş ettikçe taşıma aletleri (kask, kova, kürek…) gelir, sonra otomatik makineler. Her kademe daha pahalı; her mermi daha çok ham mermi ister, daha çok altın verir. Aşağıdakilerin kullanıcı kararı olan kısmı yalnız bu paragraf; tablolar ve sayılar öneri/yer tutucu, bot testinde (`tools/quest_sim.gd`) oturur.

Bu, `ayrintilar.md` → "Mermi tarifi"ndeki "maliyet şarjörden düşer" kuralının yerine geçer: tarif artık atış anında değil, preste fiziksel olarak yapılır. `QUESTS`'teki `hand_press`, `electric_press`, `crafted`, `bucket`, `shovel`, `wheelbarrow` açılışları bu ağacın düğümleri.

## Üç kol, tek darboğaz

```
            ┌── TAŞIMA ──┐        ┌──── PRES ────┐        ┌── ATEŞ ──┐
 yığın ──▶  el → kask → kova  ──▶ el presi → motorlu ──▶  şarjör → hedef → $
            → kürek → el arabası   pres → hortum           (silah sırası)
                     └────────── otomasyon: hortum + robot kol ──────────┘
```

Oyunun baskısı şu: her yeni mermi kademesi atış başına daha çok ham mermi ister, oyuncu hızlı silaha geçtikçe prese saniyede taşıması gereken ham mermi patlar. Taşıma yetmezse pres boş bekler, pres yetmezse şarjör boş kalır. Her satın alma bir sonraki darboğazı açığa çıkarır; "neden kürek alayım" sorusunun cevabını oyuncu kendi görür.

## Mermi kademeleri (hepsi ham mermiden, zincir yok)

Ürün zinciri yok kuralı korunur: her kademe doğrudan ham mermiden basılır, presin seviyesi neyi basabileceğini belirler.

| Kademe | Ham mermi | Atışta | Taban $ / atış | $ / ham mermi | Açılır |
|---|---|---|---|---|---|
| Ham | 1 | 1 isabet | 1 | 1,0 | baştan |
| Klon | 2 | 2 parça | 3 | 1,5 | el presi |
| Üçlü klon | 6 | 3 parça + yayılma | 12 | 2,0 | pres sv. 2 |
| Sekmeli klon | 24 | 3 parça × 2 sekme | 60 | 2,5 | pres sv. 3 + Sekme blueprint'i |
| Ağır | 120 | 4 parça × 3 sekme | 360 | 3,0 | pres sv. 4 |
| Final | 600 | gösteri | 2.400 | 4,0 | motorlu pres sv. 3 |

$/ham mermi yükseldiği için yukarı çıkmak hem yığını hızlı eritir hem kazandırır; ama taşıma ve pres yatırımı ister.

## Taşıma aletleri

| Alet | Bir seferde | Fiyat (yer tutucu) | Nasıl |
|---|---|---|---|
| El | 1 → 10 (mevcut `carry`) | 6 … 420 | E basılı tut |
| Kask | 25 | $60 | iki elle önde taşınır, E'yle yığından doldurulur |
| Kova | 60 | $250 | tek elde sallanır; huniye/prese devrilir |
| Kürek | 200 / kepçe | $1.200 | sol tık kazır, preste sol tık boşaltır; taşırken yavaşlatmaz |
| El arabası | 1.000 | $6.000 | dünyada nesne, itilir; kürekle doldurulur, presin yanında devrilir |

Alet kişisel (gold kişisel). Elde alet varken silah kılıfta; 1–4 tuşları silah, alet ayrı tuşta (öneri: 5 ya da F).

## Pres ve otomasyon

| Makine | Ne yapar | Fiyat | Gerekir |
|---|---|---|---|
| El presi | Tablasına mermi dökülür, oyuncu kolu çeker (E basılı): bir çekiş = 1 mermi, 0,6 sn | görevle açılır (m05) | tezgâh |
| Pres sv. 2-4 | Bastığı kademe yükselir | $800 / $5.000 / $30.000 | el presi |
| Motorlu pres | Haznesine dökülen mermiyi kendiliğinden basar, saniyede 2 → 8 | $3.000 | m10 (`electric_press`) |
| Besleme hortumu | Yığından prese kendiliğinden çeker (taret hortumu gibi), taşıma gereksiz | $15.000 | motorlu pres |
| Robot kol | Presin çıkışından yanındaki şarjör rafına doldurur; oyuncu raftan dolu şarjör alır | $60.000 | hortum (tam sürüm olabilir) |

Presten çıkan mermi çıkış tepsisinde birikir; oyuncu E'yle alır. Klon mermiler özel mermi cebine girer (`ammo_wheel.gd` zaten var), çarktan seçilir, şarjöre o doldurulur. Elde ham ve basılmış mermi aynı anda olabilir.

Tempo kontrolü (tempo tablosuyla, `ayrintilar.md`): Deagle + klon ≈ 5 ham/sn, UZI + üçlü ≈ 48, Scorpion + sekmeli ≈ 240. Kova ile 10 sn'lik tur ≈ 6 ham/sn: UZI'ye geçince kova yetmez, kürek ve el arabası buradan doğar; Scorpion'da hortumsuz yetişilmez. Gerisini taretler doldurur.

## Gereklilik ağacı

```
tezgâh (m01b)
 └─ el presi (m05) ── klon
     ├─ kask ($60)
     │   └─ kova ($250)  ─────────────── UZI (m03)
     │       └─ kürek ($1.2k)
     │           └─ el arabası ($6k)
     ├─ pres sv.2 ($800) ── üçlü klon
     │   └─ pres sv.3 ($5k) + Sekme bp ── sekmeli klon
     │       └─ pres sv.4 ($30k) ── ağır
     └─ motorlu pres (m10, $3k)
         ├─ hız sv. 1-3
         └─ besleme hortumu ($15k)
             └─ robot kol ($60k)   ← demo sonu tadımlık
```

## Bağlantı (kod)

- `GameState`: `press` durumu (tabla/hazne içeriği, çıkış tepsisi, seviye), oyuncuya `tool` ve `tool_load`; `crafted` görev kancası buradan beslenir.
- Yeni istemci komutları (`REQUESTS`): `request_tool_fill`, `request_tool_dump` (prese/huniye), `request_press_pull`, `request_take_output`, `request_buy_tool`. Basım host'ta; yeni dünya olayı `press_made` (`EVENTS`), istemci tepsiyi ve kolu çizer.
- Görseller: alet içindeki mermiler ve dökülme MultiMesh + havuz (`pile.gd` gibi), mermi başına node yok. Klon mermi mevcut mermi modeli + ince bir parlama shader'ı, ayrı model gerekmez.
- Viewmodel: aletler kol rig'ine yeni setler (`tools/build_arms.py`, `viewmodel.gd` `SETS`).
- Pres, kask, kova, kürek ve el arabası açılınca `Reveal.hold` ile düşer.
- Kontrol: `tools/press_check.gd` (dönüşüm oranı, co-op tepsi), `net_check.gd`'ye yeni olay ve komutlar, `quest_sim.gd`'ye taşıma turu ve pres hızı.

## Kullanıcıdan gereken asetler

**Modeller** (gerçekçi PBR, CC0 tercih, marka/logo yok):
1. Tek istasyonlu mermi presi (reloading press), kolu ayrı obje: kol pivotu animasyonla döner.
2. Motorlu / döner tablalı pres (progressive press), haznesiyle.
3. Askerî çelik kask (ters çevrilip mermi doldurulacak).
4. Metal kova (huninin yanındaki dolu kova `hopper.glb`'den ayrılabilirse o da olur).
5. Kürek (metal ağızlı, düz uçlu).
6. El arabası (tekerlek ayrı obje: döner).
7. Çıkış tepsisi ya da cephane kutusu (presin önüne).
8. (Sonra) Besleme hortumu ucu, robot kol.

**Animasyonlar:** viewmodel kolları için şunlar lazım; sen verirsen uyarlarım, yoksa Blender açıkken ben anahtarlarım: kaskı/kovayı taşıma idle'ı ve yürüme sallantısı, yığından doldurma (eğil-kepçele), prese devirme, kürekle kazıma ve boşaltma, el arabası tutuşu (kollar öne, itme), pres kolunu çekme. Pres kolu, tepsi ve dökülen mermiler kodla oynar.

**Sesler (gerçek kayıt):** mermi kaska/kovaya dökülmesi, küreğin mermiye dalması ve boşalması, el arabası tekerleği ve devrilmesi, pres kolunun çekilip oturması, basılan merminin tepsiye düşmesi, motorlu presin çalışma döngüsü, hortum emişi.
