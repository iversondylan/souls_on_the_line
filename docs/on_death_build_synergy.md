Godot Engine v4.6.1.stable.official.14d19694e - https://godotengine.org
OpenGL API 4.1 Metal - 90.5 - Compatibility - Using Device: Apple - Apple M5 Pro

[0000] SCOPE_BEGIN tick=0 kind=BATTLE data{scope_id=1, parent_scope_id=0, kind=0, label="battle_seed=1398101971 run_seed=525784061", actor_id=0, group_index=-1, turn_id=0}
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
			[0031] SCOPE_BEGIN tick=31 t=1 g=0 a=1 kind=CARD data{scope_id=7, parent_scope_id=6, kind=4, label="uid=1776825368_680863956_3774922356 Spectral Clone", actor_id=1, group_index=0, turn_id=1}
				[0032] CARD_PLAYED tick=32 t=1 g=0 a=1 kind=CARD data{source_id=1, card_id="spectral_clone", card_uid="1776825368_680863956_3774922356", card_name="Spectral Clone", insert_index=0, proto="res://cards/souls/SpectralCloneCard/spectral_clone.tres"}
				[0033] MANA tick=33 t=1 g=0 a=1 kind=CARD data{src=1 mana=3->2 Δmana=-1 max=3->3 reason="card_spend", card_uid="1776825368_680863956_3774922356", card_name="Spectral Clone", amount=1}
				[0034] SCOPE_BEGIN tick=34 t=1 g=0 a=1 kind=SUMMON_ACTION data{scope_id=8, parent_scope_id=7, kind=16, label="count=1 g=0 idx=0", actor_id=1, source_id=1, group_index=0, turn_id=1, insert_index=0, proto="", summon_count=1}
					[0035] SUMMONED * tick=35 t=1 g=0 a=1 kind=SUMMON_ACTION data{source_id=1, group_index=0, card_uid="1776825368_680863956_3774922356", insert_index=0, before_order_ids=[1], after_order_ids=[4, 1], reason="card_summon", summoned_id=4}
					[0036] TURN_STATUS tick=36 t=1 g=0 a=1 kind=SUMMON_ACTION data{group_index=0, turn_id=1, active_id=1, player_id=1, pending_ids=[]}
				[0037] SCOPE_END tick=37 t=1 g=0 a=1 kind=SUMMON_ACTION data{scope_id=8, parent_scope_id=7, kind=16, label="count=1 g=0 idx=0", actor_id=1}
			[0038] SCOPE_END tick=38 t=1 g=0 a=1 kind=CARD data{scope_id=7, parent_scope_id=6, kind=4, label="uid=1776825368_680863956_3774922356 Spectral Clone", actor_id=1}
			[0039] SET_INTENT tick=39 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=4, planned_idx=0, intent_text="3", is_ranged=false}
			[0040] TURN_STATUS tick=40 t=1 g=0 a=1 kind=ACTOR_TURN data{group_index=0, turn_id=1, active_id=1, player_id=1, pending_ids=[]}
			[0041] SCOPE_BEGIN tick=41 t=1 g=0 a=1 kind=CARD data{scope_id=9, parent_scope_id=6, kind=4, label="uid=1776825368_3330034532_707204541 Phoenix Brooch", actor_id=1, group_index=0, turn_id=1}
				[0042] CARD_PLAYED tick=42 t=1 g=0 a=1 kind=CARD data{source_id=1, card_id="phoenix_brooch", card_uid="1776825368_3330034532_707204541", card_name="Phoenix Brooch", insert_index=-1, proto="res://cards/enchantments/PhoenixBrooch/phoenix_brooch.tres"}
				[0043] MANA tick=43 t=1 g=0 a=1 kind=CARD data{src=1 mana=2->1 Δmana=-1 max=3->3 reason="card_spend", card_uid="1776825368_3330034532_707204541", card_name="Phoenix Brooch", amount=1}
				[0044] STATUS tick=44 t=1 g=0 a=1 kind=CARD data{src=1 tgt=4 status=phoenix_brooch op=APPLY stk=1, target_ids=[4], before_stacks=0, after_stacks=1, delta_stacks=1, reason=""}
			[0045] SCOPE_END tick=45 t=1 g=0 a=1 kind=CARD data{scope_id=9, parent_scope_id=6, kind=4, label="uid=1776825368_3330034532_707204541 Phoenix Brooch", actor_id=1}
			[0046] SET_INTENT tick=46 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=4, planned_idx=0, intent_text="3", is_ranged=false}
			[0047] SCOPE_BEGIN tick=47 t=1 g=0 a=1 kind=CARD data{scope_id=10, parent_scope_id=6, kind=4, label="uid=1776825368_2130307012_4150313248 Barkbound Bond", actor_id=1, group_index=0, turn_id=1}
				[0048] CARD_PLAYED tick=48 t=1 g=0 a=1 kind=CARD data{source_id=1, card_id="barkbound_bond", card_uid="1776825368_2130307012_4150313248", card_name="Barkbound Bond", insert_index=-1, proto="res://cards/convocations/BarkboundBond/barkbound_bond.tres"}
				[0049] MANA tick=49 t=1 g=0 a=1 kind=CARD data{src=1 mana=1->0 Δmana=-1 max=3->3 reason="card_spend", card_uid="1776825368_2130307012_4150313248", card_name="Barkbound Bond", amount=1}
				[0050] STATUS tick=50 t=1 g=0 a=1 kind=CARD data{src=1 tgt=4 status=barkbound_bond op=APPLY stk=2, target_ids=[4], before_stacks=0, after_stacks=2, delta_stacks=2, reason=""}
				[0051] DRAW_CARDS tick=51 t=1 g=0 a=1 kind=CARD data{source_id=1, amount=1, reason="CardAction"}
			[0052] SCOPE_END tick=52 t=1 g=0 a=1 kind=CARD data{scope_id=10, parent_scope_id=6, kind=4, label="uid=1776825368_2130307012_4150313248 Barkbound Bond", actor_id=1}
			[0053] SET_INTENT tick=53 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=4, planned_idx=0, intent_text="3", is_ranged=false}
			[0054] END_TURN_PRESSED tick=54 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=1}
			[0055] DISCARD_CARDS tick=55 t=1 g=0 a=1 kind=ACTOR_TURN data{source_id=1, card_uid="", amount=0, reason="player_turn_end_discard"}
			[0056] SCOPE_BEGIN tick=56 t=1 g=0 a=1 kind=ARCANA data{scope_id=11, parent_scope_id=6, kind=11, label="player_turn_end", actor_id=0, group_index=0, turn_id=1}
				[0057] ARCANA_PROC tick=57 t=1 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=1, proc=2}
			[0058] SCOPE_END tick=58 t=1 g=0 a=1 kind=ARCANA data{scope_id=11, parent_scope_id=6, kind=11, label="player_turn_end", actor_id=0}
			[0059] ACTOR_END tick=59 t=1 g=0 a=1 kind=ACTOR_TURN data{actor_id=1, group_index=0, turn_id=1}
		[0060] SCOPE_END tick=60 t=1 g=0 a=1 kind=ACTOR_TURN data{scope_id=6, parent_scope_id=3, kind=3, label="actor=1", actor_id=1}
		[0061] TURN_GROUP_END tick=61 t=1 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=1}
	[0062] SCOPE_END tick=62 t=1 g=0 a=1 kind=GROUP_TURN data{scope_id=3, parent_scope_id=1, kind=2, label="group=0", actor_id=0}
	[0063] SCOPE_BEGIN tick=63 t=2 g=1 kind=GROUP_TURN data{scope_id=12, parent_scope_id=1, kind=2, label="group=1", actor_id=0, group_index=1, turn_id=2}
		[0064] TURN_GROUP_BEGIN tick=64 t=2 g=1 kind=GROUP_TURN data{group_index=1, turn_id=2}
		[0065] TURN_STATUS tick=65 t=2 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=2, active_id=2, player_id=1, pending_ids=[2, 3]}
		[0066] TURN_STATUS tick=66 t=2 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=2, active_id=2, player_id=1, pending_ids=[3]}
		[0067] SCOPE_BEGIN tick=67 t=2 g=1 a=2 kind=ACTOR_TURN data{scope_id=13, parent_scope_id=12, kind=3, label="actor=2", actor_id=2, group_index=1, turn_id=2}
			[0068] ACTOR_BEGIN tick=68 t=2 g=1 a=2 kind=ACTOR_TURN data{actor_id=2, group_index=1, turn_id=2}
			[0069] STATUS tick=69 t=2 g=1 a=2 kind=ACTOR_TURN data{src=2 tgt=2 status=stability op=REMOVE stk=0, target_ids=[2], before_stacks=3, after_stacks=0, delta_stacks=-3, reason=""}
			[0070] SCOPE_BEGIN tick=70 t=2 g=1 a=2 kind=ATTACK data{scope_id=14, parent_scope_id=13, kind=5, label="attacker=2", actor_id=2, group_index=1, turn_id=2}
				[0071] SCOPE_BEGIN tick=71 t=2 g=1 a=2 kind=STRIKE data{scope_id=15, parent_scope_id=14, kind=13, label="i=0", actor_id=2, group_index=1, turn_id=2}
					[0072] STRIKE * tick=72 t=2 g=1 a=2 kind=STRIKE data{source_id=2, target_ids=[4]}
					[0073] SCOPE_BEGIN tick=73 t=2 g=1 a=2 kind=HIT data{scope_id=16, parent_scope_id=15, kind=15, label="t=4", actor_id=2, target_id=4, group_index=1, turn_id=2}
						[0074] DAMAGE_APPLIED tick=74 t=2 g=1 a=2 kind=HIT data{source_id=2, target_id=4, before_health=3, after_health=0, base=3, base_banish=0, amount=5, display_amount=5, banish_amount=0, applied_banish_amount=0, health_damage=3, was_lethal=true}
						[0075] HEAL_APPLIED tick=75 t=2 g=1 a=2 kind=HIT data{src=4 tgt=4 hp=0->3 healed=3 flat=3}
						[0076] STATUS tick=76 t=2 g=1 a=2 kind=HIT data{src=4 tgt=4 status=phoenix_brooch op=REMOVE stk=0, target_ids=[4], before_stacks=1, after_stacks=0, delta_stacks=-1, reason=""}
					[0077] SCOPE_END tick=77 t=2 g=1 a=2 kind=HIT data{scope_id=16, parent_scope_id=15, kind=15, label="t=4", actor_id=2}
				[0078] SCOPE_END tick=78 t=2 g=1 a=2 kind=STRIKE data{scope_id=15, parent_scope_id=14, kind=13, label="i=0", actor_id=2}
			[0079] SCOPE_END tick=79 t=2 g=1 a=2 kind=ATTACK data{scope_id=14, parent_scope_id=13, kind=5, label="attacker=2", actor_id=2}
			[0080] ACTOR_END tick=80 t=2 g=1 a=2 kind=ACTOR_TURN data{actor_id=2, group_index=1, turn_id=2}
		[0081] SCOPE_END tick=81 t=2 g=1 a=2 kind=ACTOR_TURN data{scope_id=13, parent_scope_id=12, kind=3, label="actor=2", actor_id=2}
		[0082] SET_INTENT tick=82 t=2 g=1 a=2 kind=GROUP_TURN data{actor_id=4, planned_idx=0, intent_text="3", is_ranged=false}
		[0083] SET_INTENT tick=83 t=2 g=1 a=2 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="5", is_ranged=false}
		[0084] TURN_STATUS tick=84 t=2 g=1 a=3 kind=GROUP_TURN data{group_index=1, turn_id=2, active_id=3, player_id=1, pending_ids=[]}
		[0085] SCOPE_BEGIN tick=85 t=2 g=1 a=3 kind=ACTOR_TURN data{scope_id=17, parent_scope_id=12, kind=3, label="actor=3", actor_id=3, group_index=1, turn_id=2}
			[0086] ACTOR_BEGIN tick=86 t=2 g=1 a=3 kind=ACTOR_TURN data{actor_id=3, group_index=1, turn_id=2}
			[0087] SCOPE_BEGIN tick=87 t=2 g=1 a=3 kind=ATTACK data{scope_id=18, parent_scope_id=17, kind=5, label="attacker=3", actor_id=3, group_index=1, turn_id=2}
				[0088] SCOPE_BEGIN tick=88 t=2 g=1 a=3 kind=STRIKE data{scope_id=19, parent_scope_id=18, kind=13, label="i=0", actor_id=3, group_index=1, turn_id=2}
					[0089] STRIKE * tick=89 t=2 g=1 a=3 kind=STRIKE data{source_id=3, target_ids=[4]}
					[0090] SCOPE_BEGIN tick=90 t=2 g=1 a=3 kind=HIT data{scope_id=20, parent_scope_id=19, kind=15, label="t=4", actor_id=3, target_id=4, group_index=1, turn_id=2}
						[0091] DAMAGE_APPLIED tick=91 t=2 g=1 a=3 kind=HIT data{source_id=3, target_id=4, before_health=3, after_health=0, base=2, base_banish=0, amount=4, display_amount=4, banish_amount=0, applied_banish_amount=0, health_damage=3, was_lethal=true}
						[0092] SUMMON_RESERVE_RELEASED tick=92 t=2 g=1 a=3 kind=HIT data{card_uid="1776825368_680863956_3774922356", reason="removal:death:damage", summoned_id=4}
						[0093] TURN_STATUS tick=93 t=2 g=1 a=3 kind=HIT data{group_index=1, turn_id=2, active_id=3, player_id=1, pending_ids=[]}
						[0094] REMOVED * tick=94 t=2 g=1 a=3 kind=HIT data{source_id=3, target_id=4, group_index=0, before_order_ids=[4, 1], after_order_ids=[1], reason="damage", removal_type=0}
						[0095] ARCANUM_STATE_CHANGED tick=95 t=2 g=1 a=3 kind=HIT data{source_id=1, arcanum_id=reapers_siphon, before_stacks=3, after_stacks=2, delta_stacks=-1, reason=""}
					[0096] SCOPE_END tick=96 t=2 g=1 a=3 kind=HIT data{scope_id=20, parent_scope_id=19, kind=15, label="t=4", actor_id=3}
				[0097] SCOPE_END tick=97 t=2 g=1 a=3 kind=STRIKE data{scope_id=19, parent_scope_id=18, kind=13, label="i=0", actor_id=3}
				[0098] ARCANUM_STATE_CHANGED tick=98 t=2 g=1 a=3 kind=ATTACK data{source_id=1, arcanum_id=reapers_siphon, before_stacks=2, after_stacks=1, delta_stacks=-1, reason=""}
				[0099] SCOPE_BEGIN tick=99 t=2 g=1 a=3 kind=STRIKE data{scope_id=21, parent_scope_id=18, kind=13, label="i=1", actor_id=3, group_index=1, turn_id=2}
					[0100] STRIKE * tick=100 t=2 g=1 a=3 kind=STRIKE data{source_id=3, target_ids=[1]}
					[0101] SCOPE_BEGIN tick=101 t=2 g=1 a=3 kind=HIT data{scope_id=22, parent_scope_id=21, kind=15, label="t=1", actor_id=3, target_id=1, group_index=1, turn_id=2}
						[0102] DAMAGE_APPLIED tick=102 t=2 g=1 a=3 kind=HIT data{source_id=3, target_id=1, before_health=50, after_health=46, base=2, base_banish=0, amount=4, display_amount=4, banish_amount=0, applied_banish_amount=0, health_damage=4, was_lethal=false}
					[0103] SCOPE_END tick=103 t=2 g=1 a=3 kind=HIT data{scope_id=22, parent_scope_id=21, kind=15, label="t=1", actor_id=3}
				[0104] SCOPE_END tick=104 t=2 g=1 a=3 kind=STRIKE data{scope_id=21, parent_scope_id=18, kind=13, label="i=1", actor_id=3}
			[0105] SCOPE_END tick=105 t=2 g=1 a=3 kind=ATTACK data{scope_id=18, parent_scope_id=17, kind=5, label="attacker=3", actor_id=3}
			[0106] ACTOR_END tick=106 t=2 g=1 a=3 kind=ACTOR_TURN data{actor_id=3, group_index=1, turn_id=2}
		[0107] SCOPE_END tick=107 t=2 g=1 a=3 kind=ACTOR_TURN data{scope_id=17, parent_scope_id=12, kind=3, label="actor=3", actor_id=3}
		[0108] TURN_STATUS tick=108 t=2 g=1 a=3 kind=GROUP_TURN data{group_index=1, turn_id=2, active_id=3, player_id=1, pending_ids=[]}
		[0109] SET_INTENT tick=109 t=2 g=1 a=3 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×4", is_ranged=true}
		[0110] SET_INTENT tick=110 t=2 g=1 a=3 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="3", is_ranged=false}
		[0111] SET_INTENT tick=111 t=2 g=1 a=3 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×2", is_ranged=true}
		[0112] STATUS tick=112 t=2 g=1 a=3 kind=GROUP_TURN data{src=2 tgt=2 status=resonance_spike op=REMOVE stk=0, target_ids=[2], before_stacks=2, after_stacks=0, delta_stacks=-2, reason=""}
		[0113] SET_INTENT tick=113 t=2 g=1 a=3 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="3", is_ranged=false}
		[0114] SET_INTENT tick=114 t=2 g=1 a=3 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×2", is_ranged=true}
		[0115] TURN_GROUP_END tick=115 t=2 g=1 a=3 kind=GROUP_TURN data{group_index=1, turn_id=2}
	[0116] SCOPE_END tick=116 t=2 g=1 a=3 kind=GROUP_TURN data{scope_id=12, parent_scope_id=1, kind=2, label="group=1", actor_id=0}
	[0117] SCOPE_BEGIN tick=117 t=3 g=0 kind=GROUP_TURN data{scope_id=23, parent_scope_id=1, kind=2, label="group=0", actor_id=0, group_index=0, turn_id=3}
		[0118] TURN_GROUP_BEGIN tick=118 t=3 g=0 kind=GROUP_TURN data{group_index=0, turn_id=3}
		[0119] MANA tick=119 t=3 g=0 kind=GROUP_TURN data{src=1 mana=0->3 Δmana=+3 max=3->3 reason="group_turn_begin_refresh"}
		[0120] STATUS tick=120 t=3 g=0 kind=GROUP_TURN data{src=2 tgt=2 status=resonance_spike op=APPLY stk=2, target_ids=[2], before_stacks=0, after_stacks=2, delta_stacks=2, reason=""}
		[0121] SET_INTENT tick=121 t=3 g=0 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="5", is_ranged=false}
		[0122] SET_INTENT tick=122 t=3 g=0 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×4", is_ranged=true}
		[0123] STATUS tick=123 t=3 g=0 kind=GROUP_TURN data{src=2 tgt=2 status=stability op=APPLY stk=3, target_ids=[2], before_stacks=0, after_stacks=3, delta_stacks=3, reason=""}
		[0124] SET_INTENT tick=124 t=3 g=0 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="5", is_ranged=false}
		[0125] SET_INTENT tick=125 t=3 g=0 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="2×4", is_ranged=true}
		[0126] TURN_STATUS tick=126 t=3 g=0 kind=GROUP_TURN data{group_index=0, turn_id=3, active_id=0, player_id=1, pending_ids=[]}
		[0127] TURN_GROUP_END tick=127 t=3 g=0 kind=GROUP_TURN data{group_index=0, turn_id=3}
	[0128] SCOPE_END tick=128 t=3 g=0 kind=GROUP_TURN data{scope_id=23, parent_scope_id=1, kind=2, label="group=0", actor_id=0}
	[0129] SCOPE_BEGIN tick=129 t=4 g=0 kind=GROUP_TURN data{scope_id=24, parent_scope_id=1, kind=2, label="group=0", actor_id=0, group_index=0, turn_id=4}
		[0130] TURN_GROUP_BEGIN tick=130 t=4 g=0 kind=GROUP_TURN data{group_index=0, turn_id=4}
		[0131] TURN_STATUS tick=131 t=4 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=4, active_id=1, player_id=1, pending_ids=[1]}
		[0132] SCOPE_BEGIN tick=132 t=4 g=0 a=1 kind=ARCANA data{scope_id=25, parent_scope_id=24, kind=11, label="player_turn_begin", actor_id=0, group_index=0, turn_id=4}
			[0133] ARCANA_PROC tick=133 t=4 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=4, proc=1}
		[0134] SCOPE_END tick=134 t=4 g=0 a=1 kind=ARCANA data{scope_id=25, parent_scope_id=24, kind=11, label="player_turn_begin", actor_id=0}
		[0135] TURN_STATUS tick=135 t=4 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=4, active_id=1, player_id=1, pending_ids=[]}
		[0136] SCOPE_BEGIN tick=136 t=4 g=0 a=1 kind=ACTOR_TURN data{scope_id=26, parent_scope_id=24, kind=3, label="actor=1", actor_id=1, group_index=0, turn_id=4}
			[0137] ACTOR_BEGIN tick=137 t=4 g=0 a=1 kind=ACTOR_TURN data{actor_id=1, group_index=0, turn_id=4}
			[0138] PLAYER_INPUT_REACHED tick=138 t=4 g=0 a=1 kind=ACTOR_TURN data{actor_id=1}
			[0139] DRAW_CARDS tick=139 t=4 g=0 a=1 kind=ACTOR_TURN data{source_id=1, amount=4, reason="player_turn_refill"}
--- Debugging process stopped ---


VIEW layer is not robustly handling cheat-death mechanics. Tick 72 leaves the combatant appearing to have 0 hp. Please harden the VIEW layer systems, most likely include turn_timeline_compiler.gd to handle the new feature introduced for phoenix_brooch.gd