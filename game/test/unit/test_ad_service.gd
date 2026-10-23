extends GdUnitTestSuite

var _ads: Node
var _provider: FakeAdProvider
var _now: Array[float] = [0.0]


func before_test() -> void:
	GameConfig.reset()
	_now[0] = 0.0
	_provider = FakeAdProvider.new()
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_ads.clock = func() -> float: return _now[0]


func after_test() -> void:
	GameConfig.reset()


func test_interstitial_only_every_n_rounds() -> void:
	assert_bool(_ads.maybe_show_interstitial(5)).is_false()
	assert_bool(_ads.maybe_show_interstitial(9)).is_false()
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	assert_int(_provider.interstitials_shown).is_equal(1)


func test_interstitial_respects_min_seconds() -> void:
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	_now[0] = 30.0
	assert_bool(_ads.maybe_show_interstitial(15)).is_false()
	_now[0] = 121.0
	assert_bool(_ads.maybe_show_interstitial(15)).is_true()
	assert_int(_provider.interstitials_shown).is_equal(2)


func test_interstitial_not_shown_when_not_ready() -> void:
	_provider.always_ready = false
	assert_bool(_ads.maybe_show_interstitial(10)).is_false()
	assert_int(_provider.interstitials_shown).is_equal(0)


func test_interstitial_cap_follows_config() -> void:
	GameConfig.apply_remote({"interstitial_every_n_rounds": 2})
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()


func test_interstitial_not_when_ads_removed() -> void:
	assert_bool(_ads.maybe_show_interstitial(10, true)).is_false()
	assert_int(_ads.interstitials_shown).is_equal(0)
	assert_int(_provider.interstitials_shown).is_equal(0)


func test_interstitial_skipped_after_rewarded_in_same_break() -> void:
	_ads.request_rewarded("double_coins", func() -> void: pass)
	assert_bool(_ads.maybe_show_interstitial(10)).is_false()
	_now[0] = 121.0
	assert_bool(_ads.maybe_show_interstitial(15)).is_true()


func test_rewarded_below_min_level_does_not_block_later_interstitial() -> void:
	_ads.request_rewarded("double_coins", func() -> void: pass)
	assert_bool(_ads.maybe_show_interstitial(3)).is_false()
	_now[0] = 121.0
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()


func test_interstitial_min_level_from_config() -> void:
	assert_bool(_ads.maybe_show_interstitial(5)).is_false()
	GameConfig.apply_remote({"interstitial_min_level": 1})
	assert_bool(_ads.maybe_show_interstitial(5)).is_true()


func test_reset_break() -> void:
	_ads.request_rewarded("double_coins", func() -> void: pass)
	_ads.reset_break()
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()


func test_rewarded_calls_callback_on_reward() -> void:
	var calls: Array[int] = [0]
	var shown: bool = _ads.request_rewarded("double_coins", func() -> void: calls[0] += 1)
	assert_bool(shown).is_true()
	assert_int(calls[0]).is_equal(1)
	assert_int(_provider.rewarded_shown).is_equal(1)


func test_rewarded_no_callback_when_not_granted() -> void:
	_provider.reward_on_show = false
	var calls: Array[int] = [0]
	_ads.request_rewarded("double_coins", func() -> void: calls[0] += 1)
	assert_int(calls[0]).is_equal(0)


func test_rewarded_unavailable_returns_false() -> void:
	_provider.always_ready = false
	var calls: Array[int] = [0]
	assert_bool(_ads.request_rewarded("x", func() -> void: calls[0] += 1)).is_false()
	assert_int(calls[0]).is_equal(0)
