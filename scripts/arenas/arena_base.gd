extends Node2D

@onready var hud: CanvasLayer = $HUD
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_spawn: Marker2D = $BossSpawn

var player_scene := preload("res://scenes/player/player.tscn")

func _ready() -> void:
	var player := player_scene.instantiate()
	add_child(player)
	player.global_position = player_spawn.global_position

	# Apply saved health from GameManager
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		player.health = gm.player_health
		player.max_health = gm.player_max_health

	var boss := _get_boss_node()
	if boss:
		boss.global_position = boss_spawn.global_position
		boss.player = player

	if hud and hud.has_method("set_boss") and boss:
		hud.set_boss(boss)
	if hud and hud.has_method("set_player"):
		hud.set_player(player)

	print("[DEBUG] Arena ready. Player at: ", player.global_position)

func _get_boss_node() -> BossBase:
	for child in get_children():
		if child is BossBase:
			return child
	return null
