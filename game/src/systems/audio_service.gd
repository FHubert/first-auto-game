extends Node
## Autoload "Audio": SFX pool, ambient music, haptics. Respects settings, focus and ad mute.

## Emitted on every play_sfx call (even when muted); observation point for tests.
signal sfx_requested(sfx_name: String)
## Emitted when haptics are enabled and a vibration is requested; observation point for tests.
signal haptic_requested(duration_ms: int)

const SFX: Dictionary = {
	"pour":
	[
		"res://assets/audio/pour_1.wav",
		"res://assets/audio/pour_2.wav",
		"res://assets/audio/pour_3.wav",
	],
	"tube_full": ["res://assets/audio/tube_full.wav"],
	"win": ["res://assets/audio/win.wav"],
	"click": ["res://assets/audio/click.wav"],
	"error": ["res://assets/audio/error.wav"],
	"coins": ["res://assets/audio/coins.wav"],
}
const MUSIC_PATH: String = "res://assets/audio/ambient_loop.ogg"
const MUSIC_DB: float = -6.0
const SFX_DB: float = 0.0
const POOL_SIZE: int = 6
const HAPTIC_MS: int = 20

var music_on: bool = true
var sfx_on: bool = true
var haptics_on: bool = true
var focused: bool = true
var muted_by_ads: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var headless: bool = DisplayServer.get_name() == "headless"
var last_played: String = ""
var play_count: int = 0
var last_haptic_ms: int = 0

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _cache: Dictionary = {}


func _ready() -> void:
	# One single point for UI click sound: every BaseButton entering the tree
	# (scenes and code-built) gets it, so scenes never wire "click" themselves.
	get_tree().node_added.connect(_on_node_added)
	rng.seed = Time.get_ticks_usec()
	for i in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)


func apply_settings(settings: Dictionary) -> void:
	music_on = bool(settings.get("music_on", true))
	sfx_on = bool(settings.get("sfx_on", true))
	haptics_on = bool(settings.get("haptics_on", true))
	_update_music()


## Plays a named SFX (random variant). True when playback was actually requested.
func play_sfx(sfx_name: String) -> bool:
	sfx_requested.emit(sfx_name)
	if not sfx_on or not SFX.has(sfx_name):
		return false
	var paths: Array = SFX[sfx_name]
	var path: String = paths[rng.randi() % paths.size()]
	last_played = path.get_file().get_basename()
	play_count += 1
	if headless or _pool.is_empty():
		return true
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = _load_stream(path)
	player.play()
	return true


func play_music() -> void:
	if headless or _music == null:
		return
	if _music.stream == null:
		var stream: AudioStream = _load_stream(MUSIC_PATH)
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_music.stream = stream
	if not _music.playing:
		_music.play()
	_update_music()


func stop_music() -> void:
	if _music != null:
		_music.stop()


func is_music_playing() -> bool:
	return music_on and focused and not muted_by_ads


func set_app_muted(muted: bool) -> void:
	muted_by_ads = muted
	_update_music()


func is_app_muted() -> bool:
	return muted_by_ads


func set_focused(f: bool) -> void:
	focused = f
	_update_music()


func haptic(duration_ms: int = HAPTIC_MS) -> bool:
	if not haptics_on:
		return false
	last_haptic_ms = duration_ms
	haptic_requested.emit(duration_ms)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_focused(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_focused(true)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(func() -> void: play_sfx("click"))


func _update_music() -> void:
	if _music != null:
		_music.stream_paused = not is_music_playing()


func _load_stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
