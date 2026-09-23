extends StaticBody2D

# Grab the visual node (Change this to $Sprite2D if using an image)
@onready var visual = $ColorRect 

func _on_area_2d_body_entered(body):
	# Check if the object entering the area is the Player
	if body.name == "Player":
		# Create a smooth animation (tween) to change opacity (alpha) to 50% over 0.2 seconds
		var tween = create_tween()
		tween.tween_property(visual, "modulate:a", 0.5, 0.2)

func _on_area_2d_body_exited(body):
	if body.name == "Player":
		# Smoothly fade the opacity back to 100% (1.0) over 0.2 seconds
		var tween = create_tween()
		tween.tween_property(visual, "modulate:a", 1.0, 0.2)
