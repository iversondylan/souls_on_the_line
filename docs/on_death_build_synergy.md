Godot Engine v4.6.1.stable.official.14d19694e - https://godotengine.org
OpenGL API 4.1 Metal - 90.5 - Compatibility - Using Device: Apple - Apple M5 Pro

[0000] SCOPE_BEGIN tick=0 kind=BATTLE data{scope_id=1, parent_scope_id=0, kind=0, label="battle_seed=3639325152 run_seed=4046642009", actor_id=0, group_index=-1, turn_id=0}
	[0001] SCOPE_BEGIN tick=1 kind=SETUP data{scope_id=2, parent_scope_id=1, kind=1, label="setup", actor_id=0, group_index=-1, turn_id=0}
		[0002] SPAWNED tick=2 kind=SETUP data{group_index=0, insert_index=0, after_order_ids=[1], proto="res://character_profiles/Cole/cole_data.tres", spawned_id=1}
		[0003] SPAWNED tick=3 kind=SETUP data{group_index=1, insert_index=-1, after_order_ids=[2], proto="", spawned_id=2}
		[0004] SPAWNED tick=4 kind=SETUP data{group_index=1, insert_index=-1, after_order_ids=[2, 3], proto="", spawned_id=3}
		[0005] FORMATION_SET tick=5 kind=SETUP data{player_id=1}
	[0006] SCOPE_END tick=6 kind=SETUP data{scope_id=2, parent_scope_id=1, kind=1, label="setup", actor_id=0}
	[0007] SET_INTENT tick=7 kind=BATTLE data{actor_id=1, planned_idx=-1, intent_text="", is_ranged=false}
	[0008] SET_INTENT tick=8 kind=BATTLE data{actor_id=2, planned_idx=1, intent_text="3", is_ranged=false}
	[0009] SET_INTENT tick=9 kind=BATTLE data{actor_id=3, planned_idx=0, intent_text="2×2", is_ranged=true}
	[0010] SCOPE_BEGIN tick=10 t=1 g=0 kind=GROUP_TURN data{scope_id=3, parent_scope_id=1, kind=2, label="group=0", actor_id=0, group_index=0, turn_id=1}
		[0011] TURN_GROUP_BEGIN tick=11 t=1 g=0 kind=GROUP_TURN data{group_index=0, turn_id=1}
		[0012] TURN_STATUS tick=12 t=1 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=1, active_id=1, player_id=1, pending_ids=[1]}
		[0013] STATUS tick=13 t=1 g=0 a=1 kind=GROUP_TURN data{src=2 tgt=2 status=resonance_spike op=APPLY stk=2, target_ids=[2], before_stacks=0, after_stacks=2, delta_stacks=2, reason=""}
		[0014] SET_INTENT tick=14 t=1 g=0 a=1 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="5", is_ranged=false}
		[0015] SET_INTENT tick=15 t=1 g=0 a=1 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×4", is_ranged=true}
		[0016] STATUS tick=16 t=1 g=0 a=1 kind=GROUP_TURN data{src=2 tgt=2 status=stability op=APPLY stk=3, target_ids=[2], before_stacks=0, after_stacks=3, delta_stacks=3, reason=""}
		[0017] SET_INTENT tick=17 t=1 g=0 a=1 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="5", is_ranged=false}
		[0018] SET_INTENT tick=18 t=1 g=0 a=1 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×4", is_ranged=true}
		[0019] TURN_STATUS tick=19 t=1 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=1, active_id=1, player_id=1, pending_ids=[1]}
		[0020] SCOPE_BEGIN tick=20 t=1 g=0 a=1 kind=ARCANA data{scope_id=4, parent_scope_id=3, kind=11, label="battle_start", actor_id=0, group_index=0, turn_id=1}
			[0021] ARCANA_PROC tick=21 t=1 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=1, proc=0}
		[0022] SCOPE_END tick=22 t=1 g=0 a=1 kind=ARCANA data{scope_id=4, parent_scope_id=3, kind=11, label="battle_start", actor_id=0}
		[0023] SCOPE_BEGIN tick=23 t=1 g=0 a=1 kind=ARCANA data{scope_id=5, parent_scope_id=3, kind=11, label="player_turn_begin", actor_id=0, group_index=0, turn_id=1}
			[0024] ARCANA_PROC tick=24 t=1 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=1, proc=1}
		[0025] SCOPE_END tick=25 t=1 g=0 a=1 kind=ARCANA data{scope_id=5, parent_scope_id=3, kind=11, label="player_turn_begin", actor_id=0}
		[0026] TURN_STATUS tick=26 t=1 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=1, active_id=1, player_id=1, pending_ids=[]}
		[0027] SCOPE_BEGIN tick=27 t=1 g=0 a=1 kind=ACTOR_TURN data{scope_id=6, parent_scope_id=3, kind=3, label="actor=1", actor_id=1, group_index=0, turn_id=1}
			[0028] ACTOR_BEGIN tick=28 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=1, group_index=0, turn_id=1}
			[0029] PLAYER_INPUT_REACHED tick=29 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=1}
			[0030] DRAW_CARDS tick=30 t=1 g=0 a=1 kind=ACTOR_TURN data{source_id=1, amount=4, reason="player_turn_refill"}
			[0031] SCOPE_BEGIN tick=31 t=1 g=0 a=1 kind=CARD data{scope_id=7, parent_scope_id=6, kind=4, label="uid=1776823869_529503468_3774922356 Spectral Clone", actor_id=1, group_index=0, turn_id=1}
				[0032] CARD_PLAYED tick=32 t=1 g=0 a=1 kind=CARD data{source_id=1, card_id="spectral_clone", card_uid="1776823869_529503468_3774922356", card_name="Spectral Clone", insert_index=1, proto="res://cards/souls/SpectralCloneCard/spectral_clone.tres"}
				[0033] MANA tick=33 t=1 g=0 a=1 kind=CARD data{src=1 mana=3->2 Δmana=-1 max=3->3 reason="card_spend", card_uid="1776823869_529503468_3774922356", card_name="Spectral Clone", amount=1}
				[0034] SCOPE_BEGIN tick=34 t=1 g=0 a=1 kind=SUMMON_ACTION data{scope_id=8, parent_scope_id=7, kind=16, label="count=1 g=0 idx=1", actor_id=1, source_id=1, group_index=0, turn_id=1, insert_index=1, proto="", summon_count=1}
					[0035] SUMMONED * tick=35 t=1 g=0 a=1 kind=SUMMON_ACTION data{source_id=1, group_index=0, card_uid="1776823869_529503468_3774922356", insert_index=1, before_order_ids=[1], after_order_ids=[1, 4], reason="card_summon", summoned_id=4}
					[0036] TURN_STATUS tick=36 t=1 g=0 a=1 kind=SUMMON_ACTION data{group_index=0, turn_id=1, active_id=1, player_id=1, pending_ids=[4]}
				[0037] SCOPE_END tick=37 t=1 g=0 a=1 kind=SUMMON_ACTION data{scope_id=8, parent_scope_id=7, kind=16, label="count=1 g=0 idx=1", actor_id=1}
			[0038] SCOPE_END tick=38 t=1 g=0 a=1 kind=CARD data{scope_id=7, parent_scope_id=6, kind=4, label="uid=1776823869_529503468_3774922356 Spectral Clone", actor_id=1}
			[0039] SET_INTENT tick=39 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=4, planned_idx=0, intent_text="3", is_ranged=true}
			[0040] TURN_STATUS tick=40 t=1 g=0 a=1 kind=ACTOR_TURN data{group_index=0, turn_id=1, active_id=1, player_id=1, pending_ids=[4]}
			[0041] SCOPE_BEGIN tick=41 t=1 g=0 a=1 kind=CARD data{scope_id=9, parent_scope_id=6, kind=4, label="uid=1776823869_3490884667_3774922356 Spectral Clone", actor_id=1, group_index=0, turn_id=1}
				[0042] CARD_PLAYED tick=42 t=1 g=0 a=1 kind=CARD data{source_id=1, card_id="spectral_clone", card_uid="1776823869_3490884667_3774922356", card_name="Spectral Clone", insert_index=0, proto="res://cards/souls/SpectralCloneCard/spectral_clone.tres"}
				[0043] MANA tick=43 t=1 g=0 a=1 kind=CARD data{src=1 mana=2->1 Δmana=-1 max=3->3 reason="card_spend", card_uid="1776823869_3490884667_3774922356", card_name="Spectral Clone", amount=1}
				[0044] SCOPE_BEGIN tick=44 t=1 g=0 a=1 kind=SUMMON_ACTION data{scope_id=10, parent_scope_id=9, kind=16, label="count=1 g=0 idx=0", actor_id=1, source_id=1, group_index=0, turn_id=1, insert_index=0, proto="", summon_count=1}
					[0045] SUMMONED * tick=45 t=1 g=0 a=1 kind=SUMMON_ACTION data{source_id=1, group_index=0, card_uid="1776823869_3490884667_3774922356", insert_index=0, before_order_ids=[1, 4], after_order_ids=[5, 1, 4], reason="card_summon", summoned_id=5}
					[0046] TURN_STATUS tick=46 t=1 g=0 a=1 kind=SUMMON_ACTION data{group_index=0, turn_id=1, active_id=1, player_id=1, pending_ids=[4]}
				[0047] SCOPE_END tick=47 t=1 g=0 a=1 kind=SUMMON_ACTION data{scope_id=10, parent_scope_id=9, kind=16, label="count=1 g=0 idx=0", actor_id=1}
			[0048] SCOPE_END tick=48 t=1 g=0 a=1 kind=CARD data{scope_id=9, parent_scope_id=6, kind=4, label="uid=1776823869_3490884667_3774922356 Spectral Clone", actor_id=1}
			[0049] SET_INTENT tick=49 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=5, planned_idx=0, intent_text="3", is_ranged=false}
			[0050] TURN_STATUS tick=50 t=1 g=0 a=1 kind=ACTOR_TURN data{group_index=0, turn_id=1, active_id=1, player_id=1, pending_ids=[4]}
			[0051] SCOPE_BEGIN tick=51 t=1 g=0 a=1 kind=CARD data{scope_id=11, parent_scope_id=6, kind=4, label="uid=1776823869_1235810078_707204541 Phoenix Brooch", actor_id=1, group_index=0, turn_id=1}
				[0052] CARD_PLAYED tick=52 t=1 g=0 a=1 kind=CARD data{source_id=1, card_id="phoenix_brooch", card_uid="1776823869_1235810078_707204541", card_name="Phoenix Brooch", insert_index=-1, proto="res://cards/enchantments/PhoenixBrooch/phoenix_brooch.tres"}
				[0053] MANA tick=53 t=1 g=0 a=1 kind=CARD data{src=1 mana=1->0 Δmana=-1 max=3->3 reason="card_spend", card_uid="1776823869_1235810078_707204541", card_name="Phoenix Brooch", amount=1}
				[0054] STATUS tick=54 t=1 g=0 a=1 kind=CARD data{src=1 tgt=5 status=phoenix_brooch op=APPLY stk=1, target_ids=[5], before_stacks=0, after_stacks=1, delta_stacks=1, reason=""}
			[0055] SCOPE_END tick=55 t=1 g=0 a=1 kind=CARD data{scope_id=11, parent_scope_id=6, kind=4, label="uid=1776823869_1235810078_707204541 Phoenix Brooch", actor_id=1}
			[0056] SET_INTENT tick=56 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=5, planned_idx=0, intent_text="3", is_ranged=false}
			[0057] END_TURN_PRESSED tick=57 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=1}
			[0058] DISCARD_CARDS tick=58 t=1 g=0 a=1 kind=ACTOR_TURN data{source_id=1, card_uid="", amount=0, reason="player_turn_end_discard"}
			[0059] SCOPE_BEGIN tick=59 t=1 g=0 a=1 kind=ARCANA data{scope_id=12, parent_scope_id=6, kind=11, label="player_turn_end", actor_id=0, group_index=0, turn_id=1}
				[0060] ARCANA_PROC tick=60 t=1 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=1, proc=2}
			[0061] SCOPE_END tick=61 t=1 g=0 a=1 kind=ARCANA data{scope_id=12, parent_scope_id=6, kind=11, label="player_turn_end", actor_id=0}
			[0062] ACTOR_END tick=62 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=1, group_index=0, turn_id=1}
		[0063] SCOPE_END tick=63 t=1 g=0 a=1 kind=ACTOR_TURN data{scope_id=6, parent_scope_id=3, kind=3, label="actor=1", actor_id=1}
		[0064] TURN_STATUS tick=64 t=1 g=0 a=4 kind=GROUP_TURN data{group_index=0, turn_id=1, active_id=4, player_id=1, pending_ids=[]}
		[0065] SCOPE_BEGIN tick=65 t=1 g=0 a=4 kind=ACTOR_TURN data{scope_id=13, parent_scope_id=3, kind=3, label="actor=4", actor_id=4, group_index=0, turn_id=1}
			[0066] ACTOR_BEGIN tick=66 t=1 g=0 a=4 kind=ACTOR_TURN data{actor_id=4, group_index=0, turn_id=1}
			[0067] SCOPE_BEGIN tick=67 t=1 g=0 a=4 kind=ATTACK data{scope_id=14, parent_scope_id=13, kind=5, label="attacker=4", actor_id=4, group_index=0, turn_id=1}
				[0068] SCOPE_BEGIN tick=68 t=1 g=0 a=4 kind=STRIKE data{scope_id=15, parent_scope_id=14, kind=13, label="i=0", actor_id=4, group_index=0, turn_id=1}
					[0069] STRIKE * tick=69 t=1 g=0 a=4 kind=STRIKE data{source_id=4, target_ids=[2]}
					[0070] SCOPE_BEGIN tick=70 t=1 g=0 a=4 kind=HIT data{scope_id=16, parent_scope_id=15, kind=15, label="t=2", actor_id=4, target_id=2, group_index=0, turn_id=1}
						[0071] DAMAGE_APPLIED tick=71 t=1 g=0 a=4 kind=HIT data{source_id=4, target_id=2, before_health=30, after_health=27, base=3, base_banish=0, amount=3, display_amount=3, banish_amount=0, applied_banish_amount=0, health_damage=3, was_lethal=false}
						[0072] STATUS tick=72 t=1 g=0 a=4 kind=HIT data{src=2 tgt=2 status=stability op=CHANGE stk=0, target_ids=[2], before_stacks=3, after_stacks=0, delta_stacks=-3, reason="damage_taken"}
						[0073] STATUS tick=73 t=1 g=0 a=4 kind=HIT data{src=2 tgt=2 status=stability op=REMOVE stk=0, target_ids=[2], before_stacks=0, after_stacks=0, delta_stacks=0, reason=""}
						[0074] SET_INTENT tick=74 t=1 g=0 a=4 kind=HIT data{actor_id=2, planned_idx=-1, intent_text="", is_ranged=false}
						[0075] SET_INTENT tick=75 t=1 g=0 a=4 kind=HIT data{actor_id=2, planned_idx=-1, intent_text="", is_ranged=false}
						[0076] SET_INTENT tick=76 t=1 g=0 a=4 kind=HIT data{actor_id=3, planned_idx=0, intent_text="2×2", is_ranged=true}
						[0077] STATUS tick=77 t=1 g=0 a=4 kind=HIT data{src=2 tgt=2 status=resonance_spike op=REMOVE stk=0, target_ids=[2], before_stacks=2, after_stacks=0, delta_stacks=-2, reason=""}
						[0078] SET_INTENT tick=78 t=1 g=0 a=4 kind=HIT data{actor_id=2, planned_idx=-1, intent_text="", is_ranged=false}
					[0079] SCOPE_END tick=79 t=1 g=0 a=4 kind=HIT data{scope_id=16, parent_scope_id=15, kind=15, label="t=2", actor_id=4}
				[0080] SCOPE_END tick=80 t=1 g=0 a=4 kind=STRIKE data{scope_id=15, parent_scope_id=14, kind=13, label="i=0", actor_id=4}
			[0081] SCOPE_END tick=81 t=1 g=0 a=4 kind=ATTACK data{scope_id=14, parent_scope_id=13, kind=5, label="attacker=4", actor_id=4}
			[0082] ACTOR_END tick=82 t=1 g=0 a=4 kind=ACTOR_TURN data{actor_id=4, group_index=0, turn_id=1}
		[0083] SCOPE_END tick=83 t=1 g=0 a=4 kind=ACTOR_TURN data{scope_id=13, parent_scope_id=3, kind=3, label="actor=4", actor_id=4}
		[0084] SET_INTENT tick=84 t=1 g=0 a=4 kind=GROUP_TURN data{actor_id=2, planned_idx=0, intent_text="1", is_ranged=false}
		[0085] SET_INTENT tick=85 t=1 g=0 a=4 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×2", is_ranged=true}
		[0086] SET_INTENT tick=86 t=1 g=0 a=4 kind=GROUP_TURN data{actor_id=4, planned_idx=0, intent_text="3", is_ranged=true}
		[0087] TURN_GROUP_END tick=87 t=1 g=0 a=4 kind=GROUP_TURN data{group_index=0, turn_id=1}
	[0088] SCOPE_END tick=88 t=1 g=0 a=4 kind=GROUP_TURN data{scope_id=3, parent_scope_id=1, kind=2, label="group=0", actor_id=0}
	[0089] SCOPE_BEGIN tick=89 t=2 g=1 kind=GROUP_TURN data{scope_id=17, parent_scope_id=1, kind=2, label="group=1", actor_id=0, group_index=1, turn_id=2}
		[0090] TURN_GROUP_BEGIN tick=90 t=2 g=1 kind=GROUP_TURN data{group_index=1, turn_id=2}
		[0091] TURN_STATUS tick=91 t=2 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=2, active_id=2, player_id=1, pending_ids=[2, 3]}
		[0092] TURN_STATUS tick=92 t=2 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=2, active_id=2, player_id=1, pending_ids=[3]}
		[0093] SCOPE_BEGIN tick=93 t=2 g=1 a=2 kind=ACTOR_TURN data{scope_id=18, parent_scope_id=17, kind=3, label="actor=2", actor_id=2, group_index=1, turn_id=2}
			[0094] ACTOR_BEGIN tick=94 t=2 g=1 a=2 kind=ACTOR_TURN data{actor_id=2, group_index=1, turn_id=2}
			[0095] SCOPE_BEGIN tick=95 t=2 g=1 a=2 kind=ATTACK data{scope_id=19, parent_scope_id=18, kind=5, label="attacker=2", actor_id=2, group_index=1, turn_id=2}
				[0096] SCOPE_BEGIN tick=96 t=2 g=1 a=2 kind=STRIKE data{scope_id=20, parent_scope_id=19, kind=13, label="i=0", actor_id=2, group_index=1, turn_id=2}
					[0097] STRIKE * tick=97 t=2 g=1 a=2 kind=STRIKE data{source_id=2, target_ids=[5]}
					[0098] SCOPE_BEGIN tick=98 t=2 g=1 a=2 kind=HIT data{scope_id=21, parent_scope_id=20, kind=15, label="t=5", actor_id=2, target_id=5, group_index=1, turn_id=2}
						[0099] DAMAGE_APPLIED tick=99 t=2 g=1 a=2 kind=HIT data{source_id=2, target_id=5, before_health=3, after_health=2, base=1, base_banish=0, amount=1, display_amount=1, banish_amount=0, applied_banish_amount=0, health_damage=1, was_lethal=false}
					[0100] SCOPE_END tick=100 t=2 g=1 a=2 kind=HIT data{scope_id=21, parent_scope_id=20, kind=15, label="t=5", actor_id=2}
				[0101] SCOPE_END tick=101 t=2 g=1 a=2 kind=STRIKE data{scope_id=20, parent_scope_id=19, kind=13, label="i=0", actor_id=2}
			[0102] SCOPE_END tick=102 t=2 g=1 a=2 kind=ATTACK data{scope_id=19, parent_scope_id=18, kind=5, label="attacker=2", actor_id=2}
			[0103] ACTOR_END tick=103 t=2 g=1 a=2 kind=ACTOR_TURN data{actor_id=2, group_index=1, turn_id=2}
		[0104] SCOPE_END tick=104 t=2 g=1 a=2 kind=ACTOR_TURN data{scope_id=18, parent_scope_id=17, kind=3, label="actor=2", actor_id=2}
		[0105] SET_INTENT tick=105 t=2 g=1 a=2 kind=GROUP_TURN data{actor_id=5, planned_idx=0, intent_text="3", is_ranged=false}
		[0106] SET_INTENT tick=106 t=2 g=1 a=2 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="3", is_ranged=false}
		[0107] TURN_STATUS tick=107 t=2 g=1 a=3 kind=GROUP_TURN data{group_index=1, turn_id=2, active_id=3, player_id=1, pending_ids=[]}
		[0108] SCOPE_BEGIN tick=108 t=2 g=1 a=3 kind=ACTOR_TURN data{scope_id=22, parent_scope_id=17, kind=3, label="actor=3", actor_id=3, group_index=1, turn_id=2}
			[0109] ACTOR_BEGIN tick=109 t=2 g=1 a=3 kind=ACTOR_TURN data{actor_id=3, group_index=1, turn_id=2}
			[0110] SCOPE_BEGIN tick=110 t=2 g=1 a=3 kind=ATTACK data{scope_id=23, parent_scope_id=22, kind=5, label="attacker=3", actor_id=3, group_index=1, turn_id=2}
				[0111] SCOPE_BEGIN tick=111 t=2 g=1 a=3 kind=STRIKE data{scope_id=24, parent_scope_id=23, kind=13, label="i=0", actor_id=3, group_index=1, turn_id=2}
					[0112] STRIKE * tick=112 t=2 g=1 a=3 kind=STRIKE data{source_id=3, target_ids=[5]}
					[0113] SCOPE_BEGIN tick=113 t=2 g=1 a=3 kind=HIT data{scope_id=25, parent_scope_id=24, kind=15, label="t=5", actor_id=3, target_id=5, group_index=1, turn_id=2}
						[0114] DAMAGE_APPLIED tick=114 t=2 g=1 a=3 kind=HIT data{source_id=3, target_id=5, before_health=2, after_health=0, base=2, base_banish=0, amount=2, display_amount=2, banish_amount=0, applied_banish_amount=0, health_damage=2, was_lethal=true}
						[0115] HEAL_APPLIED tick=115 t=2 g=1 a=3 kind=HIT data{source_id=5, target_id=5, before_health=0, after_health=3}
						[0116] STATUS tick=116 t=2 g=1 a=3 kind=HIT data{src=5 tgt=5 status=phoenix_brooch op=REMOVE stk=0, target_ids=[5], before_stacks=1, after_stacks=0, delta_stacks=-1, reason=""}
					[0117] SCOPE_END tick=117 t=2 g=1 a=3 kind=HIT data{scope_id=25, parent_scope_id=24, kind=15, label="t=5", actor_id=3}
				[0118] SCOPE_END tick=118 t=2 g=1 a=3 kind=STRIKE data{scope_id=24, parent_scope_id=23, kind=13, label="i=0", actor_id=3}
				[0119] SCOPE_BEGIN tick=119 t=2 g=1 a=3 kind=STRIKE data{scope_id=26, parent_scope_id=23, kind=13, label="i=1", actor_id=3, group_index=1, turn_id=2}
					[0120] STRIKE * tick=120 t=2 g=1 a=3 kind=STRIKE data{source_id=3, target_ids=[5]}
					[0121] SCOPE_BEGIN tick=121 t=2 g=1 a=3 kind=HIT data{scope_id=27, parent_scope_id=26, kind=15, label="t=5", actor_id=3, target_id=5, group_index=1, turn_id=2}
						[0122] DAMAGE_APPLIED tick=122 t=2 g=1 a=3 kind=HIT data{source_id=3, target_id=5, before_health=3, after_health=1, base=2, base_banish=0, amount=2, display_amount=2, banish_amount=0, applied_banish_amount=0, health_damage=2, was_lethal=false}
					[0123] SCOPE_END tick=123 t=2 g=1 a=3 kind=HIT data{scope_id=27, parent_scope_id=26, kind=15, label="t=5", actor_id=3}
				[0124] SCOPE_END tick=124 t=2 g=1 a=3 kind=STRIKE data{scope_id=26, parent_scope_id=23, kind=13, label="i=1", actor_id=3}
			[0125] SCOPE_END tick=125 t=2 g=1 a=3 kind=ATTACK data{scope_id=23, parent_scope_id=22, kind=5, label="attacker=3", actor_id=3}
			[0126] ACTOR_END tick=126 t=2 g=1 a=3 kind=ACTOR_TURN data{actor_id=3, group_index=1, turn_id=2}
		[0127] SCOPE_END tick=127 t=2 g=1 a=3 kind=ACTOR_TURN data{scope_id=22, parent_scope_id=17, kind=3, label="actor=3", actor_id=3}
		[0128] SET_INTENT tick=128 t=2 g=1 a=3 kind=GROUP_TURN data{actor_id=5, planned_idx=0, intent_text="3", is_ranged=false}
		[0129] SET_INTENT tick=129 t=2 g=1 a=3 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×2", is_ranged=true}
		[0130] TURN_GROUP_END tick=130 t=2 g=1 a=3 kind=GROUP_TURN data{group_index=1, turn_id=2}
	[0131] SCOPE_END tick=131 t=2 g=1 a=3 kind=GROUP_TURN data{scope_id=17, parent_scope_id=1, kind=2, label="group=1", actor_id=0}
	[0132] SCOPE_BEGIN tick=132 t=3 g=0 kind=GROUP_TURN data{scope_id=28, parent_scope_id=1, kind=2, label="group=0", actor_id=0, group_index=0, turn_id=3}
		[0133] TURN_GROUP_BEGIN tick=133 t=3 g=0 kind=GROUP_TURN data{group_index=0, turn_id=3}
		[0134] MANA tick=134 t=3 g=0 kind=GROUP_TURN data{src=1 mana=0->3 Δmana=+3 max=3->3 reason="group_turn_begin_refresh"}
		[0135] STATUS tick=135 t=3 g=0 kind=GROUP_TURN data{src=2 tgt=2 status=resonance_spike op=APPLY stk=2, target_ids=[2], before_stacks=0, after_stacks=2, delta_stacks=2, reason=""}
		[0136] SET_INTENT tick=136 t=3 g=0 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="5", is_ranged=false}
		[0137] SET_INTENT tick=137 t=3 g=0 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×4", is_ranged=true}
		[0138] STATUS tick=138 t=3 g=0 kind=GROUP_TURN data{src=2 tgt=2 status=stability op=APPLY stk=3, target_ids=[2], before_stacks=0, after_stacks=3, delta_stacks=3, reason=""}
		[0139] SET_INTENT tick=139 t=3 g=0 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="5", is_ranged=false}
		[0140] SET_INTENT tick=140 t=3 g=0 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×4", is_ranged=true}
		[0141] TURN_STATUS tick=141 t=3 g=0 a=5 kind=GROUP_TURN data{group_index=0, turn_id=3, active_id=5, player_id=1, pending_ids=[5]}
		[0142] TURN_STATUS tick=142 t=3 g=0 a=5 kind=GROUP_TURN data{group_index=0, turn_id=3, active_id=5, player_id=1, pending_ids=[]}
		[0143] SCOPE_BEGIN tick=143 t=3 g=0 a=5 kind=ACTOR_TURN data{scope_id=29, parent_scope_id=28, kind=3, label="actor=5", actor_id=5, group_index=0, turn_id=3}
			[0144] ACTOR_BEGIN tick=144 t=3 g=0 a=5 kind=ACTOR_TURN data{actor_id=5, group_index=0, turn_id=3}
			[0145] SCOPE_BEGIN tick=145 t=3 g=0 a=5 kind=ATTACK data{scope_id=30, parent_scope_id=29, kind=5, label="attacker=5", actor_id=5, group_index=0, turn_id=3}
				[0146] SCOPE_BEGIN tick=146 t=3 g=0 a=5 kind=STRIKE data{scope_id=31, parent_scope_id=30, kind=13, label="i=0", actor_id=5, group_index=0, turn_id=3}
					[0147] STRIKE * tick=147 t=3 g=0 a=5 kind=STRIKE data{source_id=5, target_ids=[2]}
					[0148] SCOPE_BEGIN tick=148 t=3 g=0 a=5 kind=HIT data{scope_id=32, parent_scope_id=31, kind=15, label="t=2", actor_id=5, target_id=2, group_index=0, turn_id=3}
						[0149] DAMAGE_APPLIED tick=149 t=3 g=0 a=5 kind=HIT data{source_id=5, target_id=2, before_health=27, after_health=24, base=3, base_banish=0, amount=3, display_amount=3, banish_amount=0, applied_banish_amount=0, health_damage=3, was_lethal=false}
						[0150] STATUS tick=150 t=3 g=0 a=5 kind=HIT data{src=2 tgt=2 status=stability op=CHANGE stk=0, target_ids=[2], before_stacks=3, after_stacks=0, delta_stacks=-3, reason="damage_taken"}
						[0151] STATUS tick=151 t=3 g=0 a=5 kind=HIT data{src=2 tgt=2 status=stability op=REMOVE stk=0, target_ids=[2], before_stacks=0, after_stacks=0, delta_stacks=0, reason=""}
						[0152] SET_INTENT tick=152 t=3 g=0 a=5 kind=HIT data{actor_id=2, planned_idx=-1, intent_text="", is_ranged=false}
						[0153] SET_INTENT tick=153 t=3 g=0 a=5 kind=HIT data{actor_id=2, planned_idx=-1, intent_text="", is_ranged=false}
						[0154] SET_INTENT tick=154 t=3 g=0 a=5 kind=HIT data{actor_id=3, planned_idx=0, intent_text="2×2", is_ranged=true}
						[0155] STATUS tick=155 t=3 g=0 a=5 kind=HIT data{src=2 tgt=2 status=resonance_spike op=REMOVE stk=0, target_ids=[2], before_stacks=2, after_stacks=0, delta_stacks=-2, reason=""}
						[0156] SET_INTENT tick=156 t=3 g=0 a=5 kind=HIT data{actor_id=2, planned_idx=-1, intent_text="", is_ranged=false}
					[0157] SCOPE_END tick=157 t=3 g=0 a=5 kind=HIT data{scope_id=32, parent_scope_id=31, kind=15, label="t=2", actor_id=5}
				[0158] SCOPE_END tick=158 t=3 g=0 a=5 kind=STRIKE data{scope_id=31, parent_scope_id=30, kind=13, label="i=0", actor_id=5}
			[0159] SCOPE_END tick=159 t=3 g=0 a=5 kind=ATTACK data{scope_id=30, parent_scope_id=29, kind=5, label="attacker=5", actor_id=5}
			[0160] ACTOR_END tick=160 t=3 g=0 a=5 kind=ACTOR_TURN data{actor_id=5, group_index=0, turn_id=3}
		[0161] SCOPE_END tick=161 t=3 g=0 a=5 kind=ACTOR_TURN data{scope_id=29, parent_scope_id=28, kind=3, label="actor=5", actor_id=5}
		[0162] SET_INTENT tick=162 t=3 g=0 a=5 kind=GROUP_TURN data{actor_id=2, planned_idx=0, intent_text="1", is_ranged=false}
		[0163] SET_INTENT tick=163 t=3 g=0 a=5 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×2", is_ranged=true}
		[0164] SET_INTENT tick=164 t=3 g=0 a=5 kind=GROUP_TURN data{actor_id=5, planned_idx=0, intent_text="3", is_ranged=false}
		[0165] TURN_GROUP_END tick=165 t=3 g=0 a=5 kind=GROUP_TURN data{group_index=0, turn_id=3}
	[0166] SCOPE_END tick=166 t=3 g=0 a=5 kind=GROUP_TURN data{scope_id=28, parent_scope_id=1, kind=2, label="group=0", actor_id=0}
	[0167] SCOPE_BEGIN tick=167 t=4 g=0 kind=GROUP_TURN data{scope_id=33, parent_scope_id=1, kind=2, label="group=0", actor_id=0, group_index=0, turn_id=4}
		[0168] TURN_GROUP_BEGIN tick=168 t=4 g=0 kind=GROUP_TURN data{group_index=0, turn_id=4}
		[0169] TURN_STATUS tick=169 t=4 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=4, active_id=1, player_id=1, pending_ids=[1, 4]}
		[0170] SCOPE_BEGIN tick=170 t=4 g=0 a=1 kind=ARCANA data{scope_id=34, parent_scope_id=33, kind=11, label="player_turn_begin", actor_id=0, group_index=0, turn_id=4}
			[0171] ARCANA_PROC tick=171 t=4 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=4, proc=1}
		[0172] SCOPE_END tick=172 t=4 g=0 a=1 kind=ARCANA data{scope_id=34, parent_scope_id=33, kind=11, label="player_turn_begin", actor_id=0}
		[0173] TURN_STATUS tick=173 t=4 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=4, active_id=1, player_id=1, pending_ids=[4]}
		[0174] SCOPE_BEGIN tick=174 t=4 g=0 a=1 kind=ACTOR_TURN data{scope_id=35, parent_scope_id=33, kind=3, label="actor=1", actor_id=1, group_index=0, turn_id=4}
			[0175] ACTOR_BEGIN tick=175 t=4 g=0 a=1 kind=ACTOR_TURN data{actor_id=1, group_index=0, turn_id=4}
			[0176] PLAYER_INPUT_REACHED tick=176 t=4 g=0 a=1 kind=ACTOR_TURN data{actor_id=1}
			[0177] DRAW_CARDS tick=177 t=4 g=0 a=1 kind=ACTOR_TURN data{source_id=1, amount=4, reason="player_turn_refill"}
			[0178] SCOPE_BEGIN tick=178 t=4 g=0 a=1 kind=CARD data{scope_id=36, parent_scope_id=35, kind=4, label="uid=1776823869_1298587396_2534614519 Pocket Silkstitchers", actor_id=1, group_index=0, turn_id=4}
				[0179] CARD_PLAYED tick=179 t=4 g=0 a=1 kind=CARD data{source_id=1, card_id="pocket_silkstitchers", card_uid="1776823869_1298587396_2534614519", card_name="Pocket Silkstitchers", insert_index=-1, proto="res://cards/enchantments/PocketSilkstitchers/pocket_silkstitchers.tres"}
				[0180] MANA tick=180 t=4 g=0 a=1 kind=CARD data{src=1 mana=3->1 Δmana=-2 max=3->3 reason="card_spend", card_uid="1776823869_1298587396_2534614519", card_name="Pocket Silkstitchers", amount=2}
				[0181] STATUS tick=181 t=4 g=0 a=1 kind=CARD data{src=1 tgt=1 status=pocket_silkstitchers op=APPLY stk=1, target_ids=[1], before_stacks=0, after_stacks=1, delta_stacks=1, reason=""}
				[0182] STATUS tick=182 t=4 g=0 a=1 kind=CARD data{src=1 tgt=1 status=pocket_silkstitchers op=CHANGE stk=1, target_ids=[1], before_stacks=1, after_stacks=1, delta_stacks=0, reason="pocket_silkstitchers_apply"}
			[0183] SCOPE_END tick=183 t=4 g=0 a=1 kind=CARD data{scope_id=36, parent_scope_id=35, kind=4, label="uid=1776823869_1298587396_2534614519 Pocket Silkstitchers", actor_id=1}
			[0184] SCOPE_BEGIN tick=184 t=4 g=0 a=1 kind=CARD data{scope_id=37, parent_scope_id=35, kind=4, label="uid=1776823869_3808548613_4150313248 Barkbound Bond", actor_id=1, group_index=0, turn_id=4}
				[0185] CARD_PLAYED tick=185 t=4 g=0 a=1 kind=CARD data{source_id=1, card_id="barkbound_bond", card_uid="1776823869_3808548613_4150313248", card_name="Barkbound Bond", insert_index=-1, proto="res://cards/convocations/BarkboundBond/barkbound_bond.tres"}
				[0186] MANA tick=186 t=4 g=0 a=1 kind=CARD data{src=1 mana=1->0 Δmana=-1 max=3->3 reason="card_spend", card_uid="1776823869_3808548613_4150313248", card_name="Barkbound Bond", amount=1}
				[0187] STATUS tick=187 t=4 g=0 a=1 kind=CARD data{src=1 tgt=5 status=barkbound_bond op=APPLY stk=2, target_ids=[5], before_stacks=0, after_stacks=2, delta_stacks=2, reason=""}
				[0188] DRAW_CARDS tick=188 t=4 g=0 a=1 kind=CARD data{source_id=1, amount=1, reason="CardAction"}
			[0189] SCOPE_END tick=189 t=4 g=0 a=1 kind=CARD data{scope_id=37, parent_scope_id=35, kind=4, label="uid=1776823869_3808548613_4150313248 Barkbound Bond", actor_id=1}
			[0190] SET_INTENT tick=190 t=4 g=0 a=1 kind=ACTOR_TURN data{actor_id=5, planned_idx=0, intent_text="3", is_ranged=false}
			[0191] END_TURN_PRESSED tick=191 t=4 g=0 a=1 kind=ACTOR_TURN data{actor_id=1}
			[0192] DISCARD_CARDS tick=192 t=4 g=0 a=1 kind=ACTOR_TURN data{source_id=1, card_uid="", amount=0, reason="player_turn_end_discard"}
			[0193] SCOPE_BEGIN tick=193 t=4 g=0 a=1 kind=ARCANA data{scope_id=38, parent_scope_id=35, kind=11, label="player_turn_end", actor_id=0, group_index=0, turn_id=4}
				[0194] ARCANA_PROC tick=194 t=4 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=4, proc=2}
			[0195] SCOPE_END tick=195 t=4 g=0 a=1 kind=ARCANA data{scope_id=38, parent_scope_id=35, kind=11, label="player_turn_end", actor_id=0}
			[0196] ACTOR_END tick=196 t=4 g=0 a=1 kind=ACTOR_TURN data{actor_id=1, group_index=0, turn_id=4}
		[0197] SCOPE_END tick=197 t=4 g=0 a=1 kind=ACTOR_TURN data{scope_id=35, parent_scope_id=33, kind=3, label="actor=1", actor_id=1}
		[0198] TURN_STATUS tick=198 t=4 g=0 a=4 kind=GROUP_TURN data{group_index=0, turn_id=4, active_id=4, player_id=1, pending_ids=[]}
		[0199] SCOPE_BEGIN tick=199 t=4 g=0 a=4 kind=ACTOR_TURN data{scope_id=39, parent_scope_id=33, kind=3, label="actor=4", actor_id=4, group_index=0, turn_id=4}
			[0200] ACTOR_BEGIN tick=200 t=4 g=0 a=4 kind=ACTOR_TURN data{actor_id=4, group_index=0, turn_id=4}
			[0201] SCOPE_BEGIN tick=201 t=4 g=0 a=4 kind=ATTACK data{scope_id=40, parent_scope_id=39, kind=5, label="attacker=4", actor_id=4, group_index=0, turn_id=4}
				[0202] SCOPE_BEGIN tick=202 t=4 g=0 a=4 kind=STRIKE data{scope_id=41, parent_scope_id=40, kind=13, label="i=0", actor_id=4, group_index=0, turn_id=4}
					[0203] STRIKE * tick=203 t=4 g=0 a=4 kind=STRIKE data{source_id=4, target_ids=[2]}
					[0204] SCOPE_BEGIN tick=204 t=4 g=0 a=4 kind=HIT data{scope_id=42, parent_scope_id=41, kind=15, label="t=2", actor_id=4, target_id=2, group_index=0, turn_id=4}
						[0205] DAMAGE_APPLIED tick=205 t=4 g=0 a=4 kind=HIT data{source_id=4, target_id=2, before_health=24, after_health=21, base=3, base_banish=0, amount=3, display_amount=3, banish_amount=0, applied_banish_amount=0, health_damage=3, was_lethal=false}
					[0206] SCOPE_END tick=206 t=4 g=0 a=4 kind=HIT data{scope_id=42, parent_scope_id=41, kind=15, label="t=2", actor_id=4}
				[0207] SCOPE_END tick=207 t=4 g=0 a=4 kind=STRIKE data{scope_id=41, parent_scope_id=40, kind=13, label="i=0", actor_id=4}
			[0208] SCOPE_END tick=208 t=4 g=0 a=4 kind=ATTACK data{scope_id=40, parent_scope_id=39, kind=5, label="attacker=4", actor_id=4}
			[0209] ACTOR_END tick=209 t=4 g=0 a=4 kind=ACTOR_TURN data{actor_id=4, group_index=0, turn_id=4}
		[0210] SCOPE_END tick=210 t=4 g=0 a=4 kind=ACTOR_TURN data{scope_id=39, parent_scope_id=33, kind=3, label="actor=4", actor_id=4}
		[0211] SET_INTENT tick=211 t=4 g=0 a=4 kind=GROUP_TURN data{actor_id=2, planned_idx=0, intent_text="1", is_ranged=false}
		[0212] SET_INTENT tick=212 t=4 g=0 a=4 kind=GROUP_TURN data{actor_id=4, planned_idx=0, intent_text="3", is_ranged=true}
		[0213] TURN_GROUP_END tick=213 t=4 g=0 a=4 kind=GROUP_TURN data{group_index=0, turn_id=4}
	[0214] SCOPE_END tick=214 t=4 g=0 a=4 kind=GROUP_TURN data{scope_id=33, parent_scope_id=1, kind=2, label="group=0", actor_id=0}
	[0215] SCOPE_BEGIN tick=215 t=5 g=1 kind=GROUP_TURN data{scope_id=43, parent_scope_id=1, kind=2, label="group=1", actor_id=0, group_index=1, turn_id=5}
		[0216] TURN_GROUP_BEGIN tick=216 t=5 g=1 kind=GROUP_TURN data{group_index=1, turn_id=5}
		[0217] TURN_STATUS tick=217 t=5 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=5, active_id=2, player_id=1, pending_ids=[2, 3]}
		[0218] TURN_STATUS tick=218 t=5 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=5, active_id=2, player_id=1, pending_ids=[3]}
		[0219] SCOPE_BEGIN tick=219 t=5 g=1 a=2 kind=ACTOR_TURN data{scope_id=44, parent_scope_id=43, kind=3, label="actor=2", actor_id=2, group_index=1, turn_id=5}
			[0220] ACTOR_BEGIN tick=220 t=5 g=1 a=2 kind=ACTOR_TURN data{actor_id=2, group_index=1, turn_id=5}
			[0221] SCOPE_BEGIN tick=221 t=5 g=1 a=2 kind=ATTACK data{scope_id=45, parent_scope_id=44, kind=5, label="attacker=2", actor_id=2, group_index=1, turn_id=5}
				[0222] SCOPE_BEGIN tick=222 t=5 g=1 a=2 kind=STRIKE data{scope_id=46, parent_scope_id=45, kind=13, label="i=0", actor_id=2, group_index=1, turn_id=5}
					[0223] STRIKE * tick=223 t=5 g=1 a=2 kind=STRIKE data{source_id=2, target_ids=[5]}
					[0224] SCOPE_BEGIN tick=224 t=5 g=1 a=2 kind=HIT data{scope_id=47, parent_scope_id=46, kind=15, label="t=5", actor_id=2, target_id=5, group_index=1, turn_id=5}
						[0225] DAMAGE_APPLIED tick=225 t=5 g=1 a=2 kind=HIT data{source_id=2, target_id=5, before_health=1, after_health=0, base=1, base_banish=0, amount=1, display_amount=1, banish_amount=0, applied_banish_amount=0, health_damage=1, was_lethal=true}
						[0226] SUMMON_RESERVE_RELEASED tick=226 t=5 g=1 a=2 kind=HIT data{card_uid="1776823869_3490884667_3774922356", reason="removal:death:damage", summoned_id=5}
						[0227] TURN_STATUS tick=227 t=5 g=1 a=2 kind=HIT data{group_index=1, turn_id=5, active_id=2, player_id=1, pending_ids=[3]}
						[0228] REMOVED * tick=228 t=5 g=1 a=2 kind=HIT data{source_id=2, target_id=5, group_index=0, before_order_ids=[5, 1, 4], after_order_ids=[1, 4], reason="damage", removal_type=0}
						[0229] ARCANUM_STATE_CHANGED tick=229 t=5 g=1 a=2 kind=HIT data{source_id=1, arcanum_id=reapers_siphon, before_stacks=3, after_stacks=2, delta_stacks=-1, reason=""}
					[0230] SCOPE_END tick=230 t=5 g=1 a=2 kind=HIT data{scope_id=47, parent_scope_id=46, kind=15, label="t=5", actor_id=2}
				[0231] SCOPE_END tick=231 t=5 g=1 a=2 kind=STRIKE data{scope_id=46, parent_scope_id=45, kind=13, label="i=0", actor_id=2}
				[0232] ARCANUM_STATE_CHANGED tick=232 t=5 g=1 a=2 kind=ATTACK data{source_id=1, arcanum_id=reapers_siphon, before_stacks=2, after_stacks=1, delta_stacks=-1, reason=""}
			[0233] SCOPE_END tick=233 t=5 g=1 a=2 kind=ATTACK data{scope_id=45, parent_scope_id=44, kind=5, label="attacker=2", actor_id=2}
			[0234] ACTOR_END tick=234 t=5 g=1 a=2 kind=ACTOR_TURN data{actor_id=2, group_index=1, turn_id=5}
		[0235] SCOPE_END tick=235 t=5 g=1 a=2 kind=ACTOR_TURN data{scope_id=44, parent_scope_id=43, kind=3, label="actor=2", actor_id=2}
		[0236] TURN_STATUS tick=236 t=5 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=5, active_id=2, player_id=1, pending_ids=[3]}
		[0237] SET_INTENT tick=237 t=5 g=1 a=2 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="3", is_ranged=false}
		[0238] TURN_STATUS tick=238 t=5 g=1 a=3 kind=GROUP_TURN data{group_index=1, turn_id=5, active_id=3, player_id=1, pending_ids=[]}
		[0239] SCOPE_BEGIN tick=239 t=5 g=1 a=3 kind=ACTOR_TURN data{scope_id=48, parent_scope_id=43, kind=3, label="actor=3", actor_id=3, group_index=1, turn_id=5}
			[0240] ACTOR_BEGIN tick=240 t=5 g=1 a=3 kind=ACTOR_TURN data{actor_id=3, group_index=1, turn_id=5}
			[0241] SCOPE_BEGIN tick=241 t=5 g=1 a=3 kind=ATTACK data{scope_id=49, parent_scope_id=48, kind=5, label="attacker=3", actor_id=3, group_index=1, turn_id=5}
				[0242] SCOPE_BEGIN tick=242 t=5 g=1 a=3 kind=STRIKE data{scope_id=50, parent_scope_id=49, kind=13, label="i=0", actor_id=3, group_index=1, turn_id=5}
					[0243] STRIKE * tick=243 t=5 g=1 a=3 kind=STRIKE data{source_id=3, target_ids=[1]}
					[0244] SCOPE_BEGIN tick=244 t=5 g=1 a=3 kind=HIT data{scope_id=51, parent_scope_id=50, kind=15, label="t=1", actor_id=3, target_id=1, group_index=1, turn_id=5}
						[0245] DAMAGE_APPLIED tick=245 t=5 g=1 a=3 kind=HIT data{source_id=3, target_id=1, before_health=50, after_health=48, base=2, base_banish=0, amount=2, display_amount=2, banish_amount=0, applied_banish_amount=0, health_damage=2, was_lethal=false}
					[0246] SCOPE_END tick=246 t=5 g=1 a=3 kind=HIT data{scope_id=51, parent_scope_id=50, kind=15, label="t=1", actor_id=3}
				[0247] SCOPE_END tick=247 t=5 g=1 a=3 kind=STRIKE data{scope_id=50, parent_scope_id=49, kind=13, label="i=0", actor_id=3}
				[0248] SCOPE_BEGIN tick=248 t=5 g=1 a=3 kind=STRIKE data{scope_id=52, parent_scope_id=49, kind=13, label="i=1", actor_id=3, group_index=1, turn_id=5}
					[0249] STRIKE * tick=249 t=5 g=1 a=3 kind=STRIKE data{source_id=3, target_ids=[1]}
					[0250] SCOPE_BEGIN tick=250 t=5 g=1 a=3 kind=HIT data{scope_id=53, parent_scope_id=52, kind=15, label="t=1", actor_id=3, target_id=1, group_index=1, turn_id=5}
						[0251] DAMAGE_APPLIED tick=251 t=5 g=1 a=3 kind=HIT data{source_id=3, target_id=1, before_health=48, after_health=46, base=2, base_banish=0, amount=2, display_amount=2, banish_amount=0, applied_banish_amount=0, health_damage=2, was_lethal=false}
					[0252] SCOPE_END tick=252 t=5 g=1 a=3 kind=HIT data{scope_id=53, parent_scope_id=52, kind=15, label="t=1", actor_id=3}
				[0253] SCOPE_END tick=253 t=5 g=1 a=3 kind=STRIKE data{scope_id=52, parent_scope_id=49, kind=13, label="i=1", actor_id=3}
			[0254] SCOPE_END tick=254 t=5 g=1 a=3 kind=ATTACK data{scope_id=49, parent_scope_id=48, kind=5, label="attacker=3", actor_id=3}
			[0255] ACTOR_END tick=255 t=5 g=1 a=3 kind=ACTOR_TURN data{actor_id=3, group_index=1, turn_id=5}
		[0256] SCOPE_END tick=256 t=5 g=1 a=3 kind=ACTOR_TURN data{scope_id=48, parent_scope_id=43, kind=3, label="actor=3", actor_id=3}
		[0257] SET_INTENT tick=257 t=5 g=1 a=3 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×2", is_ranged=true}
		[0258] TURN_GROUP_END tick=258 t=5 g=1 a=3 kind=GROUP_TURN data{group_index=1, turn_id=5}
	[0259] SCOPE_END tick=259 t=5 g=1 a=3 kind=GROUP_TURN data{scope_id=43, parent_scope_id=1, kind=2, label="group=1", actor_id=0}
	[0260] SCOPE_BEGIN tick=260 t=6 g=0 kind=GROUP_TURN data{scope_id=54, parent_scope_id=1, kind=2, label="group=0", actor_id=0, group_index=0, turn_id=6}
		[0261] TURN_GROUP_BEGIN tick=261 t=6 g=0 kind=GROUP_TURN data{group_index=0, turn_id=6}
		[0262] MANA tick=262 t=6 g=0 kind=GROUP_TURN data{src=1 mana=0->3 Δmana=+3 max=3->3 reason="group_turn_begin_refresh"}
		[0263] STATUS tick=263 t=6 g=0 kind=GROUP_TURN data{src=2 tgt=2 status=resonance_spike op=APPLY stk=2, target_ids=[2], before_stacks=0, after_stacks=2, delta_stacks=2, reason=""}
		[0264] SET_INTENT tick=264 t=6 g=0 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="5", is_ranged=false}
		[0265] SET_INTENT tick=265 t=6 g=0 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×4", is_ranged=true}
		[0266] STATUS tick=266 t=6 g=0 kind=GROUP_TURN data{src=2 tgt=2 status=stability op=APPLY stk=3, target_ids=[2], before_stacks=0, after_stacks=3, delta_stacks=3, reason=""}
		[0267] SET_INTENT tick=267 t=6 g=0 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="5", is_ranged=false}
		[0268] SET_INTENT tick=268 t=6 g=0 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×4", is_ranged=true}
		[0269] TURN_STATUS tick=269 t=6 g=0 kind=GROUP_TURN data{group_index=0, turn_id=6, active_id=0, player_id=1, pending_ids=[]}
		[0270] TURN_GROUP_END tick=270 t=6 g=0 kind=GROUP_TURN data{group_index=0, turn_id=6}
	[0271] SCOPE_END tick=271 t=6 g=0 kind=GROUP_TURN data{scope_id=54, parent_scope_id=1, kind=2, label="group=0", actor_id=0}
	[0272] SCOPE_BEGIN tick=272 t=7 g=0 kind=GROUP_TURN data{scope_id=55, parent_scope_id=1, kind=2, label="group=0", actor_id=0, group_index=0, turn_id=7}
		[0273] TURN_GROUP_BEGIN tick=273 t=7 g=0 kind=GROUP_TURN data{group_index=0, turn_id=7}
		[0274] TURN_STATUS tick=274 t=7 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=7, active_id=1, player_id=1, pending_ids=[1, 4]}
		[0275] STATUS tick=275 t=7 g=0 a=1 kind=GROUP_TURN data{src=1 tgt=1 status=pocket_silkstitchers op=CHANGE stk=1, target_ids=[1], before_stacks=1, after_stacks=1, delta_stacks=0, reason="pocket_silkstitchers_rearm"}
		[0276] SCOPE_BEGIN tick=276 t=7 g=0 a=1 kind=ARCANA data{scope_id=56, parent_scope_id=55, kind=11, label="player_turn_begin", actor_id=0, group_index=0, turn_id=7}
			[0277] ARCANA_PROC tick=277 t=7 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=7, proc=1}
		[0278] SCOPE_END tick=278 t=7 g=0 a=1 kind=ARCANA data{scope_id=56, parent_scope_id=55, kind=11, label="player_turn_begin", actor_id=0}
		[0279] TURN_STATUS tick=279 t=7 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=7, active_id=1, player_id=1, pending_ids=[4]}
		[0280] SCOPE_BEGIN tick=280 t=7 g=0 a=1 kind=ACTOR_TURN data{scope_id=57, parent_scope_id=55, kind=3, label="actor=1", actor_id=1, group_index=0, turn_id=7}
			[0281] ACTOR_BEGIN tick=281 t=7 g=0 a=1 kind=ACTOR_TURN data{actor_id=1, group_index=0, turn_id=7}
			[0282] PLAYER_INPUT_REACHED tick=282 t=7 g=0 a=1 kind=ACTOR_TURN data{actor_id=1}
			[0283] DRAW_CARDS tick=283 t=7 g=0 a=1 kind=ACTOR_TURN data{source_id=1, amount=4, reason="player_turn_refill"}
--- Debugging process stopped ---


I think there may be errors syncing VIEW visuals with real SIM battle state pertaining to the resurrect effect of Phoenix Brooch. Please fix. Also, please update the battle event log debug printer to update to changes.