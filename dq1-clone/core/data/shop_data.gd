## What one shopkeeper sells.
class_name ShopData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_enum("weapon", "armor", "item") var kind: String = "item"
@export var stock: Array[StringName] = []
