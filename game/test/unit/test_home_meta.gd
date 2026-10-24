extends GdUnitTestSuite


func _home(total: int, best: int) -> Home:
	var st := GameState.new()
	st.daily_completed_total = total
	st.streak_best = best
	var home: Home = auto_free(load("res://src/ui/home.tscn").instantiate())
	home.state = st
	add_child(home)
	return home


func test_daily_total_hidden_when_zero() -> void:
	assert_bool(_home(0, 0).daily_total_label.visible).is_false()


func test_daily_total_shown() -> void:
	var home := _home(23, 0)
	assert_bool(home.daily_total_label.visible).is_true()
	assert_str(home.daily_total_label.text).contains("23")


func test_streak_best_hidden_below_threshold() -> void:
	assert_bool(_home(0, 1).streak_best_label.visible).is_false()


func test_streak_best_shown() -> void:
	var home := _home(0, 12)
	assert_bool(home.streak_best_label.visible).is_true()
	assert_str(home.streak_best_label.text).contains("12")
