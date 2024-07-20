extends CharacterBody3D

signal health_changed(health_value)

var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.002

#bob variables
const  BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

#fov variables
const BASE_FOV = 75
const FOV_CHANGE = 1.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

var health = 100

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var anim_player = $AnimationPlayer
@onready var hitbox = $Head/Camera3D/WeaponPivot/WeaponMesh/Hitbox

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority():
		# Deactivate the camera for non-local players
		camera.current = false
	
	if not is_multiplayer_authority(): return
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else :
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)
	
	#head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	#fov
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8)
	
	move_and_slide()
	

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _process(delta):
	if not is_multiplayer_authority(): return
	
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	
	if Input.is_action_just_pressed("attack") and anim_player.current_animation == "idle":
		anim_player.stop()
		anim_player.play("attack")
		hitbox.monitoring = true
	
	if Input.is_action_just_pressed("secondary") and anim_player.current_animation == "idle":
		anim_player.stop()
		anim_player.play("secondary")
		hitbox.monitoring = true

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "attack":
		anim_player.play("idle")
		hitbox.monitoring = false
	else: if anim_name == "secondary":
		anim_player.play("idle")
		hitbox.monitoring = false

func _on_hitbox_area_entered(area):
	if area.is_in_group("player"):
		var player_hit = area.get_parent()
		var attacker = self
		if player_hit != attacker:
			player_hit.receive_damage.rpc_id(player_hit.get_multiplayer_authority())

@rpc("any_peer")
func receive_damage():
	health -= 20
	if health <= 0:
		health = 100
		position = Vector3.ZERO
	health_changed.emit(health)
