## The monster portrait in the battle window, read out of the generated sheet
## and scaled up with nearest-neighbour so the pixels stay square.
extends Control

const SHEET := "res://assets/art/monsters.png"
const CELL := ArtSpec.MONSTER
## Column order must match MONSTER_ORDER in tools/build_sprites.gd.
const COLUMNS := {
	&"m_slime": 0, &"m_slime_red": 1, &"m_drakee": 2, &"m_ghost": 3,
	&"m_magician": 4, &"m_scorpion": 5, &"m_wraith": 6,
	&"m_dragonlord": 7, &"m_dragonlord_true": 8,
}

var _texture: Texture2D = load(ArtSpec.sheet(&"monsters")["path"])
var _column := -1
var _home: Vector2 = Vector2.ZERO
var _tween: Tween = null


func _ready() -> void:
	_home = position


func set_monster(data: MonsterData) -> void:
	_column = COLUMNS.get(data.id, -1)
	queue_redraw()


## Recoil plus a white flash. Long enough to read, short enough not to drag.
func play_hit() -> void:
	_kill_tween()
	position = _home
	modulate = Color(2.4, 2.4, 2.4)
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color.WHITE, 0.18)
	_tween.parallel().tween_property(self, "position", _home + Vector2(5, 0), 0.05)
	_tween.parallel().tween_property(self, "position", _home, 0.18).set_delay(0.05)


func play_defeat() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.35)


func reset_presentation() -> void:
	_kill_tween()
	position = _home
	modulate = Color.WHITE


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _draw() -> void:
	if _texture == null or _column < 0:
		return
	# The scale is worked out from the space rather than fixed, so a monster
	# pack drawn at some other cell size still lands in the same box. Whole
	# numbers only: half a pixel of scaling is what makes pixel art shimmer.
	var scale := maxi(1, int(minf(size.x, size.y)) / CELL)
	var drawn := Vector2(CELL * scale, CELL * scale)
	var origin := ((size - drawn) * 0.5).floor()
	draw_texture_rect_region(_texture, Rect2(origin, drawn),
			Rect2(_column * CELL, 0, CELL, CELL))
