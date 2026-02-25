# npc_keys.gd
class_name NPCKeys

# Effect params
const DAMAGE := &"damage"
const DAMAGE_MELEE := &"damage_melee"
const DAMAGE_RANGED := &"damage_ranged"
const STRIKES := &"strikes"
const ATTACK_MODE := &"attack_mode"

const TARGET_TYPE := &"target_type"
const EXPLODE_ON_FINISH := &"explode_on_finish"
const ATTACK_SOUND := &"attack_sound"

const ARMOR_AMOUNT := &"armor_amount"
const PROJECTILE_SCENE := &"projectile_scene"
const STATUS_SCENE := &"status_scene"
const STATUS_INTENSITY := &"status_intensity"
const STATUS_DURATION := &"status_duration"
const STATUS_ID := &"status_id"


const GROUP_INDEX := &"group_index"
const INSERT_INDEX := &"insert_index"
const SUMMON_COUNT := &"summon_count"
const SUMMON_DATA := &"summon_data"
const SUMMON_SOUND := &"summon_sound"


# AI state
const ATTACK_SPREE := &"attack_spree"
const USED_1 := &"used_1"
const COOLDOWN_1 := &"cooldown_1"

# Chance-weight protocol
const CHANCE_ADD := &"chance_add"        # float, default 0.0
const CHANCE_MULT := &"chance_mult"      # float, default 1.0
const CHANCE_DISABLED := &"chance_disabled"  # bool, default false
