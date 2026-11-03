# python -I jobs.py <indirme klasörü> <proje kökü>
# process.py için iş dosyalarını yazar: <indirme klasörü>/jobs/*.json
import json, os, sys

S, ROOT = sys.argv[1], sys.argv[2]
ENV = os.path.join(ROOT, 'assets/env/acik_alan')
ATL = os.path.join(ROOT, 'assets/props/atolye')
PH = 'https://polyhaven.com/a/'
SF = 'https://sketchfab.com/3d-models/'
os.makedirs(os.path.join(S, 'jobs'), exist_ok=True)

# Poly Haven, CC0
ph = {
    # arazi
    'namaqualand_boulder_02': dict(max_tex=2048, out='kayalar', pieces=[dict(id='kaya_yassi', tris=5000)]),
    'namaqualand_boulder_04': dict(max_tex=2048, out='kayalar', pieces=[dict(id='kaya_buyuk', tris=6000)]),
    'namaqualand_boulder_05': dict(out='kayalar', pieces=[dict(id='kaya_kucuk', tris=3000)]),
    'namaqualand_boulder_03': dict(out='kayalar', pieces=[dict(id='kaya_yuksek', tris=6000)]),
    'namaqualand_boulder_06': dict(out='kayalar', pieces=[dict(id='kaya_orta', tris=3000)]),
    'namaqualand_cliff_01': dict(max_tex=2048, out='kayalar', pieces=[dict(id='kaya_kumesi_8m', tris=12000)]),
    'namaqualand_cliff_02': dict(max_tex=2048, out='kayalar', pieces=[dict(id='kaya_sirti_20m', tris=16000)]),
    'rock_07': dict(out='kayalar', size=1.6, pieces=[dict(id='kaya_sivri', tris=4000)]),
    'dead_tree_trunk_02': dict(max_tex=2048, out='bitkiler', pieces=[dict(id='devrik_kutuk', tris=8000)]),
    'dead_quiver_trunk': dict(out='bitkiler', pieces=[dict(id='olu_govde', tris=6000)]),
    'tree_stump_01': dict(out='bitkiler', pieces=[dict(id='kutuk', tris=6000)]),
    'dry_branches_medium_01': dict(out='bitkiler', hull='none', pieces=[dict(id=f'kuru_dal_{c}', names=[f'dry_branches_medium_01_{c}'], tris=3000) for c in 'abc']),
    'wild_rooibos_bush': dict(out='bitkiler', alpha=True, hull='none', pieces=[dict(id=f'kuru_cali_{c}', names=[f'wild_rooibos_bush_{c}'], tris=8000) for c in 'abcde']),
    # atölye içi
    'bench_vice_01': dict(out='ic', pieces=[dict(id='mengene', exclude=['icosphere'])]),
    'steel_frame_shelves_02': dict(out='ic', pieces=[dict(id='celik_raf')]),
    'portable_searchlight': dict(out='ic', pieces=[dict(id='el_projektoru', tris=6000)]),
    'security_light': dict(out='ic', pieces=[dict(id='duvar_projektoru')]),
    'Barrel_01': dict(out='ic', pieces=[dict(id='varil_kirmizi')]),
    'oil_tin': dict(out='ic', pieces=[dict(id='yag_tenekesi')]),
    'small_oil_can_01': dict(out='ic', pieces=[dict(id='yaglik', tris=4000)]),
    'propane_tank': dict(out='ic', pieces=[dict(id='tup')]),
    'portable_welding_cart': dict(out='ic', pieces=[dict(id='kaynak_arabasi', tris=10000)]),
    'old_military_compressor': dict(out='ic', pieces=[dict(id='kompresor', tris=12000)]),
    'industrial_pipe_lamp': dict(out='ic', pieces=[dict(id='boru_lamba')]),
    'industrial_storage_cart': dict(out='ic', pieces=[dict(id='tekerlekli_dolap', tris=8000)]),
    'metal_stool_02': dict(out='ic', pieces=[dict(id='tabure', tris=5000)]),
    'WoodenTable_03': dict(out='ic', pieces=[dict(id='cekmeceli_tezgah')]),
    'modular_electric_cables': dict(out='ic', hull='none', pieces=[dict(id='kablo_' + n, names=['cable_' + n]) for n in
                                    ('straight_long', 'turn_long', 'mount', 'box_4way', 'plug_4x', 'switch', 'double_alt_long')]),
}
# Sketchfab; boy (height) ya da en uzun kenar (size) metre
sf = {
    # atölye yapısı
    'ea06568a9e304ecc806cb7cb0552e269': dict(out='yapi', set='egri_sac', scale=0.45, kaynak='Sousinho, Rusted corrugated panels, CC-BY 4.0',
                                             pieces=[dict(id=f'egri_sac_{c}', names=[f'Object_{n}'], hull='box') for c, n in (('a', 4), ('b', 6), ('c', 8))]),
    '33f84d01ec834d8c98c39ee7251f8ff4': dict(out='yapi', size=4.0, kaynak='Cyril Demetrius, Construction steel beam, CC-BY 4.0', pieces=[dict(id='celik_h_kiris_4m', tris=2500)]),
    'dba5c00928cd400796d9f6fffdd724b3': dict(out='yapi', set='sf_palet', scale=0.6, kaynak='YadroGames, Wooden Pallets, CC-BY 4.0',
                                             pieces=[dict(id='palet_eski_a', names=['Pallet_1_Pallet_1_0'], hull='box'), dict(id='palet_eski_b', names=['Pallet_2_Pallet_2_0'], hull='box')]),
    # ufuk
    '690edb7d64b84df7bfeee3b54746d6eb': dict(out='ufuk', set='yikinti', scale=6.0, kaynak='tobiasherbers, Ruined buildings pack, CC-BY 4.0',
                                             pieces=[dict(id=f'yikinti_{c}', names=[f'Object_{n}'], tris=6000) for c, n in zip('abcdef', (4, 6, 8, 10, 12, 14))]),
    'a76b68b838424a89b7db8a38f4c3d546': dict(out='ufuk', height=9.5, hull='none', kaynak='Caboose3d, Telephone Poles, CC-BY 4.0', pieces=[dict(id='telefon_direkleri')]),
    'a1959927a98e4752bdb01b6e1f7f7d26': dict(out='ufuk', kaynak='olegolegperepelica, Abandoned Garage Block Rusty Ruined, CC-BY 4.0', pieces=[dict(id='yikik_garajlar', tris=8000)]),
    # çöl wasteland: araç enkazı ve ölü ağaçlar
    '6a2169dafc254f399387a679305bb1bf': dict(out='enkaz', size=4.6, kaynak='Rashad Ibrahimli, Abandoned Generic Sedan 1, CC-BY 4.0', pieces=[dict(id='sedan_enkazi_1', tris=10000)]),
    'db2df46c49f9441286c84c66208ef7ac': dict(out='enkaz', size=4.6, kaynak='Rashad Ibrahimli, Abandoned Generic Sedan 2, CC-BY 4.0', pieces=[dict(id='sedan_enkazi_2', tris=12000)]),
    '3cb4d59eb4844dc4802480e9ee53785e': dict(out='bitkiler', hull='none', kaynak='evolveduk, Old tree, CC-BY 4.0', alpha=True,
                                             pieces=[dict(id='olu_agac_yasli', names=['Tree_0_Tree_0Mat_0']), dict(id='olu_agac_yasli_yaprakli')]),
    # demo setinde 4 ağaç var, 1.6-3 m geliyor; 2.5 katıyla 4-7.5 m
    '9bdd36641ef541adb51f0d01ddb07b2c': dict(out='bitkiler', hull='none', set='olu_agac', scale=2.5, kaynak='Quadra3D, Dead Trees Demo, CC-BY 4.0',
                                             pieces=[dict(id=f'olu_agac_{c}', names=[f'Object_{n}'], tris=6000)
                                                     for c, n in (('a', 10), ('b', 13), ('c', 16), ('d', 19))]),
    'b47825ecb8a049d78be9bd07f49a7d5d': dict(out='bitkiler', height=4.5, hull='none', kaynak='iGauravRajput, Desert tree Skeleton, CC-BY 4.0', pieces=[dict(id='olu_col_agaci', tris=15000)]),
    # atölye içi
    '9fbc30ba31a546fe9370e6de2dcc0707': dict(out='ic', set='eski_tezgah', kaynak='Oliver Triplett, Old Work Bench, CC-BY 4.0',
                                             pieces=[dict(id='eski_tezgah', exclude=['pegboard', 'light_fixture'], below=1.1, tris=10000, hull='box'),
                                                     dict(id='eski_tezgah_panosu', match=['pegboard', 'light_fixture'], above=1.1, tris=8000, hull='box')]),
    '9634d6a81a494925a909512c8048f446': dict(out='ic', scale=0.01, kaynak='JJ Chalupnik, Workbench, CC-BY 4.0', pieces=[dict(id='rafli_tezgah', tris=10000, hull='box')]),
    'a298746adb5946b997cc19618cb110e5': dict(out='ic', size=1.6, kaynak='Sousinho, Tool Storage Board, CC-BY 4.0', pieces=[dict(id='delikli_pano', hull='box')]),
    'ff0abe17dc64498191bb41c905d00ab0': dict(out='ic', height=1.7, alpha=True, kaynak='denis_cliofas, Industrial Work Light, CC-BY 4.0', pieces=[dict(id='ayakli_cift_projektor', tris=8000)]),
    '95ad365a60434015a8700efbdaa90893': dict(out='ic', height=1.6, kaynak='Chamod1999, Flood light 02, CC-BY 4.0', pieces=[dict(id='ayakli_projektor')]),
    '22ddb8e02f944fb7b5662f14fdc50e5e': dict(out='ic', scale=0.01, kaynak='wolfgar74, Cable Spool, CC-BY 4.0', pieces=[dict(id='kablo_makarasi')]),
    '2cc3a34bdd7f48799474878334673116': dict(out='ic', height=1.0, kaynak='Steven Janes, Anvil-Vise Combo, CC-BY 4.0', pieces=[dict(id='ors_mengene')]),
}
extra = json.load(open(os.path.join(S, 'sf_extra.json'), encoding='utf8')) if os.path.exists(os.path.join(S, 'sf_extra.json')) else {}


def outdir(k):
    return os.path.join(ENV if k in ('kayalar', 'bitkiler', 'ufuk', 'enkaz') else ATL, k)


n = 0
for k, j in ph.items():
    j = dict(j); o = j.pop('out')
    j.update(set=k.lower(), src=f'{S}/dl/ph/{k}/{k}.gltf', out=outdir(o), stats=f'{S}/stats', kaynak=f'Poly Haven {PH}{k}, CC0')
    json.dump(j, open(f'{S}/jobs/ph_{k}.json', 'w', encoding='utf8'), ensure_ascii=False); n += 1
for u, j in sf.items():
    j = dict(j); j.update(extra.get(u, {})); o = j.pop('out')
    d = f'{S}/dl/sf/{u}'
    if not os.path.isdir(d): continue
    src = next((os.path.join(r, f) for r, _, fs in os.walk(d) for f in fs if f.endswith(('.gltf', '.glb'))), None)
    if not src: continue
    j.update(set=j.get('set', u[:6]), src=src, out=outdir(o), stats=f'{S}/stats', kaynak=f"{j['kaynak']} {SF}{u}")
    if 'pieces' not in j: j['id'] = 'tum_' + u[:6]
    json.dump(j, open(f'{S}/jobs/sf_{u}.json', 'w', encoding='utf8'), ensure_ascii=False); n += 1
print(n)
