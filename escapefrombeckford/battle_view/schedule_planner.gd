# schedule_planner.gd

class_name SchedulePlanner extends RefCounted

# How far ahead we *may* peek in the log later.
var lookahead_beats: int = 8

# Bar structure (can move to Transport later)
var beats_per_bar: float = 4.0

# Main entry point
func make_plan(
	clock: BattleClock,
	scheduler: BeatScheduler,
	beat: Array[BattleEvent],
	is_player_turn: bool,
	is_player_actor: bool
) -> SchedulePlan:
	var plan := SchedulePlan.new()

	var mode := scheduler.mode_for_beat(beat, is_player_turn, is_player_actor)
	var wait_q := scheduler.quarters_for_beat(beat)

	# Default: run "now"
	var now := clock.now_sec()
	plan.t_start = now

	# When GRID: align the *end barrier* to grid (your current behavior),
	# OR in the future you could choose to align the *start*.
	var t0 := now
	if mode == BeatScheduler.Mode.GRID:
		t0 = clock.next_grid_time(now, 1.0)

	# For now we do not delay playback; we only compute ownership end time.
	# This preserves your current feel.
	plan.t_start = now
	plan.t_end = (t0 + wait_q * clock.seconds_per_quarter())

	# Single “action”: play this beat immediately, with duration metadata
	var a := DirectorAction.new()
	a.t_rel = 0.0
	a.duration = wait_q * clock.seconds_per_quarter()
	a.label = "beat"
	# Stash the entire beat on the action (Director can iterate it)
	# Use `event=null` and a new field, OR just store in label/extra.
	# Easiest: store beat in plan itself and let BattleView pass it.
	plan.actions.append(a)

	return plan
