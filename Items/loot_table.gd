extends Resource
class_name LootTable

# This creates an array of entries you can easily add to in the Inspector
@export var entries: Array[LootTableEntry] = []

# Rolls the dice for everything in this table and returns an array of what actually dropped
func generate_loot() -> Array:
	var dropped_items = []
	
	for entry in entries:
		if entry.item == null:
			continue
			
		var roll = randf_range(0.0, 100.0)
		if roll <= entry.drop_chance:
			# Pick a random quantity between the min and max
			var count = randi_range(entry.min_quantity, entry.max_quantity)
			dropped_items.append({"item": entry.item, "count": count})
			
	return dropped_items
