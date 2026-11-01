import json,os,sys
S=sys.argv[1]
R={'can_rusted':.15,'russian_food_cans_01':.5,'oil_tin':.5,'cleaner_tin_01':.5,'spray_paint_bottles_02':.5,'small_oil_can_01':.5,
'rusted_wheel_rim_01':.1,'rusted_wheel_rim_02':.1,'old_tyre':.15,'gate_latch_01':.4,'adjustable_wrench':.55,'pipe_wrench':.5,
'combination_wrench':.55,'ratchet_wrench':.55,'pliers':.55,'tongue_groove_pliers':.55,'screwdriver':.5,'cross_pein_hammer':.5,
'crowbar_01':.5,'sledgehammer_01':.45,'rusted_hacksaw':.15,'bolt_cutters_01':.5,'rusted_spade_01':.1,'metal_jerrycan':.5,
'metal_jerrycan_green':.5,'watering_can_metal_01':.5,'metal_jug':.5,'small_lpg_tank':.5,'retro_multimeter':.4,'vintage_flashlight':.5,
'boombox':.4,'wooden_crate_01':.3,'wooden_crate_02':.3,'old_military_crate':.3,'wooden_military_crate':.3,'ammo_box':.5,
'metal_toolbox':.55,'cardboard_box_01':.3,'plastic_crate_03':.3}
SPLIT={'russian_food_cans_01':[('salt_box',['salt_box'],[]),('can_cond',['can_cond'],[]),('can_fish',['can_fish'],[])],
'spray_paint_bottles_02':[('a',None,['dented']),('dented',['dented'],[])],
'old_military_crate':[('a',['_a'],[]),('b',['_b'],[])]}
for k,r in R.items():
    pieces=[]
    if k in SPLIT:
        for suf,m,e in SPLIT[k]:
            pieces.append({'id':f'{k}_{suf}','match':m,'exclude':e,'rust':r,'set':k})
    else:
        pieces.append({'id':k,'rust':r})
    job={'src':f'{S}/dl/polyhaven/{k}/{k}.gltf','out':f'{S}/out','thumbs':f'{S}/thumbs','rust_dir':f'{S}/dl/ambientcg/Rust009','pieces':pieces}
    json.dump(job,open(f'{S}/jobs/ph_{k}.json','w'),ensure_ascii=False)
print(len(R))
