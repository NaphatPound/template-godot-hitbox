class_name BossBase
extends CharacterBody2D

@warning_ignore("unused_signal")
signal health_changed(new_health: int, max_health: int)
@warning_ignore("unused_signal")
signal died
@warning_ignore("unused_signal")
signal phase_changed(phase: int)

const GRAVITY := 980.0

@export var boss_name: String = "Boss"
@export var max_health: int = 100
@export var phase2_threshold: float = 0.5

var health: int = max_health
var phase: int = 1
var is_dead: bool = false
var player: Node2D = null

@onready var sprite: Node2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	print("[DEBUG] Boss ready: ", boss_name, " HP: ", health)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	health = max(health, 0)
	print("[DEBUG] Boss ", boss_name, " took ", amount, " damage. HP: ", health)
	emit_signal("health_changed", health, max_health)

	# Flash white on hit
	sprite.modulate = Color(2, 2, 2)
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		sprite.modulate = Color(1, 1, 1)

	# Phase 2 transition
	if phase == 1 and float(health) / float(max_health) <= phase2_threshold:
		phase = 2
		emit_signal("phase_changed", 2)
		_on_phase_two()

	if health <= 0:
		_die()

func _on_phase_two() -> void:
	print("[DEBUG] Boss ", boss_name, " entered Phase 2!")

func _die() -> void:
	is_dead = true
	print("[DEBUG] Boss ", boss_name, " defeated!")
	emit_signal("died")
	sprite.modulate = Color(0.2, 0.2, 0.2)
	await get_tree().create_timer(1.5).timeout
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.on_boss_defeated()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		var dmg: int = area.get_meta("damage", 10)
		take_damage(dmg)
