extends CharacterBody2D

@warning_ignore("unused_signal")
signal health_changed(new_health: int)
@warning_ignore("unused_signal")
signal died

const SPEED := 220.0
const JUMP_VELOCITY := -500.0
const DOUBLE_JUMP_VELOCITY := -420.0
const DASH_SPEED := 520.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 0.8
const GRAVITY := 980.0
const INVINCIBILITY_TIME := 1.5
const ATTACK_DAMAGE := 10

@export var max_health: int = 5

var health: int = max_health
var can_double_jump: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var facing_right: bool = true
var is_dead: bool = false

var idle_hitboxes: Array = []
var attack_hitboxes: Array = []
var _hit_this_swing: Array = []

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_timer: Timer = $AttackTimer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var attack_poly: CollisionPolygon2D = $AttackHitbox/CollisionPolygon2D
@onready var hurtbox_poly: CollisionPolygon2D = $Hurtbox/CollisionPolygon2D

func _ready() -> void:
	print("[DEBUG] Player ready. HP: ", health)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	attack_hitbox.monitoring = false
	_setup_animations()
	idle_hitboxes = HitboxLoader.load_json("res://assets/animation/player/idle/idle-hitbox.json")
	attack_hitboxes = HitboxLoader.load_json("res://assets/animation/player/attack/attack-hitbox.json")
	_update_hitbox_for_frame()

func _setup_animations() -> void:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 4.0)
	sf.add_frame("idle", load("res://assets/animation/player/idle/player-idle.PNG") as Texture2D, 1.0)
	sf.add_animation("attack")
	sf.set_animation_loop("attack", false)
	sf.set_animation_speed("attack", 12.0)
	for i in 5:
		sf.add_frame("attack", load("res://assets/animation/player/attack/player-attack-%d.PNG" % i) as Texture2D, 1.0)
	sprite.sprite_frames = sf
	sprite.scale = Vector2(HitboxLoader.SPRITE_SCALE, HitboxLoader.SPRITE_SCALE)
	sprite.play("idle")
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_finished.connect(_on_sprite_animation_finished)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_invincibility(delta)
	_handle_dash(delta)
	if not is_dashing:
		_apply_gravity(delta)
		_handle_movement()
		_handle_jump()
	move_and_slide()
	if Input.is_action_just_pressed("attack"):
		_do_attack()
	_check_attack_hits()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		can_double_jump = true

func _handle_movement() -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0:
		velocity.x = dir * SPEED
		var was_facing := facing_right
		facing_right = dir > 0
		sprite.flip_h = not facing_right
		if was_facing != facing_right:
			_update_hitbox_for_frame()
			queue_redraw()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif can_double_jump:
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false

func _handle_dash(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0
		if dash_timer <= 0:
			is_dashing = false
	elif Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		dash_direction = 1.0 if facing_right else -1.0
		print("[DEBUG] Player dash")

func _handle_invincibility(delta: float) -> void:
	if is_invincible:
		invincibility_timer -= delta
		sprite.modulate.a = 0.5 if fmod(invincibility_timer, 0.2) > 0.1 else 1.0
		if invincibility_timer <= 0:
			is_invincible = false
			sprite.modulate.a = 1.0

func _do_attack() -> void:
	if not attack_timer.is_stopped():
		return
	print("[DEBUG] Player attack")
	_hit_this_swing.clear()
	attack_hitbox.monitoring = true
	sprite.play("attack")
	attack_timer.start()

func _check_attack_hits() -> void:
	if not attack_hitbox.monitoring:
		return
	for area in attack_hitbox.get_overlapping_areas():
		if area in _hit_this_swing:
			continue
		_hit_this_swing.append(area)
		var target := area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(ATTACK_DAMAGE)

func _on_attack_timer_timeout() -> void:
	attack_hitbox.monitoring = false

func _on_sprite_frame_changed() -> void:
	_update_hitbox_for_frame()
	queue_redraw()

func _on_sprite_animation_finished() -> void:
	if sprite.animation == "attack":
		sprite.play("idle")
		attack_hitbox.monitoring = false
		_update_hitbox_for_frame()
		queue_redraw()

func _update_hitbox_for_frame() -> void:
	var is_attacking: bool = sprite.animation == "attack"
	var frame: int = sprite.frame
	var flip: bool = not facing_right

	if not is_attacking:
		if idle_hitboxes.size() > 0:
			var body := idle_hitboxes[0][0] as PackedVector2Array
			hurtbox_poly.polygon = HitboxLoader.flip_polygon(body) if flip else body
		attack_poly.polygon = PackedVector2Array()
	else:
		var body_src := (idle_hitboxes[0][0] as PackedVector2Array) if idle_hitboxes.size() > 0 else PackedVector2Array()
		attack_poly.polygon = PackedVector2Array()
		if attack_hitboxes.size() > frame:
			var frame_polys: Array = attack_hitboxes[frame]
			if frame_polys.size() >= 2:
				body_src = frame_polys[0]
				var atk := frame_polys[1] as PackedVector2Array
				attack_poly.polygon = HitboxLoader.flip_polygon(atk) if flip else atk
			elif frame_polys.size() == 1 and frame > 0:
				var atk := frame_polys[0] as PackedVector2Array
				attack_poly.polygon = HitboxLoader.flip_polygon(atk) if flip else atk
		hurtbox_poly.polygon = HitboxLoader.flip_polygon(body_src) if flip else body_src

func _draw() -> void:
	if is_dead:
		return
	var is_attacking: bool = sprite.animation == "attack"
	var frame: int = sprite.frame
	var flip: bool = not facing_right

	# Hurtbox — green
	var hbody := PackedVector2Array()
	if not is_attacking:
		if idle_hitboxes.size() > 0:
			hbody = idle_hitboxes[0][0]
	else:
		if attack_hitboxes.size() > frame and (attack_hitboxes[frame] as Array).size() >= 2:
			hbody = attack_hitboxes[frame][0]
		elif idle_hitboxes.size() > 0:
			hbody = idle_hitboxes[0][0]
	if hbody.size() > 2:
		var pts := HitboxLoader.flip_polygon(hbody) if flip else hbody
		draw_colored_polygon(pts, Color(0, 1, 0, 0.25))
		var outline := PackedVector2Array(pts)
		outline.append(outline[0])
		draw_polyline(outline, Color(0, 1, 0, 0.8), 1.0)

	# Attack hitbox — red
	var hatk := PackedVector2Array()
	if is_attacking and attack_hitboxes.size() > frame:
		var fp: Array = attack_hitboxes[frame]
		if fp.size() >= 2:
			hatk = fp[1]
		elif fp.size() == 1 and frame > 0:
			hatk = fp[0]
	if hatk.size() > 2:
		var pts := HitboxLoader.flip_polygon(hatk) if flip else hatk
		draw_colored_polygon(pts, Color(1, 0, 0, 0.25))
		var outline := PackedVector2Array(pts)
		outline.append(outline[0])
		draw_polyline(outline, Color(1, 0.2, 0.2, 0.9), 1.0)

func take_damage(amount: int) -> void:
	if is_invincible or is_dead:
		return
	health -= amount
	health = max(health, 0)
	print("[DEBUG] Player took damage. HP: ", health)
	emit_signal("health_changed", health)
	is_invincible = true
	invincibility_timer = INVINCIBILITY_TIME
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	print("[DEBUG] Player died")
	emit_signal("died")
	sprite.modulate = Color(0.3, 0.3, 0.3)
	await get_tree().create_timer(1.0).timeout
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.on_player_died()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("boss_attack"):
		var dmg: int = area.get_meta("damage", 1)
		take_damage(dmg)
