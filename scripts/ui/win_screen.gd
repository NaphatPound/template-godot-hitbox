extends Control

func _ready() -> void:
	print("[DEBUG] Win screen — all bosses defeated!")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
