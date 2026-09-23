extends Node

const SETTINGS_FILE = "user://settings.save"
const SAVE_FILE = "user://savegame.save"
var is_loading_from_file: bool = false

var current_settings = {
	"fps_limit": 1,
	"vsync": true,
	"ui_scale": 1.0,
	"volumes": {
		"Master": 1.0, "Music": 1.0, "SFX": 1.0, 
		"Ambient": 1.0, "UI": 1.0, "Voice": 1.0
	},
	"keybinds": {}
}

var game_data = {
	"player_position_x": 0.0,
	"player_position_y": 0.0,
	"world_objects": []
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	load_game()

# Automatically save when closing the game window
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		save_settings()
		get_tree().quit()

# --- SETTINGS MANAGEMENT ---

func save_settings():
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	file.store_line(JSON.stringify(current_settings))

func load_settings():
	if not FileAccess.file_exists(SETTINGS_FILE):
		save_settings()
		return
		
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed:
		current_settings = parsed
		apply_loaded_settings()

func apply_loaded_settings():
	var limits = [30, 60, 120, 144, 240, 0]
	Engine.max_fps = limits[current_settings["fps_limit"]]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if current_settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	get_tree().root.content_scale_factor = current_settings["ui_scale"]
	
	for bus_name in current_settings["volumes"].keys():
		var val = current_settings["volumes"][bus_name]
		var bus_index = AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_mute(bus_index, val == 0.0)
		if val > 0.0:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(val))

# --- GAME WORLD SAVE/LOAD ---
func restore_player_position(player_node: Node2D):
	if game_data.has("player_pos_x") and game_data.has("player_pos_y"):
		player_node.global_position = Vector2(game_data["player_pos_x"], game_data["player_pos_y"])

# Helper to reliably locate the player anywhere in the active world
func get_player_node() -> Node2D:
	var player = get_tree().get_first_node_in_group("player")
	if not player and get_tree().current_scene:
		player = get_tree().current_scene.find_child("Player", true, false)
	return player as Node2D

func save_game():
	# 1. Save Player Position
	var player = get_player_node()
	if player:
		game_data["player_pos_x"] = player.global_position.x
		game_data["player_pos_y"] = player.global_position.y
		print("Saved player at: ", player.global_position)

	# 2. Save Inventory
	if InventoryManager and InventoryManager.has_method("get_save_data"):
		game_data["inventory"] = InventoryManager.get_save_data()

	# 3. Save World Objects
	var world_data: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("persist"):
		if node.is_in_group("player"):
			continue
			
		var entity_entry = {
			"node_path": str(node.get_path()),
			"scene_path": node.scene_file_path,
			"pos_x": node.global_position.x,
			"pos_y": node.global_position.y,
			"custom_data": {}
		}
		if node.has_method("get_custom_save_data"):
			entity_entry["custom_data"] = node.get_custom_save_data()
			
		world_data.append(entity_entry)
		
	game_data["world_objects"] = world_data

	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	file.store_line(JSON.stringify(game_data))
	print("Game, Player, Inventory, and World saved successfully!")

func load_game():
	if not FileAccess.file_exists(SAVE_FILE):
		print("No save file found. Starting fresh world.")
		return
		
	is_loading_from_file = true
	
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed:
		game_data = parsed
		
		# 1. Restore Inventory
		if game_data.has("inventory") and InventoryManager and InventoryManager.has_method("load_save_data"):
			InventoryManager.load_save_data(game_data["inventory"])

		# 2. Wait one frame so MasterWorld & Player are completely initialized
		await get_tree().process_frame

		# 3. Restore Player Position (Supports both key variants)
		var player = get_player_node()
		if player:
			var px = game_data.get("player_pos_x", game_data.get("player_position_x", null))
			var py = game_data.get("player_pos_y", game_data.get("player_position_y", null))
			if px != null and py != null:
				player.global_position = Vector2(px, py)
				print("Player restored to: ", player.global_position)

		# 4. Restore World Objects
		if game_data.has("world_objects"):
			var saved_objects = game_data["world_objects"]
			for obj in saved_objects:
				if not obj is Dictionary:
					continue
					
				var node: Node = null
				var node_path_str: String = obj.get("node_path", "")
				var scene_path_str: String = obj.get("scene_path", "")
				
				if node_path_str != "" and has_node(node_path_str):
					node = get_node(node_path_str)
				elif scene_path_str != "":
					var scene = load(scene_path_str)
					if scene:
						node = scene.instantiate()
						var target_parent = get_tree().current_scene.get_node_or_null("Entities")
						if not target_parent:
							target_parent = get_tree().current_scene
						target_parent.add_child(node)
						
				if node:
					node.global_position = Vector2(obj.get("pos_x", 0.0), obj.get("pos_y", 0.0))
					if node.has_method("load_custom_save_data"):
						node.load_custom_save_data(obj.get("custom_data", {}))
						
		print("All world objects restored successfully!")
		
	is_loading_from_file = false
