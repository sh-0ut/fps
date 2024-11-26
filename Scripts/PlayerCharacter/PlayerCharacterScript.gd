extends CharacterBody3D

#class name
class_name PlayerCharacter

#states variables
enum states
{
	IDLE, WALK, RUN, CROUCH, SLIDE, JUMP, INAIR, ONWALL, DASH , HOOKING
}
var currentState 

#move variables
@export_group("move variables")
var moveSpeed : float
var desiredMoveSpeed : float 
@export var maxSpeed : float 
@export var walkSpeed : float
@export var runSpeed : float
@export var crouchSpeed : float
var slideSpeed : float
@export var slideSpeedAddon : float 
@export var dashSpeed : float 
var moveAcceleration : float
@export var walkAcceleration : float
@export var runAcceleration : float 
@export var crouchAcceleration : float 
var moveDecceleration : float
@export var walkDecceleration : float
@export var runDecceleration : float 
@export var crouchDecceleration : float 
@export var inAirMoveSpeed : float 

#movement variables
@export_group("movement variables")
var inputDirection : Vector2 
var moveDirection : Vector3 
@export var hitGroundCooldown : float #amount of time the character keep his accumulated speed before losing it (while being on ground)
var hitGroundCooldownRef : float 
var lastFramePosition : Vector3 
var floorAngle #angle of the floor the character is on 
var slopeAngle #angle of the slope the character is on
var canInput : bool 
var collisionInfo

#jump variables
@export_group("jump variables")
@export var jumpHeight : float
@export var jumpTimeToPeak : float
@export var jumpTimeToFall : float
@onready var jumpVelocity : float = (2.0 * jumpHeight) / jumpTimeToPeak
@export var jumpCooldown : float
@export var jumpCooldownRef : float 
@export var nbJumpsInAirAllowed : int 
@export var nbJumpsInAirAllowedRef : int 

#slide variables
@export_group("slide variables")
@export var slideTime : float
@export var slideTimeRef : float 
var slideVector : Vector2 = Vector2.ZERO #slide direction
var startSlideInAir : bool
@export var timeBeforeCanSlideAgain : float
var timeBeforeCanSlideAgainRef : float 

#wall run variables
@export_group("wall run variables")
@export var wallJumpVelocity : float 
var canWallRun : bool

#dash variables
@export_group("dash variables")
@export var dashTime : float
var dashTimeRef : float
@export var timeBeforeCanDashAgain : float 
var timeBeforeCanDashAgainRef : float 
var velocityPreDash : Vector3 

#gravity variables
@export_group("gravity variables")
@onready var jumpGravity : float = (-2.0 * jumpHeight) / (jumpTimeToPeak * jumpTimeToPeak)
@onready var fallGravity : float = (-2.0 * jumpHeight) / (jumpTimeToFall * jumpTimeToFall)
@export var wallGravityMultiplier : float

#references variables
@onready var cameraHolder = $CameraHolder
@onready var standHitbox = $standingHitbox
@onready var crouchHitbox = $crouchingHitbox
@onready var ceilingCheck = $CeilingCheck
@onready var mesh = $MeshInstance3D
@onready var hud = $HUD
#@onready var raycast = $CameraHolder/Camera3D/RayCast3D
@onready var hook_visual = $HookVisual
@onready var camera = $CameraHolder/Camera3D

#hook variables
@export_group("hook variables")
@export var max_hook_distance : float = 20.0
@export var pull_speed: float = 10.0
@export var hook_speed: float = 30.0
@export var hook_position: Vector3
@export var hook_target: Vector3
@export var hook_active: bool = false
@export var is_pulling: bool = false
var is_already_shoot: bool = false
var hook_position_while_flying: Vector3


func _ready():
	GState.connect("hook_signal", hookHandle)
	GState.connect("hook_current_position", handlePosition)
	#raycast.collision_mask = 1
	GState.player = self
	hook_visual.visible = false
	$Rope.visible = false
	#set the start move speed
	moveSpeed = walkSpeed
	moveAcceleration = walkAcceleration
	moveDecceleration = walkDecceleration
	
	#set the values refenrencials for the needed variables
	desiredMoveSpeed = moveSpeed 
	jumpCooldownRef = jumpCooldown
	nbJumpsInAirAllowedRef = nbJumpsInAirAllowed
	hitGroundCooldownRef = hitGroundCooldown
	slideTimeRef = slideTime
	dashTimeRef = dashTime
	timeBeforeCanSlideAgainRef = timeBeforeCanSlideAgain
	timeBeforeCanDashAgainRef = timeBeforeCanDashAgain
	canWallRun = false 
	canInput = true
	
	#disable the crouch hitbox, enable is standing one
	if !crouchHitbox.disabled: crouchHitbox.disabled = true 
	if standHitbox.disabled: standHitbox.disabled = false
	
	#set the mesh scale of the character
	mesh.scale = Vector3(1.0, 1.0, 1.0)
	
func _process(_delta):
	#the behaviours that is preferable to check every "visual" frame
	
	inputManagement()
	
	displayStats()
	
func _physics_process(delta):
	#raycast.enabled = true
	#the behaviours that is preferable to check every "physics" frame
	applies(delta)
	move(delta)
	collisionHandling()
	move_and_slide()
	hooking_mech(delta)
	#print('1', camera.get_camera_transform())
	#print('2', raycast.transform)
	#raycast.transform

func handlePosition(e: Transform3D):
	$Rope.visible = true
	hook_position_while_flying = e.origin
	#adjust_object_between_points($Rope, global_transform.origin, hook_position_while_flying)
	adjust_object_between_points($Rope, $CameraHolder/Camera3D/Gun.global_transform.origin, hook_position_while_flying)

func adjust_object_between_points(obj: Node3D, point_a: Vector3, point_b: Vector3):
	# Розрахунок середньої точки між двома точками
	var mid_point = (point_a + point_b) * 0.5
	obj.global_transform.origin = mid_point

	# Розрахунок напрямку та відстані між точками
	var direction = (point_b - point_a).normalized()
	var distance = point_a.distance_to(point_b)

	# Орієнтація об'єкта вздовж напрямку
	var up_vector = Vector3.UP  # Вектор "вгору"
	var basis = Basis()
	basis.z = direction
	basis.x = up_vector.cross(direction).normalized()  # Обчислюємо вісь X через векторний добуток
	basis.y = basis.z.cross(basis.x).normalized()  # Обчислюємо вісь Y через векторний добуток
	obj.global_transform.basis = basis
	
	# Зміна масштабу об'єкта відповідно до відстані
	obj.scale = Vector3(obj.scale.x / 10, obj.scale.y / 10, distance)  # Приклад: масштаб по X залежить від відстані

func hooking_mech(delta):
	if hook_active:
		is_pulling = true
		hook_active = false
		$Rope.visible = true
	elif is_pulling:
		adjust_object_between_points($Rope, global_transform.origin, hook_target)
		hook_visual.global_transform.origin = hook_target
		hook_visual.visible = true
		# Притягування персонажа
		var direction_to_target = (hook_target - global_transform.origin).normalized()
		direction_to_target.y += hook_target.y / global_transform.origin.y
		global_transform.origin += direction_to_target * pull_speed * delta
		# Перевірка завершення притягування
		if global_transform.origin.distance_to(hook_target) < 1.0:
			is_pulling = false
			is_already_shoot = false
			hook_visual.visible = false
			$Rope.visible = false


func hookHandle(e : Transform3D):
	if not hook_active and not is_pulling:
		hook_active = true
		hook_target = e.origin
		$Rope.visible = true
	else:
		hook_active = false
		is_pulling = false
		hook_visual.visible = false
		$Rope.visible = false
	print('transform from e', e.origin)
	#hook()


func inputManagement():
	#for each state, check the possibles actions available
	#This allow to have a good control of the controller behaviour, because you can easely check the actions possibls, 
	#add or remove some, and it prevent certain actions from being played when they shouldn't be
	
	if Input.is_action_just_pressed("shoot_hook"):
		if not is_already_shoot:
			$CameraHolder/Camera3D/Gun.fireHook()
			is_already_shoot = true
		else:
			hook_active = false
			is_pulling = false
			is_already_shoot = false
			hook_visual.visible = false
			$Rope.visible = false
			if is_instance_valid(GState.hook):
				GState.hook.queue_free()

	if Input.is_action_just_pressed('gun_shoot'):
		$Rope.scale = Vector3(3,1,1)
		$CameraHolder/Camera3D/Gun.fire()
	
	if Input.is_action_pressed("reloadScene"):
		#get_tree().reload_current_scene()
		position.x = 0;
		position.y = 0;
	if canInput:
		match currentState:
			states.IDLE:
				if Input.is_action_just_pressed("jump"):
					jump(0.0, false)
				
				if Input.is_action_just_pressed("crouch | slide"):
					crouchStateChanges()
				
			states.WALK:
				if Input.is_action_just_pressed("run"):
					runStateChanges()
				
				if Input.is_action_just_pressed("jump"):
					jump(0.0, false)
				
				if Input.is_action_just_pressed("crouch | slide"):
					crouchStateChanges()
				
				if Input.is_action_just_pressed("dash"):
					dashStateChanges()
				
			states.RUN:
				if Input.is_action_just_pressed("run"):
					walkStateChanges()
				
				if Input.is_action_just_pressed("jump"):
					jump(0.0, false)
				
				if Input.is_action_just_pressed("crouch | slide"):
					slideStateChanges()
				
				if Input.is_action_just_pressed("dash"):
					dashStateChanges()
				
			states.CROUCH: 
				if Input.is_action_just_pressed("run") and !ceilingCheck.is_colliding():
					walkStateChanges()
				
				if Input.is_action_just_pressed("crouch | slide") and !ceilingCheck.is_colliding(): 
					walkStateChanges()
				
			states.SLIDE: 
				if Input.is_action_just_pressed("run"):
					runStateChanges()
				
				if Input.is_action_just_pressed("jump"):
					jump(0.0, false)
				
				if Input.is_action_just_pressed("crouch | slide"):
					runStateChanges()
				
			states.JUMP:
				if Input.is_action_just_pressed("crouch | slide"):
					slideStateChanges()
					
				if Input.is_action_just_pressed("dash"):
					dashStateChanges()
					
				if Input.is_action_just_pressed("jump"):
					jump(0.0, false)
				
			states.INAIR: 
				if Input.is_action_just_pressed("crouch | slide"):
					slideStateChanges()
					
				if Input.is_action_just_pressed("dash"):
					dashStateChanges()
					
				if Input.is_action_just_pressed("jump"):
					jump(0.0, false)
				
			states.ONWALL:
				if Input.is_action_just_pressed("jump"):
					jump(0.0, false)
					
			states.DASH:
				pass

func displayStats():
	#call the functions in charge of displaying the controller properties
	hud.displayCurrentState(currentState)
	hud.displayMoveSpeed(moveSpeed)
	hud.displayDesiredMoveSpeed(desiredMoveSpeed)
	hud.displayVelocity(velocity.length())
	hud.displayNbJumpsAllowedInAir(nbJumpsInAirAllowed)
	
	#not a property, but a visual
	if currentState == states.DASH: hud.displaySpeedLines(dashTime)
	
func applies(delta):
	#general appliements
	
	floorAngle = get_floor_normal() #get the angle of the floor
	
	if !is_on_floor():
		#modify the type of gravity to apply to the character, depending of his velocity (when jumping jump gravity, otherwise fall gravity)
		if velocity.y >= 0.0:
				velocity.y += jumpGravity * delta
				if currentState != states.SLIDE and currentState != states.DASH: currentState = states.JUMP
		else: 
			velocity.y += fallGravity * delta
			if currentState != states.SLIDE and currentState != states.DASH: currentState = states.INAIR 
			
		if currentState == states.SLIDE:
			if !startSlideInAir: 
				slideTime = -1 #if the character start slide on the grund, and the jump, the slide is canceled
				
		if currentState == states.DASH: velocity.y = 0.0 #set the y axis velocity to 0, to allow the character to not be affected by gravity while dashing
		
		if hitGroundCooldown != hitGroundCooldownRef: hitGroundCooldown = hitGroundCooldownRef #reset the before bunny hopping value
		
	if is_on_floor():
		slopeAngle = rad_to_deg(acos(floorAngle.dot(Vector3.UP))) #get the angle of the slope 
		
		if hitGroundCooldown >= 0: hitGroundCooldown -= delta #disincremente the value each frame, when it's <= 0, the player lose the speed he accumulated while being in the air 
		
		if nbJumpsInAirAllowed != nbJumpsInAirAllowedRef: nbJumpsInAirAllowed = nbJumpsInAirAllowedRef #set the number of jumps possible
		
		#set the move state depending on the move speed, only when the character is moving
		if inputDirection != Vector2.ZERO and moveDirection != Vector3.ZERO:
			match moveSpeed:
				crouchSpeed: currentState = states.CROUCH 
				walkSpeed: currentState = states.WALK
				runSpeed: currentState = states.RUN 
				slideSpeed: currentState = states.SLIDE 
				dashSpeed: currentState= states.DASH 
				
		else:
			#set the state to idle
			if currentState == states.JUMP or currentState == states.INAIR or currentState == states.WALK or currentState == states.RUN: 
				if velocity.length() < 1.0: currentState = states.IDLE 
				
	if is_on_wall(): #if the character is on a wall
		#set the state on onwall
		wallrunStateChanges()
		
	if is_on_floor() or !is_on_floor():
		#manage the slide behaviour
		if currentState == states.SLIDE:
			if !startSlideInAir and lastFramePosition.y < position.y: slideTime = -1 #if character slide on an uphill, cancel slide
			if slopeAngle < 16:
				if slideTime > 0: 
					slideTime -= delta
			if slideTime <= 0: 
				timeBeforeCanSlideAgain = timeBeforeCanSlideAgainRef
				#go to crouch state if the ceiling is too low, otherwise go to run state 
				if ceilingCheck.is_colliding(): crouchStateChanges()
				else: runStateChanges()
			
		#manage the dash behaviour
		if currentState == states.DASH:
			if canInput: canInput = false #the character cannot change direction while dashing 
			
			if dashTime > 0: dashTime -= delta
			
			#the character cannot dash anymore, change to corresponding variables, and go back to run state
			if dashTime <= 0: 
				velocity = velocityPreDash #go back to pre dash velocity
				canInput = true 
				timeBeforeCanDashAgain = timeBeforeCanDashAgainRef
				runStateChanges()
				
		if timeBeforeCanSlideAgain > 0: timeBeforeCanSlideAgain -= delta 
		
		if timeBeforeCanDashAgain > 0: timeBeforeCanDashAgain -= delta
		
		if currentState == states.JUMP: floor_snap_length = 0.0 #the character cannot stick to structures while jumping
			
		if currentState == states.INAIR: floor_snap_length = 2.5 #but he can if he stopped jumping, but he's still in the air
			
		if jumpCooldown > 0: jumpCooldown -= delta
		



func move(delta):
	#direction input
	inputDirection = Input.get_vector("moveLeft", "moveRight", "moveForward", "moveBackward")
	
	#get direction input when sliding
	if currentState == states.SLIDE:
		if moveDirection == Vector3.ZERO: #if the character is moving
			moveDirection = (cameraHolder.basis * Vector3(slideVector.x, 0.0, slideVector.y)).normalized() #get move direction at the start of the slide, and stick to it
	
	#get direction input when wall running
	elif currentState == states.ONWALL:
		moveDirection = velocity.normalized() #get character current velocity and apply it as the current move direction, and stick to it
		
	#dash
	elif currentState == states.DASH:
		if moveDirection == Vector3.ZERO: #if the character is moving
			moveDirection = (cameraHolder.basis * Vector3(inputDirection.x, 0.0, inputDirection.y)).normalized() #get move direction at the start of the dash, and stick to it
		
	#all others 
	else:
		#get the move direction depending on the input
		moveDirection = (cameraHolder.basis * Vector3(inputDirection.x, 0.0, inputDirection.y)).normalized()
		
	#move applies when the character is on the floor
	if is_on_floor():
		#if the character is moving
		if moveDirection:
			#apply slide move
			if currentState == states.SLIDE:
				if slopeAngle > 40: desiredMoveSpeed += 3.0 * delta #increase more significantly desired move speed if the slope is steep enough
				else: desiredMoveSpeed += 2.0 * delta
				
				velocity.x = moveDirection.x * desiredMoveSpeed
				velocity.z = moveDirection.z * desiredMoveSpeed
				
			#apply dash move
			elif currentState == states.DASH:
				velocity.x = moveDirection.x * dashSpeed
				velocity.z = moveDirection.z * dashSpeed 
			
			#apply smooth move when walking, crouching, running
			else:
				velocity.x = lerp(velocity.x, moveDirection.x * moveSpeed, moveAcceleration * delta)
				velocity.z = lerp(velocity.z, moveDirection.z * moveSpeed, moveAcceleration * delta)
				
				#cancel desired move speed accumulation if the timer is out
				if hitGroundCooldown <= 0:
					#here, there's some nasty code : to keep it simple, i struggle to get a way to have a good speed accumulation behaviour
					#and so i decided to add some resistance related to the current state the character is, to get a smoother momuntem
					#but it's clearly not ideal, i and advice you to modify the values depending on the speed your character will move
					if currentState == states.WALK : desiredMoveSpeed = velocity.length()-walkSpeed
					else: desiredMoveSpeed = velocity.length()-(runSpeed / 2.5)
					
		#if the character is not moving
		else:
			#apply smooth stop 
			velocity.x = lerp(velocity.x, 0.0, moveDecceleration * delta)
			velocity.z = lerp(velocity.z, 0.0, moveDecceleration * delta)
			
			#cancel desired move speed accumulation
			
			if currentState == states.WALK : desiredMoveSpeed = velocity.length()-walkSpeed
			else: desiredMoveSpeed = velocity.length()-(runSpeed / 2.5)
			
	#move applies when the character is not on the floor (so if he's in the air)
	if !is_on_floor():
		if moveDirection:
			#apply dash move
			if currentState == states.DASH: 
				velocity.x = moveDirection.x * dashSpeed
				velocity.z = moveDirection.z * dashSpeed 
				
			#apply slide move
			elif currentState == states.SLIDE:
				desiredMoveSpeed += 2.5 * delta
				
				velocity.x = moveDirection.x * desiredMoveSpeed
				velocity.z = moveDirection.z * desiredMoveSpeed
				
			#apply smooth move when in the air (air control)
			else:
				if desiredMoveSpeed < maxSpeed: desiredMoveSpeed += 1.5 * delta
				
				velocity.x = lerp(velocity.x, moveDirection.x * desiredMoveSpeed, inAirMoveSpeed * delta)
				velocity.z = lerp(velocity.z, moveDirection.z * desiredMoveSpeed, inAirMoveSpeed * delta)
				
		else:
			#accumulate desired speed for bunny hopping
			if currentState == states.WALK : desiredMoveSpeed = velocity.length()-walkSpeed
			else: desiredMoveSpeed = velocity.length()-(runSpeed / 2.5)
			
	#move applies when the character is on the wall
	if is_on_wall():
		#apply on wall move
		if currentState == states.ONWALL:
			if moveDirection:
				desiredMoveSpeed += 1.0 * delta 
				
				velocity.x = moveDirection.x * desiredMoveSpeed
				velocity.z = moveDirection.z * desiredMoveSpeed
				
	if desiredMoveSpeed >= maxSpeed: desiredMoveSpeed = maxSpeed #set to ensure the character don't exceed the max speed authorized
				
	lastFramePosition = position
			
func jump(jumpBoostValue : float, isJumpBoost : bool): 
	#this function manage the jump behaviour, depending of the different variables and states the character is
	
	var canJump : bool = false #jump condition
	
	#on wall jump 
	if is_on_wall() and canWallRun: 
		currentState = states.JUMP
		velocity = get_wall_normal() * wallJumpVelocity #add some knockback in the opposite direction of the wall
		velocity.y = jumpVelocity
		jumpCooldown = jumpCooldownRef
	else:
		#in air jump
		if !is_on_floor():
			if jumpCooldown <= 0:
				#if the character jump from a jumppad, the jump isn't taken into account in the max numbers of jumps allowed, allowing the character to continusly jump as long as it lands on a jumppad
				if (nbJumpsInAirAllowed > 0) or (nbJumpsInAirAllowed <= 0 and isJumpBoost):
					if !isJumpBoost: nbJumpsInAirAllowed -= 1
					jumpCooldown = jumpCooldownRef
					canJump = true 
		#on floor jump
		else:
			jumpCooldown = jumpCooldownRef
			canJump = true 
			
	#apply jump
	if canJump:
		if isJumpBoost: nbJumpsInAirAllowed = nbJumpsInAirAllowedRef
		currentState = states.JUMP
		velocity.y = jumpVelocity + jumpBoostValue #apply directly jump velocity to y axis velocity, to give the character instant vertical forcez
		canJump = false 
		
#theses functions manages the differents changes and appliments the character will go trought when changing his current state
func crouchStateChanges():
	currentState = states.CROUCH
	moveSpeed = crouchSpeed
	moveAcceleration = crouchAcceleration 
	moveDecceleration = crouchDecceleration
	
	standHitbox.disabled = true
	crouchHitbox.disabled = false 
	
	if mesh.scale.y != 0.7:
		mesh.scale.y = 0.7
		mesh.position.y = -0.5
		
func walkStateChanges():
	currentState = states.WALK
	moveSpeed = walkSpeed
	moveAcceleration = walkAcceleration
	moveDecceleration = walkDecceleration
	
	standHitbox.disabled = false 
	crouchHitbox.disabled = true
	
	if mesh.scale.y != 1.0:
		mesh.scale.y = 1.0
		mesh.position.y = 0.0
	
func runStateChanges():
	currentState = states.RUN
	moveSpeed = runSpeed
	moveAcceleration = runAcceleration
	moveDecceleration = runDecceleration
	
	standHitbox.disabled = false 
	crouchHitbox.disabled = true 
	
	if mesh.scale.y != 1.0:
		mesh.scale.y = 1.0
		mesh.position.y = 0.0
	
func slideStateChanges():
	#condition here, the state is changed only if the character is moving (so has an input direction)
	if inputDirection != Vector2.ZERO and timeBeforeCanSlideAgain <= 0 and lastFramePosition.y >= position.y: #character can slide only on flat or downhill surfaces
		currentState = states.SLIDE 
		
		#change the start slide in air variable depending zon where the slide begun
		if !is_on_floor() and slideTime <= 0: startSlideInAir = true
		elif is_on_floor(): 
			desiredMoveSpeed += slideSpeedAddon #slide speed boost when on ground (for balance purpose)
			startSlideInAir = false 
			
		slideTime = slideTimeRef
		moveSpeed = slideSpeed
		slideVector = inputDirection
		
		standHitbox.disabled = true
		crouchHitbox.disabled = false 
		
		if mesh.scale.y != 0.7:
			mesh.scale.y = 0.7
			mesh.position.y = -0.5
			
func dashStateChanges():
	#condition here, the state is changed only if the character is moving (so has an input direction)
	if inputDirection != Vector2.ZERO and timeBeforeCanDashAgain <= 0:
		currentState = states.DASH
		moveSpeed = dashSpeed 
		dashTime = dashTimeRef
		velocityPreDash = velocity #save the pre dash velocity, to apply it when the dash is finished (to get back to a normal velocity)
		
		if mesh.scale.y != 1.0:
			mesh.scale.y = 1.0
			mesh.position.y = 0.0
			
func wallrunStateChanges():
	#condition here, the state is changed only if the character speed is greater than the walk speed
	if velocity.length() > walkSpeed and currentState != states.DASH and currentState != states.CROUCH and canWallRun: 
		currentState = states.ONWALL
		velocity.y *= wallGravityMultiplier #gravity value became onwall one
		
		if nbJumpsInAirAllowed != nbJumpsInAirAllowedRef: nbJumpsInAirAllowed = nbJumpsInAirAllowedRef
		
		standHitbox.disabled = false
		crouchHitbox.disabled = true
		
		if mesh.scale.y != 1.0:
			mesh.scale.y = 1.0
			mesh.position.y = 0.0
			
func collisionHandling():
	#this function handle the collisions, but in this case, only the collision with a wall, to detect if the character can wallrun
	if is_on_wall():
		var lastCollision = get_slide_collision(0)
		
		if lastCollision:
			var collidedBody = lastCollision.get_collider()
			var layer = collidedBody.collision_layer
			
			#here, we check the layer of the collider, then we check if the layer 3 (walkableWall) is enabled, with 1 << 3-1. If theses two points are valid, the character can wallrun
			if layer & (1 << 3-1) != 0: canWallRun = true 
			else: canWallRun = false 
