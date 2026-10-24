extends GdUnitTestSuite
## Regresja SortSolver (T-124): wyniki zapisane z implementacji sprzed optymalizacji.
## Optymalizacja nie może zmienić ruchów, `exact`, `expanded` ani ścieżki.

const DAILY_DAY: int = 20750
const FAIL_HASH: String = "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945"
## level 0 = Poziom dnia DAILY_DAY.
const CASES: Array = [
	{
		"level": 2,
		"budget": 250,
		"weight": 1.0,
		"moves": 7,
		"exact": true,
		"expanded": 56,
		"hash": "b388ec025f82ca3aaeeed37615154ed5338d0bf8659f7fca39164faf696e88ea",
	},
	{
		"level": 10,
		"budget": 1000,
		"weight": 1.0,
		"moves": 11,
		"exact": true,
		"expanded": 227,
		"hash": "30ec561eb905eed91ae042210e06245a509b2c34c9188c0b62e93cf767e8bbc6",
	},
	{
		"level": 10,
		"budget": 250,
		"weight": 3.0,
		"moves": 12,
		"exact": false,
		"expanded": 13,
		"hash": "0b7ded1c222af1b14e701cd55108bf470e2b33c099d1acc6d2027ca6a48cdf4a",
	},
	{
		"level": 26,
		"budget": 1000,
		"weight": 1.0,
		"moves": -1,
		"exact": false,
		"expanded": 1000,
		"hash": FAIL_HASH,
	},
	{
		"level": 26,
		"budget": 50000,
		"weight": 1.0,
		"moves": 16,
		"exact": true,
		"expanded": 1215,
		"hash": "54295cb527fc65325a90a58a339a7cb1698a1ecbf67304e367bc16c49c74c456",
	},
	{
		"level": 26,
		"budget": 250,
		"weight": 3.0,
		"moves": 18,
		"exact": false,
		"expanded": 19,
		"hash": "fbee7f21ed5ed0c2b6d6ab344aa0d7f90b5ed64f60bb432dd8ae8517e8c00aec",
	},
	{
		"level": 50,
		"budget": 1000,
		"weight": 1.0,
		"moves": -1,
		"exact": false,
		"expanded": 1000,
		"hash": FAIL_HASH,
	},
	{
		"level": 50,
		"budget": 250,
		"weight": 3.0,
		"moves": 38,
		"exact": false,
		"expanded": 239,
		"hash": "43babd2e7465b7c1c1ef8d5f470c214435b680258ebcde48955205449b5795a1",
	},
	{
		"level": 0,
		"budget": 1000,
		"weight": 1.0,
		"moves": -1,
		"exact": false,
		"expanded": 1000,
		"hash": FAIL_HASH,
	},
	{
		"level": 0,
		"budget": 250,
		"weight": 3.0,
		"moves": 25,
		"exact": false,
		"expanded": 26,
		"hash": "58246e2acd9b2783f2b776ff6053b05cb23bcc36870d629f0f11d18fd4e9b91a",
	},
]


func _board_for(level: int) -> SortBoard:
	var data: Dictionary
	if level == 0:
		data = DailyChallenge.level_for_day(DAILY_DAY)
	else:
		data = ContentGenerator.new().generate(int(GameConfig.get_value("campaign_seed")), level)
	return SortBoard.from_payload(data["payload"])


func test_results_match_recorded_baseline() -> void:
	for c in CASES:
		var label: String = "L%d b%d w%s" % [c["level"], c["budget"], c["weight"]]
		var r: Dictionary = SortSolver.solve(_board_for(c["level"]), c["budget"], c["weight"])
		assert_int(r["moves"]).override_failure_message(label + " moves").is_equal(c["moves"])
		assert_bool(r["exact"]).override_failure_message(label + " exact").is_equal(c["exact"])
		assert_int(r["expanded"]).override_failure_message(label + " expanded").is_equal(
			c["expanded"]
		)
		assert_str(str(r["path"]).sha256_text()).override_failure_message(label + " path").is_equal(
			c["hash"]
		)


func test_recorded_paths_replay_to_win() -> void:
	var r: Dictionary = SortSolver.solve(_board_for(26), 50000, 1.0)
	assert_bool(SortSolver.replay(_board_for(26), r["path"])).is_true()
