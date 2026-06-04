extends Sprite3D
## The office dog 🐕 — procedural pixel pup that wanders the recreation room.
## Pure ambient life: no events, no nameplate, just charm.

const TROT_A: Array[String] = [
	"..........oo..",
	".........oBBo.",
	"oo.......oBBBo",
	".oo.....ooBeBo",
	"..oBBBBBBBBBo.",
	"..oBBBBBBBBBo.",
	"..oBbBBBBbBo..",
	"..oBo....oBo..",
	"..oBo....oBo..",
	"..............",
]
const TROT_B: Array[String] = [
	"..........oo..",
	".........oBBo.",
	"oo.......oBBBo",
	".oo.....ooBeBo",
	"..oBBBBBBBBBo.",
	"..oBBBBBBBBBo.",
	"..oBbBBBBbBo..",
	".oBo......oBo.",
	"...oBo..oBo...",
	"..............",
]

## Wander area (the recreation room).
const ROAM := Rect2(-9.2, 6.8, 11.4, 5.6)  # x, z, w, d
const SPEED := 1.3

var _tex_a: ImageTexture
var _tex_b: ImageTexture
var _tween: Tween
var _t := 0.0
var _frame_t := 0.0
var _frame := 0
var _moving := false

func _ready() -> void:
	layers = 2  # moving prop — keep it off the static map render
	var colors := {
		"o": Color8(28, 20, 14),
		"B": Color8(158, 106, 62),
		"b": Color8(224, 196, 156),
		"e": Color8(22, 22, 28),
	}
	_tex_a = _bake(TROT_A, colors)
	_tex_b = _bake(TROT_B, colors)
	texture = _tex_a
	pixel_size = 0.05
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = true
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_roam_loop()

func _bake(art: Array[String], colors: Dictionary) -> ImageTexture:
	var img := Image.create(art[0].length(), art.size(), false, Image.FORMAT_RGBA8)
	for y in art.size():
		for x in art[y].length():
			if colors.has(art[y][x]):
				img.set_pixel(x, y, colors[art[y][x]])
	return ImageTexture.create_from_image(img)

func _roam_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(1.5, 5.0)).timeout
		if not is_inside_tree():
			return
		var target := Vector3(
			randf_range(ROAM.position.x, ROAM.position.x + ROAM.size.x),
			position.y,
			randf_range(ROAM.position.y, ROAM.position.y + ROAM.size.y))
		flip_h = target.x < position.x  # art faces right
		var dur := position.distance_to(target) / SPEED
		_moving = true
		_tween = create_tween()
		_tween.tween_property(self, "position", target, dur)
		await _tween.finished
		_moving = false

func _process(delta: float) -> void:
	_t += delta * (10.0 if _moving else 3.0)
	offset.y = absf(sin(_t)) * (1.2 if _moving else 0.3)
	if _moving:
		_frame_t += delta
		if _frame_t >= 0.14:
			_frame_t = 0.0
			_frame = 1 - _frame
			texture = _tex_b if _frame == 1 else _tex_a
	elif texture != _tex_a:
		texture = _tex_a
