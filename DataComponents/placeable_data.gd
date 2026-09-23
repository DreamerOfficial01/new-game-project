extends Resource
class_name PlaceableData

@export var scene_to_spawn: PackedScene
@export var snap_to_grid: bool = true
@export var grid_size: Vector2 = Vector2(16, 16)
@export var allow_overlap: bool = false
@export var max_placement_distance: float = 150.0
