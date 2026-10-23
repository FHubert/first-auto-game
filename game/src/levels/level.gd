class_name Level
extends Control
## Scena poziomu: generuje poziom, uruchamia GameRound i podaje go do BoardView.

@export var level: int = 2

var round: GameRound

@onready var board: BoardView = $Board


func _ready() -> void:
	if round == null:
		load_level(level)


func load_level(level_no: int, theme_id: String = "classic") -> void:
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	round = GameRound.new()
	round.start(ContentGenerator.new().generate(seed_value, level_no))
	board.setup(round, theme_id)
