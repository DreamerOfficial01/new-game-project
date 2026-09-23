extends Marker2D

@export var vertical_lift_speed: float = 15.0 # Slowed down so they don't fly off too fast
@export var lift_duration: float = 3.0
@export var fade_duration: float = 1.0

var time_alive: float = 0.0
@onready var label: Label = $Label

func _ready():
	# Put this notification into a group so the Player can talk to it
	add_to_group("loot_notifications")

func setup_item_pickup(item_name: String, quantity: int, bg_color: Color):
	label.text = "+%d %s" % [quantity, item_name]
	
	# 1. Remove the old shadow
	if label.label_settings:
		label.label_settings = label.label_settings.duplicate()
		label.label_settings.shadow_size = 0
		
	# 2. Create the smooth, rounded background
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.bg_color.a = 0.6 # Make it slightly see-through (0.0 to 1.0)
	
	# Round the corners
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	
	# Add padding so the text doesn't touch the edges of the box
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	
	# Apply the background to the Label
	label.add_theme_stylebox_override("normal", style)
	
	# Pop-in animation
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Called by the Player right before a new notification spawns
func shift_up():
	var tween = create_tween()
	# The .as_relative() means it will smoothly move 20px higher than wherever it currently is!
	tween.tween_property(self, "position:y", -30.0, 0.15).as_relative().set_trans(Tween.TRANS_SINE)

func _process(delta: float):
	time_alive += delta
	
	# Slowly drift up on its own
	position.y -= vertical_lift_speed * delta
	
	# Fading logic
	if time_alive >= (lift_duration - fade_duration):
		var time_remaining = lift_duration - time_alive
		var current_fade_alpha = time_remaining / fade_duration
		modulate.a = max(current_fade_alpha, 0.0)
	
	if time_alive >= lift_duration:
		queue_free()
