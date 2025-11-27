#class_name BattleController 
extends Node

enum CardsViewState {
	NO_CARDS_VIEW,
	COLLECTION_VIEW,
	DRAW_VIEW,
	DISCARD_VIEW
}

var is_running: bool = true
var turn_number: int = 0

enum BattleState {
	PRE_GAME,
	FRIENDLY_TURN,
	ENEMY_TURN,
	GAME_OVER,
	VICTORY
}

var current_state: BattleState = BattleState.PRE_GAME
var current_cards_view_state: CardsViewState = CardsViewState.NO_CARDS_VIEW

func pause():
	is_running = false

func resume():
	is_running = true

func end_phase() -> void:
	match current_state:
		BattleState.PRE_GAME:
			Events.reset_enemies.emit()
			Events.reset_friendlies.emit()
			Events.pre_game_ended.emit()
		BattleState.FRIENDLY_TURN:
			Events.friendly_turn_ended.emit()
		BattleState.ENEMY_TURN:
			Events.enemy_turn_ended.emit()
		BattleState.GAME_OVER:
			pass
		BattleState.VICTORY:
			pass

func begin_phase(next_state: BattleState) -> void:
	current_state = next_state
	
	match current_state:
		BattleState.PRE_GAME:
			pass
		BattleState.FRIENDLY_TURN:
			turn_number += 1
			Events.friendly_turn_started.emit()
		BattleState.ENEMY_TURN:
			turn_number += 1
			Events.enemy_turn_started.emit()
		BattleState.GAME_OVER:
			is_running = false
			Events.game_over_started.emit()
		BattleState.VICTORY:
			is_running = false
			Events.victory_started.emit()

func transition(next_state: BattleState):
	if !is_running:
		return
	match current_state:
		BattleState.PRE_GAME:
			Events.reset_enemies.emit()
			Events.reset_friendlies.emit()
			Events.pre_game_ended.emit()
		BattleState.FRIENDLY_TURN:
			Events.friendly_turn_ended.emit()
		BattleState.ENEMY_TURN:
			Events.enemy_turn_ended.emit()
		BattleState.GAME_OVER:
			pass
		BattleState.VICTORY:
			pass
	
	current_state = next_state
	
	match current_state:
		BattleState.PRE_GAME:
			pass
		BattleState.FRIENDLY_TURN:
			turn_number += 1
			Events.friendly_turn_started.emit()
		BattleState.ENEMY_TURN:
			turn_number += 1
			Events.enemy_turn_started.emit()
		BattleState.GAME_OVER:
			is_running = false
			Events.game_over_started.emit()
		BattleState.VICTORY:
			is_running = false
			Events.victory_started.emit()
			
func transition_cards_view(next_state: CardsViewState):
	match current_cards_view_state:
		CardsViewState.NO_CARDS_VIEW:
			pass
		CardsViewState.COLLECTION_VIEW:
			pass
		CardsViewState.DRAW_VIEW:
			pass
		CardsViewState.DISCARD_VIEW:
			pass
	
	current_cards_view_state = next_state
	
	match current_cards_view_state:
		CardsViewState.NO_CARDS_VIEW:
			resume()
		CardsViewState.COLLECTION_VIEW:
			pause()
		CardsViewState.DRAW_VIEW:
			pause()
		CardsViewState.DISCARD_VIEW:
			pause()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
