extends Control 
@onready var context_menu = $ContextMenu
@onready var use_btn = $ContextMenu/VBoxContainer/UseBtn
@onready var split_btn = $ContextMenu/VBoxContainer/SplitBtn
@onready var split_slider = $ContextMenu/VBoxContainer/SplitSlider
@onready var split_label = $ContextMenu/VBoxContainer/SplitLabel
@onready var health_bar = $HotbarLayout/VBoxContainer/HealthBar
@onready var hunger_bar = $HotbarLayout/VBoxContainer/HungerBar

var active_slot = null # Remembers which slot we right-clicked


@onready var inventory_window = $CenterContainer 
# Drag your MainGrid from the Scene tree here if this path doesn't match perfectly
@onready var main_grid = $CenterContainer/InventoryBackground/VBoxContainer/HBoxContainer/MainGrid
# Replace these paths by dragging the nodes from your Scene tree!
@onready var hotbar_grid = $HotbarLayout/HotbarGrid
@onready var side_slots = $CenterContainer/InventoryBackground/VBoxContainer/HBoxContainer/SideSlots
# 1. Add a new variable for the main window container


var slot_scene = preload("res://inventory_slot.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS 
	inventory_window.hide() 
	context_menu.hide() # Make sure it starts hidden
	add_to_group("inventory_ui_group")
	# Change this from hide() so it ONLY hides the main window, not the hotbar!
	inventory_window.hide() 
	
	# Connect the new signal
	InventoryManager.active_slot_changed.connect(_on_active_slot_changed)
	
	# Highlight the default slot on startup
	_on_active_slot_changed(InventoryManager.active_hotbar_slot)
	
	for child in main_grid.get_children(): child.queue_free()
	for child in hotbar_grid.get_children(): child.queue_free()
	for child in side_slots.get_children(): child.queue_free()
		
	for i in range(InventoryManager.max_slots):
		main_grid.add_child(slot_scene.instantiate())
		
	for i in range(8):
		hotbar_grid.add_child(slot_scene.instantiate())
		
	for i in range(4):
		side_slots.add_child(slot_scene.instantiate())
		
	InventoryManager.inventory_updated.connect(update_ui)
	
	# Connect PlayerStats so the bars update automatically!
	PlayerStats.stats_changed.connect(update_stats_ui)
	
	update_ui()
	update_stats_ui() # Initialize bar values on startup
	# Connect the new signals!
	InventoryManager.slot_right_clicked.connect(_on_slot_right_clicked)
	use_btn.pressed.connect(_on_use_pressed)
	split_slider.value_changed.connect(_on_slider_changed)
	split_btn.pressed.connect(_on_split_pressed)
	update_ui()

func update_ui():
	var main_slots = main_grid.get_children()
	for i in range(InventoryManager.max_slots):
		if i < main_slots.size():
			main_slots[i].set_slot_data(InventoryManager.inventory[i])
			
	var h_slots = hotbar_grid.get_children()
	for i in range(9):
		if i < h_slots.size():
			h_slots[i].set_slot_data(InventoryManager.hotbar_inventory[i])
			
	var s_slots = side_slots.get_children()
	for i in range(4):
		if i < s_slots.size():
			s_slots[i].set_slot_data(InventoryManager.side_inventory[i])

# 1. Shows the menu when a slot is right-clicked
func _on_slot_right_clicked(slot, pos):
	active_slot = slot
	var item = slot.my_data["item"]
	var count = slot.my_data["count"]
	
	# Position the menu at the mouse
	context_menu.global_position = pos
	context_menu.show()
	
	# Show/Hide the Use button based on the item type
	use_btn.visible = item.can_use
	
	# Setup the Split slider based on how many items are in the stack
	if item.can_split and count > 1:
		split_slider.show()
		split_btn.show()
		split_label.show()
		split_slider.max_value = count - 1 # Leave at least 1 behind
		split_slider.value = 1
		split_label.text = "Amount: 1"
	else:
		split_slider.hide()
		split_btn.hide()
		split_label.hide()

# 2. Updates the label when dragging the slider

func _on_active_slot_changed(active_index: int):
	# Grab the actual slot nodes from the grid
	var current_hotbar_slots = hotbar_grid.get_children()
	
	# Loop through all 8 hotbar slots in your UI
	for i in range(current_hotbar_slots.size()):
		var slot_ui = current_hotbar_slots[i]
		
		# Turn the highlight ON if the index matches, OFF if it doesn't
		# We check if the slot has the method just to be extra safe!
		if slot_ui.has_method("set_highlight"):
			if i == active_index:
				slot_ui.set_highlight(true)
			else:
				slot_ui.set_highlight(false)
func _on_slider_changed(value):
	split_label.text = "Amount: " + str(value)

# 3. Uses the item directly from the UI
func _on_use_pressed():
	var item = active_slot.my_data["item"]
	item.use_item() # Calls your custom function in ItemData!
	
	active_slot.my_data["count"] -= 1
	if active_slot.my_data["count"] <= 0:
		active_slot.my_data["item"] = null
		
	context_menu.hide()
	InventoryManager.inventory_updated.emit()

# 4. Hides the context menu if you click away (optional but helpful)
# Replace _input(event) with this:
func _unhandled_input(event):
	# 1. Hide the context menu if you click outside of it
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var rect = Rect2(context_menu.global_position, context_menu.size)
		if not rect.has_point(get_global_mouse_position()):
			context_menu.hide()
			
	# 2. Toggle the inventory using the universal "interact" action
	if event.is_action_pressed("interact"): 
		if not inventory_window.visible:
			get_tree().call_group("crafting_ui_group", "close_crafting")
			
		inventory_window.visible = !inventory_window.visible
		
		# Consume the input so it stops traveling through the game
		get_viewport().set_input_as_handled()
		
func _on_split_pressed():
	if active_slot == null:
		return
		
	var item = active_slot.my_data["item"]
	var split_amount = int(split_slider.value)
	
	# 1. Check if we have enough items to split
	if active_slot.my_data["count"] <= split_amount:
		return
		
	# 2. Find an empty slot in the inventory to dump the split items into
	var target_slot_data = null
	
	# Search main inventory first
	for slot_data in InventoryManager.inventory:
		if slot_data["item"] == null:
			target_slot_data = slot_data
			break
			
	# If main is full, check hotbar
	if target_slot_data == null:
		for slot_data in InventoryManager.hotbar_inventory:
			if slot_data["item"] == null:
				target_slot_data = slot_data
				break
				
	# 3. Perform the split if we found an empty slot
	if target_slot_data != null:
		target_slot_data["item"] = item
		target_slot_data["count"] = split_amount
		
		# Remove from the original stack
		active_slot.my_data["count"] -= split_amount
		
		# Hide menu and refresh UI
		context_menu.hide()
		InventoryManager.inventory_updated.emit()
	else:
		print("No empty slots available to split into!")
func update_stats_ui():
	# Health Bar reads from PlayerStats dictionary automatically
	health_bar.max_value = PlayerStats.stats["health"]["max"]
	health_bar.value = PlayerStats.stats["health"]["current"]
	
	# Hunger Bar reads from PlayerStats dictionary automatically
	hunger_bar.max_value = PlayerStats.stats["hunger"]["max"]
	hunger_bar.value = PlayerStats.stats["hunger"]["current"]
func close_inventory():
	if inventory_window.visible:
		inventory_window.visible = false
		#get_tree().paused = false
