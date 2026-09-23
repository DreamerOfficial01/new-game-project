extends Camera2D

# The constraints for how far in or out you can zoom
const MIN_ZOOM = 0.5
const MAX_ZOOM = 0.75


# How much one scroll of the wheel changes the zoom (higher = fewer scrolls to max zoom)
const ZOOM_INCREMENT = 0.25 

# How fast the camera glides to the new zoom level (higher = faster, snappier lerp)
const ZOOM_RATE = 15.0 

var target_zoom: Vector2

func _ready():
	# Set the starting zoom to whatever is currently set in the Inspector
	target_zoom = zoom
	
	# Ensure the starting zoom respects our min/max limits
	target_zoom.x = clamp(target_zoom.x, MIN_ZOOM, MAX_ZOOM)
	target_zoom.y = clamp(target_zoom.y, MIN_ZOOM, MAX_ZOOM)
	zoom = target_zoom

func _unhandled_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		
		# --- MOUSE WHEEL UP ---
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if Input.is_key_pressed(KEY_CTRL):
				# Ctrl + Scroll Up = Zoom In
				target_zoom += Vector2(ZOOM_INCREMENT, ZOOM_INCREMENT)
			else:
				# Just Scroll Up = Move Hotbar Selection Left
				InventoryManager.cycle_hotbar(-1)
				
		# --- MOUSE WHEEL DOWN ---
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_CTRL):
				# Ctrl + Scroll Down = Zoom Out
				target_zoom -= Vector2(ZOOM_INCREMENT, ZOOM_INCREMENT)
			else:
				# Just Scroll Down = Move Hotbar Selection Right
				InventoryManager.cycle_hotbar(1)
				
		# Clamp limits the target zoom so it never goes below MIN_ZOOM or above MAX_ZOOM
		target_zoom.x = clamp(target_zoom.x, MIN_ZOOM, MAX_ZOOM)
		target_zoom.y = clamp(target_zoom.y, MIN_ZOOM, MAX_ZOOM)

func _process(delta):
	# Smoothly transition the actual zoom to match our target_zoom
	zoom = zoom.lerp(target_zoom, ZOOM_RATE * delta)
