"""docs/ayrintilar.md (eski tek belge) -> docs/sistemler/*.md bölme betiği (2026-11-06, tasarruf).
Kullanım: python tools/docs_bol.py <eski_ayrintilar.md>   (tam kopya docs/arsiv/ altına da yazılır)
Başlık sınırlarından keser, satırlara dokunmaz; sonda kayıpsızlık doğrulaması yapar:
orijinaldeki her dolu satır yeni dosyalarda aynı sayıda bulunmalı (yalnız üç üst başlık satırı hariç)."""
import sys,collections,glob
src=open(sys.argv[1],encoding="utf-8").read().split(chr(10))
def idx(prefix, start=0):
    for i in range(start,len(src)):
        if src[i].startswith(prefix): return i
    raise SystemExit('yok: '+prefix)
b={}
b['fikir']=idx('## Oyun fikri')
b['acik']=idx('### Yeni yön: açık alan')
b['ev']=idx('### Ev ve televizyon')
b['zomb']=idx('### Yeni yön: zombi dalgaları')
b['hurda']=idx('### Yeni yön: hurdalık')
b['kural']=idx('### Tasarım kuralları')
b['gorev']=idx('### Görev ağacı')
b['tezgah']=idx('### Tezgâhta silah geliştirme')
b['arayuz']=idx('### Arayüz')
b['eski']=idx('### Eski tasarımdan kodda kalanlar')
b['kararlar']=idx('## Kararlar')
b['teknik']=idx('## Teknik yaklaşım')
b['ses']=idx('### PS1 ses düzeni')
b['aset']=idx('## Seçilen ve aday asetler')
b['ortam']=idx('**Ortam (2026-10-19):**', b['aset'])
b['asetkural']=idx('### Aset kuralları')
b['zekai']=idx('### Zombi zekâsı ve gece akışı')
b['son']=len(src)
while src[b['son']-1]=='' : b['son']-=1
# parçalar: (dosya, [(başlangıç,bitiş)...], başlık)
parts=[
 ('acik_alan',[(b['acik'],b['ev'])]),
 ('ev_tv',[(b['ev'],b['zomb'])]),
 ('zombiler',[(b['zomb'],b['hurda']),(b['zekai'],b['son'])]),
 ('hurdalik',[(b['hurda'],b['kural'])]),
 ('tasarim_atis',[(b['kural'],b['gorev'])]),
 ('gorev_pano',[(b['gorev'],b['tezgah'])]),
 ('atolye_tezgah_pres',[(b['tezgah'],b['arayuz'])]),
 ('arayuz',[(b['arayuz'],b['eski'])]),
 ('eski_tasarimdan_kalanlar',[(b['eski'],b['kararlar'])]),
 ('kararlar',[(b['kararlar'],b['teknik'])]),
 ('teknik',[(b['teknik'],b['ses'])]),
 ('ses',[(b['ses'],b['aset'])]),
 ('asetler',[(b['aset'],b['ortam']),(b['asetkural'],b['zekai'])]),
]
arsiv=[(b['ortam'],b['asetkural'])]
# kapsama kontrolü: 'fikir' başlığı ve üst bilgi dışında her satır tam bir kez
covered=[0]*len(src)
for _,rs in parts:
    for a,e in rs:
        for i in range(a,e): covered[i]+=1
for a,e in arsiv:
    for i in range(a,e): covered[i]+=1
head_end=b['acik']
for i in range(head_end): covered[i]+=1
for i in range(b['son'],len(src)): covered[i]+=1
bad=[i+1 for i,c in enumerate(covered) if c!=1]
assert not bad, bad[:20]
OZ={
'acik_alan':("Açık alan yönü","Kullanıcı kararı (2026-11-02): oyun açık alanda gece-gündüz hayatta kalma; salon, korkuluk ve atış alanı, hurda çukuru gidiyor.\nArkada ucu bucağı olmayan dağ şeklinde bir çöplük var; oradan alınan hurda sökülüp işlenir. Gündüz topla ve üret (otomasyon, taret, silah), gece dalgalar.\nBu bölüm eski bölümlerin önüne geçer. Ayrıntılar ve uygulama notları aşağıda; ışık, PS1 görünümü ve 2026-11-06 fener (elde tutulan fener, titreme, ormanda sönme; kullanıcı kararları) de burada."),
'ev_tv':("Ev ve televizyon","Kullanıcı kararı (2026-11-05): dağ başındaki adamın evi hissi veren ev; içinde eski tüplü TV'de her gün haberler.\nEv modeli kullanıcının seçtiği \"Post-Apocalyptic | House | Dirty | Old | Wooden\" (CC-BY, jenerikte isim zorunlu).\nYerleşim ve ölçüler (ana oda 6,9 x 10,8 m, yan oda atölye, tek dış kapı) yazarın seçimi, kural değil."),
'zombiler':("Zombiler, dalgalar, gece akışı","Kullanıcı kararı (2026-10-29): sabit hedefler yerine zombi, iskelet ve canavar akınları; dalga oyuncunun istediği zaman başlar, süresi oyuncunun gücüne göre.\nDalga bölümündeki \"taret yok\" satırı ve eski taret planı o günün tasarımıdır; 2026-11-02 açık alan yönünde taret üretilir (CLAUDE.md).\nSonda 2026-11-05 \"Zombi zekâsı ve gece akışı\" ile 2026-11-06 \"Avcı zekâsı\" (yönetmen, pusu, saklanma, arkadan sızma; kullanıcı: \"sürekli de tetiklenmesin, tadında kalsın\"): takılma düzeltmesi, fark etme mesafeleri, saldırı vuruş anı, 20:00-06:00 gece dalgası. O bölümdeki sayılar yazarın tahmini, kural değil."),
'hurdalik':("Hurdalık","Kullanıcı kararı (2026-11-01): her şey hurdalıktan edinilen materyalden yapılır; hurda öğütülür, öğütülen malzeme barutta ya da kovanda kullanılır.\nYeni kovan ve mermi türleri açıldıkça daha fazla hurda gerekir.\nSalon ve hurda çukuru ayrıntıları 2026-11-02 açık alan kararıyla geçersiz; hurda dağı tekniği için CLAUDE.md ve `teknik.md`."),
'tasarim_atis':("Tasarım kuralları, anahtarlar, atış","Konuşma/ağız animasyonu yok, iletişim ping ve emote ile. 12 anahtar hurda dağına gömülü (`scripts/key_cache.gd`).\nAtış becerisi: zayıf nokta x2, kombo penceresi 1,5 sn. Atış hattı korkuluğu eski salona ait.\nKullanıcı kararı (2026-10-31): dummy'ler, hedef çeşitleri ve teçhizat hedefleri kaldırıldı."),
'gorev_pano':("Görev ağacı, görev tahtası, pano","Kullanıcı kararı (2026-10-27): yeni mekanikler kasadan değil görevlerden açılır; tezgâh ilk görevlerle açılır, parçalı blueprint'ler panoda birleşir.\nÖdül panodan alınır, panoda hep 5 kart asılı; sayılar yer tutucu.\nUygulama sırası: `docs/gorev_sistemi_plani.md`."),
'atolye_tezgah_pres':("Tezgâh, atölye, huni, pres","Tezgâh silah geliştirme ekranı (`scripts/bench_menu.gd`), takma gösterisi, elde lazer; atölye masası ve hikâyesi; üçüncü istasyon pres (`press.gd`).\nHuninin mermi eritmesi bırakıldı, hurdalıkta malzeme öğütücüden gelir; modeller ve yerleşim geçerli.\nEkran dili: kamera makineye süzülür (`station_view.gd`); kullanıcı 2026-10-28: ilk hâl \"kötü\", \"AI kokuyor\"."),
'arayuz':("Arayüz","UiStyle (`scripts/ui_style.gd`), HUD (`hud.gd`), istek listesi ödülü Altın Deagle (2026-10-23, kullanıcı kararı).\nKullanıcı 2026-10-28: \"AI kokuyor, gereksiz yazı çok, oyuncuyu aptal yerine koyuyorsun\"; fontlar yeniden: Oswald, IBM Plex Sans Condensed, Stardos Stencil.\nKurallar için memory: UI'de gereksiz yazı yok, tuş harfleri büyük."),
'eski_tasarimdan_kalanlar':("Eski tasarımdan kodda kalanlar","2026-11-02'de mermi yığını bırakıldı; aşağıdaki kod hâlâ duruyor ve hurdalık sistemleri geldikçe kalkacak ya da değişecek.\nÖrnekler: `GameState.pile` sayacı, yığından mermi alma, SPECIALS özel mermileri, huni-erit ve pres-basma.\nSilmeden önce ilgili `tools/*_check.gd`'yi çalıştır."),
'kararlar':("Kararlar","Motor Godot 4; tür 3D FPS (kullanıcı kararı, 2D top-down reddedildi); 4 kişilik co-op; ekip 2 kişi.\nDemo 4 kişilik co-op (2026-10-20); sıra `docs/yol_haritasi.md`."),
'teknik':("Teknik yaklaşım","Hurda dağı `scripts/pile.gd` (yükseklik alanı + gerçek parçalar), atış izi/kovan/mermi MultiMesh ve havuz.\nViewmodel tek kol rig'i (`tools/build_arms.py`); başlangıç tabancası, Minigun kilidi.\nOyuncu karakteri İhtiyar (2026-11-05, kullanıcı kararı); diğer beden seçenekleri kaldırıldı."),
'ses':("PS1 ses düzeni","Kullanıcı isteği (2026-11-03): PS1 tarzı ses düzeni; verilen tüm sesler bu düzene göre eklenir. Ses kodla üretilmez, kayıtlar kullanıcıdan.\nKlasör = tür = ses yolu (`data/ses_duzeni.json`, `scripts/ps1_sound.gd`, `tools/ses_ekle.py`); tablodaki sayılar yazarın seçimi.\nZombi sesi karışımı 2026-11-04 kullanıcı geri bildirimiyle ayarlandı."),
'asetler':("Asetler ve lisanslar","Kullanılan aset kaynakları ve lisansları (CC-BY olanlar jenerikte isim ister). Yeni aset buraya yazılır.\nKurallar: CC0 tercih, NC/ND/\"personal use only\" yok, yalnız Unreal'a özel ve Lyra kaynaklı yok, gerçek marka ve logo yok, silah başına 50 bin poligonun altı.\n2026-10-18 güncellemesi: low-poly set kullanılmayacaktı; CLAUDE.md'deki 2026-11-02 low poly kararı bunu değiştirir."),
}
import os
os.makedirs('docs/sistemler',exist_ok=True); os.makedirs('docs/arsiv',exist_ok=True)
for name,rs in parts:
    title,oz=OZ[name]
    out=['# '+title,'','> **Özet (2026-11-06):**']+['> '+l for l in oz.split('\n')]+['> Tam eski belge: `docs/arsiv/ayrintilar_tam_2026-11-06.md`. Dizin: `docs/sistemler/README.md`.','']
    for a,e in rs:
        out+=src[a:e]
        while out and out[-1]=='' : out.pop()
        out.append('')
    open(f'docs/sistemler/{name}.md','w',encoding='utf-8',newline='\n').write('\n'.join(out).rstrip('\n')+'\n')
a,e=arsiv[0]
open('docs/arsiv/eski_salon_poligon_ortam.md','w',encoding='utf-8',newline='\n').write('# Eski salon, atış poligonu ve ortam notları (arşiv)\n\n> 2026-11-02 kullanıcı kararıyla (salon, korkuluk ve atış alanı, hurda çukuru gidiyor) geçersiz. `docs/ayrintilar.md`\'den aynen taşındı (2026-11-06).\n\n'+'\n'.join(src[a:e]).rstrip('\n')+'\n')
open('docs/arsiv/ayrintilar_tam_2026-11-06.md','w',encoding='utf-8',newline='\n').write('\n'.join(src))
print('yazıldı')

# ---- doğrulama ----
new=[]
for f in glob.glob('docs/sistemler/*.md')+['docs/arsiv/eski_salon_poligon_ortam.md']:
    if f.endswith('README.md'): continue
    new+=open(f,encoding='utf-8').read().split(chr(10))
co=collections.Counter(l for l in src if l.strip()); cn=collections.Counter(l for l in new if l.strip())
eksik=[(l[:60],n-cn[l]) for l,n in co.items() if cn[l]<n]
print('eksik satır türü:',len(eksik),'(beklenen 3: üst başlık satırları)')
for e in eksik: print('  ',e)
print('kaynak dolu satır:',sum(co.values()),' yeni (özetler dahil):',sum(cn.values()))
print('kaynak karakter:',sum(len(l)+1 for l in src),' yeni gövde karakter:',sum(len(l)+1 for l in new))
sys.exit(1 if len(eksik)>3 else 0)
