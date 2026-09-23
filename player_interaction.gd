extends Area2D

@onready var progress_bar: ProgressBar = get_node_or_null("../InteractionProgress")

var current_target: Node2D = null
var is_interacting: bool = false

func _ready() -> void:
	if progress_bar:
		progress_bar.hide()
		progress_bar.max_value = 100
		progress_bar.z_index = 100
		progress_bar.z_as_relative = false

func _process(delta: float) -> void:
	# 1. Safety check: If the target was destroyed (like a chopped tree), clear it
	if current_target and not is_instance_valid(current_target):
		current_target = null
		is_interacting = false
		if progress_bar:
			progress_bar.hide()
			progress_bar.value = 0.0

	# 2. FOCUS LOCK: Only scan for a new target if we are NOT currently gathering
	if not is_interacting:
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

	# 3. Process the Gathering Loop
	if current_target and Input.is_action_pressed("gather"):
		if not is_interacting:
			is_interacting = true
			if progress_bar:
				progress_bar.show()
			
		var active_item = get_active_item()
		var tool_data = active_item.tool_data if active_item else null
		
		if current_target.has_method("process_gather"):
			var progress = current_target.process_gather(delta, owner, tool_data)
			
			if progress_bar:
				progress_bar.value = progress
				
			if progress >= 100.0:
				is_interacting = false
				if progress_bar:
					progress_bar.hide()
					progress_bar.value = 0.0
	else:
		# Player let go of F early, cancel gathering
		if is_interacting:
			is_interacting = false
			if current_target and current_target.has_method("cancel_gather"):
				current_target.cancel_gather()
			if progress_bar:
				progress_bar.hide()
				progress_bar.value = 0.0
func get_active_item() -> ItemData:
	if InventoryManager and InventoryManager.active_hotbar_slot < InventoryManager.hotbar_inventory.size():
		var slot_dict = InventoryManager.hotbar_inventory[InventoryManager.active_hotbar_slot]
		if slot_dict and slot_dict.has("item"):
			return slot_dict["item"]
	return null
