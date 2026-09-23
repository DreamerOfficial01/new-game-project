extends Node2D

@export var ghost_scene: PackedScene # Assign GhostPreview.tscn here
var current_ghost: Area2D = null
var active_placeable: PlaceableData = null

func _process(_delta: float) -> void:
	update_active_item()
	
	if active_placeable and current_ghost:
		current_ghost.show()
		
		# 1. Get Mouse Position & Apply Snapping
		var mouse_pos = get_global_mouse_position()
		
		# HOLD CTRL to bypass grid snapping
		if active_placeable.snap_to_grid and not Input.is_action_pressed("ui_ctrl"): # Map ui_ctrl to Ctrl key
			var grid = active_placeable.grid_size
			mouse_pos.x = snapped(mouse_pos.x, grid.x)
			mouse_pos.y = snapped(mouse_pos.y, grid.y)
			
		current_ghost.global_position = mouse_pos
		
		# 2. Validation (Collision, Distance)
		var is_valid = true
		if global_position.distance_to(mouse_pos) > active_placeable.max_placement_distance:
			is_valid = false
			
		if not active_placeable.allow_overlap and current_ghost.has_overlapping_bodies():
			# Ignore the ground/TileMap if needed, check if overlapping Player or StaticBodies
			for body in current_ghost.get_overlapping_bodies():
				if body != get_tree().current_scene.get_node_or_null("TileMapLayer"):
					is_valid = false
					break
		
		# Visual feedback (Red/Green)
		var sprite = current_ghost.get_node("Sprite2D")
		if is_valid:
			sprite.modulate = Color(0, 1, 0, 0.5) # Green
		else:
			sprite.modulate = Color(1, 0, 0, 0.5) # Red
			
		# 3. Execute Placement (Left Click)
		if is_valid and Input.is_action_just_pressed("interact_main"): # Typically Left Mouse Button
			place_object(mouse_pos)
	else:
		if current_ghost:
			current_ghost.hide()

func update_active_item() -> void:
	var slot = InventoryManager.hotbar_inventory[InventoryManager.active_hotbar_slot]
	var item = slot["item"]
	
	if item and item.placeable_data:
		active_placeable = item.placeable_data
		if current_ghost == null:
			current_ghost = ghost_scene.instantiate()
			get_tree().current_scene.add_child(current_ghost)
			
		current_ghost.get_node("Sprite2D").texture = item.icon
	else:
		active_placeable = null

func place_object(pos: Vector2) -> void:
	var inst = active_placeable.scene_to_spawn.instantiate()
	inst.global_position = pos
	
	var entities = get_tree().current_scene.get_node_or_null("Entities")
	if entities:
		entities.add_child(inst)
	else:
		get_tree().current_scene.add_child(inst)
		
	# Consume item from hotbar (Using your exact phase 2 architecture)
	var active_slot = InventoryManager.hotbar_inventory[InventoryManager.active_hotbar_slot]
	active_slot["count"] -= 1
	if active_slot["count"] <= 0:
		active_slot["item"] = null
	InventoryManager.inventory_updated.emit()
