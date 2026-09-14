## Dungeon darkness: paints over every tile outside the party's sight.
##
## A square radius, like the original — a circle reads as a lantern, a square
## reads as "the walls are just beyond your torch".
extends Node2D

const TILE := ArtSpec.TILE

var _center := Vector2i.ZERO
var _radius := 0
var _width := 0
var _height := 0


## radius 0 means the map is fully lit and nothing is drawn.
func configure(center: Vector2i, radius: int, width: int, height: int) -> void:
	_center = center
	_radius = radius
	_width = width
	_height = height
	visible = radius > 0
	queue_redraw()


func _draw() -> void:
	if _radius <= 0:
		return
	for y in _height:
		for x in _width:
			var distance := maxi(absi(x - _center.x), absi(y - _center.y))
			if distance <= _radius:
				continue
			# One tile of half-light at the edge keeps the boundary from
			# looking like a hard cut-out.
			var shade := 0.72 if distance == _radius + 1 else 1.0
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color(0, 0, 0, shade))
