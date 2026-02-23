# keys.gd
class_name Keys

# -----------------------------------------------------------------------------
# Shared param keys for SIM / headless contexts (StringName constants)
# Use these anywhere you'd otherwise write &"some_key".
# -----------------------------------------------------------------------------

# General context
const MODE := &"mode"					# e.g. ctx.params[Keys.MODE] = Keys.MODE_SIM
const MODE_SIM := &"sim"

# Actor / ownership
const PLAYER_ID := &"player_id"			# combat_id of player in sim
const SOURCE_ID := &"source_id"			# combat_id of source/owner for effects

# Formation / placement
const GROUP_INDEX := &"group_index"		# 0 friendly, 1 enemy
const INSERT_INDEX := &"insert_index"	# insert position for summons

# -----------------------------------------------------------------------------
# SIM-relevant status ids you’ve used so far
# (Still "keys", but for StringName hygiene in headless queries.)
# -----------------------------------------------------------------------------
const STATUS_MARKED := &"marked"

# -----------------------------------------------------------------------------
# Optional: headless “op” dictionary keys (used in BattleResolver emit-only ops)
# Only include if you want these to be StringName too.
# -----------------------------------------------------------------------------
const OP := &"op"
const OP_GROUP_TURN_START := &"group_turn_start"
const OP_GROUP_TURN_END := &"group_turn_end"
const OP_ARCANA_PROC := &"arcana_proc"

const GROUP := &"group"
const PROC := &"proc"
const GROUP_TURN := &"group_turn"

const TARGET_ID := &"target_id"
