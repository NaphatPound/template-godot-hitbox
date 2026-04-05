extends Area2D

const HOMING_FORCE := 280.0
const LIFETIME := 6.0

var velocity: Vector2 = Vector2.ZERO
var is_homing: bool = false
var homing_target: Node2D = null
var _lifetime: float = LIFETIME

func _ready() -> void:
	add_to_group("boss_attack")
	set_meta("damage", 1)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0:
		queue_free()
		return

	if is_homing and homing_target and is_instance_valid(homing_target):
		var dir := (homing_target.global_position - global_position).normalized()
		velocity = velocity.move_toward(dir * HOMING_FORCE, HOMING_FORCE * delta * 2.5)

	global_position += velocity * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("world"):
		queue_free()
