extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var dir
var timer = 0

func _ready() -> void:
	dir = global_transform.basis.z.normalized() 

func _physics_process(delta: float) -> void:
	timer += delta
	
	if timer > 1:
		queue_free()
		return
	
	var o = move_and_collide(dir * SPEED)
	if o:
		print('bulet ', o.get_collider().name)
		queue_free()
	
