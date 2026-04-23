		[0370] SET_INTENT tick=370 t=5 g=0 a=1 kind=ACTOR_TURN data{actor_id=7, planned_idx=0, intent_text="5", is_ranged=true}
			[0371] TURN_STATUS tick=371 t=5 g=0 a=1 kind=ACTOR_TURN data{group_index=0, turn_id=5, active_id=1, player_id=1, pending_ids=[3, 7]}
			[0372] SCOPE_BEGIN tick=372 t=5 g=0 a=1 kind=CARD data{scope_id=77, parent_scope_id=71, kind=4, label="uid=1776925222_3852955648_3517252845 Stand Firm", actor_id=1, group_index=0, turn_id=5}
				[0373] CARD_PLAYED tick=373 t=5 g=0 a=1 kind=CARD data{source_id=1, card_id="stand_firm", card_uid="1776925222_3852955648_3517252845", card_name="Stand Firm", insert_index=-1, proto="res://cards/convocations/StandFirm/stand_firm.tres"}
				[0374] MANA tick=374 t=5 g=0 a=1 kind=CARD data{src=1 mana=1->0 Δmana=-1 max=3->3 reason="card_spend", card_uid="1776925222_3852955648_3517252845", card_name="Stand Firm", amount=1}
				[0375] STATUS tick=375 t=5 g=0 a=1 kind=CARD data{src=1 tgt=1 status=jabber_collector op=CHANGE stk=1, target_ids=[1], before_stacks=1, after_stacks=1, delta_stacks=0, reason="jabber_collector_count"}
				[0376] STATUS tick=376 t=5 g=0 a=1 kind=CARD data{src=1 tgt=1 status=jabber_collector op=CHANGE stk=1, target_ids=[1], before_stacks=1, after_stacks=1, delta_stacks=0, reason="jabber_collector_trigger"}
				[0377] STATUS tick=377 t=5 g=0 a=1 kind=CARD data{src=1 tgt=6 status=bulwark op=APPLY stk=10, target_ids=[6], before_stacks=0, after_stacks=10, delta_stacks=10, reason="jabber_collector"}
				[0378] STATUS tick=378 t=5 g=0 a=1 kind=CARD data{src=1 tgt=6 status=full_fortitude op=APPLY stk=2, target_ids=[6], before_stacks=0, after_stacks=2, delta_stacks=2, reason=""}
				[0379] CHANGE_MAX_HEALTH tick=379 t=5 g=0 a=1 kind=CARD data{tgt=6 max=7->9 hp=7->9 Δ=+2 relative=true reason="full_fortitude"}
				[0380] DRAW_CARDS tick=380 t=5 g=0 a=1 kind=CARD data{source_id=1, amount=1, reason="CardAction"}
			[0381] SCOPE_END tick=381 t=5 g=0 a=1 kind=CARD data{scope_id=77, parent_scope_id=71, kind=4, label="uid=1776925222_3852955648_3517252845 Stand Firm", actor_id=1}
			[0382] SET_INTENT tick=382 t=5 g=0 a=1 kind=ACTOR_TURN data{actor_id=6, planned_idx=0, intent_text="4", is_ranged=false}
			[0383] END_TURN_PRESSED tick=383 t=5 g=0 a=1 kind=ACTOR_TURN data{actor_id=1}
			[0384] DISCARD_CARDS tick=384 t=5 g=0 a=1 kind=ACTOR_TURN data{source_id=1, card_uid="", amount=0, reason="player_turn_end_discard"}
			[0385] SCOPE_BEGIN tick=385 t=5 g=0 a=1 kind=ARCANA data{scope_id=78, parent_scope_id=71, kind=11, label="player_turn_end", actor_id=0, group_index=0, turn_id=5}
				[0386] ARCANA_PROC tick=386 t=5 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=5, proc=2}
			[0387] SCOPE_END tick=387 t=5 g=0 a=1 kind=ARCANA data{scope_id=78, parent_scope_id=71, kind=11, label="player_turn_end", actor_id=0}
			[0388] ACTOR_END tick=388 t=5 g=0 a=1 kind=ACTOR_TURN data{actor_id=1, group_index=0, turn_id=5}
		[0389] SCOPE_END tick=389 t=5 g=0 a=1 kind=ACTOR_TURN data{scope_id=71, parent_scope_id=69, kind=3, label="actor=1", actor_id=1}
		[0390] STATUS tick=390 t=5 g=0 a=1 kind=GROUP_TURN data{src=1 tgt=1 status=amplify op=REMOVE stk=0, target_ids=[1], before_stacks=0, after_stacks=0, delta_stacks=0, reason=""}
		[0391] STATUS tick=391 t=5 g=0 a=1 kind=GROUP_TURN data{src=1 tgt=1 status=weakened op=REMOVE stk=0, target_ids=[1], before_stacks=0, after_stacks=0, delta_stacks=0, reason=""}
		[0392] TURN_STATUS tick=392 t=5 g=0 a=3 kind=GROUP_TURN data{group_index=0, turn_id=5, active_id=3, player_id=1, pending_ids=[7]}
		[0393] SCOPE_BEGIN tick=393 t=5 g=0 a=3 kind=ACTOR_TURN data{scope_id=79, parent_scope_id=69, kind=3, label="actor=3", actor_id=3, group_index=0, turn_id=5}
			[0394] ACTOR_BEGIN tick=394 t=5 g=0 a=3 kind=ACTOR_TURN data{actor_id=3, group_index=0, turn_id=5}
			[0395] SCOPE_BEGIN tick=395 t=5 g=0 a=3 kind=STATUS_ACTION data{scope_id=80, parent_scope_id=79, kind=17, label="id=amplify tgts=4", actor_id=3, source_id=3, target_id=6, target_ids=[6, 1, 3, 7], group_index=0, turn_id=5, status_id=amplify, stacks=1}
				[0396] STATUS tick=396 t=5 g=0 a=3 kind=STATUS_ACTION data{src=3 tgt=6 status=amplify op=APPLY stk=1, target_ids=[6], before_stacks=0, after_stacks=1, delta_stacks=1, reason="npc_status_action"}
				[0397] STATUS tick=397 t=5 g=0 a=3 kind=STATUS_ACTION data{src=3 tgt=1 status=amplify op=APPLY stk=1, target_ids=[1], before_stacks=0, after_stacks=1, delta_stacks=1, reason="npc_status_action"}
				[0398] STATUS tick=398 t=5 g=0 a=3 kind=STATUS_ACTION data{src=3 tgt=3 status=amplify op=APPLY stk=1, target_ids=[3], before_stacks=0, after_stacks=1, delta_stacks=1, reason="npc_status_action"}
				[0399] STATUS tick=399 t=5 g=0 a=3 kind=STATUS_ACTION data{src=3 tgt=7 status=amplify op=APPLY stk=1, target_ids=[7], before_stacks=0, after_stacks=1, delta_stacks=1, reason="npc_status_action"}
			[0400] SCOPE_END tick=400 t=5 g=0 a=3 kind=STATUS_ACTION data{scope_id=80, parent_scope_id=79, kind=17, label="id=amplify tgts=4", actor_id=3}
			[0401] SCOPE_BEGIN tick=401 t=5 g=0 a=3 kind=ATTACK data{scope_id=81, parent_scope_id=79, kind=5, label="attacker=3", actor_id=3, group_index=0, turn_id=5}
				[0402] SCOPE_BEGIN tick=402 t=5 g=0 a=3 kind=STRIKE data{scope_id=82, parent_scope_id=81, kind=13, label="i=0", actor_id=3, group_index=0, turn_id=5}
					[0403] STRIKE * tick=403 t=5 g=0 a=3 kind=STRIKE data{source_id=3, target_ids=[6, 1, 3, 7]}
					[0404] SCOPE_BEGIN tick=404 t=5 g=0 a=3 kind=HIT data{scope_id=83, parent_scope_id=82, kind=15, label="t=6", actor_id=3, target_id=6, group_index=0, turn_id=5}
						[0405] DAMAGE_APPLIED tick=405 t=5 g=0 a=3 kind=HIT data{source_id=3, target_id=6, before_health=9, after_health=8, base=1, base_banish=0, amount=1, display_amount=1, banish_amount=0, applied_banish_amount=0, health_damage=1, was_lethal=false}
						[0406] CHANGE_MAX_HEALTH tick=406 t=5 g=0 a=3 kind=HIT data{tgt=6 max=9->10 hp=8->8 Δ=+1 reason="tempered"}
						[0407] MODIFY_BATTLE_CARD tick=407 t=5 g=0 a=3 kind=HIT data{card_uid="1776925222_725089061_576656833", reason="tempered"}
					[0408] SCOPE_END tick=408 t=5 g=0 a=3 kind=HIT data{scope_id=83, parent_scope_id=82, kind=15, label="t=6", actor_id=3}
					[0409] SCOPE_BEGIN tick=409 t=5 g=0 a=3 kind=HIT data{scope_id=84, parent_scope_id=82, kind=15, label="t=1", actor_id=3, target_id=1, group_index=0, turn_id=5}
						[0410] DAMAGE_APPLIED tick=410 t=5 g=0 a=3 kind=HIT data{source_id=3, target_id=1, before_health=30, after_health=29, base=1, base_banish=0, amount=1, display_amount=1, banish_amount=0, applied_banish_amount=0, health_damage=1, was_lethal=false}
					[0411] SCOPE_END tick=411 t=5 g=0 a=3 kind=HIT data{scope_id=84, parent_scope_id=82, kind=15, label="t=1", actor_id=3}
					[0412] SCOPE_BEGIN tick=412 t=5 g=0 a=3 kind=HIT data{scope_id=85, parent_scope_id=82, kind=15, label="t=3", actor_id=3, target_id=3, group_index=0, turn_id=5}
						[0413] DAMAGE_APPLIED tick=413 t=5 g=0 a=3 kind=HIT data{source_id=3, target_id=3, before_health=3, after_health=2, base=1, base_banish=0, amount=1, display_amount=1, banish_amount=0, applied_banish_amount=0, health_damage=1, was_lethal=false}
					[0414] SCOPE_END tick=414 t=5 g=0 a=3 kind=HIT data{scope_id=85, parent_scope_id=82, kind=15, label="t=3", actor_id=3}
					[0415] SCOPE_BEGIN tick=415 t=5 g=0 a=3 kind=HIT data{scope_id=86, parent_scope_id=82, kind=15, label="t=7", actor_id=3, target_id=7, group_index=0, turn_id=5}
						[0416] DAMAGE_APPLIED tick=416 t=5 g=0 a=3 kind=HIT data{source_id=3, target_id=7, before_health=5, after_health=4, base=1, base_banish=0, amount=1, display_amount=1, banish_amount=0, applied_banish_amount=0, health_damage=1, was_lethal=false}
					[0417] SCOPE_END tick=417 t=5 g=0 a=3 kind=HIT data{scope_id=86, parent_scope_id=82, kind=15, label="t=7", actor_id=3}
				[0418] SCOPE_END tick=418 t=5 g=0 a=3 kind=STRIKE data{scope_id=82, parent_scope_id=81, kind=13, label="i=0", actor_id=3}
			[0419] SCOPE_END tick=419 t=5 g=0 a=3 kind=ATTACK data{scope_id=81, parent_scope_id=79, kind=5, label="attacker=3", actor_id=3}
			[0420] SCOPE_BEGIN tick=420 t=5 g=0 a=3 kind=ATTACK data{scope_id=87, parent_scope_id=79, kind=5, label="attacker=3", actor_id=3, group_index=0, turn_id=5}
				[0421] SCOPE_BEGIN tick=421 t=5 g=0 a=3 kind=STRIKE data{scope_id=88, parent_scope_id=87, kind=13, label="i=0", actor_id=3, group_index=0, turn_id=5}
					[0422] STRIKE * tick=422 t=5 g=0 a=3 kind=STRIKE data{source_id=3, target_ids=[2]}
					[0423] SCOPE_BEGIN tick=423 t=5 g=0 a=3 kind=HIT data{scope_id=89, parent_scope_id=88, kind=15, label="t=2", actor_id=3, target_id=2, group_index=0, turn_id=5}
						[0424] DAMAGE_APPLIED tick=424 t=5 g=0 a=3 kind=HIT data{source_id=3, target_id=2, before_health=38, after_health=36, base=1, base_banish=0, amount=2, display_amount=2, banish_amount=0, applied_banish_amount=0, health_damage=2, was_lethal=false}
					[0425] SCOPE_END tick=425 t=5 g=0 a=3 kind=HIT data{scope_id=89, parent_scope_id=88, kind=15, label="t=2", actor_id=3}
				[0426] SCOPE_END tick=426 t=5 g=0 a=3 kind=STRIKE data{scope_id=88, parent_scope_id=87, kind=13, label="i=0", actor_id=3}
			[0427] SCOPE_END tick=427 t=5 g=0 a=3 kind=ATTACK data{scope_id=87, parent_scope_id=79, kind=5, label="attacker=3", actor_id=3}
			[0428] ACTOR_END tick=428 t=5 g=0 a=3 kind=ACTOR_TURN data{actor_id=3, group_index=0, turn_id=5}
		[0429] SCOPE_END tick=429 t=5 g=0 a=3 kind=ACTOR_TURN data{scope_id=79, parent_scope_id=69, kind=3, label="actor=3", actor_id=3}
		[0430] STATUS tick=430 t=5 g=0 a=3 kind=GROUP_TURN data{src=3 tgt=3 status=weakened op=REMOVE stk=0, target_ids=[3], before_stacks=0, after_stacks=0, delta_stacks=0, reason=""}
		[0431] STATUS tick=431 t=5 g=0 a=3 kind=GROUP_TURN data{src=3 tgt=3 status=amplify op=REMOVE stk=0, target_ids=[3], before_stacks=0, after_stacks=0, delta_stacks=0, reason=""}
		[0432] SET_INTENT tick=432 t=5 g=0 a=3 kind=GROUP_TURN data{actor_id=6, planned_idx=0, intent_text="6", is_ranged=false}
		[0433] SET_INTENT tick=433 t=5 g=0 a=3 kind=GROUP_TURN data{actor_id=7, planned_idx=0, intent_text="8", is_ranged=true}
		[0434] SET_INTENT tick=434 t=5 g=0 a=3 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="2×6", is_ranged=false}
		[0435] SET_INTENT tick=435 t=5 g=0 a=3 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="1+", is_ranged=false}
		[0436] TURN_STATUS tick=436 t=5 g=0 a=7 kind=GROUP_TURN data{group_index=0, turn_id=5, active_id=7, player_id=1, pending_ids=[]}
		[0437] SCOPE_BEGIN tick=437 t=5 g=0 a=7 kind=ACTOR_TURN data{scope_id=90, parent_scope_id=69, kind=3, label="actor=7", actor_id=7, group_index=0, turn_id=5}
			[0438] ACTOR_BEGIN tick=438 t=5 g=0 a=7 kind=ACTOR_TURN data{actor_id=7, group_index=0, turn_id=5}
			[0439] SCOPE_BEGIN tick=439 t=5 g=0 a=7 kind=ATTACK data{scope_id=91, parent_scope_id=90, kind=5, label="attacker=7", actor_id=7, group_index=0, turn_id=5}
				[0440] SCOPE_BEGIN tick=440 t=5 g=0 a=7 kind=STRIKE data{scope_id=92, parent_scope_id=91, kind=13, label="i=0", actor_id=7, group_index=0, turn_id=5}
					[0441] STRIKE * tick=441 t=5 g=0 a=7 kind=STRIKE data{source_id=7, target_ids=[2]}
					[0442] SCOPE_BEGIN tick=442 t=5 g=0 a=7 kind=HIT data{scope_id=93, parent_scope_id=92, kind=15, label="t=2", actor_id=7, target_id=2, group_index=0, turn_id=5}
						[0443] DAMAGE_APPLIED tick=443 t=5 g=0 a=7 kind=HIT data{source_id=7, target_id=2, before_health=36, after_health=28, base=5, base_banish=0, amount=8, display_amount=8, banish_amount=0, applied_banish_amount=0, health_damage=8, was_lethal=false}
					[0444] SCOPE_END tick=444 t=5 g=0 a=7 kind=HIT data{scope_id=93, parent_scope_id=92, kind=15, label="t=2", actor_id=7}
				[0445] SCOPE_END tick=445 t=5 g=0 a=7 kind=STRIKE data{scope_id=92, parent_scope_id=91, kind=13, label="i=0", actor_id=7}
			[0446] SCOPE_END tick=446 t=5 g=0 a=7 kind=ATTACK data{scope_id=91, parent_scope_id=90, kind=5, label="attacker=7", actor_id=7}
			[0447] ACTOR_END tick=447 t=5 g=0 a=7 kind=ACTOR_TURN data{actor_id=7, group_index=0, turn_id=5}
		[0448] SCOPE_END tick=448 t=5 g=0 a=7 kind=ACTOR_TURN data{scope_id=90, parent_scope_id=69, kind=3, label="actor=7", actor_id=7}
		[0449] STATUS tick=449 t=5 g=0 a=7 kind=GROUP_TURN data{src=7 tgt=7 status=amplify op=REMOVE stk=0, target_ids=[7], before_stacks=0, after_stacks=0, delta_stacks=0, reason=""}
		[0450] SET_INTENT tick=450 t=5 g=0 a=7 kind=GROUP_TURN data{actor_id=2, planned_idx=1, intent_text="2×6", is_ranged=false}
		[0451] SET_INTENT tick=451 t=5 g=0 a=7 kind=GROUP_TURN data{actor_id=7, planned_idx=0, intent_text="5", is_ranged=true}
		[0452] TURN_GROUP_END tick=452 t=5 g=0 a=7 kind=GROUP_TURN data{group_index=0, turn_id=5}
	[0453] SCOPE_END tick=453 t=5 g=0 a=7 kind=GROUP_TURN data{scope_id=69, parent_scope_id=1, kind=2, label="group=0", actor_id=0}
	[0454] SCOPE_BEGIN tick=454 t=6 g=1 kind=GROUP_TURN data{scope_id=94, parent_scope_id=1, kind=2, label="group=1", actor_id=0, group_index=1, turn_id=6}
		[0455] TURN_GROUP_BEGIN tick=455 t=6 g=1 kind=GROUP_TURN data{group_index=1, turn_id=6}
		[0456] TURN_STATUS tick=456 t=6 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=6, active_id=2, player_id=1, pending_ids=[2]}
		[0457] TURN_STATUS tick=457 t=6 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=6, active_id=2, player_id=1, pending_ids=[]}
		[0458] SCOPE_BEGIN tick=458 t=6 g=1 a=2 kind=ACTOR_TURN data{scope_id=95, parent_scope_id=94, kind=3, label="actor=2", actor_id=2, group_index=1, turn_id=6}
			[0459] ACTOR_BEGIN tick=459 t=6 g=1 a=2 kind=ACTOR_TURN data{actor_id=2, group_index=1, turn_id=6}
			[0460] SCOPE_BEGIN tick=460 t=6 g=1 a=2 kind=ATTACK data{scope_id=96, parent_scope_id=95, kind=5, label="attacker=2", actor_id=2, group_index=1, turn_id=6}
				[0461] SCOPE_BEGIN tick=461 t=6 g=1 a=2 kind=STRIKE data{scope_id=97, parent_scope_id=96, kind=13, label="i=0", actor_id=2, group_index=1, turn_id=6}
					[0462] STRIKE * tick=462 t=6 g=1 a=2 kind=STRIKE data{source_id=2, target_ids=[6]}
					[0463] SCOPE_BEGIN tick=463 t=6 g=1 a=2 kind=HIT data{scope_id=98, parent_scope_id=97, kind=15, label="t=6", actor_id=2, target_id=6, group_index=1, turn_id=6}
						[0464] DAMAGE_APPLIED tick=464 t=6 g=1 a=2 kind=HIT data{source_id=2, target_id=6, before_health=8, after_health=0, base=6, base_banish=0, amount=8, display_amount=8, banish_amount=0, applied_banish_amount=0, health_damage=8, was_lethal=true}
						[0465] SUMMON_RESERVE_RELEASED tick=465 t=6 g=1 a=2 kind=HIT data{card_uid="1776925222_725089061_576656833", reason="removal:death:damage", summoned_id=6}
						[0466] TURN_STATUS tick=466 t=6 g=1 a=2 kind=HIT data{group_index=1, turn_id=6, active_id=2, player_id=1, pending_ids=[]}
						[0467] REMOVED * tick=467 t=6 g=1 a=2 kind=HIT data{source_id=2, target_id=6, group_index=0, before_order_ids=[6, 1, 3, 7], after_order_ids=[1, 3, 7], reason="damage", removal_type=0}
					[0468] SCOPE_END tick=468 t=6 g=1 a=2 kind=HIT data{scope_id=98, parent_scope_id=97, kind=15, label="t=6", actor_id=2}
				[0469] SCOPE_END tick=469 t=6 g=1 a=2 kind=STRIKE data{scope_id=97, parent_scope_id=96, kind=13, label="i=0", actor_id=2}
				[0470] ARCANUM_STATE_CHANGED tick=470 t=6 g=1 a=2 kind=ATTACK data{source_id=1, arcanum_id=reapers_siphon, before_stacks=1, after_stacks=3, delta_stacks=2, reason=""}
				[0471] DRAW_CARDS tick=471 t=6 g=1 a=2 kind=ATTACK data{source_id=1, amount=1, reason="reapers_siphon"}
				[0472] SCOPE_BEGIN tick=472 t=6 g=1 a=2 kind=STRIKE data{scope_id=99, parent_scope_id=96, kind=13, label="i=1", actor_id=2, group_index=1, turn_id=6}
					[0473] STRIKE * tick=473 t=6 g=1 a=2 kind=STRIKE data{source_id=2, target_ids=[1]}
					[0474] SCOPE_BEGIN tick=474 t=6 g=1 a=2 kind=HIT data{scope_id=100, parent_scope_id=99, kind=15, label="t=1", actor_id=2, target_id=1, group_index=1, turn_id=6}
						[0475] DAMAGE_APPLIED tick=475 t=6 g=1 a=2 kind=HIT data{source_id=2, target_id=1, before_health=29, after_health=20, base=6, base_banish=0, amount=9, display_amount=9, banish_amount=0, applied_banish_amount=0, health_damage=9, was_lethal=false}
					[0476] SCOPE_END tick=476 t=6 g=1 a=2 kind=HIT data{scope_id=100, parent_scope_id=99, kind=15, label="t=1", actor_id=2}
				[0477] SCOPE_END tick=477 t=6 g=1 a=2 kind=STRIKE data{scope_id=99, parent_scope_id=96, kind=13, label="i=1", actor_id=2}
			[0478] SCOPE_END tick=478 t=6 g=1 a=2 kind=ATTACK data{scope_id=96, parent_scope_id=95, kind=5, label="attacker=2", actor_id=2}
			[0479] SCOPE_BEGIN tick=479 t=6 g=1 a=2 kind=STATUS_ACTION data{scope_id=101, parent_scope_id=95, kind=17, label="id=weakened tgts=3", actor_id=2, source_id=2, target_id=1, target_ids=[1, 3, 7], group_index=1, turn_id=6, status_id=weakened, stacks=1}
				[0480] STATUS tick=480 t=6 g=1 a=2 kind=STATUS_ACTION data{src=2 tgt=1 status=weakened op=APPLY stk=1, target_ids=[1], before_stacks=0, after_stacks=1, delta_stacks=1, reason="npc_status_action"}
				[0481] STATUS tick=481 t=6 g=1 a=2 kind=STATUS_ACTION data{src=2 tgt=3 status=weakened op=APPLY stk=1, target_ids=[3], before_stacks=0, after_stacks=1, delta_stacks=1, reason="npc_status_action"}
				[0482] STATUS tick=482 t=6 g=1 a=2 kind=STATUS_ACTION data{src=2 tgt=7 status=weakened op=APPLY stk=1, target_ids=[7], before_stacks=0, after_stacks=1, delta_stacks=1, reason="npc_status_action"}
			[0483] SCOPE_END tick=483 t=6 g=1 a=2 kind=STATUS_ACTION data{scope_id=101, parent_scope_id=95, kind=17, label="id=weakened tgts=3", actor_id=2}
			[0484] SCOPE_BEGIN tick=484 t=6 g=1 a=2 kind=STATUS_ACTION data{scope_id=102, parent_scope_id=95, kind=17, label="id=vulnerable_aura tgts=1", actor_id=2, source_id=2, target_id=2, target_ids=[2], group_index=1, turn_id=6, status_id=vulnerable_aura, stacks=2}
				[0485] STATUS tick=485 t=6 g=1 a=2 kind=STATUS_ACTION data{src=2 tgt=1 status=vulnerable op=CHANGE stk=3, target_ids=[1], before_stacks=1, after_stacks=3, delta_stacks=2, reason=""}
				[0486] STATUS tick=486 t=6 g=1 a=2 kind=STATUS_ACTION data{src=2 tgt=3 status=vulnerable op=CHANGE stk=3, target_ids=[3], before_stacks=1, after_stacks=3, delta_stacks=2, reason=""}
				[0487] STATUS tick=487 t=6 g=1 a=2 kind=STATUS_ACTION data{src=2 tgt=7 status=vulnerable op=CHANGE stk=3, target_ids=[7], before_stacks=1, after_stacks=3, delta_stacks=2, reason=""}
				[0488] SET_INTENT tick=488 t=6 g=1 a=2 kind=STATUS_ACTION data{actor_id=3, planned_idx=0, intent_text="1+", is_ranged=false}
				[0489] SET_INTENT tick=489 t=6 g=1 a=2 kind=STATUS_ACTION data{actor_id=7, planned_idx=0, intent_text="3", is_ranged=true}
				[0490] TURN_STATUS tick=490 t=6 g=1 a=2 kind=STATUS_ACTION data{group_index=1, turn_id=6, active_id=2, player_id=1, pending_ids=[]}
			[0491] SCOPE_END tick=491 t=6 g=1 a=2 kind=STATUS_ACTION data{scope_id=102, parent_scope_id=95, kind=17, label="id=vulnerable_aura tgts=1", actor_id=2}
			[0492] ACTOR_END tick=492 t=6 g=1 a=2 kind=ACTOR_TURN data{actor_id=2, group_index=1, turn_id=6}
		[0493] SCOPE_END tick=493 t=6 g=1 a=2 kind=ACTOR_TURN data{scope_id=95, parent_scope_id=94, kind=3, label="actor=2", actor_id=2}
		[0494] STATUS tick=494 t=6 g=1 a=2 kind=GROUP_TURN data{src=2 tgt=1 status=vulnerable op=CHANGE stk=2, target_ids=[1], before_stacks=3, after_stacks=2, delta_stacks=-1, reason=""}
		[0495] STATUS tick=495 t=6 g=1 a=2 kind=GROUP_TURN data{src=2 tgt=3 status=vulnerable op=CHANGE stk=2, target_ids=[3], before_stacks=3, after_stacks=2, delta_stacks=-1, reason=""}
		[0496] STATUS tick=496 t=6 g=1 a=2 kind=GROUP_TURN data{src=2 tgt=7 status=vulnerable op=CHANGE stk=2, target_ids=[7], before_stacks=3, after_stacks=2, delta_stacks=-1, reason=""}
		[0497] SET_INTENT tick=497 t=6 g=1 a=2 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="1+", is_ranged=false}
		[0498] SET_INTENT tick=498 t=6 g=1 a=2 kind=GROUP_TURN data{actor_id=7, planned_idx=0, intent_text="3", is_ranged=true}
		[0499] SET_INTENT tick=499 t=6 g=1 a=2 kind=GROUP_TURN data{actor_id=3, planned_idx=0, intent_text="1+", is_ranged=false}
		[0500] SET_INTENT tick=500 t=6 g=1 a=2 kind=GROUP_TURN data{actor_id=7, planned_idx=0, intent_text="3", is_ranged=true}
		[0501] STATUS tick=501 t=6 g=1 a=2 kind=GROUP_TURN data{src=2 tgt=2 status=banishing_strikes op=APPLY stk=5, target_ids=[2], before_stacks=0, after_stacks=5, delta_stacks=5, reason=""}
		[0502] SET_INTENT tick=502 t=6 g=1 a=2 kind=GROUP_TURN data{actor_id=2, planned_idx=0, intent_text="3×6", is_ranged=false}
		[0503] SET_INTENT tick=503 t=6 g=1 a=2 kind=GROUP_TURN data{actor_id=2, planned_idx=0, intent_text="3×6", is_ranged=false}
		[0504] TURN_GROUP_END tick=504 t=6 g=1 a=2 kind=GROUP_TURN data{group_index=1, turn_id=6}
	[0505] SCOPE_END tick=505 t=6 g=1 a=2 kind=GROUP_TURN data{scope_id=94, parent_scope_id=1, kind=2, label="group=1", actor_id=0}
	[0506] SCOPE_BEGIN tick=506 t=7 g=0 kind=GROUP_TURN data{scope_id=103, parent_scope_id=1, kind=2, label="group=0", actor_id=0, group_index=0, turn_id=7}
		[0507] TURN_GROUP_BEGIN tick=507 t=7 g=0 kind=GROUP_TURN data{group_index=0, turn_id=7}
		[0508] MANA tick=508 t=7 g=0 kind=GROUP_TURN data{src=1 mana=0->3 Δmana=+3 max=3->3 reason="group_turn_begin_refresh"}
		[0509] TURN_STATUS tick=509 t=7 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=7, active_id=1, player_id=1, pending_ids=[1, 3, 7]}
		[0510] STATUS tick=510 t=7 g=0 a=1 kind=GROUP_TURN data{src=1 tgt=1 status=jabber_collector op=CHANGE stk=1, target_ids=[1], before_stacks=1, after_stacks=1, delta_stacks=0, reason="jabber_collector_reset"}
		[0511] SCOPE_BEGIN tick=511 t=7 g=0 a=1 kind=ARCANA data{scope_id=104, parent_scope_id=103, kind=11, label="player_turn_begin", actor_id=0, group_index=0, turn_id=7}
			[0512] ARCANA_PROC tick=512 t=7 g=0 a=1 kind=ARCANA data{group_index=0, turn_id=7, proc=1}
		[0513] SCOPE_END tick=513 t=7 g=0 a=1 kind=ARCANA data{scope_id=104, parent_scope_id=103, kind=11, label="player_turn_begin", actor_id=0}
		[0514] TURN_STATUS tick=514 t=7 g=0 a=1 kind=GROUP_TURN data{group_index=0, turn_id=7, active_id=1, player_id=1, pending_ids=[3, 7]}
		[0515] SCOPE_BEGIN tick=515 t=7 g=0 a=1 kind=ACTOR_TURN data{scope_id=105, parent_scope_id=103, kind=3, label="actor=1", actor_id=1, group_index=0, turn_id=7}
			[0516] ACTOR_BEGIN tick=516 t=7 g=0 a=1 kind=ACTOR_TURN data{actor_id=1, group_index=0, turn_id=7}
			[0517] PLAYER_INPUT_REACHED tick=517 t=7 g=0 a=1 kind=ACTOR_TURN data{actor_id=1}
			[0518] DRAW_CARDS tick=518 t=7 g=0 a=1 kind=ACTOR_TURN data{source_id=1, amount=4, reason="player_turn_refill"}


did something weird happen here? idk why the tempered silverback died early it seems like and the player took 10 damage