extends StaticBody2D
class_name CraftingStation

@export_group("Station Identity")
@export var station_type: String = "potion_station"
@export var station_name: String = "Potion Station"
@export var current_tier: int = 1
@export var max_tier: int = 3

@export_group("Upgrade Requirements (For Next Tier)")
@export var required_player_level: int = 2
@export var upgrade_cost: Array[RecipeIngredient] = []

var is_player_near: bool = false
var crafting_queue: Array[CraftingRecipe] = []
var finished_items: Array[ItemData] = []
var is_paused: bool = false

var items_left_to_craft: int = 0
var current_recipe: CraftingRecipe = null

@onready var prompt_label = $PromptLabel
@onready var finished_icon = $FinishedIcon
@onready var craft_timer = $CraftTimer

signal station_ui_opened(station_reference)

func _ready():
	prompt_label.hide()
	finished_icon.hide()
	
	$InteractArea.body_entered.connect(_on_interact_area_entered)
	$InteractArea.body_exited.connect(_on_interact_area_exited)
	craft_timer.timeout.connect(_on_craft_timer_timeout)
	
	# Automatically register to the universal save system!
	add_to_group("persist")

func _unhandled_input(event):
	if is_player_near and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		get_tree().call_group("crafting_ui_group", "toggle_station_crafting", self)

func _on_interact_area_entered(body):
	if body.name == "Player":
		is_player_near = true
		prompt_label.show()

func _on_interact_area_exited(body):
	if body.name == "Player":
		is_player_near = false
		prompt_label.hide()
		get_tree().call_group("crafting_ui_group", "close_if_station", self)

func add_to_queue(recipe: CraftingRecipe, amount: int):
	if current_recipe != null and current_recipe != recipe:
		return

	current_recipe = recipe
	items_left_to_craft += amount

	if craft_timer.is_stopped() and not is_paused:
		craft_timer.wait_time = recipe.crafting_time
		craft_timer.start()

func _on_craft_timer_timeout():
	if items_left_to_craft > 0 and current_recipe != null:
		for i in range(current_recipe.output_amount):
			finished_items.append(current_recipe.output_item)
			
		items_left_to_craft -= 1
		
		if items_left_to_craft > 0:
			craft_timer.start()

func collect_finished_items():
	for item in finished_items:
		InventoryManager.add_item(item)
		
	finished_items.clear()
	
	if items_left_to_craft <= 0:
		current_recipe = null

func _process(delta):
	if finished_items.size() > 0:
		finished_icon.texture = finished_items[0].icon
		finished_icon.show()
	else:
		finished_icon.hide()

# --- UNIVERSAL PERSISTENCE HOOKS ---

func get_custom_save_data() -> Dictionary:
	var recipe_path = ""
	if current_recipe != null:
		recipe_path = current_recipe.resource_path
		
	var current_time_left = 0.0
	if not craft_timer.is_stopped():
		current_time_left = craft_timer.time_left
		
	return {
		"recipe_path": recipe_path,
		"items_left": items_left_to_craft,
		"is_paused": is_paused,
		"time_left": current_time_left,
		"timestamp": Time.get_unix_time_from_system()
	}

func load_custom_save_data(data: Dictionary):
	# If this station just spawned and hasn't finished waking up, wait for @onready!
	if not is_node_ready():
		await ready
		
	# Fallback safety in case craft_timer hasn't been cached yet
	if not craft_timer:
		craft_timer = get_node_or_null("CraftTimer")

	items_left_to_craft = data.get("items_left", 0)
	is_paused = data.get("is_paused", false)
	
	var recipe_path = data.get("recipe_path", "")
	if recipe_path != "":
		current_recipe = load(recipe_path) as CraftingRecipe
		var saved_time_left = data.get("time_left", 0.0)
		
		# Check if loading from disk vs background chunk simulation
		if GameManager.is_loading_from_file:
			# GAME RESTART: Resume timer exactly where it was frozen
			if current_recipe != null and items_left_to_craft > 0 and not is_paused:
				if craft_timer:
					craft_timer.wait_time = current_recipe.crafting_time
					craft_timer.start(saved_time_left if saved_time_left > 0 else current_recipe.crafting_time)
		else:
			# CHUNK UNLOAD SIMULATION: Game is running, player was in another chunk
			if current_recipe != null and items_left_to_craft > 0 and not is_paused:
				var elapsed_seconds = (Time.get_unix_time_from_system() - data.get("timestamp", 0)) + (current_recipe.crafting_time - saved_time_left)
				var time_per_item = current_recipe.crafting_time
				var items_made = int(elapsed_seconds / time_per_item)
				var remaining_mod = fmod(elapsed_seconds, time_per_item)
				
				if items_made >= items_left_to_craft:
					for i in range(items_left_to_craft * current_recipe.output_amount):
						finished_items.append(current_recipe.output_item)
					items_left_to_craft = 0
					current_recipe = null
				else:
					for i in range(items_made * current_recipe.output_amount):
						finished_items.append(current_recipe.output_item)
					items_left_to_craft -= items_made
					if craft_timer:
						craft_timer.wait_time = time_per_item
						craft_timer.start(time_per_item - remaining_mod)
