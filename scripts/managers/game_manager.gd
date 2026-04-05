extends Node

@warning_ignore("unused_signal")
signal game_over
@warning_ignore("unused_signal")
signal boss_defeated(boss_index: int)
@warning_ignore("unused_signal")
signal all_bosses_defeated

const BOSS_SCENES := [
	"res://scenes/arenas/arena_01.tscn",
	"res://scenes/arenas/arena_02.tscn",
]

var current_boss_index: int = 0
var player_max_health: int = 5
var player_health: int = 5

func _ready() -> void:
	print("[DEBUG] GameManager ready")

func start_game() -> void:
	current_boss_index = 0
	player_health = player_max_health
	load_next_boss()

func load_next_boss() -> void:
	if current_boss_index >= BOSS_SCENES.size():
		all_bosses_defeated.emit()
		get_tree().change_scene_to_file("res://scenes/win_screen.tscn")
		return
	print("[DEBUG] Loading boss arena: ", BOSS_SCENES[current_boss_index])
	get_tree().change_scene_to_file(BOSS_SCENES[current_boss_index])

func on_boss_defeated() -> void:
	boss_defeated.emit(current_boss_index)
	current_boss_index += 1
	await get_tree().create_timer(2.0).timeout
	load_next_boss()

func on_player_died() -> void:
	game_over.emit()
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")
