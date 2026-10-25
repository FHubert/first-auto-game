extends GdUnitTestSuite

var _state: GameState
var _round: GameRound


func before_test() -> void:
	GameConfig.reset()
	_state = GameState.new()
	_state.coins = 100
	_round = GameRound.new()
	_round.start(ContentGenerator.new().generate(1, 2))


func after_test() -> void:
	GameConfig.reset()


func test_extra_tube_spends_and_adds_then_limit() -> void:
	var tubes: int = _round.board().tube_count()
	assert_bool(Boosters.buy_extra_tube(_state, _round)).is_true()
	assert_int(_state.coins).is_equal(100 - Economy.extra_tube_cost())
	assert_int(_round.board().tube_count()).is_equal(tubes + 1)
	var coins: int = _state.coins
	assert_bool(Boosters.buy_extra_tube(_state, _round)).is_false()
	assert_int(_state.coins).is_equal(coins)
	assert_int(_round.board().tube_count()).is_equal(tubes + 1)


func test_extra_tube_without_funds() -> void:
	_state.coins = 0
	var tubes: int = _round.board().tube_count()
	assert_bool(Boosters.buy_extra_tube(_state, _round)).is_false()
	assert_int(_round.board().tube_count()).is_equal(tubes)
	assert_int(_state.coins).is_equal(0)


func test_undo_refill() -> void:
	var charges: int = _round.counters.undo_charges
	assert_bool(Boosters.buy_undo_refill(_state, _round)).is_true()
	assert_int(_state.coins).is_equal(100 - Economy.undo_refill_cost())
	assert_int(_round.counters.undo_charges).is_equal(charges + 3)
	_state.coins = 0
	assert_bool(Boosters.buy_undo_refill(_state, _round)).is_false()
	assert_int(_round.counters.undo_charges).is_equal(charges + 3)


func test_hint_needs_funds_then_returns_legal_move() -> void:
	_state.coins = Economy.hint_cost() - 1
	assert_that(Boosters.buy_hint(_state, _round)).is_equal(GameRound.NO_HINT)
	assert_int(_state.coins).is_equal(Economy.hint_cost() - 1)
	_state.coins = 100
	var h: Vector2i = Boosters.buy_hint(_state, _round)
	assert_bool(_round.board().can_pour(h.x, h.y)).is_true()
	assert_int(_state.coins).is_equal(100 - Economy.hint_cost())
