extends CanvasLayer

@onready var tab_container = $TabContainer

# Added "TabContainer/" to these two paths so it looks in the right folder!
@onready var settings_vbox = $TabContainer/Settings/VBoxContainer
@onready var fps_dropdown = $TabContainer/Settings/VBoxContainer/HBoxContainer/OptionButton

@onready var resume_btn = $TabContainer/Main/VBoxContainer/ResumeBtn
@onready var save_btn = $TabContainer/Main/VBoxContainer/SaveBtn
@onready var quit_btn = $TabContainer/Main/VBoxContainer/QuitBtn

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS 

	# 1. Connect the FPS Dropdown
	if fps_dropdown:
		fps_dropdown.item_selected.connect(_on_fps_selected)

	# 2. Automatically set up Sliders and SpinBoxes!
	for hbox in settings_vbox.get_children():
		var label = hbox.get_node_or_null("Label")
		var slider = hbox.get_node_or_null("HSlider")
		var spinbox = hbox.get_node_or_null("SpinBox")
		
		if label and slider and spinbox:
			var bus_name = label.text.replace(" Volume", "").strip_edges()
			
			# Setup a clean 0-100 scale for the UI
			slider.min_value = 0
			slider.max_value = 100
			spinbox.min_value = 0
			spinbox.max_value = 100
			
			# Load the current saved value (Convert engine's 0.0-1.0 to UI's 0-100)
			var saved_vol = GameManager.current_settings["volumes"].get(bus_name, 1.0) * 100.0
			slider.set_value_no_signal(saved_vol)
			spinbox.set_value_no_signal(saved_vol)
			
			# Connect BOTH inputs to the exact same master function
			slider.value_changed.connect(_on_volume_changed.bind(bus_name, slider, spinbox))
			spinbox.value_changed.connect(_on_volume_changed.bind(bus_name, slider, spinbox))

	# 3. Connect Main Menu Buttons
	resume_btn.pressed.connect(toggle_menu)
	save_btn.pressed.connect(func(): GameManager.save_game())
	quit_btn.pressed.connect(func(): 
		GameManager.save_settings() # Forces the settings to save!
		get_tree().quit()
	)

func _unhandled_input(event: InputEvent) -> void:
	# "ui_cancel" is bound to the ESC key by default
	if event.is_action_pressed("ui_cancel"):
		toggle_menu()
		get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	if visible:
		hide()
		get_tree().paused = false
		GameManager.save_settings() # Save settings to hard drive when closing the menu!
	else:
		show()
		tab_container.current_tab = 0 # Always open to the 'Main' tab
		if not is_multiplayer_active():
			get_tree().paused = true

func is_multiplayer_active() -> bool:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.get_peers().size() > 0:
			return true
	return false

# --- SETTINGS LOGIC ---

# --- SETTINGS LOGIC ---

func _on_fps_selected(index: int) -> void:
	GameManager.current_settings["fps_limit"] = index
	GameManager.apply_loaded_settings()

# This single function handles both the slider and the spinbox simultaneously
func _on_volume_changed(val: float, bus_name: String, slider: HSlider, spinbox: SpinBox) -> void:
	# 1. Sync the UI visuals without triggering an infinite loop
	slider.set_value_no_signal(val)
	spinbox.set_value_no_signal(val)
	
	# 2. Convert the UI's 0-100 scale back to the engine's 0.0-1.0 scale
	GameManager.current_settings["volumes"][bus_name] = val / 100.0
	GameManager.apply_loaded_settings()
