extends GdUnitTestSuite


func test_summarize_three_seeds() -> void:
	var r: Dictionary = CurveStats.summarize(
		{"56+": [30.0, 40.0, 35.0], "26-55": [60.0, 70.0, 65.0]}
	)
	assert_int(r["n"]).is_equal(3)
	assert_float(r["mean"]["56+"]).is_equal_approx(35.0, 0.001)
	assert_float(r["mean"]["26-55"]).is_equal_approx(65.0, 0.001)
	assert_float(r["stderr_pp"]["56+"]).is_equal_approx(5.0 / sqrt(3.0), 0.01)
	assert_float(r["min"]["56+"]).is_equal(30.0)
	assert_float(r["max"]["26-55"]).is_equal(70.0)


func test_summarize_single_seed_has_zero_stderr() -> void:
	var r: Dictionary = CurveStats.summarize({"56+": [42.0]})
	assert_int(r["n"]).is_equal(1)
	assert_float(r["mean"]["56+"]).is_equal(42.0)
	assert_float(r["stderr_pp"]["56+"]).is_equal(0.0)
