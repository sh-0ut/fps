extends CharacterBody3D


const SPEED = 75
const JUMP_VELOCITY = 4.5
var timer = 0
var dir
var is_hit: bool = false




func _ready() -> void:
	GState.hook = self
	dir = global_transform.basis.z.normalized() 


func _physics_process(delta: float) -> void:
	timer += delta
	
	if timer > 2:
		queue_free()
		return
	GState.emit_signal("hook_current_position", global_transform)

	var o = move_and_collide(dir * SPEED * delta)
	if o:
		#is_hit = true
		GState.emit_signal('hook_signal', global_transform)
		#print('hit', o.get_collider().name)
		#print('Position ', global_transform)
		queue_free()
	
