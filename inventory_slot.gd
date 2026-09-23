extends Control 

@onready var icon = $ItemIcon
@onready var count_label = $ItemCount

# This holds the reference to this slot's exact place in the global array
var my_data: Dictionary = {}

func _ready():
	icon.texture = null
	count_label.hide()

# Replaces your old set_item function
func set_slot_data(data: Dictionary):
	my_data = data
	if my_data["item"] != null:
		icon.texture = my_data["item"].icon
		if my_data["count"] > 1:
			count_label.text = str(my_data["count"])
			count_label.show()
		else:
			count_label.hide()
	else:
		icon.texture = null
		count_label.hide()

# ==========================================
# GODOT DRAG AND DROP BUILT-IN FUNCTIONS
# ==========================================

# 1. This runs the moment you click and drag a slot
func _get_drag_data(at_position):
	# Don't drag if the slot is empty!
	if my_data["item"] == null:
		return null 
		
	# Create a "Ghost" image of the item that follows your mouse
	var preview_texture = TextureRect.new()
	preview_texture.texture = my_data["item"].icon
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = Vector2(64, 64)
	preview_texture.modulate = Color(1, 1, 1, 0.7) # Make it slightly transparent
	
	var preview = Control.new()
	preview.add_child(preview_texture)
	preview_texture.position = -preview_texture.custom_minimum_size / 2
	set_drag_preview(preview)
	
	# Package up the origin slot so the destination knows where it came from
	return {"origin_slot": self}

# 2. This checks if your mouse is hovering over a valid drop target
func _can_drop_data(at_position, data):
	return typeof(data) == TYPE_DICTIONARY and data.has("origin_slot")

# 3. This runs when you release the mouse button over this slot!
func _drop_data(at_position, data):
	var origin_slot = data["origin_slot"]
	var origin_data = origin_slot.my_data
	
	# Check if we are dropping the same item and should combine the stacks
	if my_data["item"] != null and my_data["item"] == origin_data["item"] and my_data["item"].is_stackable:
		var space_left = my_data["item"].max_stack - my_data["count"]
		if space_left > 0:
			var amount_to_move = min(space_left, origin_data["count"])
			my_data["count"] += amount_to_move
			origin_data["count"] -= amount_to_move
			
			# Clear the old slot if we took everything
			if origin_data["count"] <= 0:
				origin_data["item"] = null
	else:
		# If they are different items (or one is empty), swap them!
		var temp_item = my_data["item"]
		var temp_count = my_data["count"]
		
		my_data["item"] = origin_data["item"]
		my_data["count"] = origin_data["count"]
		
		origin_data["item"] = temp_item
		origin_data["count"] = temp_count
		
	# Update both slots visually (the dictionary updates the manager automatically!)
	set_slot_data(my_data)
	origin_slot.set_slot_data(origin_data)
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if my_data.has("item") and my_data["item"] != null:
			# Tell the main UI that we right-clicked this specific slot!
			InventoryManager.slot_right_clicked.emit(self, get_global_mouse_position())

func open_context_menu():
	# We will build the UI Popup for this next!
	print("Opening options for: ", my_data["item"].name)
	if my_data["item"].can_use:
		print("- Use")
	if my_data["item"].can_split and my_data["count"] > 1:
		print("- Split")

@onready var highlight_panel = $Highlight # Adjust path if your node is named differently

func set_highlight(is_active: bool):
	if highlight_panel:
		highlight_panel.visible = is_active
