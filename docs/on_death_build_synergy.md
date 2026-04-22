
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