extends Resource
class_name RecipeIngredient

# You will drag your ItemData (like apple.tres or iron_bar.tres) into this slot
@export var item: ItemData
@export var amount: int = 1
