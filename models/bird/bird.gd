extends Node3D

@export var bot: bool
@export var pathBots: Path3D

@export var pivot_root: Node3D
@export var pivot_feet: Node3D
@export var pivot_com: Node3D

@export var rayC: RayCast3D
@export var rayC_front: RayCast3D
@export var rayC_back: RayCast3D
@export var rayC_right: RayCast3D
@export var rayC_left: RayCast3D

@export var bird: Node3D
@export var springArm: Node3D
@export var camera: Camera3D
@export var birdAnimPlayer:AnimationPlayer
@export var birdAnimTree: AnimationTree

@export var snowsplash_l: MeshInstance3D
@export var snowsplash_r: MeshInstance3D

@export var audiostream_ground: AudioStreamPlayer3D

var arr_linVel = []
var arr_rotVel = []
var linVel: Vector3 = Vector3.ZERO
var rotVel

var sdt = 0.0

const gravity = Vector3(0, -9.8, 0)

var skiwi_left = 0.0
var skiwi_right = 0.0
var skiwi_forward = 0.0
var skiwi_back = 0.0
var skiwi_face_left = 0.0

var boolTest = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	arr_linVel.insert(0, self.global_position)
	arr_linVel.insert(1, self.global_position)
	arr_rotVel.insert(0, self.basis.get_rotation_quaternion())
	arr_rotVel.insert(1, self.basis.get_rotation_quaternion())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	sdt = delta * 0.016
	
	if (!bot):
		camera.make_current()
		
		skiwi_left = Input.get_action_strength("skiwi_left")
		skiwi_right = Input.get_action_strength("skiwi_right")
		skiwi_forward = Input.get_action_strength("skiwi_forward")
		skiwi_back = Input.get_action_strength("skiwi_back")
		skiwi_face_left = Input.get_action_strength("skiwi_face_left")
		
		if (Input.is_action_just_pressed("skiwi_bumper_right")):
			_trick_init("trick1")
		elif (Input.is_action_pressed("skiwi_bumper_right") and Input.is_action_just_pressed("skiwi_face_left")):
			_trick_special("trick1")
		elif (Input.is_action_just_released("skiwi_bumper_right")):
			_trick_release("trick1")
	else:
		_bot()
		
	_forces()
	_controls()
	_camera()
	#_animations()
	#_sound()

func _forces():
	arr_linVel.insert(0, self.global_position)
	arr_rotVel.insert(0, self.basis.get_rotation_quaternion())
	arr_linVel.resize(2)
	arr_rotVel.resize(2)
	
	linVel = arr_linVel[0] - arr_linVel[1]
	rotVel = arr_rotVel[0] - arr_rotVel[1]
	
	# Ground
	if (rayC.is_colliding()):
		var normal = rayC.get_collision_normal()
		
		var rayPoint_front = rayC_front.get_collision_point()
		var rayPoint_back = rayC_back.get_collision_point()
		var rayPoint_right = rayC_right.get_collision_point()
		var rayPoint_left = rayC_left.get_collision_point()
		
		var forwV = (rayPoint_back - rayPoint_front).normalized()
		var rightV = (rayPoint_right - rayPoint_left).normalized()
		var upV = forwV.cross(rightV).normalized()
		
		# Force up to point in the same hemisphere as the raycast normals
		if upV.dot(normal) < 0:
			upV = -upV
		
		#var basisTest = Basis(rightV, upV, forwV)
		
		var forwardV = -self.transform.basis.z.normalized()
		
		forwardV = forwardV.slide(normal).normalized()
		var right = normal.cross(forwardV).normalized()
		
		var newBasis = Basis(-right, normal, -forwardV)
		
		if (linVel.length() > 0.2):
			linVel -= linVel * (linVel.length() - 0.2)
		
		var slopeForce = linVel.slide(normal)
		slopeForce += gravity.slide(normal) * sdt
		
		var downHillForce = forwardV * slopeForce.dot(forwardV)
		
		var combinedForce = downHillForce.lerp(slopeForce, 0.5)
		
		if (combinedForce.length() > 0.15):
			combinedForce = combinedForce.normalized() * 0.2
			
		position += combinedForce
		#position += downHillForce
		
		var deltaPos = rayC.global_position - rayC.get_collision_point()
		if (deltaPos.length() < 0.299):
			for i in 10:
				position += rayC.get_collision_normal() / 1000
				deltaPos = rayC.global_position - rayC.get_collision_point()
				if (deltaPos.length() >= 0.3):
					break
		
		transform.basis = newBasis
		#transform.basis = basisTest.orthonormalized()
		#global_transform.basis = global_transform.basis.slerp(basisTest, 0.2)
	
	# Air
	elif (!rayC.is_colliding()):
		self.position += linVel + (gravity * sdt)
		
		var pos = position
		var vel = linVel
		
		var spaceState = get_world_3d().direct_space_state
		
		var steps = 90
		for t in range(steps):
			var nextPos = pos + vel
			nextPos += gravity * sdt
			
			var rayParams = PhysicsRayQueryParameters3D.create(pos, nextPos)
			rayParams.exclude = [self]
			var result = spaceState.intersect_ray(rayParams)
			
			#DebugDraw3D.draw_line(pos, nextPos, Color.YELLOW)

			vel += gravity * sdt
			pos = nextPos
			
			if (result):
				var normal = result["normal"]
				var forwardV = -transform.basis.z.normalized()
				
				forwardV = forwardV.slide(normal).normalized()
				var right = normal.cross(forwardV).normalized()
				
				var newBasis = Basis(-right, normal, -forwardV)
				transform.basis = transform.basis.slerp(newBasis, 100 * sdt)

var onGround

func _controls():
	
	# Ground system
	if (rayC.is_colliding()):
		if (!onGround):
			onGround = true
			pivot_root.reparent(pivot_feet, false)
			pivot_com.rotation = Vector3(0,0,0)
			#print("ground")
			
		rotate_object_local(Vector3.UP, deg_to_rad(skiwi_left * 5000) * sdt)
		rotate_object_local(Vector3.UP, deg_to_rad(skiwi_right * -5000) * sdt)
		translate_object_local((Vector3.BACK * skiwi_back) * sdt)
		translate_object_local((Vector3.FORWARD * skiwi_face_left) * sdt)
	# Air system
	elif (!rayC.is_colliding()):
		if (onGround):
			onGround = false
			pivot_root.reparent(pivot_com, false)
			#print("air")
			
		pivot_com.rotate_object_local(Vector3.UP, deg_to_rad(skiwi_left * 12000) * sdt)
		pivot_com.rotate_object_local(Vector3.UP, deg_to_rad(skiwi_right * -12000) * sdt)
		pivot_com.rotate_object_local(Vector3.RIGHT, deg_to_rad(skiwi_back * 12000) * sdt)
		pivot_com.rotate_object_local(Vector3.RIGHT, deg_to_rad(skiwi_forward * -12000) * sdt)
		
		#if (Input.is_action_just_released("skiwi_up")):
			#var deltaPos = rayC.global_position - rayC.get_collision_point()
			#if (deltaPos.length() < 0.25):
				#for i in 10:
					#global_position += rayC.get_collision_normal() / 300
					#deltaPos = global_position - rayC.get_collision_point()
					#if (deltaPos.length() >= 0.25):
						#break
			#translate(Vector3(0, 150, 0) * sdt)
			
	if (Input.is_action_just_pressed("skiwi_up")):
		var deltaPos = rayC.global_position - rayC.get_collision_point()
		if (deltaPos.length() < 0.25):
			for i in 10:
				global_position += rayC.get_collision_normal() / 300
				deltaPos = global_position - rayC.get_collision_point()
				if (deltaPos.length() >= 0.25):
					break
		translate(Vector3(0, 150, 0) * sdt)

func _camera():
	springArm.position = self.global_position
	
	var ROT_SMOOTH = 200.0
	
	if (rayC.is_colliding()):
		# get target world rotation (Basis) from this node
		var target_basis: Basis = global_transform.basis

		# slerp the springArm's current world basis toward target
		var xf = springArm.global_transform
		xf.basis = xf.basis.slerp(target_basis, clamp(ROT_SMOOTH * sdt, 0.0, 1.0)).orthonormalized()
		springArm.global_transform = xf
	else:
		# get target world rotation (Basis) from this node
		#var target_basis: Basis = global_transform.basis
		#target_basis = target_basis.looking_at(linVel)

		# slerp the springArm's current world basis toward target
		var xf = springArm.global_transform
		if (xf.basis.y.dot(linVel) > 0.001):
			xf.basis = xf.basis.slerp(Basis.looking_at(linVel), clamp(ROT_SMOOTH * sdt, 0.0, 1.0)).orthonormalized()
			springArm.global_transform = xf

func _animations():
	#var direction = Vector2(skiwi_right - skiwi_left,  skiwi_forward - skiwi_back)
	#
	#if (rayC.is_colliding()):
		#birdAnimTree["parameters/bs2d_fast/blend_position"] = direction
		#birdAnimTree["parameters/bs2d_slow/blend_position"] = direction
	#elif (!rayC.is_colliding()):
		#pass
	
	# Snow splash effect
	if (rayC.is_colliding()):
		if (Input.is_action_pressed("skiwi_left")):
			snowsplash_l.visible = false
			snowsplash_r.visible = true
		elif (Input.is_action_pressed("skiwi_right")):
			snowsplash_l.visible = true
			snowsplash_r.visible = false
		else:
			snowsplash_l.visible = false
			snowsplash_r.visible = false
	else:
		snowsplash_l.visible = false
		snowsplash_r.visible = false

func _sound():
	if (rayC.is_colliding()):
		if (audiostream_ground.playing != true):
			audiostream_ground.play()
		audiostream_ground.volume_db = remap(linVel.length(), 0.0, 0.2, -40.0, 0.0)
		#audiostream_ground.pitch_scale = clamp(linVel.length() * 10, 1.0, 1.2)
		
		#if (Input.is_action_pressed("skiwi_left")):
			#audiostream_ground.pitch_scale += 0.2
		#elif (Input.is_action_pressed("skiwi_right")):
			#audiostream_ground.pitch_scale += 0.2
		
	elif (!rayC.is_colliding()):
		audiostream_ground.stop()
	pass

func _trick_init(trick_name: String) -> void:
	# Only start the init animation if we aren’t already in idle
	if birdAnimPlayer.current_animation != trick_name + "_idle":
		birdAnimPlayer.play(trick_name + "_init")
		
		# Disconnect any old signal to avoid duplicates
		if birdAnimPlayer.is_connected("animation_finished", Callable(self, "_trick_idle")):
			birdAnimPlayer.disconnect("animation_finished", Callable(self, "_trick_idle"))

		# Connect the signal to handle chaining
		birdAnimPlayer.connect("animation_finished", Callable(self, "_trick_idle").bind(trick_name))

func _trick_idle(anim_name: String, trick_name: String) -> void:
	if anim_name == trick_name + "_init":
		birdAnimPlayer.play(trick_name + "_idle")
		
		# Disconnect so it doesn’t keep triggering forever
		if birdAnimPlayer.is_connected("animation_finished", Callable(self, "_trick_idle")):
			birdAnimPlayer.disconnect("animation_finished", Callable(self, "_trick_idle"))

func _trick_special(trick_name: String) -> void:
	if birdAnimPlayer.is_connected("animation_finished", Callable(self, "_trick_idle")):
		birdAnimPlayer.disconnect("animation_finished", Callable(self, "_trick_idle"))
		
	birdAnimPlayer.play(trick_name + "_special")

func _trick_release(trick_name: String) -> void:
	if birdAnimPlayer.is_connected("animation_finished", Callable(self, "_trick_idle")):
		birdAnimPlayer.disconnect("animation_finished", Callable(self, "_trick_idle"))
		
	birdAnimPlayer.play_backwards(trick_name + "_init")

func _bot():
	if (rayC.is_colliding()):
		var target = pathBots.curve.get_closest_point(self.position)
		#var offset = pathBots.curve.get_closest_offset(self.position)
		var pos = self.position
		var rightV = self.basis.x
		
		var vec = target - pos
		
		var dot = rightV.dot(vec.normalized())
		
		#var trans = pathBots.curve.sample_baked_with_rotation(offset, false)
		
		rotate_object_local(Vector3.UP, deg_to_rad(dot * -5000) * sdt)
