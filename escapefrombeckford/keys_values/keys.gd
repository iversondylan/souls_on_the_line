# keys.gd
class_name Keys

const LOG_ENUM_STRINGS := false

# -------------------------
# Shared context keys
# -------------------------
const MODE := &"mode"
const MODE_SIM := &"sim"

const PLAYER_ID := &"player_id"
const SOURCE_ID := &"source_id"
const TARGET_ID := &"target_id"
const ACTOR_ID := &"actor_id"

const TURN_ID := &"turn_id"
const GROUP_INDEX := &"group_index"
const INSERT_INDEX := &"insert_index"
const GROUP_TURN := &"group_turn"

# -------------------------
# Scope frame keys
# -------------------------
const SCOPE_ID := &"scope_id"
const PARENT_SCOPE_ID := &"parent_scope_id"
const SCOPE_KIND := &"kind"
const SCOPE_LABEL := &"label"

# Scope kinds (these are *values* used in BattleScopeManager / writer)
const SCOPE_BATTLE := &"battle"
const SCOPE_GROUP_TURN := &"group_turn"
const SCOPE_ACTOR_TURN := &"actor_turn"
const SCOPE_CARD := &"card"
const SCOPE_ATTACK := &"attack"
const SCOPE_DAMAGE := &"damage"
const SCOPE_STATUS := &"status"
const SCOPE_SUMMON := &"summon"
const SCOPE_MOVE := &"move"
const SCOPE_ARCANA := &"arcana"

# -------------------------
# Event data keys
# -------------------------

# Card played
const CARD_UID := &"card_uid"
const CARD_NAME := &"card_name"
const CARD_TYPE_I := &"card_type_i"
const CARD_TARGET_TYPE_I := &"card_target_type_i"
const CARD_TYPE_S := &"card_type_s"
const CARD_TARGET_TYPE_S := &"card_target_type_s"
const TARGETS := &"targets"

# Damage applied
const BASE_AMOUNT := &"base"
const FINAL_AMOUNT := &"amount"
const ARMOR_DAMAGE := &"armor_damage"
const HEALTH_DAMAGE := &"health_damage"
const WAS_LETHAL := &"was_lethal"

# Summon
const SUMMONED_ID := &"summoned_id"
const PROTO := &"proto"
const SUMMON_SPEC := &"spec"

# Card mutated
const REASON := &"reason"
const DELTA := &"delta"

# Status
const STATUS_ID := &"status_id"
const STACKS_DELTA := &"stacks_delta"
const DURATION := &"duration"
const REMOVED_ALL := &"removed_all"

# Move (formation)
const MOVE_TYPE := &"move_type"
const BEFORE_ORDER_IDS := &"before_order_ids"
const AFTER_ORDER_IDS := &"after_order_ids"
const SWAP_A := &"swap_a"
const SWAP_B := &"swap_b"
const TO_INDEX := &"to_index"

# Death
const DEATH_REASON := &"death_reason"

# Arcana proc
const PROC := &"proc"

# -------------------------
# Status ids you’ve used so far
# -------------------------
const STATUS_MARKED := &"marked"
