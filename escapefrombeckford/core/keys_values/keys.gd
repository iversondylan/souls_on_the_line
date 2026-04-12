# keys.gd
class_name Keys

const LOG_ENUM_STRINGS := false

# -------------------------
# Shared context keys
# -------------------------
const MODE := &"mode"
const MODE_SIM := &"sim"

const PLAYER_ID := &"player_id"
const IS_PLAYER := &"is_player"
const MORTALITY := &"mortality"
const SOURCE_ID := &"source_id"
const SPAWNED_ID := &"spawned_id"
const ORDER_IDS := &"order_ids"
const GROUPS := &"groups" # maybe
const GROUP_0 := &"group_0"
const GROUP_1 := &"group_1"
const ACTIVE_ID := &"active_id"
const PENDING_IDS := &"pending_ids"
const PRIMARY_ACTION_KIND := &"primary_action_kind"
# for single instances of damage and HITS:
const TARGET_ID := &"target_id"
# an attacker's STRIKE may result in multiple HITS on its targets.
const STRIKE_COUNT := &"strike_count"
const TOTAL_HIT_COUNT := &"total_hit_count"
const HAS_LETHAL_HIT := &"has_lethal_hit"
#for the targets of attacks (often size = 1) and STRIKES:
const TARGET_IDS := &"target_ids"
const ACTOR_ID := &"actor_id"

const TURN_ID := &"turn_id"
const GROUP_INDEX := &"group_index"
const INSERT_INDEX := &"insert_index"
const GROUP_TURN := &"group_turn"
const NPC_ACTION_SKIPPED_THIS_TURN := &"npc_action_skipped_this_turn"
const BEFORE_MANA := &"before_mana"
const AFTER_MANA := &"after_mana"
const BEFORE_MAX_MANA := &"before_max_mana"
const AFTER_MAX_MANA := &"after_max_mana"
const OVERLOAD := &"overload"
const OVERLOAD_MOD := &"overload_mod"

# -------------------------
# Scope frame keys
# -------------------------
const SCOPE_ID := &"scope_id"
const PARENT_SCOPE_ID := &"parent_scope_id"
const SCOPE_KIND := &"kind"
const SCOPE_LABEL := &"label"

const DEFAULT_SUMMON_DATA_PATH := &"DEFAULT_SUMMON_DATA_PATH"
const DEFAULT_SUMMON_DATA_UID := &"DEFAULT_SUMMON_DATA_UID"
# -------------------------
# Event data keys
# -------------------------

# Card played
const CARD_ID := &"card_id"
const CARD_UID := &"card_uid"
const CARD_NAME := &"card_name"
const CARD_TYPE_I := &"card_type_i"
const CARD_TARGET_TYPE_I := &"card_target_type_i"
const CARD_TYPE_S := &"card_type_s"
const CARD_TARGET_TYPE_S := &"card_target_type_s"
const TARGETS := &"targets"
const SUMMONED_IDS := &"summon_ids"
const AMOUNT := &"amount"
const REQUEST_ID := &"request_id"
const CHOSEN_UIDS := &"chosen_uids"
const DISABLE_UNTIL_NEXT_PLAYER_TURN := &"disable_until_next_player_turn"
const DRAW_CONTEXT := &"draw_context"
const DISCARD_CONTEXT := &"discard_context"

# Arcana
const ARCANUM_ID := &"arcanum_id"
const PROC := &"proc"
const PROC_LABEL := &"proc_label"

# Damage applied
const BASE_AMOUNT := &"base"
const BASE_BANISH_AMOUNT := &"base_banish"
const FINAL_AMOUNT := &"amount"
const DISPLAY_AMOUNT := &"display_amount"
const BANISH_AMOUNT := &"banish_amount"
const APPLIED_BANISH_AMOUNT := &"applied_banish_amount"
const ARMOR_DAMAGE := &"armor_damage"
const HEALTH_DAMAGE := &"health_damage"
const WAS_LETHAL := &"was_lethal"
const BEFORE_HEALTH := &"before_health"
const AFTER_HEALTH := &"after_health"

const FLAT_AMOUNT := &"flat_amount"
const OF_TOTAL := &"of_total"
const OF_MISSING := &"of_missing"
const HEALED_AMOUNT := &"healed_amount"
const BEFORE_MAX_HEALTH := &"before_max_health"
const AFTER_MAX_HEALTH := &"after_max_health"
const CHANGE_HEALTH_RELATIVE := &"change_health_relative"
# Attack
#const TARGETED := &"targeted"
const STRIKE_INDEX := &"strike_index"
const ORIGIN_STRIKE_INDEX := &"origin_strike_index"
const ATTACK_META := &"attack_meta"
const STRIKE_META := &"strike_meta"
const HIT_META := &"hit_meta"
const CLEAVE := &"cleave"
const CHAINED_FROM_PREVIOUS := &"chained_from_previous"
const CLEAVE_DAMAGE := &"cleave_damage"
const CHAIN_SOURCE_TARGET_ID := &"chain_source_target_id"
const SELF_RECOIL := &"self_recoil"
const RECOIL_STATUS_ID := &"recoil_status_id"

# Summon
const SUMMONED_ID := &"summoned_id"
const PROTO := &"proto"
const SUMMON_SPEC := &"spec"
const COMBATANT_NAME := &"combatant_name"
const MAX_HEALTH := &"max_health"
const HEALTH := &"health"
const SUMMON_MAX_HEALTH := &"summon_max_health"
const ARMOR := &"armor"
const MAX_MANA := &"max_mana"
const APR := &"apr"
const APM := &"apm"
const ART_UID := &"art_uid"
const ART_FACES_RIGHT := &"art_faces_right"
const HEIGHT := &"height"
const COLOR_TINT := &"color_tint"
const PROTO_PATH := &"proto_path"
const HAS_SUMMON_RESERVE_CARD := &"has_summon_reserve_card"
const WINDUP_LAYOUT_COUNT := &"windup_layout_count"
const WINDUP_ORDER_IDS := &"windup_order_ids"
const REPLACED_ID := &"replaced_id" # optional, useful for director FX pairing
const REPLACED_INSERT_INDEX := &"replaced_insert_index"

# Card mutated
const REASON := &"reason"
const REMOVAL_TYPE := &"removal_type"
const MODIFIED_FIELDS := &"modified_fields"
const DELTA := &"delta"

# Status
const STATUS_ID := &"status_id"
const STATUS_PENDING := &"status_pending"
const STATUS_PRESENTATION_HINT := &"status_presentation_hint"
const INTENSITY := &"intensity"
const DURATION := &"duration"
const OP := &"op"
const STABILITY_BROKEN := &"stability_broken"
const DELTA_INTENSITY := &"delta_intensity"
const DELTA_DURATION := &"delta_duration"
const BEFORE_INTENSITY := &"before_intensity"
const AFTER_INTENSITY := &"after_intensity"
const BEFORE_DURATION := &"before_duration"
const AFTER_DURATION := &"after_duration"
const BEFORE_PENDING := &"before_pending"
const AFTER_PENDING := &"after_pending"

# Move (formation)
const MOVE_TYPE := &"move_type"
const BEFORE_ORDER_IDS := &"before_order_ids"
const AFTER_ORDER_IDS := &"after_order_ids"
const SWAP_A := &"swap_a"
const SWAP_B := &"swap_b"
const TO_INDEX := &"to_index"

# -------------------------
# Status ids you’ve used so far
# -------------------------
const STATUS_MARKED := &"marked"
const STATUS_DESPAIR := &"despair"
const STATUS_DANGER_ZONE := &"danger_zone"
const STATUS_HEAVY_ATTACK := &"heavy_attack"
const STATUS_SMALL := &"small"
const STATUS_DOUBLE_EDGE := &"double_edge"


# Effect params
const DAMAGE := &"damage"
const BANISH_DAMAGE := &"banish_damage"
const DAMAGE_MELEE := &"damage_melee"
const DAMAGE_RANGED := &"damage_ranged"
const STRIKES := &"strikes"
const ATTACK_MODE := &"attack_mode"
const DEAL_MOD_TYPE := &"deal_mod_type"
const TAKE_MOD_TYPE := &"take_mod_type"

const TARGET_TYPE := &"target_type"
const EXPLODE_ON_FINISH := &"explode_on_finish"
const ATTACK_SOUND := &"attack_sound"

const ARMOR_AMOUNT := &"armor_amount"
const PROJECTILE_SCENE := &"projectile_scene"
const STATUS_SCENE := &"status_scene"
const STATUS_INTENSITY := &"status_intensity"
const STATUS_DURATION := &"status_duration"
#const STATUS_ID := &"status_id"


#const GROUP_INDEX := &"group_index"
#const INSERT_INDEX := &"insert_index"
const SUMMON_COUNT := &"summon_count"
const SUMMON_DATA := &"summon_data"
const SUMMON_SOUND := &"summon_sound"


# AI state
const ATTACK_SPREE := &"attack_spree"
const USED_1 := &"used_1"
const COOLDOWN_1 := &"cooldown_1"
const PLANNING_NOW := &"planning_now"
const REPLAN_DIRTY := &"replan_dirty"
const INTENT_DIRTY := &"intent_dirty"
const IS_ACTING := &"is_acting"
const FIRST_INTENTS_READY := &"first_intent_ready"
const ACTIONS_PERFORMED_COUNT := &"actions_performed_count"
const PLANNED_SELECTION_SOURCE := &"planned_selection_source"
const ACTION_STATE := &"action_state"
const SPREE := &"spree"
const TARGETING_DANGER_ZONE := &"targeting_danger_zone"

# Chance-weight protocol
const CHANCE_ADD := &"chance_add"        # float, default 0.0
const CHANCE_MULT := &"chance_mult"      # float, default 1.0
const CHANCE_DISABLED := &"chance_disabled"  # bool, default false

# Intent
# keys.gd
const PLANNED_IDX := &"planned_idx"
const INTENT_ICON_UID := &"intent_icon_uid"
const INTENT_ICON_RANGED_UID := &"intent_icon_ranged_uid"
const INTENT_TEXT := &"intent_text"
const TOOLTIP_TEXT := &"tooltip_text"
const IS_RANGED := &"is_ranged"
const INTENT_TEXT_COLOR := &"intent_text_color"
