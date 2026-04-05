extends CanvasLayer

@onready var boss_name_label: Label = $BossInfo/BossName
@onready var boss_health_bar: ProgressBar = $BossInfo/BossHealthBar
@onready var player_health_container: HBoxContainer = $PlayerHealth/HBoxContainer
@onready var phase_label: Label = $BossInfo/PhaseLabel

func _ready() -> void:
	print("[DEBUG] HUD ready")

func set_boss(boss: BossBase) -> void:
	boss_name_label.text = boss.boss_name
	boss_health_bar.max_value = boss.max_health
	boss_health_bar.value = boss.max_health
	phase_label.text = "Phase 1"
	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)

func set_player(player: Node) -> void:
	player.health_changed.connect(_on_player_health_changed)
	_update_player_masks(player.health)

func _on_boss_health_changed(new_hp: int, _max_hp: int) -> void:
	boss_health_bar.value = new_hp

func _on_boss_phase_changed(phase: int) -> void:
	phase_label.text = "Phase " + str(phase)
	phase_label.modulate = Color(1.5, 0.5, 0.5)

func _on_player_health_changed(new_hp: int) -> void:
	_update_player_masks(new_hp)

func _update_player_masks(hp: int) -> void:
	for child in player_health_container.get_children():
		child.queue_free()
	for i in range(5):
		var mask := ColorRect.new()
		mask.size = Vector2(24, 24)
		mask.color = Color(0.2, 0.7, 1.0) if i < hp else Color(0.15, 0.15, 0.15)
		player_health_container.add_child(mask)
