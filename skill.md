# Skill: Sprite + Hitbox JSON → Godot Game Integration

## What this skill does
Converts per-frame PNG sprites and polygon hitbox JSON files into a fully working Godot 4 game with:
- `AnimatedSprite2D` for sprite rendering
- `CollisionPolygon2D` updated per animation frame from JSON data
- Debug draw overlay showing hitbox polygons in-game
- Facing-direction flip (mirror hitboxes for left/right)

## Two integration approaches

| Approach | File | Best for |
|----------|------|----------|
| **Component (recommended)** | `scripts/hitbox_controller.gd` | Any character — drop node + 3 lines of code |
| **Manual (low-level)** | `scripts/hitbox_loader.gd` | Fine-grained control, custom logic |

---

## Approach A: HitboxController component (auto-everything)

`HitboxController` is a Node you add as a child of any `CharacterBody2D`. It auto-discovers PNG frames and JSON in a directory, builds the sprite, and manages hitboxes — no boilerplate needed.

### Scene structure
```
CharacterBody2D (your_character.gd)
├── AnimatedSprite2D          ← controller finds this automatically
├── CollisionShape2D          ← physics body, keep simple
├── Hurtbox (Area2D)
│   └── CollisionPolygon2D   ← controller finds and updates this
├── AttackHitbox (Area2D)  [group: "player_attack" or name contains "attack"]
│   └── CollisionPolygon2D   ← controller finds and updates this
└── HitboxController          ← add this node (hitbox_controller.gd)
```

The controller auto-detects nodes by type and group/name heuristics — no path configuration needed.

### Usage in character script

```gdscript
extends CharacterBody2D

@onready var hitbox: HitboxController = $HitboxController

func _ready() -> void:
    hitbox.setup({
        "idle": {
            "dir": "res://assets/animation/player/idle/",
            "fps": 4.0,
            "loop": true
        },
        "attack": {
            "dir": "res://assets/animation/player/attack/",
            "fps": 12.0,
            "loop": false
        }
    })
    # Optional: react to frame changes
    hitbox.frame_updated.connect(_on_hitbox_frame)

func _draw() -> void:
    hitbox.draw_debug(self)   # green = hurtbox, red = attack

func _on_direction_change(facing_right: bool) -> void:
    hitbox.set_facing(facing_right)

func do_attack() -> void:
    hitbox.play("attack")

func _on_hitbox_frame(anim: String, frame: int, has_attack: bool) -> void:
    # Enable attack area monitoring when attack polygon is active
    $AttackHitbox.monitoring = has_attack
```

### HitboxController API

| Method | Description |
|--------|-------------|
| `setup(anim_configs: Dictionary)` | **Main entry.** Auto-discovers PNGs + JSON, builds sprite, loads hitboxes |
| `play(anim_name: String)` | Play an animation and update hitboxes immediately |
| `set_facing(right: bool)` | Flip sprite and mirror hitbox polygons |
| `get_current_hitboxes() -> Dictionary` | Returns `{"body": PackedVector2Array, "attack": PackedVector2Array}` |
| `draw_debug(canvas: CanvasItem)` | Call from parent `_draw()` to show overlay |

| Signal | Description |
|--------|-------------|
| `frame_updated(anim, frame, has_attack)` | Fires on every frame change |

| Property | Default | Description |
|----------|---------|-------------|
| `sprite_scale` | `0.045` | Scale applied to sprite and polygon vertices |
| `img_width` | `2480.0` | Source PNG width in pixels |
| `img_height` | `3508.0` | Source PNG height in pixels |
| `show_debug` | `true` | Toggle debug overlay |

### Auto-discovery rules
- Scans the `dir` path for `*.PNG` / `*.png` files — sorted alphabetically = frame order
- Finds `*hitbox*.json` in the same directory automatically
- Override JSON path with `"hitbox_json": "res://path/to/file.json"` in the config
- Limit frames with `"frame_count": 3` in the config

### anim_configs full format
```gdscript
hitbox.setup({
    "idle": {
        "dir":         "res://assets/animation/player/idle/",  # required
        "fps":         4.0,    # default: 8.0
        "loop":        true,   # default: true
        # optional overrides:
        "frame_count": 1,      # limit to N frames
        "hitbox_json": "res://assets/animation/player/idle/idle-hitbox.json"
    },
    "attack": {
        "dir":   "res://assets/animation/player/attack/",
        "fps":   12.0,
        "loop":  false
    },
    # Add as many animations as needed
    "run": {
        "dir":  "res://assets/animation/player/run/",
        "fps":  10.0,
        "loop": true
    }
})
```

---

## Approach B: Manual (HitboxLoader)

## Asset format expected

### Directory structure
```
assets/animation/
├── player/
│   ├── idle/
│   │   ├── player-idle.PNG          # single frame PNG
│   │   └── idle-hitbox.json
│   └── attack/
│       ├── player-attack-0.PNG      # frame 0
│       ├── player-attack-1.PNG      # frame 1
│       ├── ...
│       └── attack-hitbox.json
└── boss/
    ├── idle/
    │   ├── boss-idle.PNG
    │   └── idle-hitbox.json
    └── attack/
        ├── boss-attack-0.PNG
        ├── boss-attack-1.PNG
        ├── ...
        └── attack-hitbox.json
```

### Hitbox JSON format
Each JSON file describes per-frame polygon hitboxes for one animation.
```json
{
  "source": "5 images",
  "total_frames": 5,
  "frames": [
    {
      "filename": "player-attack-0.PNG",
      "index": 0,
      "polygons": [
        {
          "points": [[382, 735], [1697, 735], ...],
          "type": "hitbox",
          "vertex_count": 64
        }
      ],
      "rect": { "x": 0, "y": 0, "w": 2480, "h": 3508 }
    },
    {
      "filename": "player-attack-1.PNG",
      "index": 1,
      "polygons": [
        { "points": [...], "type": "hitbox", "vertex_count": 64 },
        { "points": [...], "type": "hitbox", "vertex_count": 81 }
      ],
      "rect": { "x": 0, "y": 3512, "w": 2480, "h": 3508 }
    }
  ]
}
```

**Key rules:**
- `points` coordinates are in the local coordinate space of the individual PNG (0,0 = top-left of that frame's PNG)
- `rect.y` is just a stacking offset reference — do NOT subtract it from polygon points
- First polygon in a frame = body/hurtbox
- Second polygon (if present) = attack/weapon area
- Frames with only 1 polygon in an attack animation: that single polygon IS the attack area (no separate body)

---

## Step 1: Create HitboxLoader utility

Create `scripts/hitbox_loader.gd`:

```gdscript
class_name HitboxLoader

const SPRITE_SCALE := 0.045        # scales 2480x3508 images to ~111x158px in game
const IMG_CX := 1240.0             # image width / 2
const IMG_CY := 1754.0             # image height / 2

## Returns Array of frames.
## Each frame is Array of PackedVector2Array (one entry per polygon).
## Coordinates are in the CharacterBody2D's node-local space.
static func load_json(json_path: String) -> Array:
    var file := FileAccess.open(json_path, FileAccess.READ)
    if file == null:
        push_error("HitboxLoader: cannot open " + json_path)
        return []
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
        push_error("HitboxLoader: invalid JSON " + json_path)
        return []
    var result: Array = []
    for frame_data in parsed.get("frames", []):
        var frame_polys: Array = []
        for poly_data in frame_data.get("polygons", []):
            var pts := PackedVector2Array()
            for pt in poly_data.get("points", []):
                pts.append(Vector2(
                    (float(pt[0]) - IMG_CX) * SPRITE_SCALE,
                    (float(pt[1]) - IMG_CY) * SPRITE_SCALE
                ))
            frame_polys.append(pts)
        result.append(frame_polys)
    return result

## Mirrors a polygon horizontally (for left-facing sprites)
static func flip_polygon(poly: PackedVector2Array) -> PackedVector2Array:
    var flipped := PackedVector2Array()
    for p in poly:
        flipped.append(Vector2(-p.x, p.y))
    return flipped
```

**How the coordinate transform works:**
- `AnimatedSprite2D` with `centered = true` (default) renders the texture with its center (IMG_CX, IMG_CY) at the node origin
- Subtract center then multiply by scale → vertex in node-local space
- At scale 0.045: player body ≈ 59×74px, boss body ≈ 51×56px

**Adjusting scale:**
- If sprites appear too large: reduce SPRITE_SCALE (e.g. 0.03)
- If too small: increase (e.g. 0.06)
- Image dimensions must match IMG_CX/IMG_CY (half of actual PNG size)

---

## Step 2: Update the scene (.tscn)

Replace `ColorRect "Sprite"` with `AnimatedSprite2D "Sprite"`.
Replace `CollisionShape2D` under attack/hurtbox areas with `CollisionPolygon2D`.

**Player scene template:**
```
[gd_scene load_steps=3 format=3 uid="..."]

[ext_resource type="Script" path="res://scripts/player/player.gd" id="1"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(28, 46)   # physics body — keep simple rectangle

[node name="Player" type="CharacterBody2D" groups=["player"]]
script = ExtResource("1")

[node name="Sprite" type="AnimatedSprite2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="AttackHitbox" type="Area2D" parent="." groups=["player_attack"]]

[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="AttackHitbox"]

[node name="Hurtbox" type="Area2D" parent="." groups=["player_hurtbox"]]

[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="Hurtbox"]

[node name="AttackTimer" type="Timer" parent="."]
wait_time = 0.42    # match animation duration: frame_count / fps
one_shot = true
```

**Boss scene template:**
```
[node name="Boss01" type="CharacterBody2D" groups=["boss"]]

[node name="Sprite" type="AnimatedSprite2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")   # physics body

[node name="AttackArea" type="Area2D" parent="." groups=["boss_attack"]]

[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="AttackArea"]

[node name="Hurtbox" type="Area2D" parent="."]

[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="Hurtbox"]
```

**Notes:**
- Keep the physics body `CollisionShape2D` as a simple rectangle — it handles movement/floor detection
- Remove any position offsets from AttackHitbox/AttackArea — the polygon vertices already encode position
- `load_steps` = 1 (scene) + count(ext_resources) + count(sub_resources)
- If a base class references `$Sprite` as `ColorRect`, change the type annotation to `Node2D` so both ColorRect and AnimatedSprite2D work

---

## Step 3: Setup animations in code

In `_ready()`, build `SpriteFrames` programmatically:

```gdscript
func _setup_animations() -> void:
    var sf := SpriteFrames.new()

    # Idle animation (1 frame, looping)
    sf.add_animation("idle")
    sf.set_animation_loop("idle", true)
    sf.set_animation_speed("idle", 4.0)
    sf.add_frame("idle", load("res://assets/animation/player/idle/player-idle.PNG") as Texture2D, 1.0)

    # Attack animation (N frames, no loop)
    sf.add_animation("attack")
    sf.set_animation_loop("attack", false)
    sf.set_animation_speed("attack", 12.0)
    for i in 5:  # adjust count to match actual frame count
        sf.add_frame("attack",
            load("res://assets/animation/player/attack/player-attack-%d.PNG" % i) as Texture2D, 1.0)

    sprite.sprite_frames = sf
    sprite.scale = Vector2(HitboxLoader.SPRITE_SCALE, HitboxLoader.SPRITE_SCALE)
    sprite.play("idle")
    sprite.frame_changed.connect(_on_sprite_frame_changed)
    sprite.animation_finished.connect(_on_sprite_animation_finished)
```

**Attack timer duration:** set `wait_time = frame_count / fps` in tscn (e.g. 5 frames ÷ 12 fps = 0.42s)

---

## Step 4: Load hitboxes and wire onready refs

```gdscript
var idle_hitboxes: Array = []
var attack_hitboxes: Array = []

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_poly: CollisionPolygon2D = $AttackHitbox/CollisionPolygon2D
@onready var hurtbox_poly: CollisionPolygon2D = $Hurtbox/CollisionPolygon2D

func _ready() -> void:
    _setup_animations()
    idle_hitboxes   = HitboxLoader.load_json("res://assets/animation/player/idle/idle-hitbox.json")
    attack_hitboxes = HitboxLoader.load_json("res://assets/animation/player/attack/attack-hitbox.json")
    _update_hitbox_for_frame()
```

---

## Step 5: Update hitbox per frame

```gdscript
var facing_right: bool = true

func _on_sprite_frame_changed() -> void:
    _update_hitbox_for_frame()
    queue_redraw()   # triggers _draw() for debug overlay

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
        # Idle: set body polygon, clear attack polygon
        if idle_hitboxes.size() > 0:
            var body := idle_hitboxes[0][0] as PackedVector2Array
            hurtbox_poly.polygon = HitboxLoader.flip_polygon(body) if flip else body
        attack_poly.polygon = PackedVector2Array()
    else:
        # Attack: determine body and attack polygons per frame
        attack_poly.polygon = PackedVector2Array()
        var body_src := (idle_hitboxes[0][0] as PackedVector2Array) if idle_hitboxes.size() > 0 else PackedVector2Array()

        if attack_hitboxes.size() > frame:
            var frame_polys: Array = attack_hitboxes[frame]
            if frame_polys.size() >= 2:
                # Two polygons: [0] = body, [1] = weapon/attack area
                body_src = frame_polys[0]
                var atk := frame_polys[1] as PackedVector2Array
                attack_poly.polygon = HitboxLoader.flip_polygon(atk) if flip else atk
            elif frame_polys.size() == 1 and frame > 0:
                # Single polygon on non-first frame = attack arc (no separate body)
                var atk := frame_polys[0] as PackedVector2Array
                attack_poly.polygon = HitboxLoader.flip_polygon(atk) if flip else atk
            # frame 0 with 1 polygon = body only, no attack

        hurtbox_poly.polygon = HitboxLoader.flip_polygon(body_src) if flip else body_src
```

**When facing direction changes:**
```gdscript
sprite.flip_h = not facing_right
_update_hitbox_for_frame()
queue_redraw()
```

---

## Step 6: Debug draw overlay

Implement `_draw()` on the CharacterBody2D node:

```gdscript
func _draw() -> void:
    var is_attacking: bool = sprite.animation == "attack"
    var frame: int = sprite.frame
    var flip: bool = not facing_right

    # Draw hurtbox in green
    var hbody := PackedVector2Array()
    if not is_attacking:
        if idle_hitboxes.size() > 0:
            hbody = idle_hitboxes[0][0]
    else:
        if attack_hitboxes.size() > frame:
            var fp: Array = attack_hitboxes[frame]
            hbody = fp[0] if fp.size() >= 2 else (idle_hitboxes[0][0] if idle_hitboxes.size() > 0 else PackedVector2Array())

    if hbody.size() > 2:
        var pts := HitboxLoader.flip_polygon(hbody) if flip else hbody
        draw_colored_polygon(pts, Color(0, 1, 0, 0.25))
        var outline := PackedVector2Array(pts)
        outline.append(outline[0])
        draw_polyline(outline, Color(0, 1, 0, 0.8), 1.0)

    # Draw attack hitbox in red
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
```

**Colors used:**
- Green (`Color(0,1,0,0.25)` fill + `Color(0,1,0,0.8)` outline) = hurtbox/body
- Red (`Color(1,0,0,0.25)` fill + `Color(1,0.2,0.2,0.9)` outline) = attack hitbox

---

## Polygon frame logic summary

| Animation | Frame | polygon[0] | polygon[1] | Notes |
|-----------|-------|-----------|-----------|-------|
| idle | 0 | hurtbox (body) | — | Only 1 poly |
| attack | 0 | hurtbox (body) | — | No attack yet |
| attack | 1 | hurtbox (body) | attack area | 2 polys |
| attack | 2-N | attack arc | — | 1 poly = attack arc; use idle body for hurtbox |

This pattern applies to both player and boss. Boss usually maintains a body polygon in all attack frames.

---

## Common issues and fixes

| Problem | Cause | Fix |
|---------|-------|-----|
| Hitbox appears mirrored | Facing direction wrong | Check `facing_right` logic; ensure `flip_polygon()` is called correctly |
| Hitboxes too large/small | Wrong `SPRITE_SCALE` | Adjust `HitboxLoader.SPRITE_SCALE`; player body should be ~60-80px tall |
| Hitbox offset from sprite | Image center ≠ character center | Adjust `IMG_CX`/`IMG_CY` to match the actual image dimensions |
| `_draw()` not updating | `queue_redraw()` not called | Call `queue_redraw()` in `_on_sprite_frame_changed()` and on direction change |
| Attack polygon active during idle | Polygon not cleared | Set `attack_poly.polygon = PackedVector2Array()` in idle branch |
| Boss body reference changes | Base class uses wrong sprite type | Change `@onready var sprite: ColorRect` to `@onready var sprite: Node2D` in base class |
| JSON load fails silently | Wrong path | Verify `res://` path; check `FileAccess.open()` returns non-null |

---

## Files produced by this skill

```
scripts/hitbox_loader.gd          # Static utility — reusable for any character
scenes/player/player.tscn         # AnimatedSprite2D + CollisionPolygon2D nodes
scripts/player/player.gd          # Sprite setup, hitbox update, debug draw
scenes/bosses/boss_01.tscn        # Same structure for boss
scripts/bosses/boss_01.gd         # Boss hitbox + animation integration
scripts/bosses/boss_base.gd       # sprite type changed: ColorRect → Node2D
```
