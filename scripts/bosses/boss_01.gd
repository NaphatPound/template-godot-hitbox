## Knight Shade — melee boss with dash-slash and ground slam
extends BossBase

const MOVE_SPEED := 160.0
const DASH_SPEED := 500.0
const SLAM_DAMAGE := 2
const DASH_DAMAGE := 1
const ATTACK_COOLDOWN_MIN := 1.8
const ATTACK_COOLDOWN_MAX := 3.0

enum BossState { IDLE, CHASE, DASH_TELEGRAPH, DASHING, SLAM_TELEGRAPH, SLAMMING, RECOVER }

var state: BossState = BossState.IDLE
var state_timer: float = 0.0
var attack_cooldown: float = 2.0
var dash_direction: float = 1.0
var patterns: Array = ["dash", "slam"]
var pattern_index: int = 0
var facing_right: bool = false

var idle_hitboxes: Array = []
var attack_hitboxes: Array = []

func _is_attack_playing() -> bool:
	return anim_sprite != null and anim_sprite.animation == "attack" and anim_sprite.is_playing()

@onready var anim_sprite: AnimatedSprite2D = $Sprite
@onready var shockwave_area: Area2D = $ShockwaveArea
@onready var telegraph_label: Label = $TelegraphLabel
@onready var attack_poly: CollisionPolygon2D = $AttackArea/CollisionPolygon2D
@onready var hurtbox_poly: CollisionPolygon2D = $Hurtbox/CollisionPolygon2D

func _ready() -> void:
	super._ready()
	if shockwave_area:
		shockwave_area.monitoring = false
	if attack_area:
		attack_area.monitoring = false
	if telegraph_label:
		telegraph_label.visible = false
	_setup_animations()
	idle_hitboxes = HitboxLoader.load_json("res://assets/animation/boss/idle/idle-hitbox.json")
	attack_hitboxes = HitboxLoader.load_json("res://assets/animation/boss/attack/attack-hitbox.json")
	_update_hitbox_for_frame()

func _setup_animations() -> void:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 4.0)
	sf.add_frame("idle", load("res://assets/animation/boss/idle/boss-idle.PNG") as Texture2D, 1.0)
	sf.add_animation("attack")
	sf.set_animation_loop("attack", false)
	sf.set_animation_speed("attack", 8.0)
	for i in 4:
		sf.add_frame("attack", load("res://assets/animation/boss/attack/boss-attack-%d.PNG" % i) as Texture2D, 1.0)
	anim_sprite.sprite_frames = sf
	anim_sprite.scale = Vector2(HitboxLoader.SPRITE_SCALE, HitboxLoader.SPRITE_SCALE)
	anim_sprite.play("idle")
	anim_sprite.frame_changed.connect(_on_sprite_frame_changed)
	anim_sprite.animation_finished.connect(_on_sprite_animation_finished)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	super._physics_process(delta)
	state_timer -= delta
	attack_cooldown -= delta

	match state:
		BossState.IDLE:
			_idle(delta)
		BossState.CHASE:
			_chase(delta)
		BossState.DASH_TELEGRAPH:
			_dash_telegraph(delta)
		BossState.DASHING:
			_do_dash(delta)
		BossState.SLAM_TELEGRAPH:
			_slam_telegraph(delta)
		BossState.SLAMMING:
			_do_slam(delta)
		BossState.RECOVER:
			_recover(delta)

func _idle(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 100 * _delta)
	if state_timer <= 0:
		_set_state(BossState.CHASE)

func _chase(_delta: float) -> void:
	if player == null:
		return

	# Freeze movement while attack animation is still playing
	if _is_attack_playing():
		velocity.x = move_toward(velocity.x, 0, 300 * _delta)
		return

	var dir: float = sign(player.global_position.x - global_position.x)
	velocity.x = dir * MOVE_SPEED

	# Only flip sprite direction when not mid-attack animation
	if not _is_attack_playing():
		facing_right = dir >= 0
		anim_sprite.flip_h = not facing_right
		_update_hitbox_for_frame()

	# Block new attack trigger while attack animation is still playing
	if attack_cooldown <= 0 and not _is_attack_playing():
		var dist: float = abs(player.global_position.x - global_position.x)
		var pattern: String = str(patterns[pattern_index % patterns.size()])
		if pattern == "dash" or dist > 300:
			_set_state(BossState.DASH_TELEGRAPH)
		else:
			_set_state(BossState.SLAM_TELEGRAPH)
		pattern_index += 1

func _dash_telegraph(_delta: float) -> void:
	velocity.x = 0
	anim_sprite.modulate = Color(2.0, 0.5, 0.5)
	if telegraph_label:
		telegraph_label.text = "!"
		telegraph_label.visible = true
	if state_timer <= 0:
		if telegraph_label:
			telegraph_label.visible = false
		if player:
			dash_direction = sign(player.global_position.x - global_position.x)
			facing_right = dash_direction >= 0
			# Attack sprites are natively mirrored vs idle, so flip logic is inverted
			anim_sprite.flip_h = facing_right
		if attack_area:
			attack_area.monitoring = true
		_set_state(BossState.DASHING)

func _do_dash(_delta: float) -> void:
	# Hold position while attack animation plays; transition on animation end
	velocity.x = 0
	anim_sprite.modulate = Color(2.0, 0.2, 0.2)
	# Fallback: if animation already finished, recover
	if not _is_attack_playing() and state_timer <= 0:
		if attack_area:
			attack_area.monitoring = false
		_set_state(BossState.RECOVER)

func _slam_telegraph(_delta: float) -> void:
	velocity.x = 0
	anim_sprite.modulate = Color(0.5, 0.5, 2.0)
	if telegraph_label:
		telegraph_label.text = "!!"
		telegraph_label.visible = true
	if state_timer <= 0:
		if telegraph_label:
			telegraph_label.visible = false
		_set_state(BossState.SLAMMING)

func _do_slam(_delta: float) -> void:
	anim_sprite.modulate = Color(0.2, 0.2, 2.0)
	if is_on_floor() and state_timer <= 0:
		if shockwave_area:
			shockwave_area.monitoring = true
			await get_tree().create_timer(0.3).timeout
			if shockwave_area:
				shockwave_area.monitoring = false
		_set_state(BossState.RECOVER)

func _recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 200 * delta)
	anim_sprite.modulate = Color(1.0, 1.0, 1.0)
	if state_timer <= 0:
		attack_cooldown = randf_range(ATTACK_COOLDOWN_MIN, ATTACK_COOLDOWN_MAX)
		if phase == 2:
			attack_cooldown *= 0.6
		_set_state(BossState.CHASE)

func _set_state(new_state: BossState) -> void:
	state = new_state
	match new_state:
		BossState.IDLE:
			state_timer = 0.5
			anim_sprite.play("idle")
		BossState.CHASE:
			state_timer = 999.0
			anim_sprite.play("idle")
		BossState.DASH_TELEGRAPH:
			state_timer = 0.8
		BossState.DASHING:
			state_timer = 0.35
			anim_sprite.play("attack")
		BossState.SLAM_TELEGRAPH:
			state_timer = 1.0
		BossState.SLAMMING:
			state_timer = 0.5
			anim_sprite.play("attack")
		BossState.RECOVER:
			state_timer = 0.6
			anim_sprite.play("idle")

func _on_sprite_frame_changed() -> void:
	_update_hitbox_for_frame()
	queue_redraw()

func _on_sprite_animation_finished() -> void:
	if anim_sprite.animation == "attack":
		if attack_area:
			attack_area.monitoring = false
		# Transition out of any attack state when animation ends naturally
		if state == BossState.DASHING or state == BossState.SLAMMING:
			_set_state(BossState.RECOVER)
		anim_sprite.play("idle")
		_update_hitbox_for_frame()
		queue_redraw()

func _update_hitbox_for_frame() -> void:
	var is_attacking: bool = anim_sprite.animation == "attack"
	var frame: int = anim_sprite.frame
	# Attack sprites are natively mirrored vs idle, so polygon flip is also inverted
	var flip: bool = facing_right if is_attacking else not facing_right

	if not is_attacking:
		if idle_hitboxes.size() > 0:
			var body := idle_hitboxes[0][0] as PackedVector2Array
			hurtbox_poly.polygon = HitboxLoader.flip_polygon(body) if flip else body
		attack_poly.polygon = PackedVector2Array()
	else:
		attack_poly.polygon = PackedVector2Array()
		if attack_hitboxes.size() > frame:
			var frame_polys: Array = attack_hitboxes[frame]
			var body_src := (idle_hitboxes[0][0] as PackedVector2Array) if idle_hitboxes.size() > 0 else PackedVector2Array()
			if frame_polys.size() >= 2:
				body_src = frame_polys[0]
				var atk := frame_polys[1] as PackedVector2Array
				attack_poly.polygon = HitboxLoader.flip_polygon(atk) if flip else atk
			elif frame_polys.size() == 1:
				body_src = frame_polys[0]
			hurtbox_poly.polygon = HitboxLoader.flip_polygon(body_src) if flip else body_src

func _draw() -> void:
	if is_dead:
		return
	var is_attacking: bool = anim_sprite.animation == "attack"
	var frame: int = anim_sprite.frame
	var flip: bool = facing_right if is_attacking else not facing_right

	# Hurtbox — green
	var hbody := PackedVector2Array()
	if not is_attacking:
		if idle_hitboxes.size() > 0:
			hbody = idle_hitboxes[0][0]
	else:
		if attack_hitboxes.size() > frame:
			var fp: Array = attack_hitboxes[frame]
			hbody = fp[0] if fp.size() >= 1 else PackedVector2Array()
	if hbody.size() > 2:
		var pts := HitboxLoader.flip_polygon(hbody) if flip else hbody
		draw_colored_polygon(pts, Color(0, 1, 0, 0.25))
		var outline := PackedVector2Array(pts)
		outline.append(outline[0])
		draw_polyline(outline, Color(0, 1, 0, 0.8), 1.0)

	# Attack hitbox — red (only when attack_area is monitoring)
	if attack_area and attack_area.monitoring:
		var hatk := PackedVector2Array()
		if is_attacking and attack_hitboxes.size() > frame:
			var fp: Array = attack_hitboxes[frame]
			if fp.size() >= 2:
				hatk = fp[1]
		if hatk.size() > 2:
			var pts := HitboxLoader.flip_polygon(hatk) if flip else hatk
			draw_colored_polygon(pts, Color(1, 0, 0, 0.3))
			var outline := PackedVector2Array(pts)
			outline.append(outline[0])
			draw_polyline(outline, Color(1, 0.2, 0.2, 0.9), 1.0)

func _on_phase_two() -> void:
	super._on_phase_two()
	patterns = ["dash", "slam", "dash", "dash"]
	anim_sprite.modulate = Color(0.6, 0.1, 0.8)
