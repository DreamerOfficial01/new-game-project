extends Node

var database: Dictionary = {}
var loot_tables: Dictionary = {} # New dictionary to hold all loot tables

var items_folder: String = "res://Items/" 
var loot_tables_folder: String = "res://Items/loot_tables/" # The new folder path

var pickup_scene: PackedScene = preload("res://PickupItem.tscn") 

func _ready():
	load_all_items_in_folder(items_folder)
	load_all_loot_tables_in_folder(loot_tables_folder) # Auto-load the tables on startup

# --- AUTO-LOADING FUNCTIONS ---

func load_all_items_in_folder(path: String):
	var dir = DirAccess.open(path)
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var actual_file_name = file_name.replace(".remap", "")
				var key = actual_file_name.replace(".tres", "")
				database[key] = load(path + actual_file_name)
	else:
		print("Warning: Could not open items folder at ", path)

func load_all_loot_tables_in_folder(path: String):
	var dir = DirAccess.open(path)
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var actual_file_name = file_name.replace(".remap", "")
				var key = actual_file_name.replace(".tres", "")
				loot_tables[key] = load(path + actual_file_name)
				print("Auto-loaded loot table: ", key)
	else:
		print("Warning: Could not open loot tables folder at ", path)

# --- ITEM FETCHING & DROPPING ---

func get_item(item_id: String) -> ItemData:
	if database.has(item_id):
		return database[item_id]
	return null

func drop_loot(item_data: ItemData, count: int, drop_position: Vector2, is_random_loot: bool = true):
	if item_data == null or count <= 0:
		return
		
	if is_random_loot:
		var roll = randf_range(0.0, 100.0)
		if roll > item_data.drop_chance:
			return 
			
	if pickup_scene != null:
		var dropped_item = pickup_scene.instantiate()
		dropped_item.item_data = item_data 
		
		if "count" in dropped_item:
			dropped_item.count = count
		elif "amount" in dropped_item:
			dropped_item.amount = count
			
		dropped_item.global_position = drop_position 
		dropped_item.scale = Vector2(5, 5)
		get_tree().current_scene.add_child(dropped_item)

# --- LOOT TABLE DROPPING ---

# This now expects a String name (e.g., "goblin_loot") instead of a Resource!
func drop_from_table(table_name: String, drop_position: Vector2):
	# 1. Check if the table exists in our auto-loaded dictionary
	if not loot_tables.has(table_name):
		print("Error: Loot table not found: ", table_name)
		return
		
	# 2. Get the table and generate the drops
	var loot_table = loot_tables[table_name]
	var items_to_drop = loot_table.generate_loot()
	
	# 3. Spawn the physical items
	for drop in items_to_drop:
		var random_offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		var final_position = drop_position + random_offset
		
		drop_loot(drop["item"], drop["count"], final_position, false)
