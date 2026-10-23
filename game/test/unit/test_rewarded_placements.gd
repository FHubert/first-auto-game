extends GdUnitTestSuite

var _ads: Node
var _provider: FakeAdProvider
var _rp: RewardedPlacements
var _calls: Array[int] = [0]


func before_test() -> void:
	GameConfig.reset()
	_provider = FakeAdProvider.new()
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_rp = RewardedPlacements.new()
	_calls[0] = 0


func after_test() -> void:
	GameConfig.reset()


func _grant() -> void:
	_calls[0] += 1


func test_granted_exactly_once() -> void:
	assert_bool(_rp.offer("skip_level", _grant, _ads)).is_true()
	assert_int(_calls[0]).is_equal(1)
	assert_int(_rp.granted_count("skip_level")).is_equal(1)


func test_skipped_grants_nothing() -> void:
	_provider.reward_on_show = false
	assert_bool(_rp.offer("double_coins", _grant, _ads)).is_true()
	assert_int(_calls[0]).is_equal(0)
	assert_int(_rp.granted_count("double_coins")).is_equal(0)


func test_unavailable_grants_nothing() -> void:
	_provider.always_ready = false
	assert_bool(_rp.can_offer("double_coins", _ads)).is_false()
	assert_bool(_rp.offer("double_coins", _grant, _ads)).is_false()
	assert_int(_calls[0]).is_equal(0)


func test_undo_refill_cap_and_reset() -> void:
	assert_bool(_rp.offer("undo_refill", _grant, _ads)).is_true()
	assert_bool(_rp.offer("undo_refill", _grant, _ads)).is_true()
	assert_bool(_rp.offer("undo_refill", _grant, _ads)).is_false()
	assert_int(_calls[0]).is_equal(2)
	_rp.reset()
	assert_bool(_rp.can_offer("undo_refill", _ads)).is_true()


func test_double_coins_once() -> void:
	assert_bool(_rp.offer("double_coins", _grant, _ads)).is_true()
	assert_bool(_rp.offer("double_coins", _grant, _ads)).is_false()
	assert_int(_calls[0]).is_equal(1)


func test_unknown_id() -> void:
	assert_bool(_rp.can_offer("nope", _ads)).is_false()
	assert_int(_rp.max_per_level("nope")).is_equal(0)


func test_max_per_level_follows_config() -> void:
	GameConfig.apply_remote({"rewarded_undo_refill_max_per_level": 1})
	assert_int(_rp.max_per_level("undo_refill")).is_equal(1)
	assert_int(_rp.max_per_level("daily_x2")).is_equal(1)
