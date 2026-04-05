## Void Archer — ranged boss with spread shot and homing orb
extends BossBase

const MOVE_SPEED := 80.0
const BULLET_SPEED := 350.0
const HOMING_SPEED := 200.0
const ATTACK_COOLDOWN_MIN := 2.0
const ATTACK_COOLDOWN_MAX := 3.5

enum BossState { IDLE, POSITION, SHOOT_TELEGRAPH, SPREAD_SHOT, HOMING_TELEGRAPH, HOMING_ORB, TELEPORT, RECOVER }

var state: BossState = BossState.IDLE
var state_timer: float = 0.0
var attack_cooldown: float = 2.5
var patterns: Array = ["spread", "homing"]
var pattern_index: int = 0

@onready var telegraph_label: Label = $TelegraphLabel
@onready var bullet_spawn: Marker2D = $BulletSpawn

var _bullet_scene: PackedScene = null

func _ready() -> void:
	super._ready()
	if telegraph_label:
		telegraph_label.visible = false
	_bullet_scene = load("res://scenes/bosses/bullet.tscn")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	super._physics_process(delta)
	state_timer -= delta
	attack_cooldown -= delta

	match state:
		BossState.IDLE:
			if state_timer <= 0:
				_set_state(BossState.POSITION)
		BossState.POSITION:
			_do_position(delta)
		BossState.SHOOT_TELEGRAPH:
			if state_timer <= 0:
				_set_state(BossState.SPREAD_SHOT)
		BossState.SPREAD_SHOT:
			_fire_spread()
			_set_state(BossState.RECOVER)
		BossState.HOMING_TELEGRAPH:
			if state_timer <= 0:
				_set_state(BossState.HOMING_ORB)
		BossState.HOMING_ORB:
			_fire_homing()
			_set_state(BossState.RECOVER)
		BossState.TELEPORT:
			_do_teleport()
		BossState.RECOVER:
			if state_timer <= 0:
				attack_cooldown = randf_range(ATTACK_COOLDOWN_MIN, ATTACK_COOLDOWN_MAX)
				if phase == 2:
					attack_cooldown *= 0.5
				_set_state(BossState.POSITION)

func _do_position(delta: float) -> void:
	if player == null:
		return
	# Stay at distance from player, elevated
	var target_x: float = player.global_position.x + (randf_range(-300, -150) if player.global_position.x > global_position.x else randf_range(150, 300))
	velocity.x = sign(target_x - global_position.x) * MOVE_SPEED
	sprite.modulate = Color(0.2, 0.5, 0.9)

	if attack_cooldown <= 0:
		var pattern: String = str(patterns[pattern_index % patterns.size()])
		if pattern == "spread":
			_set_state(BossState.SHOOT_TELEGRAPH)
		else:
			if phase == 2:
				_set_state(BossState.TELEPORT)
			else:
				_set_state(BossState.HOMING_TELEGRAPH)
		pattern_index += 1

func _fire_spread() -> void:
	if _bullet_scene == null or bullet_spawn == null:
		return
	var count := 3 if phase == 1 else 5
	var spread_angle := PI / 6.0
	var start_angle := -spread_angle * (count - 1) / 2.0
	for i in range(count):
		var angle := start_angle + spread_angle * i
		var dir := Vector2(cos(angle + PI), sin(angle)).normalized()
		if player:
			var to_player := (player.global_position - bullet_spawn.global_position).normalized()
			var base_angle := to_player.angle()
			dir = Vector2(cos(base_angle + angle - spread_angle * (count - 1) / 2.0), sin(base_angle + angle - spread_angle * (count - 1) / 2.0)).normalized()
		_spawn_bullet(bullet_spawn.global_position, dir * BULLET_SPEED, false)
	print("[DEBUG] Boss 02 fired spread shot x", count)

func _fire_homing() -> void:
	if _bullet_scene == null or bullet_spawn == null:
		return
	_spawn_bullet(bullet_spawn.global_position, Vector2.ZERO, true)
	print("[DEBUG] Boss 02 fired homing orb")

func _spawn_bullet(pos: Vector2, vel: Vector2, homing: bool) -> void:
	if _bullet_scene == null:
		return
	var b := _bullet_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = pos
	b.velocity = vel
	b.is_homing = homing
	if homing:
		b.homing_target = player

func _do_teleport() -> void:
	var tx := randf_range(200, 1080)
	global_position.x = tx
	global_position.y = 200
	sprite.modulate = Color(2.0, 2.0, 2.0)
	print("[DEBUG] Boss 02 teleported")
	_set_state(BossState.HOMING_TELEGRAPH)

func _set_state(new_state: BossState) -> void:
	state = new_state
	match new_state:
		BossState.IDLE: state_timer = 0.5
		BossState.POSITION: state_timer = 999.0
		BossState.SHOOT_TELEGRAPH:
			state_timer = 0.7
			sprite.modulate = Color(2.0, 1.0, 0.2)
			if telegraph_label:
				telegraph_label.text = "★"
				telegraph_label.visible = true
		BossState.SPREAD_SHOT:
			if telegraph_label: telegraph_label.visible = false
			state_timer = 0.1
		BossState.HOMING_TELEGRAPH:
			state_timer = 1.0
			sprite.modulate = Color(0.5, 2.0, 0.5)
			if telegraph_label:
				telegraph_label.text = "◉"
				telegraph_label.visible = true
		BossState.HOMING_ORB:
			if telegraph_label: telegraph_label.visible = false
			state_timer = 0.1
		BossState.TELEPORT: state_timer = 0.1
		BossState.RECOVER:
			state_timer = 0.8
			sprite.modulate = Color(0.2, 0.5, 0.9)

func _on_phase_two() -> void:
	super._on_phase_two()
	patterns = ["spread", "homing", "spread", "teleport"]
	sprite.modulate = Color(0.0, 0.05, 0.15)
