extends GdUnitTestSuite
## T-227: format snapshotu GameRound.to_dict() zamrożony (klucze, kolejność, wartości).


func before_test() -> void:
	GameConfig.reset()


func _snapshot() -> Dictionary:
	return {
		"level_data":
		{
			"payload":
			{
				"tubes": [[0, 1], [1, 0], []],
				"capacity": 2,
				"min_moves": 3,
				"min_moves_exact": true,
			},
		},
		"tubes": [[0], [1, 1], [0], []],
		"capacity": 2,
		"history": [[[0, 1], [1, 0], [], []], [[0, 1], [1], [0], []]],
		"moves": 2,
		"undo_charges": 2,
		"undos_used": 1,
		"extra_tubes_added": 1,
		"boosters_used": 3,
		"restarts": 1,
		"elapsed_s": 12.5,
	}


func test_snapshot_round_trip_is_identical() -> void:
	var d: Dictionary = _snapshot()
	var r: GameRound = GameRound.from_dict(d)
	assert_object(r).is_not_null()
	assert_bool(r.to_dict() == d).is_true()
	assert_array(r.to_dict().keys()).is_equal(d.keys())
	assert_str(JSON.stringify(r.to_dict())).is_equal(JSON.stringify(d))
