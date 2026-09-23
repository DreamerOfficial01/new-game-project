extends Node

var max_slots: int = 32
var inventory: Array = []
var hotbar_inventory: Array = []
var side_inventory: Array = []

var active_hotbar_slot: int = 0

signal inventory_updated
signal slot_right_clicked(slot_reference, mouse_position)
signal active_slot_changed(new_slot_index)

func _ready():
	# Generate data for the main inventory
	for i in range(max_slots):
		inventory.append({"item": null, "count": 0})
		
	# Generate data for the 8 hotbar slots
	for i in range(8):
		hotbar_inventory.append({"item": null, "count": 0})
		
	# Generate data for the 4 side slots
	for i in range(4):
		side_inventory.append({"item": null, "count": 0})

# Checks if there is room for an item (used by your physical pickups)
func has_space_for(item_data: ItemData) -> bool:
	# Check hotbar first
	for slot in hotbar_inventory:
		if slot["item"] == item_data and item_data.is_stackable and slot["count"] < item_data.max_stack:
			return true
		if slot["item"] == null:
			return true
			
	# Check main inventory
	for slot in inventory:
		if slot["item"] == item_data and item_data.is_stackable and slot["count"] < item_data.max_stack:
			return true
		if slot["item"] == null:
			return true
			
	return false

# Adds the item to the first available slot
func add_item(item_data: ItemData):
	# 1. Try to stack in hotbar
	if item_data.is_stackable:
		for slot in hotbar_inventory:
			if slot["item"] == item_data and slot["count"] < item_data.max_stack:
				slot["count"] += 1
				inventory_updated.emit()
				return
				
	# 2. Try to stack in main inventory
	if item_data.is_stackable:
		for slot in inventory:
			if slot["item"] == item_data and slot["count"] < item_data.max_stack:
				slot["count"] += 1
				inventory_updated.emit()
				return

	# 3. Put in empty hotbar slot
	for slot in hotbar_inventory:
		if slot["item"] == null:
			slot["item"] = item_data
			slot["count"] = 1
			inventory_updated.emit()
			return
			
	# 4. Put in empty main inventory slot
	for slot in inventory:
		if slot["item"] == null:
			slot["item"] = item_data
			slot["count"] = 1
			inventory_updated.emit()
			return

func cycle_hotbar(direction: int):
	active_hotbar_slot += direction
	
	# Wrap around logic (assuming 8 hotbar slots, indexed 0 to 7)
	if active_hotbar_slot < 0:
		active_hotbar_slot = 7 
	elif active_hotbar_slot > 7:
		active_hotbar_slot = 0
		
	# Tell the UI to update the border
	active_slot_changed.emit(active_hotbar_slot)

# Checks if the player has all required ingredients for a recipe
func has_all_ingredients(recipe: CraftingRecipe) -> bool:
	for ingredient in recipe.ingredients:
		var count_needed = ingredient.amount
		var count_found = 0
		
		# Check main inventory
		for slot in inventory:
			if slot["item"] == ingredient.item:
				count_found += slot["count"]
				
		# Check hotbar
		for slot in hotbar_inventory:
			if slot["item"] == ingredient.item:
				count_found += slot["count"]
				
		if count_found < count_needed:
			return false
			
	return true

# Removes the exact amount of ingredients needed for the recipe
func consume_ingredients(recipe: CraftingRecipe, multiplier: int = 1):
	for ingredient in recipe.ingredients:
		var count_needed = ingredient.amount * multiplier
		
		# 1. Drain from main inventory first
		for slot in inventory:
			if slot["item"] == ingredient.item and count_needed > 0:
				if slot["count"] >= count_needed:
					slot["count"] -= count_needed
					count_needed = 0
				else:
					count_needed -= slot["count"]
					slot["count"] = 0
				
				if slot["count"] == 0:
					slot["item"] = null
					
		# 2. Drain from hotbar if we still need more
		for slot in hotbar_inventory:
			if slot["item"] == ingredient.item and count_needed > 0:
				if slot["count"] >= count_needed:
					slot["count"] -= count_needed
					count_needed = 0
				else:
					count_needed -= slot["count"]
					slot["count"] = 0
					
				if slot["count"] == 0:
					slot["item"] = null

	inventory_updated.emit()

# Calculates how many of this recipe we can make based on current materials
func get_max_craftable_amount(recipe: CraftingRecipe) -> int:
	var max_possible = 9999
	
	for ingredient in recipe.ingredients:
		var count_found = 0
		for slot in inventory:
			if slot["item"] == ingredient.item:
				count_found += slot["count"]
		for slot in hotbar_inventory:
			if slot["item"] == ingredient.item:
				count_found += slot["count"]
				
		var can_make = count_found / ingredient.amount
		if can_make < max_possible:
			max_possible = can_make
			
	return max_possible

# Safely checks if there is at least one completely empty slot
func has_empty_slot() -> bool:
	for slot in hotbar_inventory:
		if slot["item"] == null:
			return true
	for slot in inventory:
		if slot["item"] == null:
			return true
	return false

# --- PERSISTENCE HOOKS ---

# Packages all inventory arrays into serializable dictionary data
func get_save_data() -> Dictionary:
	return {
		"hotbar": _serialize_slot_array(hotbar_inventory),
		"inventory": _serialize_slot_array(inventory),
		"side": _serialize_slot_array(side_inventory),
		"active_hotbar_slot": active_hotbar_slot
	}

# Restores items into hotbar, main, and side slots
func load_save_data(data: Variant):
	if not data is Dictionary:
		return
		
	if data.has("hotbar"):
		_deserialize_slot_array(hotbar_inventory, data["hotbar"])
	if data.has("inventory"):
		_deserialize_slot_array(inventory, data["inventory"])
	if data.has("side"):
		_deserialize_slot_array(side_inventory, data["side"])
	if data.has("active_hotbar_slot"):
		active_hotbar_slot = data["active_hotbar_slot"]
		active_slot_changed.emit(active_hotbar_slot)
		
	inventory_updated.emit()

func _serialize_slot_array(arr: Array) -> Array:
	var saved: Array = []
	for slot in arr:
		if slot["item"] != null:
			saved.append({
				"item_path": slot["item"].resource_path,
				"count": slot["count"]
			})
		else:
			saved.append(null)
	return saved

func _deserialize_slot_array(target_arr: Array, saved_arr: Array):
	for i in range(mini(target_arr.size(), saved_arr.size())):
		var slot_data = saved_arr[i]
		if slot_data != null and slot_data.has("item_path"):
			var item_res = load(slot_data["item_path"]) as ItemData
			target_arr[i]["item"] = item_res
			# Force float from JSON to become a clean whole integer:
			target_arr[i]["count"] = int(slot_data.get("count", 1))
		else:
			target_arr[i]["item"] = null
			target_arr[i]["count"] = 0
