extends Control

func _ready() -> void:
	print("[DEBUG] Main Menu ready")
	# Ensure GameManager is accessible
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		push_warning("[DEBUG] GameManager autoload not found — check project settings")

func _on_start_button_pressed() -> void:
	print("[DEBUG] Start Game pressed")
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.start_game()
	else:
		get_tree().change_scene_to_file("res://scenes/arenas/arena_01.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
