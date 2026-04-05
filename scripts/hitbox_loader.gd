class_name HitboxLoader

const SPRITE_SCALE := 0.045
const IMG_CX := 1240.0  # 2480 / 2
const IMG_CY := 1754.0  # 3508 / 2

## Returns Array of frames.
## Each frame is Array of PackedVector2Array (one per polygon, node-local space).
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

static func flip_polygon(poly: PackedVector2Array) -> PackedVector2Array:
	var flipped := PackedVector2Array()
	for p in poly:
		flipped.append(Vector2(-p.x, p.y))
	return flipped
