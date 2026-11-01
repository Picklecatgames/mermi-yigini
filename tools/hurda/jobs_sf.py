# Sketchfab adayları: id, uid öneki, mod ve gerçek boyut
import json,os,sys
S=sys.argv[1]
meta=json.load(open(os.path.join(S,'sf_meta.json'),encoding='utf8'))
full={u[:8]:u for u in meta}
W=dict(rust=0.2,paint=0.3,tris=2500)   # silahlar: zaten hurdadan
C=[
# (id, uid8, tip, ayarlar)   tip: one | pieces | obj | cluster
('rusted_copper_gear','75d1f09e','one',dict(size=0.2,rust=0.2)),
('rusty_gears','10e4ab22','cluster',dict(scale=0.04,min=0.03,rust=0.2)),
('steampunk_gear','249b3611','obj',dict(scale=0.2,rust=0.45,paint=0.8)),
('saw_blade','98d471f4','one',dict(size=0.25,rust=0.55)),
('coil_spring','3bf2215c','one',dict(size=0.25,rust=0.75,tris=2000,metal_override=1.0,base_override=[0.3,0.3,0.31,1.0])),
('old_pipe','fbe3129e','obj',dict(scale=0.3,rust=0.3)),
('small_copper_pipe','02a9298f','obj',dict(scale=0.01,rust=0.35,min_obj=0.03)),
('small_steel_pipe','dfd00922','obj',dict(scale=0.01,rust=0.55)),
('rusty_pipe','23f2e48c','obj',dict(scale=0.012,rust=0.25)),
('copper_pipe_section','91807ce3','one',dict(size=0.5,rust=0.35)),
('valve_wheel_scan','0264beb6','one',dict(rust=0.25)),
('pipe_valve_scan','5b8d5bb5','one',dict(rust=0.25)),
('iron_valve_wheel','8ec35185','one',dict(size=0.25,rust=0.35)),
('pressure_gauge','95cf5b63','one',dict(size=0.1,rust=0.45)),
('old_faucet','3a7ff8c3','one',dict(size=0.2,rust=0.45)),
('stylized_pipe','9e052369','obj',dict(scale=0.008,rust=0.55)),
('crumpled_can','5f4c354c','obj',dict(rust=0.35)),
('rusty_sardine_can','af964af1','one',dict(size=0.11,rust=0.2)),
('rusty_can','6f429979','one',dict(size=0.12,rust=0.2)),
('rusty_tin_can_scan','69455297','one',dict(size=0.2,rust=0.2)),
('soviet_tin_can','70a8473d','obj',dict(piece_size=0.1,rust=0.4,dedupe=True)),
('crushed_can','51e709ee','one',dict(size=0.12,rust=0.35)),
('metal_paint_can','f5d97bc8','one',dict(size=0.18,rust=0.55)),
('paint_can','30d6217c','obj',dict(rust=0.5)),
('motor_oil_tin','0b69e10a','one',dict(rust=0.35)),
('truck_wheel','87533e42','one',dict(size=1.0,rust=0.2,paint=0.0,base_override=[0.07,0.07,0.07,1.0])),
('muddy_tire','19296738','cluster',dict(piece_size=0.62,rust=0.2,paint=0.0)),
('dirty_tire','3ac31ac8','obj',dict(piece_size=0.62,rust=0.2,paint=0.0)),
('stacked_tire','f9d64bd1','cluster',dict(piece_size=0.62,rust=0.2,paint=0.0)),
('rusty_chain','be9648f8','cluster',dict(scale=0.25,min=0.05,rust=0.2)),
('chain_shackles','924c7cc2','one',dict(size=0.6,rust=0.25)),
('iron_chain','fccedd90','one',dict(size=0.6,rust=0.35)),
('old_padlock','1353b1c4','one',dict(size=0.15,rust=0.4)),
('old_key','dcf61f79','one',dict(size=0.08,rust=0.4)),
('horse_shoe','17d5d616','one',dict(size=0.14,rust=0.4)),
('bolts_nuts','a7b0477b','cluster',dict(scale=0.0006,min=0.008,gap=0.0003,rust=0.45)),
('rusty_spark_plug','d634946e','one',dict(rust=0.25)),
('spark_plug','306c0031','one',dict(size=0.09,rust=0.45)),
('camshaft_scan','1f1c66b2','one',dict(size=0.45,rust=0.45)),
('electric_motor','66b2ea9e','one',dict(rust=0.4)),
('rusty_wrench','900caf6a','one',dict(size=0.2,rust=0.25)),
('rusty_pliers','31b548d2','one',dict(size=0.2,rust=0.2,exclude=['icosphere'])),
('old_wrench_scan','1bf090bb','one',dict(size=0.25,rust=0.3)),
('old_hammer','a3d7bc18','one',dict(size=0.32,rust=0.3)),
('rusty_sledgehammer_scan','0d4f90b8','one',dict(size=0.9,rust=0.2)),
('old_screwdriver','3d79e901','obj',dict(piece_size=0.22,rust=0.35)),
('pipe_wrench_2','9877bc3a','one',dict(rust=0.35)),
('rusted_bucket','ca0755cc','one',dict(size=0.3,rust=0.2)),
('soviet_fuel_canister','a2e479f5','one',dict(size=0.5,rust=0.2)),
('jerry_can','01fea903','obj',dict(piece_size=0.47,rust=0.55)),
('metal_sheet','b1994c52','one',dict(size=0.6,rust=0.4)),
('junk_scrap','c4615266','obj',dict(scale=0.67,rust=0.3,match=['RustedMetalPlate','Baznat','WoodBarBroken','MetalPlate_02','Old_Tire'])),
('cardboard_box','8986ba51','obj',dict(rust=0.0,paint=0.0,match=['430x210x270_1_','290x170x190_1_','290x290x290_1_','290x290x400_1_'])),
('old_ammo_crate','6a834e91','one',dict(size=0.6,rust=0.3,paint=0.3)),
('wooden_box','ddecbe45','obj',dict(rust=0.2,paint=0.0)),
('hand_made_pistol','1e83dccd','one',dict(W,size=0.2)),
('junk_magnum','0eeef674','one',dict(W,size=0.35)),
('scrap_smg','93341754','one',dict(W,size=0.6)),
('post_apo_smg','2affecbe','one',dict(W,size=0.6)),
('homemade_smg','7663ba7c','one',dict(W,size=0.6)),
('scrap_gatling','c213d60d','one',dict(W,size=1.2,match=['Object_11','Object_12'],local=True)),
('scrap_gun','61b72a1a','one',dict(W,size=0.9)),
('homemade_gun','25bca561','one',dict(W,size=1.0)),
('grenade_launcher','a6d47b3f','one',dict(W,size=0.8)),
('stylized_shotgun','795eebab','one',dict(W,size=1.0)),
]
assert len(C)==65, len(C)
seen=set()
for pid,u8,kind,o in C:
    uid=full[u8]; seen.add(uid)
    base={'src':f'{S}/dl/sketchfab/{uid}/model.glb','out':f'{S}/out','thumbs':f'{S}/thumbs','rust_dir':f'{S}/dl/ambientcg/Rust009','kaynak':uid}
    o=dict(o)
    if kind=='one': base['pieces']=[dict(o,id=pid)]
    elif kind=='obj': base['per_object']=dict(o,prefix=pid)
    elif kind=='cluster': base['cluster']=dict(o,prefix=pid)
    json.dump(base,open(f'{S}/jobs/sf_{pid}.json','w'),ensure_ascii=False)
assert seen==set(meta)
print('ok')
