class_name BattleRemovalLog extends RefCounted

var records: Array[RemovalRecord] = []

func clear() -> void:
	records.clear()

func append(record: RemovalRecord) -> void:
	if record == null:
		return
	records.append(record)

func count_by_round(removal_type: int, round_number: int, group_index: int = -1) -> int:
	var total := 0
	for record in records:
		if record == null:
			continue
		if int(record.removal_type) != int(removal_type):
			continue
		if int(record.round_number) != int(round_number):
			continue
		if int(group_index) >= 0 and int(record.group_index) != int(group_index):
			continue
		total += 1
	return total

func count_by_group_turn(removal_type: int, group_turn_number: int, group_index: int = -1) -> int:
	var total := 0
	for record in records:
		if record == null:
			continue
		if int(record.removal_type) != int(removal_type):
			continue
		if int(record.group_turn_number) != int(group_turn_number):
			continue
		if int(group_index) >= 0 and int(record.group_index) != int(group_index):
			continue
		total += 1
	return total

func clone() -> BattleRemovalLog:
	var c := BattleRemovalLog.new()
	for record in records:
		c.records.append(record.clone() if record != null else null)
	return c
