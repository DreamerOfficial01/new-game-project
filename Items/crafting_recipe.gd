@tool
extends Resource
class_name CraftingRecipe

enum CraftingCategory { ALL, WEAPONS, TOOLS, HEALTH, FOOD, MISC }

@export_group("Recipe Info")
@export var recipe_name: String = "New Recipe"
@export var category: CraftingCategory = CraftingCategory.MISC

@export_group("Output")
@export var output_item: ItemData
@export var output_amount: int = 1

@export_group("Ingredients")
@export var ingredients: Array[RecipeIngredient] = []

@export_group("Crafting Rules")
@export var crafting_time: float = 2.0 
@export var max_craft_amount: int = 99
@export var required_station_tier: int = 1 

# Changed to an Array so you can select as many stations as you want!
var required_stations: Array[String] = [] 

# FIXED: Added [Dictionary] to the return type and variable to satisfy Godot 4.2+
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	
	# Removed the colon! It now saves exactly as "Hand Crafting"
	var dropdown_options = "Hand Crafting," 
	
	var dir = DirAccess.open("res://Crafting_stations/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				var clean_name = file_name.replace(".tscn", "")
				# Removed the colon here too!
				dropdown_options += clean_name + ","
			file_name = dir.get_next()
			
	var array_hint = str(TYPE_STRING) + "/" + str(PROPERTY_HINT_ENUM) + ":" + dropdown_options.trim_suffix(",")
	
	properties.append({
		"name": "required_stations",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": array_hint
	})
	
	return properties
