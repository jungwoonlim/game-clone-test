## One fruit in the jar.
##
## A plain RigidBody2D that draws itself procedurally (no image assets needed)
## and reports to the game when it touches another fruit of the same tier.
class_name Fruit
extends RigidBody2D

## Emitted once per colliding pair; the game node does the actual merging.
signal request_merge(a: Fruit, b: Fruit)

## Tier index into the FruitData tables.
var level: int = 0
## Cached from FruitData so callers can read it without a table lookup.
var radius: float = 18.0
## True once the fruit has left the dropper and takes part in physics.
var dropped: bool = false
## Set on both partners the instant a merge is decided, so a fruit can never
## be consumed by two merges in the same physics frame.
var is_merging: bool = false
## How long *this* fruit has been sitting above the dead line. Tracked per
## fruit so that a stream of different fruits briefly crossing the line cannot
## add up to a false game over.
var danger_time: float = 0.0

var _color: Color = Color.WHITE

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body_entered.connect(_on_body_entered)
	_apply_level()


## Must be called right after instantiating, before add_child().
func setup(new_level: int) -> void:
	level = new_level
	radius = FruitData.RADII[level]
	_color = FruitData.COLORS[level]
	if is_node_ready():
		_apply_level()


## Preview fruits sit on the dropper: visible, but completely inert.
func set_active(active: bool) -> void:
	freeze = not active
	collision_layer = 1 if active else 0
	collision_mask = 1 if active else 0
	if active:
		sleeping = false


## Called by the game once per frame while the run is live.
func update_danger(delta: float) -> void:
	if global_position.y - radius < Playfield.DEAD_LINE_Y:
		danger_time += delta
	else:
		danger_time = 0.0


func _apply_level() -> void:
	radius = FruitData.RADII[level]
	_color = FruitData.COLORS[level]
	var circle := CircleShape2D.new()
	circle.radius = radius
	_collision.shape = circle
	# Bigger fruit is heavier so it shoulders the small ones aside, but the
	# ratio is deliberately gentler than real area (r^2) would give: a 60:1
	# mass ratio makes the contact solver spit fruit out of the jar.
	mass = pow(radius, 1.5) * 0.05
	queue_redraw()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Safety net. A merge drops a larger fruit right on top of its neighbours;
	# without these clamps the solver can launch fruit clean out of the jar.
	var velocity := state.linear_velocity
	if velocity.length() > Playfield.MAX_SPEED:
		state.linear_velocity = velocity.normalized() * Playfield.MAX_SPEED
	state.angular_velocity = clampf(
			state.angular_velocity, -Playfield.MAX_ANGULAR, Playfield.MAX_ANGULAR)

	var xform := state.transform
	var pos := xform.origin
	var bounded := pos
	bounded.x = clampf(pos.x, Playfield.LEFT + radius, Playfield.RIGHT - radius)
	bounded.y = clampf(pos.y, Playfield.CEILING + radius, Playfield.FLOOR_Y - radius)
	if not bounded.is_equal_approx(pos):
		xform.origin = bounded
		state.transform = xform


func _on_body_entered(body: Node) -> void:
	if is_merging or not dropped:
		return
	if not (body is Fruit):
		return
	var other: Fruit = body
	if other.is_merging or not other.dropped or other.level != level:
		return
	# Both bodies report the contact. Let exactly one of them own the merge.
	if get_instance_id() < other.get_instance_id():
		return
	is_merging = true
	other.is_merging = true
	request_merge.emit(self, other)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, _color)
	draw_arc(Vector2.ZERO, radius - 1.0, 0.0, TAU, 48, _color.darkened(0.3), 2.0, true)
	# Glossy highlight.
	draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.2, Color(1, 1, 1, 0.45))
	# A tiny face, mostly so you can see the fruit spinning.
	var eye_dx := radius * 0.3
	var eye_r := maxf(radius * 0.09, 1.5)
	var eye_col := Color(0.15, 0.1, 0.1)
	draw_circle(Vector2(-eye_dx, -radius * 0.05), eye_r, eye_col)
	draw_circle(Vector2(eye_dx, -radius * 0.05), eye_r, eye_col)
	draw_arc(Vector2(0, radius * 0.1), radius * 0.3, PI * 0.15, PI * 0.85, 16,
			eye_col, maxf(radius * 0.05, 1.0), true)
