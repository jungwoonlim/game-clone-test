## Single source of truth for the playfield geometry and physics limits.
##
## The collision shapes in main.tscn are positioned to match these numbers —
## if you move a wall here, move it there too.
class_name Playfield
extends RefCounted

## Inner face of the left wall.
const LEFT: float = 60.0
## Inner face of the right wall.
const RIGHT: float = 480.0
## Top face of the floor.
const FLOOR_Y: float = 900.0
## Where the drawn part of the jar starts. The walls continue invisibly up to
## CEILING so a fruit can never be squeezed out over the rim.
const TOP_Y: float = 190.0
## Hard upper bound for any fruit.
const CEILING: float = -320.0
## Height the dropper holds the next fruit at.
const DROP_Y: float = 152.0
## Fruits resting with their top above this line lose the run.
const DEAD_LINE_Y: float = 228.0

## Speed cap. A merge spawns a larger fruit overlapping its neighbours and the
## solver can resolve that overlap explosively; this keeps the blast contained.
const MAX_SPEED: float = 1500.0
const MAX_ANGULAR: float = 25.0
