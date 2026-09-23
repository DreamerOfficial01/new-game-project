extends Resource
class_name ToolData

@export var tool_type: String = "Axe" # e.g., Axe, Pickaxe, Hammer, Multitool
@export var power: int = 10
@export var harvest_methods: Array[String] = ["Chop"]
@export var speed: float = 1.0 # Multiplier for interaction speed
