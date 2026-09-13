## Static table describing every fruit tier in the game.
##
## The whole game balance lives here: adding a tier is just adding one entry
## to each array (they must all stay the same length).
class_name FruitData
extends RefCounted

## Display names, smallest tier first.
const NAMES: Array[String] = [
	"Cherry", "Strawberry", "Grape", "Dekopon", "Persimmon", "Apple",
	"Pear", "Peach", "Pineapple", "Melon", "Watermelon",
]

## Collision/draw radius in pixels for each tier.
const RADII: Array[float] = [
	18.0, 24.0, 32.0, 40.0, 50.0, 60.0, 72.0, 85.0, 100.0, 118.0, 140.0,
]

## Body colour for each tier.
const COLORS: Array[Color] = [
	Color("e5484d"), # Cherry
	Color("ff5c7a"), # Strawberry
	Color("9b5de5"), # Grape
	Color("ffa92b"), # Dekopon
	Color("f76707"), # Persimmon
	Color("e03131"), # Apple
	Color("a8c93a"), # Pear
	Color("ffa8b6"), # Peach
	Color("f2c14e"), # Pineapple
	Color("b8e986"), # Melon
	Color("2f9e44"), # Watermelon
]

## Points awarded when a fruit of this tier is *created* by a merge.
const SCORES: Array[int] = [
	0, 3, 6, 12, 20, 35, 55, 80, 120, 180, 300,
]

## Index of the biggest fruit. Two of these annihilate each other.
const MAX_LEVEL: int = 10

## Only tiers 0..DROPPABLE_MAX can come out of the dropper.
const DROPPABLE_MAX: int = 4

static func random_droppable_level() -> int:
	return randi_range(0, DROPPABLE_MAX)
