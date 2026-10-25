extends GdUnitTestSuite
## T-227: RoundCounters - liczniki i boostery rundy.


func test_reset_and_restart_keep_boosters_and_undos() -> void:
	var c := RoundCounters.new()
	c.reset(2)
	(
		assert_dict(c.to_dict())
		. is_equal(
			{
				"undo_charges": 2,
				"undos_used": 0,
				"extra_tubes_added": 0,
				"boosters_used": 0,
				"restarts": 0,
			}
		)
	)
	c.use_undo()
	c.on_extra_tube()
	c.on_restart(2)
	assert_int(c.undo_charges).is_equal(2)
	assert_int(c.extra_tubes_added).is_equal(0)
	assert_int(c.restarts).is_equal(1)
	assert_int(c.undos_used).is_equal(1)
	assert_int(c.boosters_used).is_equal(1)


func test_add_undo_charges_and_use_undo() -> void:
	var c := RoundCounters.new()
	assert_bool(c.use_undo()).is_false()
	c.add_undo_charges(0)
	c.add_undo_charges(-3)
	assert_int(c.undo_charges).is_equal(0)
	assert_int(c.boosters_used).is_equal(0)
	c.add_undo_charges(2)
	assert_int(c.undo_charges).is_equal(2)
	assert_int(c.boosters_used).is_equal(1)
	assert_bool(c.use_undo()).is_true()
	assert_int(c.undo_charges).is_equal(1)
	assert_int(c.undos_used).is_equal(1)


func test_extra_tube_and_hint_increment_boosters() -> void:
	var c := RoundCounters.new()
	c.on_extra_tube()
	assert_int(c.extra_tubes_added).is_equal(1)
	assert_int(c.boosters_used).is_equal(1)
	c.on_hint_used()
	assert_int(c.boosters_used).is_equal(2)
	assert_int(c.extra_tubes_added).is_equal(1)


func test_from_dict_validation_and_fallback() -> void:
	assert_object(RoundCounters.from_dict({"restarts": -1}, 3)).is_null()
	assert_object(RoundCounters.from_dict({"undos_used": "x"}, 3)).is_null()
	var c: RoundCounters = RoundCounters.from_dict({"boosters_used": 4.0}, 3)
	assert_object(c).is_not_null()
	assert_int(c.undo_charges).is_equal(3)
	assert_int(c.boosters_used).is_equal(4)
	assert_int(c.restarts).is_equal(0)
