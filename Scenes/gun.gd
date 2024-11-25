extends Node3D



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

const B = preload("res://Scenes/bullet.tscn")

func fire():
	var b = B.instantiate()
	b.global_transform = $start.global_transform
	GState.add(b)
