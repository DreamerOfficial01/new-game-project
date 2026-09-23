extends Control

@onready var category_tabs = $Background/MainLayout/LeftSide/CategoryTabs
@onready var recipe_grid = $Background/MainLayout/LeftSide/ScrollContainer/RecipeGrid

@onready var recipe_name_label = $Background/MainLayout/RightSideDetails/RecipeName
@onready var ingredients_list = $Background/MainLayout/RightSideDetails/IngredientsList
@onready var amount_slider = $Background/MainLayout/RightSideDetails/AmountSlider
@onready var craft_button = $Background/MainLayout/RightSideDetails/CraftButton
@onready var hand_craft_progress = $Background/MainLayout/RightSideDetails/HandCraftProgressBar
@onready var collect_button = $Background/MainLayout/RightSideDetails/CollectButton
@onready var amount_label = $Background/MainLayout/RightSideDetails/AmountLabel
@onready var stop_button = $Background/MainLayout/RightSideDetails/StopButton
@onready var refund_button = $Background/MainLayout/RightSideDetails/RefundButton

var selected_recipe: CraftingRecipe = null
var all_recipes: Array[CraftingRecipe] = []
var active_station: CraftingStation = null # Null means Hand Crafting (Press B)
var current_category: CraftingRecipe.CraftingCategory = CraftingRecipe.CraftingCategory.ALL

func _ready():
	stop_button.pressed.connect(_on_stop_button_pressed)
	refund_button.pressed.connect(_on_refund_button_pressed)
	stop_button.hide()
	refund_button.hide()
	collect_button.pressed.connect(_on_collect_button_pressed)
	collect_button.hide()
	
	add_to_group("crafting_ui_group")
	amount_slider.value_changed.connect(func(value): amount_label.text = "Amount: " + str(value))
	hide()
	
	load_all_recipes()
	setup_category_tabs()
	
	craft_button.pressed.connect(_on_craft_button_pressed)
	hand_craft_progress.hide()
	InventoryManager.inventory_updated.connect(refresh_recipe_grid)

func close_if_station(station: CraftingStation):
	if active_station == station and visible:
		hide()

func _process(delta):
	if active_station and visible:
		var is_crafting = not active_station.craft_timer.is_stopped()
		var has_finished = active_station.finished_items.size() > 0
		var is_paused = active_station.is_paused and active_station.items_left_to_craft > 0
		
		# 1. CRAFT/QUEUE BUTTON & SLIDER VISIBILITY
		if active_station.current_recipe != null and selected_recipe != active_station.current_recipe:
			# Station is busy with a DIFFERENT recipe. Lock it down.
			craft_button.disabled = true
			craft_button.text = "STATION BUSY"
			craft_button.show()
			amount_slider.hide()
			amount_label.hide()
		elif selected_recipe != null:
			# This recipe matches the queue (or station is idle). We can queue more!
			craft_button.disabled = not InventoryManager.has_all_ingredients(selected_recipe)
			if active_station.current_recipe != null:
				craft_button.text = "ADD MORE TO QUEUE"
			else:
				craft_button.text = "CRAFT ITEM"
				
			# ALWAYS show the slider and button so you can queue more!
			craft_button.show()
			amount_slider.show()
			amount_label.show()
				
		# 2. STOP / RESUME / REFUND VISIBILITY
		if is_crafting:
			hand_craft_progress.show()
			stop_button.show()
			stop_button.text = "STOP CRAFTING"
			refund_button.hide()
			
			var t = active_station.craft_timer
			hand_craft_progress.value = 100.0 - ((t.time_left / t.wait_time) * 100.0)
		elif is_paused:
			hand_craft_progress.hide()
			stop_button.show()
			stop_button.text = "RESUME CRAFTING"
			refund_button.show()
			refund_button.text = "GET BACK ITEMS"
		else:
			hand_craft_progress.hide()
			stop_button.hide()
			refund_button.hide()

		# 3. COLLECT BUTTON & RED INVENTORY WARNING
		if has_finished:
			collect_button.show()
			if not InventoryManager.has_empty_slot():
				collect_button.text = "INVENTORY FULL!"
				collect_button.modulate = Color(1.0, 0.2, 0.2) # Turns the button Red!
			else:
				collect_button.modulate = Color(1.0, 1.0, 1.0) # Normal color
				var left_text = ""
				if active_station.items_left_to_craft > 0:
					left_text = " (Left: " + str(active_station.items_left_to_craft) + ")"
				collect_button.text = "COLLECT " + str(active_station.finished_items.size()) + left_text
		else:
			collect_button.hide()


func load_all_recipes():
	var dir = DirAccess.open("res://Recipes/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var recipe = load("res://Recipes/" + file_name) as CraftingRecipe
				if recipe:
					all_recipes.append(recipe)
			file_name = dir.get_next()

func setup_category_tabs():
	for cat in CraftingRecipe.CraftingCategory.values():
		var btn = Button.new()
		btn.text = CraftingRecipe.CraftingCategory.keys()[cat].capitalize()
		btn.pressed.connect(set_category.bind(cat)) 
		category_tabs.add_child(btn)

func set_category(cat_enum):
	current_category = cat_enum
	refresh_recipe_grid()

func toggle_hand_crafting():
	if visible and active_station == null:
		hide()
	else:
		active_station = null
		clear_details_panel() 
		refresh_recipe_grid()
		get_tree().call_group("inventory_ui_group", "close_inventory") 
		show()

func toggle_station_crafting(station: CraftingStation):
	if visible and active_station == station:
		hide()
	else:
		active_station = station
		clear_details_panel() 
		refresh_recipe_grid()
		get_tree().call_group("inventory_ui_group", "close_inventory")
		show()
		
		if active_station.current_recipe != null:
			select_recipe(active_station.current_recipe)

func refresh_recipe_grid():
	for child in recipe_grid.get_children():
		child.queue_free()
		
	for recipe in all_recipes:
		if current_category != CraftingRecipe.CraftingCategory.ALL and recipe.category != current_category:
			continue
			
		if active_station == null:
			if not ("Hand Crafting" in recipe.required_stations or recipe.required_stations.is_empty()):
				continue 
		else:
			if not (active_station.station_type in recipe.required_stations):
				continue
			if recipe.required_station_tier > active_station.current_tier:
				continue
			
		create_recipe_icon(recipe)

func create_recipe_icon(recipe: CraftingRecipe):
	var btn = TextureButton.new()
	btn.texture_normal = recipe.output_item.icon
	
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = Vector2(64, 64) 
	
	if InventoryManager.has_all_ingredients(recipe):
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0) 
	else:
		btn.modulate = Color(0.3, 0.3, 0.3, 1.0) 
		
	# FIXED LAMBDA BUG
	btn.pressed.connect(select_recipe.bind(recipe))
	recipe_grid.add_child(btn)
	
func select_recipe(recipe: CraftingRecipe):
	selected_recipe = recipe
	recipe_name_label.text = recipe.recipe_name
	
	craft_button.custom_minimum_size = Vector2(0, 40)
	craft_button.text = "CRAFT ITEM"
	hand_craft_progress.custom_minimum_size = Vector2(0, 20)
	
	for child in ingredients_list.get_children():
		child.queue_free()
		
	for ingredient in recipe.ingredients:
		var row = HBoxContainer.new()
		var icon = TextureRect.new()
		icon.texture = ingredient.item.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var label = Label.new()
		label.text = str(ingredient.amount) + "x " + ingredient.item.item_name 
		
		row.add_child(icon)
		row.add_child(label)
		ingredients_list.add_child(row)
		
	var max_possible = InventoryManager.get_max_craftable_amount(recipe)
	var actual_max = min(max_possible, recipe.max_craft_amount)
	
	if actual_max < 1:
		actual_max = 1 
		craft_button.disabled = true
	else:
		craft_button.disabled = false

	amount_slider.min_value = 1
	amount_slider.max_value = actual_max
	amount_slider.value = 1
	amount_label.text = "Amount: 1"
	
	amount_slider.show()
	amount_label.show()
	craft_button.show()

func _on_craft_button_pressed():
	if selected_recipe == null or craft_button.disabled:
		return
		
	var craft_amount = int(amount_slider.value)
	InventoryManager.consume_ingredients(selected_recipe, craft_amount)
	
	if active_station != null:
		active_station.add_to_queue(selected_recipe, craft_amount)
		select_recipe(selected_recipe) 
	else:
		start_hand_crafting(craft_amount)

func start_hand_crafting(amount: int):
	craft_button.disabled = true
	hand_craft_progress.show()
	
	var total_time = selected_recipe.crafting_time * amount
	var tween = create_tween()
	
	hand_craft_progress.value = 0
	tween.tween_property(hand_craft_progress, "value", 100.0, total_time)
	
	await tween.finished
	
	hand_craft_progress.hide()
	
	for i in range(selected_recipe.output_amount * amount):
		InventoryManager.add_item(selected_recipe.output_item)
		
	refresh_recipe_grid()
	select_recipe(selected_recipe)

func _on_collect_button_pressed():
	if active_station:
		if not InventoryManager.has_empty_slot():
			collect_button.text = "INVENTORY FULL!"
			return 
		
		active_station.collect_finished_items()
		refresh_recipe_grid() 
		
		if selected_recipe != null:
			select_recipe(selected_recipe)
		else:
			clear_details_panel()
		
func clear_details_panel():
	selected_recipe = null
	recipe_name_label.text = ""
	stop_button.hide()
	refund_button.hide()
	
	for child in ingredients_list.get_children():
		child.queue_free()
		
	amount_slider.hide()
	amount_label.hide() # FIXED CLEARING BUG
	craft_button.hide()
	collect_button.hide()
	hand_craft_progress.hide()

func close_crafting():
	hide()

func _on_stop_button_pressed():
	if active_station:
		if active_station.is_paused:
			active_station.is_paused = false
			active_station.craft_timer.start()
		else:
			active_station.is_paused = true
			active_station.craft_timer.stop()

func _on_refund_button_pressed():
	if active_station and active_station.is_paused:
		if not InventoryManager.has_empty_slot():
			refund_button.text = "INV FULL!"
			return
			
		var recipe = active_station.current_recipe
		var amount_cancelled = active_station.items_left_to_craft
		
		for ingredient in recipe.ingredients:
			var total_to_return = ingredient.amount * amount_cancelled
			for i in range(total_to_return):
				InventoryManager.add_item(ingredient.item)
				
		active_station.items_left_to_craft = 0
		active_station.is_paused = false
		
		if active_station.finished_items.size() == 0:
			active_station.current_recipe = null
			
		refresh_recipe_grid()
		select_recipe(selected_recipe)
