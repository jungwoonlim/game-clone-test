## Hand-off between the title screen and the game scene.
##
## A static var survives change_scene_to_file, which is all this needs to carry.
class_name Boot
extends RefCounted

static var continue_from_save: bool = false
