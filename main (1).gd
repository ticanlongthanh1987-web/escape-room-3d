extends Node3D
# Escape room 3D: tìm manh mối -> mở két sắt -> lấy chìa khóa -> mở cửa thoát ra.
# Toàn bộ căn phòng được dựng bằng code nên bạn dễ đọc, dễ sửa.

const SAFE_CODE := "0738"  # hai số đầu: đồng hồ (07), hai số sau: dưới thảm (38)

const PROMPTS := {
	"note": "Đọc tờ giấy",
	"rug": "Kéo tấm thảm",
	"safe": "Mở két sắt",
	"door": "Mở cửa",
}

var player
var inventory: Array[String] = []
var rug_moved := false
var safe_open := false
var finished := false
var msg_id := 0

var rug: StaticBody3D
var door: StaticBody3D

var prompt_label: Label
var msg_label: Label
var inv_label: Label
var keypad: PanelContainer
var code_input: LineEdit
var keypad_msg: Label
var win_rect: ColorRect


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_objects()
	_build_ui()

	player = preload("res://player.gd").new()
	player.position = Vector3(0, 0.1, 3)
	add_child(player)
	player.interact_pressed.connect(_on_interact)

	show_message("Bạn bị nhốt trong căn phòng này. Hãy quan sát xung quanh!\n(WASD: đi, chuột: nhìn, E: tương tác)", 6.0)


func _process(_delta: float) -> void:
	if player.locked:
		prompt_label.text = ""
		return
	var t = player.get_target()
	if t == null:
		prompt_label.text = ""
	else:
		var id: String = t.get_meta("id")
		prompt_label.text = "[E] " + PROMPTS.get(id, "Tương tác")


func _input(event: InputEvent) -> void:
	if keypad.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_keypad()


# ---------------------------------------------------------------- Dựng thế giới

func make_box(size: Vector3, pos: Vector3, color: Color, layer := 1, id := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = layer
	body.collision_mask = 0

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)

	if id != "":
		body.set_meta("id", id)
	add_child(body)
	return body


func make_label(text: String, pos: Vector3, rot_deg: Vector3, size := 64, color := Color.BLACK, pixel := 0.01) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation_degrees = rot_deg
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	add_child(l)
	return l


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.7, 0)
	lamp.omni_range = 14.0
	lamp.light_energy = 1.3
	add_child(lamp)


func _build_room() -> void:
	var wall := Color(0.75, 0.72, 0.65)
	make_box(Vector3(8, 0.2, 8), Vector3(0, -0.1, 0), Color(0.35, 0.28, 0.22))   # sàn
	make_box(Vector3(8, 0.2, 8), Vector3(0, 3.1, 0), Color(0.85, 0.85, 0.85))    # trần
	make_box(Vector3(8, 3, 0.2), Vector3(0, 1.5, 4.1), wall)                     # tường nam
	make_box(Vector3(0.2, 3, 8), Vector3(4.1, 1.5, 0), wall)                     # tường đông
	make_box(Vector3(0.2, 3, 8), Vector3(-4.1, 1.5, 0), wall)                    # tường tây
	# tường bắc có khoảng trống cho cửa (rộng 1.4, cao 2.4)
	make_box(Vector3(3.3, 3, 0.2), Vector3(-2.35, 1.5, -4.1), wall)
	make_box(Vector3(3.3, 3, 0.2), Vector3(2.35, 1.5, -4.1), wall)
	make_box(Vector3(1.4, 0.6, 0.2), Vector3(0, 2.7, -4.1), wall)
	# cửa thoát hiểm
	door = make_box(Vector3(1.4, 2.4, 0.2), Vector3(0, 1.2, -4.1), Color(0.4, 0.22, 0.1), 3, "door")


func _build_objects() -> void:
	# Bàn + tờ giấy ghi chú
	make_box(Vector3(1.6, 0.8, 0.8), Vector3(-2.8, 0.4, -2.8), Color(0.45, 0.3, 0.15))
	make_box(Vector3(0.4, 0.02, 0.3), Vector3(-2.8, 0.82, -2.8), Color(1, 1, 0.9), 2, "note")

	# Đồng hồ treo tường (tường tây) hiển thị 07:00
	make_box(Vector3(0.1, 0.7, 0.7), Vector3(-3.95, 2.0, 0), Color(0.95, 0.95, 0.95), 0)
	make_label("07:00", Vector3(-3.89, 2.0, 0), Vector3(0, 90, 0), 64, Color.BLACK, 0.008)

	# Tấm thảm che con số 38 dưới sàn
	make_label("38", Vector3(0, 0.01, 1.5), Vector3(-90, 0, 0), 128, Color(0.7, 0.05, 0.05), 0.006)
	rug = make_box(Vector3(2, 0.02, 1.4), Vector3(0, 0.01, 1.5), Color(0.6, 0.12, 0.12), 2, "rug")

	# Két sắt
	make_box(Vector3(0.9, 1.0, 0.7), Vector3(2.7, 0.5, -3.4), Color(0.25, 0.27, 0.3), 3, "safe")
	make_box(Vector3(0.5, 0.3, 0.02), Vector3(2.7, 0.62, -3.04), Color(0.05, 0.05, 0.05), 0)

	# Vài đồ trang trí cho phòng đỡ trống
	make_box(Vector3(0.5, 0.5, 0.5), Vector3(3.2, 0.25, 2.8), Color(0.3, 0.4, 0.55))
	make_box(Vector3(0.5, 0.5, 0.5), Vector3(3.2, 0.75, 2.8), Color(0.55, 0.4, 0.3))


# ---------------------------------------------------------------- Giao diện

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	# tâm ngắm
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 24)
	ui.add_child(cross)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cross.grow_vertical = Control.GROW_DIRECTION_BOTH

	# gợi ý tương tác
	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(prompt_label)
	prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_label.offset_top = -110
	prompt_label.offset_bottom = -70

	# thông báo
	msg_label = Label.new()
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(msg_label)
	msg_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	msg_label.offset_left = 80
	msg_label.offset_right = -80
	msg_label.offset_top = 40
	msg_label.offset_bottom = 160

	# túi đồ
	inv_label = Label.new()
	inv_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(inv_label)
	inv_label.position = Vector2(16, 12)
	_update_inventory()

	# bàn phím nhập mã
	keypad = PanelContainer.new()
	keypad.visible = false
	ui.add_child(keypad)
	keypad.set_anchors_preset(Control.PRESET_CENTER)
	keypad.grow_horizontal = Control.GROW_DIRECTION_BOTH
	keypad.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 0)
	box.add_theme_constant_override("separation", 10)
	keypad.add_child(box)
	var title := Label.new()
	title.text = "Nhập mật mã 4 chữ số"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	code_input = LineEdit.new()
	code_input.max_length = 4
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.add_theme_font_size_override("font_size", 28)
	code_input.text_submitted.connect(_submit_code)
	box.add_child(code_input)
	keypad_msg = Label.new()
	keypad_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(keypad_msg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for n in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Xóa", "0", "<"]:
		var b := Button.new()
		b.text = n
		b.custom_minimum_size = Vector2(80, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_keypad_press.bind(n))
		grid.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var ok := Button.new()
	ok.text = "Xác nhận"
	ok.pressed.connect(func(): _submit_code(code_input.text))
	row.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Hủy (Esc)"
	cancel.pressed.connect(close_keypad)
	row.add_child(cancel)

	# màn hình chiến thắng
	win_rect = ColorRect.new()
	win_rect.color = Color(0, 0, 0, 0.85)
	win_rect.visible = false
	ui.add_child(win_rect)
	win_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var win_label := Label.new()
	win_label.text = "Bạn đã trốn thoát!\nChúc mừng bạn đã giải xong câu đố."
	win_label.add_theme_font_size_override("font_size", 36)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_rect.add_child(win_label)
	win_label.set_anchors_preset(Control.PRESET_FULL_RECT)


func show_message(text: String, seconds := 4.0) -> void:
	msg_id += 1
	var my_id := msg_id
	msg_label.text = text
	await get_tree().create_timer(seconds).timeout
	if my_id == msg_id:
		msg_label.text = ""


func _update_inventory() -> void:
	if inventory.is_empty():
		inv_label.text = "Túi đồ: (trống)"
	else:
		inv_label.text = "Túi đồ: " + ", ".join(inventory)


# ---------------------------------------------------------------- Tương tác

func _on_interact() -> void:
	var t = player.get_target()
	if t == null:
		return
	match t.get_meta("id"):
		"note":
			show_message("Tờ giấy ghi: \"Két sắt dùng mã 4 số. Hai số đầu là giờ trên đồng hồ. Hai số sau bị giấu dưới tấm thảm.\"", 9.0)
		"rug":
			if rug_moved:
				show_message("Dưới sàn khắc con số 38.")
			else:
				rug_moved = true
				create_tween().tween_property(rug, "position:x", 2.5, 0.6)
				show_message("Bạn kéo tấm thảm ra. Dưới sàn có khắc số 38!")
		"safe":
			if safe_open:
				show_message("Két sắt đã mở và trống rỗng.")
			else:
				open_keypad()
		"door":
			if "Chìa khóa" in inventory:
				_open_door()
			else:
				show_message("Cửa bị khóa. Bạn cần tìm chìa khóa.")


func open_keypad() -> void:
	player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	keypad.visible = true
	keypad_msg.text = ""
	code_input.text = ""
	code_input.call_deferred("grab_focus")


func _keypad_press(k: String) -> void:
	if k == "Xóa":
		code_input.text = ""
	elif k == "<":
		code_input.text = code_input.text.substr(0, code_input.text.length() - 1)
	elif code_input.text.length() < 4:
		code_input.text += k


func close_keypad() -> void:
	keypad.visible = false
	if not finished:
		player.locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _submit_code(code: String) -> void:
	if code == SAFE_CODE:
		safe_open = true
		inventory.append("Chìa khóa")
		_update_inventory()
		close_keypad()
		show_message("Cạch! Két sắt mở ra. Bạn nhặt được một chiếc chìa khóa.", 5.0)
	else:
		keypad_msg.text = "Sai mật mã, thử lại!"
		code_input.text = ""


func _open_door() -> void:
	finished = true
	show_message("Bạn dùng chìa khóa mở cửa...", 3.0)
	var tw := create_tween()
	tw.tween_property(door, "position:y", 3.8, 1.2)
	await tw.finished
	player.locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	win_rect.visible = true
