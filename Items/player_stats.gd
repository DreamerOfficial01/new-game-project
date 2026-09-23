extends Node

# Define ALL your stats here in one central place!
var stats: Dictionary = {
	"health": { "current": 100.0, "max": 100.0, "regen": 1.0 },
	"hunger": { "current": 100.0, "max": 100.0, "drain": 2.0 }
}

signal stats_changed

var hunger_timer: float = 0.0
var starvation_timer: float = 0.0

func _process(delta):
	# Hunger drain loop reads directly from the central dictionary
	hunger_timer += delta
	if hunger_timer >= 5.0:
		hunger_timer = 0.0
		if stats["hunger"]["current"] > 0:
			modify_stat("hunger", -stats["hunger"]["drain"])
			
	# Starvation check
	if stats["hunger"]["current"] <= 0:
		starvation_timer += delta
		if starvation_timer >= 2.0:
			starvation_timer = 0.0
			modify_stat("health", -5.0) # Take 5 damage
	else:
		starvation_timer = 0.0

# Universal function to modify ANY stat by its name!
func modify_stat(stat_name: String, amount: float):
	if stats.has(stat_name):
		var s = stats[stat_name]
		s["current"] = clamp(s["current"] + amount, 0.0, s["max"])
		stats_changed.emit()
