extends CharacterBody3D

@onready var UI: Control = $CanvasLayer/UI
#@onready var pistol: Node3D = %Pistol
@onready var weapon_manager: WeaponManager = $WeaponManager
@onready var interact_manager: Node3D = $InteractManager
@onready var sound_manager: Node3D = $SoundManager

@export var UI_node : Control
@export var physics_objects_node : Node3D

@export var look_sensitivity : float = 0.006
@export var jump_velocity := 6.0
@export var auto_bhop := true

@export var walk_speed := 7.0
@export var sprint_speed := 8.5
@export var ground_accel := 11.0
@export var ground_decel := 7.0
@export var ground_friction := 3.5

@export var air_cap := 0.85 # Can surf steeper ramps if this is higher, makes it easier to stick and bhop
@export var air_accel := 800.0
@export var air_move_speed := 500.0

const HEADBOB_MOVE_AMOUNT = 0.06
const HEADBOB_FREQUENCY = 2.4
var headbob_time := 0.0

@export var camera_holder : Node3D
@export var cam_speed : float = 5
@export var cam_rotation_amount : float = 1

@export var weapon_holder : Node3D
@export var weapon_sway_amount : float = 5
@export var weapon_rotation_amount : float = 1
@export var invert_weapon_sway : bool = false
var def_weapon_holder_pos : Vector3
var mouse_input : Vector2

const MAX_STEP_HEIGHT = 0.5 # Raycasts length should match this. StairsAhead one should be slightly longer.
var _snapped_to_stairs_last_frame := false
var _last_frame_was_on_floor = -INF

var wish_dir := Vector3.ZERO
var cam_aligned_wish_dir := Vector3.ZERO
var mouse_delta := Vector2.ZERO

const CROUCH_TRANSLATE = 0.7
const CROUCH_JUMP_ADD = CROUCH_TRANSLATE * 0.9 # * 0.9 for sourcelike camera jitter in air on crouch, makes for a nice notifier
var is_crouched := false

var noclip_speed_mult := 3.0
var noclip := false

func get_move_speed() -> float:
	if is_crouched:
		return walk_speed * 0.6
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed

func _push_away_rigid_bodies():
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var push_dir = -c.get_normal()
			# How much velocity the object needs to increase to match player velocity in the push direction
			var velocity_diff_in_push_dir = self.velocity.dot(push_dir) - c.get_collider().linear_velocity.dot(push_dir)
			# Only count velocity towards push dir, away from character
			velocity_diff_in_push_dir = max(0., velocity_diff_in_push_dir)
			# Objects with more mass than us should be harder to push. But doesn't really make sense to push faster than we are going
			const MY_APPROX_MASS_KG = 80.0
			var mass_ratio = min(1., MY_APPROX_MASS_KG / c.get_collider().mass)
			# Optional add: Don't push object at all if it's 4x heavier or more
			if mass_ratio < 0.25:
				continue
			# Don't push object from above/below
			push_dir.y = 0
			# 5.0 is a magic number, adjust to your needs
			var push_force = mass_ratio * 5.0
			c.get_collider().apply_impulse(push_dir * velocity_diff_in_push_dir * push_force, c.get_position() - c.get_collider().global_position)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("interact"):
		var interactable_object = interact_manager.attempt_interaction()
		if interactable_object != null:
			if interactable_object is EquipableWeapon:
				if interactable_object.weapon_resource != null:
					if weapon_manager.current_weapon_view_model and weapon_manager.current_weapon:
						weapon_manager.drop_current_weapon(weapon_manager.current_weapon_view_model,weapon_manager.current_weapon)
					weapon_manager.equip_weapon(interactable_object.weapon_resource)
					interactable_object.despawn()
	if Input.is_action_just_pressed("drop") and weapon_manager.current_weapon:
		weapon_manager.drop_current_weapon(weapon_manager.current_weapon_view_model,weapon_manager.current_weapon)
	if Input.is_action_just_pressed("reload") and weapon_manager.current_weapon:
		weapon_manager.attempt_reload()
	
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity)
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))
			
var has_stepped_this_cycle := false
func _headbob_effect(delta):
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0
	)
	if sin(headbob_time * HEADBOB_FREQUENCY) < -0.9:
		if not has_stepped_this_cycle:
			sound_manager.play_footstep()
			has_stepped_this_cycle = true
	else:
		has_stepped_this_cycle = false

var _saved_camera_global_pos = null
func _save_camera_pos_for_smoothing():
	if _saved_camera_global_pos == null:
		_saved_camera_global_pos = %CameraHolder.global_position

func _slide_camera_smooth_back_to_origin(delta):
	if _saved_camera_global_pos == null: return
	%CameraHolder.global_position.y = _saved_camera_global_pos.y
	%CameraHolder.position.y = clampf(%CameraHolder.position.y, -CROUCH_TRANSLATE, CROUCH_TRANSLATE) # Clamp incase teleported
	var move_amount = max(self.velocity.length() * delta, walk_speed/2 * delta)
	%CameraHolder.position.y = move_toward(%CameraHolder.position.y, 0.0, move_amount)
	_saved_camera_global_pos = %CameraHolder.global_position
	if %CameraHolder.position.y == 0:
		_saved_camera_global_pos = null # Stop smoothing camera

func _process(delta: float) -> void:
	update_recoil(delta)
	if weapon_manager.current_weapon:
		if weapon_manager.current_weapon.auto_fire:
			if Input.is_action_pressed("shoot") and weapon_manager.can_shoot:
				weapon_manager.attempt_shoot()
		else:
			if Input.is_action_just_pressed("shoot")  and weapon_manager.can_shoot:
				weapon_manager.attempt_shoot()

func _physics_process(delta: float) -> void:
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	
	var input_dir = Input.get_vector("left","right","up","down").normalized()
	wish_dir = self.global_transform.basis * Vector3(input_dir.x,0,input_dir.y)
	cam_aligned_wish_dir = %Camera3D.global_transform.basis * Vector3(input_dir.x,0,input_dir.y)
	
	_handle_crouch(delta)
	
	interact_manager.check_if_raycast_hit_interactable(delta)
	
	if not _handle_noclip(delta):
		if is_on_floor() or _snapped_to_stairs_last_frame:
			if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
				self.velocity.y = jump_velocity
			_handle_ground_physics(delta)
		else:
			_handle_air_physics(delta)
		UI.update_speed_label(self.velocity.length())
		
		if not _snap_up_stairs_check(delta):
			_push_away_rigid_bodies()
			move_and_slide()
			_snap_down_to_stairs_check()
	_slide_camera_smooth_back_to_origin(delta)
	
	cam_tilt(input_dir.x, delta)
	weapon_tilt(input_dir.x, delta)
	weapon_bob(velocity.length(),delta)

func cam_tilt(input_x, delta):
	if camera_holder:
		camera_holder.rotation.z = lerp(camera_holder.rotation.z, -input_x * cam_rotation_amount, 10 * delta)

func weapon_tilt(input_x, delta):
	if weapon_holder:
		weapon_holder.rotation.z = lerp(weapon_holder.rotation.z, -input_x * weapon_rotation_amount * 10, 10 * delta)

var step_triggered := false
func weapon_bob(vel : float, delta):
	if weapon_holder:
		if vel > 0 and is_on_floor():
			var bob_amount : float = 0.005
			var bob_freq : float = 0.01
			
			var time = Time.get_ticks_msec()
			var wave = sin(time * bob_freq)
			
			weapon_holder.position.y = lerp(
				weapon_holder.position.y,
				def_weapon_holder_pos.y + wave * bob_amount,
				10 * delta
			)
			
			weapon_holder.position.x = lerp(
				weapon_holder.position.x,
				def_weapon_holder_pos.x + sin(time * bob_freq * 0.5) * bob_amount,
				10 * delta
			)
		else:
			weapon_holder.position.y = lerp(weapon_holder.position.y, def_weapon_holder_pos.y, 10 * delta)
			weapon_holder.position.x = lerp(weapon_holder.position.x, def_weapon_holder_pos.x, 10 * delta)

var target_recoil := Vector2.ZERO
var current_recoil := Vector2.ZERO
const RECOIL_APPLY_SPEED : float = 10.0
const RECOIL_RECOVER_SPEED : float = 7.0

func add_recoil(pitch: float, yaw: float) -> void:
	target_recoil.x += pitch
	target_recoil.y += yaw

func get_current_recoil() -> Vector2:
	return current_recoil

func update_recoil(delta: float) -> void:
	# Slowly move target recoil back to 0,0
	target_recoil = target_recoil.lerp(Vector2.ZERO, RECOIL_RECOVER_SPEED * delta)
	
	# Slowly move current recoil to the target recoil
	var prev_recoil = current_recoil
	current_recoil = current_recoil.lerp(target_recoil, RECOIL_APPLY_SPEED * delta)
	var recoil_difference = current_recoil - prev_recoil
	
	# Rotate player/camera to current recoil
	rotate_y(recoil_difference.y)
	%Camera3D.rotate_x(recoil_difference.x)
	%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	# Modified slightly from tutorial. I don't notice any visual difference but I think this is correct.
	# Since it is called after move_and_slide, _last_frame_was_on_floor should still be current frame number.
	# After move_and_slide off top of stairs, on floor should then be false. Update raycast incase it's not already.
	%StairsBelowRayCast3D.force_raycast_update()
	var floor_below : bool = %StairsBelowRayCast3D.is_colliding() and not is_surface_too_steep(%StairsBelowRayCast3D.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() == _last_frame_was_on_floor
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result = KinematicCollision3D.new()
		if self.test_move(self.global_transform, Vector3(0,-MAX_STEP_HEIGHT,0), body_test_result):
			_save_camera_pos_for_smoothing()
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap

func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snapped_to_stairs_last_frame: return false
	# Don't snap stairs if trying to jump, also no need to check for stairs ahead if not moving
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
	var expected_move_motion = self.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	# Run a body_test_motion slightly above the pos we expect to move to, towards the floor.
	#  We give some clearance above to ensure there's ample room for the player.
	#  If it hits a step <= MAX_STEP_HEIGHT, we can teleport the player on top of the step
	#  along with their intended motion forward.
	var down_check_result = KinematicCollision3D.new()
	if (self.test_move(step_pos_with_clearance, Vector3(0,-MAX_STEP_HEIGHT*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		# Note I put the step_height <= 0.01 in just because I noticed it prevented some physics glitchiness
		# 0.02 was found with trial and error. Too much and sometimes get stuck on a stair. Too little and can jitter if running into a ceiling.
		# The normal character controller (both jolt & default) seems to be able to handled steps up of 0.1 anyway
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_position() - self.global_position).y > MAX_STEP_HEIGHT: return false
		%StairsAheadRayCast3D.global_position = down_check_result.get_position() + Vector3(0,MAX_STEP_HEIGHT,0) + expected_move_motion.normalized() * 0.1
		%StairsAheadRayCast3D.force_raycast_update()
		if %StairsAheadRayCast3D.is_colliding() and not is_surface_too_steep(%StairsAheadRayCast3D.get_collision_normal()):
			_save_camera_pos_for_smoothing()
			self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true
	return false

func _handle_ground_physics(delta: float) -> void:
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var add_speed_til_cap = get_move_speed() - cur_speed_in_wish_dir
	if add_speed_til_cap > 0:
		var accel_speed = ground_accel * get_move_speed() * delta
		accel_speed = min(accel_speed,add_speed_til_cap)
		self.velocity += accel_speed * wish_dir
	
	#apply friction
	var control = max(self.velocity.length(),ground_decel)
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed
	
	_headbob_effect(delta)

func _handle_noclip(delta: float) -> bool:
	if Input.is_action_just_pressed('noclip') and OS.has_feature("debug"):
		noclip = !noclip
		
	$CollisionShape3D.disabled = noclip
	if not noclip:
		return false
	var speed = get_move_speed() * noclip_speed_mult
	self.velocity = cam_aligned_wish_dir * speed
	global_position += self.velocity * delta
	return true

#This is to prevent velocity from moving into walls and allow surfing to work
func clip_velocity(normal: Vector3, overbounce: float, delta: float) -> void:
	var backoff := self.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	var change := normal * backoff
	self.velocity -= change
	#Not sure why bottom is neccarary but Gabe knows better than me
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust

@onready var _original_capsule_height = $CollisionShape3D.shape.height
func _handle_crouch(delta) -> void:
	var was_crouched_last_frame = is_crouched
	if Input.is_action_pressed("crouch"):
		is_crouched = true
	elif is_crouched and not self.test_move(self.global_transform, Vector3(0,CROUCH_TRANSLATE,0)):
		is_crouched = false
	
	# Allow for crouch to heighten/extend a jump
	var translate_y_if_possible := 0.0
	if was_crouched_last_frame != is_crouched and not is_on_floor():
		translate_y_if_possible = CROUCH_JUMP_ADD if is_crouched else -CROUCH_JUMP_ADD
	# Make sure not to get player stuck in floor/ceiling during crouch jumps
	if translate_y_if_possible != 0.0:
		var result = KinematicCollision3D.new()
		self.test_move(self.global_transform, Vector3(0,translate_y_if_possible,0), result)
		self.position.y += result.get_travel().y
		%Head.position.y -= result.get_travel().y
		%Head.position.y = clampf(%Head.position.y, -CROUCH_TRANSLATE, 0)
	
	%Head.position.y = move_toward(%Head.position.y, -CROUCH_TRANSLATE if is_crouched else 0.0, 7.0 * delta)
	$CollisionShape3D.shape.height = _original_capsule_height - CROUCH_TRANSLATE if is_crouched else _original_capsule_height
	$CollisionShape3D.position.y = $CollisionShape3D.shape.height / 2

func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func _run_body_test_motion(from: Transform3D, motion: Vector3, result=null) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(),params,result)

func _handle_air_physics(delta: float) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	var add_speed_til_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_til_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed,add_speed_til_cap)
		self.velocity += accel_speed * wish_dir
	
	if is_on_wall():
		clip_velocity(get_wall_normal(),1,delta) #for surfing
	

	
