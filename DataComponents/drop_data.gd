extends Resource
class_name DropData

@export var item: ItemData
@export var min_quantity: int = 1
@export var max_quantity: int = 1
@export_range(0.0, 100.0) var drop_chance: float = 100.0
