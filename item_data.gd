extends Resource
class_name ItemData

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var item_name: String = "New Item"
@export var icon: Texture2D
@export_group("Optional Components")
@export var tool_data: ToolData = null
@export var placeable_data: PlaceableData = null
@export_group("Visuals & Rarity")
# This creates the actual dropdown in the Inspector, defaulting to Common
@export var rarity: Rarity = Rarity.COMMON
# A helper function that returns the exact color based on the dropdown choice
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.DARK_GRAY
		Rarity.UNCOMMON:
			return Color.GREEN
		Rarity.RARE:
			return Color.DODGER_BLUE
		Rarity.EPIC:
			return Color.DARK_VIOLET
		Rarity.LEGENDARY:
			return Color.GOLD
	return Color.BLACK


@export_group("Loot & Drops")
@export_range(0.0, 100.0) var drop_chance: float = 100.0

@export_group("Stacking")
@export var is_stackable: bool = false
@export var max_stack: int = 1

@export_group("Combat Stats")
@export var attack_damage: int = 0
@export var damage_type: String = "None"

@export_group("Consumable Stats")
@export var can_use: bool = false
@export var can_split: bool = true

# Type the exact name of the stat from PlayerStats here (e.g., "hunger", "health")
@export var stat_to_buff: String = "hunger" 
@export var buff_amount: float = 15.0

@export_group("Placement")
@export var is_placeable: bool = false
@export var placeable_scene: PackedScene # Drag the CraftingStation.tscn here!

func use_item():
	if not can_use:
		return
	
	# Automatically tells PlayerStats to modify whatever stat this item targets!
	PlayerStats.modify_stat(stat_to_buff, buff_amount)
