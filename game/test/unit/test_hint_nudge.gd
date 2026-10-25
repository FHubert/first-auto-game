extends GdUnitTestSuite


func test_due_once_after_delay() -> void:
	var n := HintNudge.new()
	n.delay = 8.0
	n.reset(0.0)
	assert_bool(n.due(7.9)).is_false()
	assert_bool(n.due(8.0)).is_true()
	assert_bool(n.is_active()).is_true()
	assert_bool(n.due(9.0)).is_false()


func test_reset_rearms() -> void:
	var n := HintNudge.new()
	n.delay = 8.0
	n.reset(0.0)
	n.due(8.0)
	n.reset(9.0)
	assert_bool(n.is_active()).is_false()
	assert_bool(n.due(16.9)).is_false()
	assert_bool(n.due(17.0)).is_true()
