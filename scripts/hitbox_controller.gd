## HitboxController — drop into any CharacterBody2D scene.
## Auto-discovers PNG frames and hitbox JSON from directories,
## builds AnimatedSprite2D, updates CollisionPolygon2D per frame,
## and draws a debug overlay.
##
## Usage in parent _ready():
##   $HitboxController.setup({
##       "idle":   {"dir": "res://assets/animation/player/idle/",   "fps": 4.0,  "loop": true},
##       "attack": {"dir": "res://assets/animation/player/attack/", "fps": 12.0, "loop": false}
##   })
##
## Then in parent code:
##   $HitboxController.play("attack")
##   $HitboxController.set_facing(facing_right)
##   # In parent _draw(): $HitboxController.draw_debug(self)

class_name HitboxController
extends Node

## Emitted whenever animation frame changes — use to trigger game logic.
signal frame_updated(anim: String, frame: int, has_attack_polygon: bool)

# ── Node references (resolved from parent automatically) ──────────────────────
var _sprite: AnimatedSprite2D = null
var _hurtbox_poly: CollisionPolygon2D = null
var _attack_poly: CollisionPolygon2D = null
var _parent: Node2D = null

# ── Internal state ─────────────────────────────────────────────────────────────
var _hitboxes: Dictionary = {}     # anim_name -> Array[Array[PackedVector2Array]]
var _facing_right: bool = true
var _ready_done: bool = false

## Scale applied to sprite and hitbox polygons.
## For 2480×3508 source images, 0.045 gives ~111×158 px display.
## Adjust if your source images are a different size.
var sprite_scale: float = 0.045

## Image dimensions — update if your sprites have different pixel dimensions.
var img_width: float = 2480.0
var img_height: float = 3508.0

## Show debug hitbox overlay (green = hurtbox, red = attack).
var show_debug: bool = true


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Main entry point. Call from the parent character's _ready().
##
## anim_configs format:
## {
##   "idle":   {"dir": "res://assets/.../idle/",   "fps": 4.0,  "loop": true},
##   "attack": {"dir": "res://assets/.../attack/", "fps": 12.0, "loop": false}
## }
##
## Optional keys per animation:
##   "frame_count": int  — limit discovery to N frames
##   "hitbox_json": str  — explicit JSON path (skips auto-discovery)
func setup(anim_configs: Dictionary) -> void:
	_parent = get_parent() as Node2D
	assert(_parent != null, "HitboxController must be a child of a Node2D")

	_resolve_child_nodes()
	assert(_sprite != null, "HitboxController: no AnimatedSprite2D found on parent")

	var sf := SpriteFrames.new()
	_hitboxes = {}

	for anim_name in anim_configs:
		var cfg: Dictionary = anim_configs[anim_name]
		var dir_path: String = cfg.get("dir", "")
		var fps: float = cfg.get("fps", 8.0)
		var loop: bool = cfg.get("loop", true)
		var limit: int = cfg.get("frame_count", 0)

		# Discover PNG frames and hitbox JSON in the directory
		var discovered := _discover_dir(dir_path, limit)
		var frames: Array = discovered["frames"]
		var json_path: String = cfg.get("hitbox_json", discovered["hitbox_json"])

		if frames.is_empty():
			push_warning("HitboxController: no PNG frames found in " + dir_path)
			continue

		# Build SpriteFrames animation
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, loop)
		sf.set_animation_speed(anim_name, fps)
		for frame_path in frames:
			var tex := load(frame_path) as Texture2D
			if tex:
				sf.add_frame(anim_name, tex, 1.0)

		# Load hitbox polygons
		if json_path != "":
			_hitboxes[anim_name] = _load_hitboxes(json_path)
		else:
			_hitboxes[anim_name] = []

	_sprite.sprite_frames = sf
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)

	_ready_done = true
	play("idle" if sf.has_animation("idle") else anim_configs.keys()[0])


## Play a named animation.
func play(anim_name: String) -> void:
	if _sprite == null or not _ready_done:
		return
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim_name):
		_sprite.play(anim_name)
		_update_polygons()


## Update facing direction and flip sprite + hitboxes.
func set_facing(facing_right: bool) -> void:
	if _facing_right == facing_right:
		return
	_facing_right = facing_right
	if _sprite:
		_sprite.flip_h = not facing_right
	_update_polygons()
	if _parent:
		_parent.queue_redraw()


## Returns current hitboxes in node-local space (already flipped for facing).
## Keys: "body" (PackedVector2Array), "attack" (PackedVector2Array, may be empty).
func get_current_hitboxes() -> Dictionary:
	return _get_hitboxes_for_frame(_sprite.animation if _sprite else "", _sprite.frame if _sprite else 0)


## Call this from the parent node's _draw() to render debug overlays.
## Example: func _draw(): $HitboxController.draw_debug(self)
func draw_debug(canvas: CanvasItem) -> void:
	if not show_debug:
		return
	var h := get_current_hitboxes()
	_draw_poly(canvas, h.get("body", PackedVector2Array()), Color(0, 1, 0, 0.25), Color(0, 1, 0, 0.85))
	_draw_poly(canvas, h.get("attack", PackedVector2Array()), Color(1, 0, 0, 0.25), Color(1, 0.2, 0.2, 0.9))


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — node discovery
# ═══════════════════════════════════════════════════════════════════════════════

func _resolve_child_nodes() -> void:
	# Search parent's children for AnimatedSprite2D and CollisionPolygon2D nodes.
	for child in _parent.get_children():
		if child is AnimatedSprite2D and _sprite == null:
			_sprite = child
		if child is Area2D:
			for sub in child.get_children():
				if sub is CollisionPolygon2D:
					# Heuristic: first Area2D = hurtbox, second = attack
					var grp: String = " ".join(child.get_groups())
					if "attack" in grp or "attack" in child.name.to_lower():
						if _attack_poly == null:
							_attack_poly = sub
					else:
						if _hurtbox_poly == null:
							_hurtbox_poly = sub


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — file discovery
# ═══════════════════════════════════════════════════════════════════════════════

## Scan a directory for PNG frames and a hitbox JSON file.
func _discover_dir(dir_path: String, limit: int = 0) -> Dictionary:
	var frames: Array = []
	var hitbox_json: String = ""

	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("HitboxController: cannot open directory: " + dir_path)
		return {"frames": frames, "hitbox_json": hitbox_json}

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var lower := file_name.to_lower()
		if not dir.current_is_dir():
			if (lower.ends_with(".png")):
				frames.append(dir_path + file_name)
			elif lower.ends_with(".json") and "hitbox" in lower:
				hitbox_json = dir_path + file_name
		file_name = dir.get_next()
	dir.list_dir_end()

	frames.sort()  # alphabetical order = frame order (0, 1, 2, ...)
	if limit > 0:
		frames = frames.slice(0, limit)

	return {"frames": frames, "hitbox_json": hitbox_json}


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — hitbox loading
# ═══════════════════════════════════════════════════════════════════════════════

## Load and scale hitbox polygons from a JSON file.
## Returns Array of frames; each frame is Array of PackedVector2Array.
func _load_hitboxes(json_path: String) -> Array:
	var cx := img_width * 0.5
	var cy := img_height * 0.5

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("HitboxController: cannot open " + json_path)
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("HitboxController: invalid JSON " + json_path)
		return []

	var result: Array = []
	for frame_data in parsed.get("frames", []):
		var frame_polys: Array = []
		for poly_data in frame_data.get("polygons", []):
			var pts := PackedVector2Array()
			for pt in poly_data.get("points", []):
				pts.append(Vector2(
					(float(pt[0]) - cx) * sprite_scale,
					(float(pt[1]) - cy) * sprite_scale
				))
			frame_polys.append(pts)
		result.append(frame_polys)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — hitbox logic
# ═══════════════════════════════════════════════════════════════════════════════

func _get_hitboxes_for_frame(anim: String, frame: int) -> Dictionary:
	var flip := not _facing_right
	var anim_data: Array = _hitboxes.get(anim, [])
	var idle_data: Array = _hitboxes.get("idle", [])

	var body := PackedVector2Array()
	var attack := PackedVector2Array()

	# Default body from idle frame 0
	if idle_data.size() > 0 and idle_data[0].size() > 0:
		body = idle_data[0][0]

	if anim_data.size() > frame:
		var polys: Array = anim_data[frame]
		if polys.size() >= 2:
			body = polys[0]
			attack = polys[1]
		elif polys.size() == 1:
			if frame == 0 or anim == "idle":
				body = polys[0]
			else:
				# Single polygon on non-zero attack frame = attack arc
				attack = polys[0]

	if flip:
		body = _flip(body)
		attack = _flip(attack)

	return {"body": body, "attack": attack}


func _update_polygons() -> void:
	if _sprite == null:
		return
	var h := _get_hitboxes_for_frame(_sprite.animation, _sprite.frame)
	if _hurtbox_poly:
		_hurtbox_poly.polygon = h["body"]
	if _attack_poly:
		_attack_poly.polygon = h["attack"]


func _flip(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(Vector2(-p.x, p.y))
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — signals
# ═══════════════════════════════════════════════════════════════════════════════

func _on_frame_changed() -> void:
	_update_polygons()
	if _parent:
		_parent.queue_redraw()
	var h := get_current_hitboxes()
	frame_updated.emit(_sprite.animation, _sprite.frame, h["attack"].size() > 0)


func _on_animation_finished() -> void:
	if _sprite and _sprite.animation != "idle" and _sprite.sprite_frames.has_animation("idle"):
		play("idle")


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — debug draw
# ═══════════════════════════════════════════════════════════════════════════════

func _draw_poly(canvas: CanvasItem, poly: PackedVector2Array, fill: Color, outline: Color) -> void:
	if poly.size() < 3:
		return
	canvas.draw_colored_polygon(poly, fill)
	var loop := PackedVector2Array(poly)
	loop.append(loop[0])
	canvas.draw_polyline(loop, outline, 1.0)
