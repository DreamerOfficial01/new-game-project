extends CharacterBody2D # Or whatever your player extends
var knockback: Vector2 = Vector2.ZERO
@export var grid_snap_size: float = 96.0 # Adjust this! (e.g., 16px tile * 6 scale = 96)
@onready var ghost_preview = $GhostPreview
@onready var preview_area = $GhostPreview/Area2D

# 1. ADD THIS AT THE TOP
# Preload your new LootNotifier scene so it's ready instantly.
# Make sure this path exactly matches where you saved LootNotifier.tscn!
var loot_notifier_scene: PackedScene = preload("res://loot_notifier.tscn")

# This node handles the offset so notifications appear clearly above the player's head.
@onready var loot_spawn_point: Marker2D = $LootSpawnPoint

# Adjust this base SPEED based on the math above (try 150.0 if 300.0 feels too fast)
const SPEED = 300.0 
var running_speed = 150.0 # Adds 100 on top of the base speed
const ACCELERATION = 10.0 

@onready var animated_sprite = $AnimatedSprite2D

# Drag your InventoryUI node from the scene tree into this slot in the Inspector!
@export var inventory_ui: Control 

func _ready():
	add_to_group("player")
	
	# Ask GameManager to restore saved position the instant the player is ready
	if GameManager:
		GameManager.restore_player_position(self)

func collect_item(item: ItemData):
	# Your original working line:
	InventoryManager.add_item(item)
	
	# 3. TRIGGER THE VISUALS
	spawn_loot_notification(item)

func spawn_loot_notification(item_data: ItemData):
	if loot_notifier_scene != null and loot_spawn_point != null:
		
		# Tell all existing notifications to move up!
		get_tree().call_group("loot_notifications", "shift_up")
		
		var notification = loot_notifier_scene.instantiate()
		var rarity_color = item_data.get_rarity_color()
		
		get_tree().current_scene.add_child(notification)
		
		notification.global_position = loot_spawn_point.global_position
		notification.setup_item_pickup(item_data.item_name, 1, rarity_color)
		
	else:
		print("Warning: loot_notifier_scene or loot_spawn_point is missing in Player.gd")

func _physics_process(delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_speed = SPEED
	if Input.is_action_pressed("sprint_move"):
		target_speed += running_speed
		
	var target_velocity = direction * target_speed
	
	# --- NEW: Knockback physics ---
	if knockback != Vector2.ZERO:
		velocity = knockback
		# Smoothly slow down the knockback force
		knockback = knockback.move_toward(Vector2.ZERO, 1500 * delta)
	else:
		if direction == Vector2.ZERO:
			velocity = Vector2.ZERO
		else:
			velocity = velocity.lerp(target_velocity, ACCELERATION * delta)
	
	move_and_slide()
	update_animation()

func update_animation():
	if velocity == Vector2.ZERO:
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")
		return
		
	# Dynamically scale animation speed based on how fast we are actually moving
	animated_sprite.speed_scale = velocity.length() / SPEED
		
	if abs(velocity.x) > abs(velocity.y):
		if velocity.x > 0:
			animated_sprite.play("run_right")
		else:
			animated_sprite.play("run_left")
	else:
		if velocity.y > 0:
			animated_sprite.play("run_down")
		else:
			animated_sprite.play("run_up")

func _unhandled_input(event):
	# PLACE ITEM LOGIC
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		try_place_item()
		
	# OPEN / CLOSE HAND CRAFTING
	if event is InputEventKey and event.keycode == KEY_B and event.is_pressed() and not event.echo:
		get_tree().call_group("crafting_ui_group", "toggle_hand_crafting")

func try_place_item():
	var active_index = InventoryManager.active_hotbar_slot
	var active_slot = InventoryManager.hotbar_inventory[active_index]
	var item = active_slot["item"]
	
	# Verify we are holding a placeable item with a valid scene attached
	if item != null and item.is_placeable and item.placeable_scene != null:
		
		# --- NEW OVERLAP CHECK ---
		# If the ghost's Area2D is touching anything, cancel the placement!
		if preview_area.has_overlapping_bodies() or preview_area.has_overlapping_areas():
			print("Cannot place here, something is in the way!")
			return # This stops the rest of the function from running
		# -------------------------
		
		# 1. Spawn the object
		var new_object = item.placeable_scene.instantiate()
		get_tree().current_scene.add_child(new_object)
		
		# 2. Snap it to the exact same grid position the Ghost is showing
		var mouse_pos = get_global_mouse_position()
		var snapped_x = snapped(mouse_pos.x, grid_snap_size)
		var snapped_y = snapped(mouse_pos.y, grid_snap_size)
		new_object.global_position = Vector2(snapped_x, snapped_y)
		
		# 3. Remove 1 from the player's hotbar
		active_slot["count"] -= 1
		if active_slot["count"] <= 0:
			active_slot["item"] = null
			
		# 4. Tell the UI to update
		InventoryManager.inventory_updated.emit()

func _input(event):
	# Select Hotbar Slots 1-8
	for i in range(8):
		if event.is_action_pressed("hotbar_" + str(i + 1)):
			InventoryManager.active_hotbar_slot = i
			print("Selected slot: ", i)
			
	# Use Item on Right Click (when inventory is closed)
	if event.is_action_pressed("right_click") and not get_tree().paused:
		var slot_data = InventoryManager.hotbar_inventory[InventoryManager.active_hotbar_slot]
		
		if slot_data["item"] != null and slot_data["item"].can_use:
			slot_data["item"].use_item()
			slot_data["count"] -= 1
			
			if slot_data["count"] <= 0:
				slot_data["item"] = null
			
			InventoryManager.inventory_updated.emit()

func _process(_delta):
	update_ghost_preview()

func update_ghost_preview():
	# 1. Get the currently selected hotbar slot from the InventoryManager
	var active_index = InventoryManager.active_hotbar_slot
	var active_slot = InventoryManager.hotbar_inventory[active_index]
	var active_item = active_slot["item"]
	
	# 2. Check if the item exists and is placeable
	if active_item != null and active_item.is_placeable:
		ghost_preview.show()
		ghost_preview.texture = active_item.icon
		
		# 3. Calculate Grid Snapping
		var mouse_pos = get_global_mouse_position()
		var snapped_x = snapped(mouse_pos.x, grid_snap_size)
		var snapped_y = snapped(mouse_pos.y, grid_snap_size)
		
		ghost_preview.global_position = Vector2(snapped_x, snapped_y)
		
		# Optional: Scale the ghost up if your player/world is scaled 6x!
		ghost_preview.scale = Vector2(0.15, 0.15) 
	else:
		# Hide the ghost if holding a sword, apple, or empty slot
		ghost_preview.hide()

# ==========================================
# COMBAT & DAMAGE LOGIC
# ==========================================
# ==========================================
# COMBAT & DAMAGE LOGIC
# ==========================================
# --- UPDATE YOUR TAKE_DAMAGE FUNCTION ---
func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	PlayerStats.modify_stat("health", -amount)
	
	var tween = create_tween()
	modulate = Color(3, 0, 0, 1)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)
	
	if knockback_dir != Vector2.ZERO:
		# Apply brute force to the velocity!
		knockback = knockback_dir * 500.0 
		
	if PlayerStats.stats["health"]["current"] <= 0:
		die()
		
func die() -> void:
	print("Player has died!")
	# You can expand this later to trigger a Game Over UI or respawn the player!
