extends Area2D

@onready var progress_bar: TextureProgressBar = $"../InteractionProgress" # Adjust path to your UI bar

var current_target: Node2D = null
var is_interacting: bool = false
var interact_timer: float = 0.0
var required_hold_time: float = 1.0

func _ready() -> void:
	progress_bar.hide()
	progress_bar.max_value = 100

func _process(delta: float) -> void:
	# 1. FIX: Create an untyped generic array first, then add both to it!
	var overlapping: Array = [] 
	overlapping.append_array(get_overlapping_areas())
	overlapping.append_array(get_overlapping_bodies())
	
	var closest = null
	var min_dist = INF
	
	for node in overlapping:
		if node.is_in_group("interactable"):
			var dist = global_position.distance_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = node
				
	current_target = closest

	# Handle Hold F interaction
	if current_target and Input.is_action_pressed("gather"):
		if not is_interacting:
			is_interacting = true
			interact_timer = 0.0
			var active_item = get_active_item()
			var tool_data = active_item.tool_data if active_item else null
			required_hold_time = current_target.get_hold_duration(tool_data)
			progress_bar.show()
			
		interact_timer += delta
		progress_bar.value = (interact_timer / required_hold_time) * 100.0
		
		if interact_timer >= required_hold_time:
			# Execute interaction
			var active_item = get_active_item()
			var tool_data = active_item.tool_data if active_item else null
			
			if current_target.has_method("interact"):
				if current_target is WorldResource:
					current_target.interact(owner, tool_data)
				else:
					current_target.interact(owner) # For pickups
					
			# Reset loop for multi-hit resources like trees
			interact_timer = 0.0
			progress_bar.value = 0.0
	else:
		# Cancel interaction if key released or walked away
		is_interacting = false
		interact_timer = 0.0
		progress_bar.hide()

func get_active_item() -> ItemData:
	var slot_index = InventoryManager.active_hotbar_slot
	var slot_dict = InventoryManager.hotbar_inventory[slot_index]
	return slot_dict["item"]
