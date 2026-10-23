class_name Level
extends Control
## Scena poziomu: generuje poziom, uruchamia GameRound, HUD, wygrana i zapis.

signal level_won(level_no: int, coins: int)
signal next_requested(level_no: int)
signal pause_requested

const MODE_CAMPAIGN: String = "campaign"

@export var level: int = 2

var round: GameRound
var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var mode: String = MODE_CAMPAIGN
var level_no: int = 1

@onready var board: BoardView = $Board
@onready var hud: Hud = $Hud
@onready var level_complete: LevelComplete = $LevelComplete


func _ready() -> void:
	if state == null:
		state = SaveSystem.load()
	board.round_won.connect(_on_round_won)
	board.pour_finished.connect(func(_from: int, _to: int) -> void: hud.refresh())
	hud.undo_pressed.connect(undo)
	hud.restart_pressed.connect(restart)
	hud.pause_pressed.connect(pause)
	level_complete.next_pressed.connect(on_next_pressed)
	if round == null:
		load_level(state.level, state.theme_active)


func load_level(level_in: int, theme_id: String = "classic") -> void:
	level_no = level_in
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	round = GameRound.new()
	round.start(ContentGenerator.new().generate(seed_value, level_no))
	board.setup(round, theme_id)
	hud.bind(round, level_no)


func on_next_pressed() -> void:
	level_complete.visible = false
	load_level(state.level, state.theme_active)
	next_requested.emit(state.level)


func undo() -> void:
	if round.undo():
		board.refresh()
	hud.refresh()


func restart() -> void:
	round.restart()
	state.level_restarts += 1
	board.refresh()
	hud.refresh()
	Analytics.track_progression("Fail", mode, _level_id())


func pause() -> void:
	pause_requested.emit()


func _on_round_won() -> void:
	var result: Dictionary = round.result()
	var coins: int = Economy.apply_win(state, result)
	state.level += 1
	state.levels_completed += 1
	DailyRewards.register_play(state, DailyRewards.utc_day_from_unix(int(clock.call())))
	SaveSystem.save(state)
	Analytics.track_progression("Complete", mode, _level_id(), int(result.get("moves", 0)))
	hud.refresh()
	level_complete.show_result(coins, bool(result.get("perfect", false)), level_no)
	level_won.emit(level_no, coins)


func _level_id() -> String:
	return "level_%04d" % level_no
