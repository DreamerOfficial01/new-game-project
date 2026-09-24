extends Area2D

@onready var progress_bar: ProgressBar = get_node_or_null("../InteractionProgress")
@onready var weapon_hitbox: Area2D = get_node_or_null("../WeaponHitbox")
@onready var weapon_shape: CollisionShape2D = get_node_or_null("../WeaponHitbox/CollisionShape2D")

var current_target: Node2D = null
var is_interacting: bool = false
var is_attacking: bool = false

func _ready() -> void:
	if progress_bar:
		progress_bar.hide()
		progress_bar.max_value = 100
		progress_bar.z_index = 100
		progress_bar.z_as_relative = false
	if weapon_shape:
		weapon_shape.disabled = true

func _process(delta: float) -> void:
	if current_target and not is_instance_valid(current_target):
		current_target = null
		is_interacting = false
		if progress_bar:
			progress_bar.hide()
			progress_bar.value = 0.0

	# --- NEW: Combat Logic ---
	if Input.is_action_just_pressed("attack") and not is_interacting and not is_attacking:
		var active_item = get_active_item()
		if active_item and active_item.tool_data and active_item.tool_data.tool_type == "Sword":
			perform_attack(active_item.tool_data.power)

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
		if is_interacting:
			is_interacting = false
			if current_target and current_target.has_method("cancel_gather"):
				current_target.cancel_gather()
			if progress_bar:
				progress_bar.hide()
				progress_bar.value = 0.0

# --- NEW: Attack Execution ---
func perform_attack(damage: int) -> void:
	is_attacking = true
	
	if weapon_shape:
		weapon_shape.disabled = false
		
	# Scan for enemies inside the hitbox
	if weapon_hitbox:
		var targets = weapon_hitbox.get_overlapping_bodies()
		for target in targets:
			if target.is_in_group("enemy") and target.has_method("take_damage"):
				target.take_damage(damage)
				
	# Keep the hitbox active for 0.2 seconds (the length of a swing)
	await get_tree().create_timer(0.2).timeout
	
	if weapon_shape:
		weapon_shape.disabled = true
	
	# Cooldown before you can swing again
	await get_tree().create_timer(0.3).timeout
	is_attacking = false

func get_active_item() -> ItemData:
	if InventoryManager and InventoryManager.active_hotbar_slot < InventoryManager.hotbar_inventory.size():
		var slot_dict = InventoryManager.hotbar_inventory[InventoryManager.active_hotbar_slot]
		if slot_dict and slot_dict.has("item"):
			return slot_dict["item"]
	return null
