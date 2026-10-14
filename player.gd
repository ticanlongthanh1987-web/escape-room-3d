extends CharacterBody3D
# Nhân vật góc nhìn thứ nhất: di chuyển WASD / phím mũi tên, xoay bằng chuột, nhấn E để tương tác.

signal interact_pressed

const SPEED := 4.0
const SENS := 0.003
const GRAVITY := 20.0

var cam: Camera3D
var ray: RayCast3D
var locked := false  # true khi đang mở bàn phím nhập mã hoặc đã thắng


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)

	cam = Camera3D.new()
	cam.position.y = 1.6
	add_child(cam)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.5)
	ray.collision_mask = 3
	ray.add_exception(self)
	cam.add_child(ray)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENS)
		cam.rotate_x(-event.relative.y * SENS)
		cam.rotation.x = clamp(cam.rotation.x, -1.4, 1.4)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		interact_pressed.emit()


func _physics_process(delta: float) -> void:
	var d := Vector2.ZERO
	if not locked:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			d.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			d.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			d.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			d.x += 1
	var dir := (transform.basis * Vector3(d.x, 0, d.y)).normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()


# Trả về vật đang được nhìn vào (nếu có thể tương tác), ngược lại trả về null.
func get_target() -> Node:
	if ray.is_colliding():
		var c = ray.get_collider()
		if c != null and c.has_meta("id"):
			return c
	return null
