extends Control

func _ready() -> void:
	print("[DEBUG] Game Over screen")

func _on_retry_pressed() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.start_game()
	else:
		get_tree().change_scene_to_file("res://scenes/arenas/arena_01.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
