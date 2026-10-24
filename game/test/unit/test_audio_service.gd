extends GdUnitTestSuite

var _audio: Node


func before_test() -> void:
	_audio = auto_free(load("res://src/systems/audio_service.gd").new())
	add_child(_audio)
	_audio.rng.seed = 1


func test_sfx_off_does_not_play() -> void:
	_audio.apply_settings({"sfx_on": false})
	assert_bool(_audio.play_sfx("pour")).is_false()
	assert_int(_audio.play_count).is_equal(0)


func test_sfx_on_plays_variant() -> void:
	_audio.apply_settings({"sfx_on": true})
	assert_bool(_audio.play_sfx("pour")).is_true()
	assert_array(["pour_1", "pour_2", "pour_3"]).contains([_audio.last_played])
	assert_int(_audio.play_count).is_equal(1)
	assert_bool(_audio.play_sfx("nope")).is_false()
	assert_int(_audio.play_count).is_equal(1)


func test_music_state_follows_settings_focus_and_ads() -> void:
	_audio.apply_settings({"music_on": false})
	assert_bool(_audio.is_music_playing()).is_false()
	_audio.apply_settings({"music_on": true})
	assert_bool(_audio.is_music_playing()).is_true()
	_audio.set_focused(false)
	assert_bool(_audio.is_music_playing()).is_false()
	_audio.set_focused(true)
	assert_bool(_audio.is_music_playing()).is_true()
	_audio.set_app_muted(true)
	assert_bool(_audio.is_music_playing()).is_false()
	_audio.set_app_muted(false)
	assert_bool(_audio.is_music_playing()).is_true()


func test_haptics_respect_setting() -> void:
	_audio.apply_settings({"haptics_on": false})
	assert_bool(_audio.haptic()).is_false()
	assert_int(_audio.last_haptic_ms).is_equal(0)
	_audio.apply_settings({"haptics_on": true})
	_audio.haptic()
	assert_int(_audio.last_haptic_ms).is_equal(20)


func test_audio_files_exist() -> void:
	for key: String in _audio.SFX:
		for path: String in _audio.SFX[key]:
			assert_bool(ResourceLoader.exists(path)).is_true()
	assert_bool(ResourceLoader.exists(_audio.MUSIC_PATH)).is_true()


func test_haptic_ms_const() -> void:
	assert_int(_audio.HAPTIC_MS).is_equal(20)


func test_click_through_single_point() -> void:
	var clicks: Array[int] = [0]
	_audio.sfx_requested.connect(
		func(n: String) -> void:
			if n == "click":
				clicks[0] += 1
	)
	var a: Button = auto_free(Button.new())
	add_child(a)
	a.pressed.emit()
	assert_int(clicks[0]).is_equal(1)
	var b: Button = auto_free(Button.new())
	add_child(b)
	b.pressed.emit()
	assert_int(clicks[0]).is_equal(2)
