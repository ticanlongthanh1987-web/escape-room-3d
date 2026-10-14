extends Node3D
# Escape Room 3D - bản kinh dị 2 phòng.
# Phòng 1: tìm manh mối -> két sắt -> chìa khóa (+ đèn pin trong tủ) -> mở cửa.
# Phòng 2: tối đen -> nhật ký -> bấm 3 nút đúng thứ tự -> bánh răng -> cỗ máy -> mã -> cửa thoát.

const SAFE_CODE := "0738"                        # phòng 1: giờ đồng hồ (07) + số dưới thảm (38)
const EXIT_CODE := "317"                         # phòng 2: số hiện trên cỗ máy
const BUTTON_ORDER := ["blue", "red", "yellow"]  # xanh -> đỏ -> vàng

const PROMPTS := {
	"note": "Đọc tờ giấy",
	"rug": "Kéo tấm thảm",
	"safe": "Mở két sắt",
	"cabinet": "Mở tủ",
	"door1": "Mở cửa",
	"diary": "Đọc trang nhật ký",
	"btn_blue": "Bấm nút xanh",
	"btn_red": "Bấm nút đỏ",
	"btn_yellow": "Bấm nút vàng",
	"panel": "Xem tấm gỗ",
	"gear": "Nhặt bánh răng",
	"machine": "Xem cỗ máy",
	"door2": "Mở cửa thoát",
}

var player
var inventory: Array[String] = []

# trạng thái trò chơi
var rug_moved := false
var safe_open := false
var cabinet_open := false
var door1_open := false
var door2_open := false
var entered_room2 := false
var panel_open := false
var machine_on := false
var finished := false
var btn_seq: Array = []

# vật thể cần nhớ
var rug: StaticBody3D
var door1: StaticBody3D
var door2: StaticBody3D
var panel: StaticBody3D
var machine_label: Label3D
var machine_light: OmniLight3D

# hiệu ứng đèn chập chờn
var flicker_lights: Array = []
var flicker_t := 0.0
var blackout_t := 0.0
var render_layer := 1   # phòng 1 = lớp 1, phòng 2 = lớp 2 (để đèn phòng 1 không lọt sang phòng 2)

# giao diện
var msg_id := 0
var keypad_target := ""
var keypad_code := ""
var prompt_label: Label
var msg_label: Label
var inv_label: Label
var keypad: PanelContainer
var keypad_title: Label
var code_input: LineEdit
var keypad_msg: Label
var win_rect: ColorRect


func _ready() -> void:
	_build_environment()
	_build_room1()
	_build_room2()
	_build_ui()

	player = preload("res://player.gd").new()
	player.position = Vector3(0, 0.1, 3)
	add_child(player)
	player.interact_pressed.connect(_on_interact)

	show_message("Bạn tỉnh dậy trong một căn phòng lạnh lẽo. Bóng đèn trên trần chập chờn...\n(WASD: đi, chuột: nhìn, E: tương tác)", 7.0)


func _process(delta: float) -> void:
	_update_flicker(delta)

	if not entered_room2 and player.global_position.z < -5.0:
		entered_room2 = true
		blackout_t = 1.6
		show_message("Đèn phía sau lưng bạn chập chờn rồi tắt phụt. Có thứ gì đó đang thở trong bóng tối...", 6.0)

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


func _update_flicker(delta: float) -> void:
	if blackout_t > 0.0:
		blackout_t -= delta
	elif randf() < 0.35 * delta:
		blackout_t = randf_range(0.1, 0.35)
	flicker_t -= delta
	if flicker_t <= 0.0:
		flicker_t = 0.06
		for f in flicker_lights:
			var k := randf_range(0.8, 1.05)
			if blackout_t > 0.0:
				k = 0.05
			f["light"].light_energy = f["base"] * k


# ---------------------------------------------------------------- Dựng thế giới

func make_box(size: Vector3, pos: Vector3, color: Color, layer := 1, id := "", glow := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = layer
	body.collision_mask = 0

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.layers = render_layer
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
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


func make_label(text: String, pos: Vector3, rot_deg: Vector3, size := 64, color := Color.BLACK, pixel := 0.01, shaded := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation_degrees = rot_deg
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.shaded = shaded
	l.layers = render_layer
	add_child(l)
	return l


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.ambient_light_energy = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# bóng đèn phòng 1: ánh vàng ố, chập chờn (chỉ chiếu lên lớp 1)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.6, 0)
	lamp.omni_range = 11.0
	lamp.light_energy = 1.1
	lamp.light_color = Color(1.0, 0.72, 0.45)
	lamp.light_cull_mask = 1
	add_child(lamp)
	flicker_lights.append({"light": lamp, "base": 1.1})

	# đèn đỏ mờ ở phòng 2 (chỉ chiếu lên lớp 2)
	var red := OmniLight3D.new()
	red.position = Vector3(3.0, 2.4, -10.5)
	red.omni_range = 6.0
	red.light_energy = 0.5
	red.light_color = Color(1.0, 0.1, 0.05)
	red.light_cull_mask = 2
	add_child(red)
	flicker_lights.append({"light": red, "base": 0.5})


# Dựng vỏ phòng (sàn, trần, tường). Tường bắc có lỗ cửa rộng 1.4, cao 2.4.
# Phòng 2 dùng chung tường nam với phòng 1 nên không dựng tường nam.
func _build_shell(cz: float, solid_south: bool, wall: Color, floor_col: Color) -> void:
	var length := 8.4
	var center := cz
	if not solid_south:
		length = 8.2
		center = cz - 0.1
	make_box(Vector3(8.4, 0.2, length), Vector3(0, -0.1, center), floor_col)
	make_box(Vector3(8.4, 0.2, length), Vector3(0, 3.1, center), Color(0.2, 0.2, 0.2))
	make_box(Vector3(0.2, 3, length), Vector3(4.1, 1.5, center), wall)
	make_box(Vector3(0.2, 3, length), Vector3(-4.1, 1.5, center), wall)
	if solid_south:
		make_box(Vector3(8.4, 3, 0.2), Vector3(0, 1.5, cz + 4.1), wall)
	make_box(Vector3(3.5, 3, 0.2), Vector3(-2.45, 1.5, cz - 4.1), wall)
	make_box(Vector3(3.5, 3, 0.2), Vector3(2.45, 1.5, cz - 4.1), wall)
	make_box(Vector3(1.4, 0.6, 0.2), Vector3(0, 2.7, cz - 4.1), wall)


func _build_room1() -> void:
	render_layer = 1
	_build_shell(0.0, true, Color(0.55, 0.5, 0.42), Color(0.25, 0.19, 0.15))

	# cửa sang phòng 2 (khóa)
	door1 = make_box(Vector3(1.4, 2.4, 0.2), Vector3(0, 1.2, -4.1), Color(0.3, 0.17, 0.08), 3, "door1")

	# bàn + tờ giấy ghi chú
	make_box(Vector3(1.6, 0.8, 0.8), Vector3(-2.8, 0.4, -2.8), Color(0.45, 0.3, 0.15))
	make_box(Vector3(0.4, 0.02, 0.3), Vector3(-2.8, 0.82, -2.8), Color(1, 1, 0.9), 2, "note")

	# đồng hồ ngừng ở 07:00 (tường tây)
	make_box(Vector3(0.1, 0.7, 0.7), Vector3(-3.95, 2.0, 0), Color(0.9, 0.9, 0.85), 0)
	make_label("07:00", Vector3(-3.89, 2.0, 0), Vector3(0, 90, 0), 64, Color.BLACK, 0.008)

	# tấm thảm che con số khắc dưới sàn
	make_label("38", Vector3(0, 0.01, 1.5), Vector3(-90, 0, 0), 128, Color(0.7, 0.05, 0.05), 0.006)
	rug = make_box(Vector3(2, 0.02, 1.4), Vector3(0, 0.01, 1.5), Color(0.5, 0.1, 0.1), 2, "rug")

	# két sắt
	make_box(Vector3(0.9, 1.0, 0.7), Vector3(2.7, 0.5, -3.4), Color(0.25, 0.27, 0.3), 3, "safe")
	make_box(Vector3(0.5, 0.3, 0.02), Vector3(2.7, 0.62, -3.04), Color(0.05, 0.05, 0.05), 0)

	# tủ gỗ cũ (có đèn pin)
	make_box(Vector3(0.6, 1.8, 0.9), Vector3(-3.6, 0.9, 2.4), Color(0.28, 0.18, 0.1), 3, "cabinet")

	# vài thùng cũ
	make_box(Vector3(0.5, 0.5, 0.5), Vector3(3.2, 0.25, 2.8), Color(0.3, 0.35, 0.45))
	make_box(Vector3(0.5, 0.5, 0.5), Vector3(3.2, 0.75, 2.8), Color(0.45, 0.35, 0.3))

	# dòng chữ đỏ trên tường sau lưng người chơi
	make_label("ĐỪNG NHÌN VÀO BÓNG TỐI", Vector3(0, 1.8, 3.98), Vector3(0, 180, 0), 56, Color(0.7, 0.0, 0.0), 0.01, true)


func _build_room2() -> void:
	render_layer = 2
	var cz := -8.2
	_build_shell(cz, false, Color(0.28, 0.3, 0.28), Color(0.12, 0.1, 0.1))

	# cửa thoát hiểm cuối cùng (ổ khóa số)
	door2 = make_box(Vector3(1.4, 2.4, 0.2), Vector3(0, 1.2, cz - 4.1), Color(0.25, 0.25, 0.3), 3, "door2")

	# bàn + trang nhật ký
	make_box(Vector3(1.2, 0.8, 0.8), Vector3(-3.0, 0.4, -6.0), Color(0.3, 0.2, 0.12))
	make_box(Vector3(0.35, 0.02, 0.28), Vector3(-3.0, 0.82, -6.0), Color(0.9, 0.85, 0.7), 2, "diary")

	# ba nút trên tường phía đông: xanh - đỏ - vàng
	make_box(Vector3(0.1, 0.3, 0.3), Vector3(3.95, 1.4, -6.5), Color(0.1, 0.3, 1.0), 2, "btn_blue", 0.6)
	make_box(Vector3(0.1, 0.3, 0.3), Vector3(3.95, 1.4, -7.5), Color(1.0, 0.1, 0.1), 2, "btn_red", 0.6)
	make_box(Vector3(0.1, 0.3, 0.3), Vector3(3.95, 1.4, -8.5), Color(1.0, 0.85, 0.1), 2, "btn_yellow", 0.6)

	# tấm gỗ che ngăn bí mật (có bánh răng bên trong)
	make_box(Vector3(0.1, 0.3, 0.3), Vector3(3.93, 0.9, -9.8), Color(0.75, 0.55, 0.15), 2, "gear", 0.3)
	panel = make_box(Vector3(0.2, 0.6, 0.8), Vector3(3.9, 0.9, -9.8), Color(0.2, 0.14, 0.1), 3, "panel")

	# cỗ máy cũ (cần bánh răng)
	make_box(Vector3(1.2, 1.2, 0.8), Vector3(-2.6, 0.6, -11.6), Color(0.3, 0.3, 0.32), 3, "machine")
	make_box(Vector3(0.3, 0.3, 0.02), Vector3(-2.6, 0.5, -11.19), Color(0.03, 0.03, 0.03), 0)
	machine_label = make_label("3  1  7", Vector3(-2.6, 0.9, -11.19), Vector3.ZERO, 96, Color(0.3, 1.0, 0.4), 0.005)
	machine_label.visible = false
	machine_light = OmniLight3D.new()
	machine_light.position = Vector3(-2.6, 1.7, -10.6)
	machine_light.omni_range = 4.0
	machine_light.light_energy = 1.0
	machine_light.light_color = Color(0.3, 1.0, 0.4)
	machine_light.light_cull_mask = 2
	machine_light.visible = false
	add_child(machine_light)

	# đồ vật trang trí
	make_box(Vector3(0.8, 0.8, 0.8), Vector3(2.5, 0.4, -5.5), Color(0.35, 0.3, 0.25))
	make_box(Vector3(0.5, 0.5, 0.5), Vector3(3.4, 0.25, -5.3), Color(0.3, 0.28, 0.25))
	make_box(Vector3(0.5, 3, 0.5), Vector3(-0.8, 1.5, -8.5), Color(0.22, 0.22, 0.22))

	# dòng chữ rùng rợn trên tường tây
	make_label("NÓ ĐANG NHÌN BẠN", Vector3(-3.89, 1.7, -8.8), Vector3(0, 90, 0), 72, Color(0.75, 0.0, 0.0), 0.01, true)


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
	keypad_title = Label.new()
	keypad_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(keypad_title)
	code_input = LineEdit.new()
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
	win_rect.color = Color(0, 0, 0, 0.9)
	win_rect.visible = false
	ui.add_child(win_rect)
	win_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var win_label := Label.new()
	win_label.text = "Bạn đã trốn thoát khỏi ngôi nhà...\nNhưng tiếng thì thầm vẫn còn vang trong đầu bạn."
	win_label.add_theme_font_size_override("font_size", 34)
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
		var text := "Túi đồ: " + ", ".join(inventory)
		if "Đèn pin" in inventory:
			text += "   (F: bật/tắt đèn pin)"
		inv_label.text = text


# ---------------------------------------------------------------- Tương tác

func _on_interact() -> void:
	var t = player.get_target()
	if t == null:
		return
	var id: String = t.get_meta("id")
	match id:
		"note":
			show_message("Tờ giấy ố vàng, chữ viết nguệch ngoạc, dính vết nâu: \"Két sắt dùng mã 4 số. Hai số đầu là giờ trên chiếc đồng hồ đã ngừng chạy. Hai số sau bị giấu dưới tấm thảm. Đừng nhìn vào bóng tối.\"", 10.0)
		"rug":
			if rug_moved:
				show_message("Dưới sàn khắc con số 38.")
			else:
				rug_moved = true
				create_tween().tween_property(rug, "position:x", 2.5, 0.6)
				show_message("Bạn kéo tấm thảm ra. Dưới sàn có khắc số 38, như bằng móng tay...")
		"safe":
			if safe_open:
				show_message("Két sắt đã mở và trống rỗng.")
			else:
				open_keypad("safe", SAFE_CODE, "Nhập mật mã 4 chữ số")
		"cabinet":
			if cabinet_open:
				show_message("Chiếc tủ trống rỗng, chỉ còn mùi ẩm mốc.")
			else:
				cabinet_open = true
				inventory.append("Đèn pin")
				_update_inventory()
				player.give_flashlight()
				show_message("Trong ngăn tủ có một chiếc đèn pin cũ. Bạn nhặt nó lên. (Nhấn F để bật/tắt)", 6.0)
		"door1":
			if door1_open:
				return
			if "Chìa khóa" in inventory:
				door1_open = true
				inventory.erase("Chìa khóa")
				_update_inventory()
				create_tween().tween_property(door1, "position:y", 3.8, 1.0)
				if "Đèn pin" in inventory:
					show_message("Cánh cửa kẽo kẹt mở ra. Phía sau là bóng tối đặc quánh...", 5.0)
				else:
					show_message("Cánh cửa mở ra. Bóng tối phía sau dày đặc... Có lẽ bạn nên tìm thứ gì đó để soi sáng trước.", 6.0)
			else:
				show_message("Cửa bị khóa. Bạn cần tìm chìa khóa.")
		"diary":
			show_message("Trang nhật ký: \"Ngày thứ ba. Ba cái nút trên tường cứ thì thầm với tôi. Bầu trời đến trước, rồi đến máu, và cuối cùng là mặt trời. Nếu bấm sai, chúng sẽ bắt đầu lại từ đầu...\"", 10.0)
		"btn_blue":
			_press_button("blue")
		"btn_red":
			_press_button("red")
		"btn_yellow":
			_press_button("yellow")
		"panel":
			if panel_open:
				show_message("Tấm gỗ đã trượt sang bên.")
			else:
				show_message("Một tấm gỗ ghim chặt vào tường. Nó không nhúc nhích.")
		"gear":
			inventory.append("Bánh răng")
			_update_inventory()
			t.queue_free()
			show_message("Bạn nhặt một chiếc bánh răng bằng đồng, lạnh buốt và hơi nhớt.", 4.0)
		"machine":
			if machine_on:
				show_message("Màn hình trên cỗ máy hiện ba con số: 3 1 7.", 4.0)
			elif "Bánh răng" in inventory:
				machine_on = true
				inventory.erase("Bánh răng")
				_update_inventory()
				machine_label.visible = true
				machine_light.visible = true
				blackout_t = 0.5
				show_message("Bạn lắp bánh răng vào. Cỗ máy rùng rùng chạy, màn hình xanh lè hiện ba con số: 3 1 7.", 6.0)
			else:
				show_message("Một cỗ máy sắt cũ kỹ. Ở giữa có một chỗ trống hình bánh răng.", 4.0)
		"door2":
			if not door2_open:
				open_keypad("door2", EXIT_CODE, "Ổ khóa số: nhập 3 chữ số")


func _press_button(color: String) -> void:
	if panel_open:
		show_message("Các nút đã nguội lạnh, không còn phản ứng.")
		return
	btn_seq.append(color)
	var i := btn_seq.size() - 1
	if btn_seq[i] != BUTTON_ORDER[i]:
		btn_seq.clear()
		blackout_t = 0.8
		show_message("Cạch... Các nút bật ngược trở lại. Có tiếng thì thầm: \"Sai rồi.\"", 4.0)
		return
	if btn_seq.size() == BUTTON_ORDER.size():
		panel_open = true
		create_tween().tween_property(panel, "position:z", panel.position.z - 1.0, 0.8)
		show_message("Rầm! Một tấm gỗ trên tường trượt sang bên, để lộ một khoảng trống...", 5.0)
	else:
		show_message("Cạch. Nút sáng lên một lúc rồi tắt.", 2.5)


func open_keypad(target: String, code: String, title: String) -> void:
	keypad_target = target
	keypad_code = code
	keypad_title.text = title
	code_input.max_length = code.length()
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
	elif code_input.text.length() < keypad_code.length():
		code_input.text += k


func close_keypad() -> void:
	keypad.visible = false
	if not finished:
		player.locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _submit_code(code: String) -> void:
	if code != keypad_code:
		keypad_msg.text = "Sai mật mã, thử lại!"
		code_input.text = ""
		return
	var target := keypad_target
	close_keypad()
	if target == "safe":
		safe_open = true
		inventory.append("Chìa khóa")
		_update_inventory()
		show_message("Cạch! Két sắt mở ra. Bên trong có một chiếc chìa khóa.", 5.0)
	elif target == "door2":
		_open_exit()


func _open_exit() -> void:
	door2_open = true
	finished = true
	player.locked = true
	show_message("Ổ khóa bật mở. Một luồng gió lạnh thổi vào từ bên ngoài...", 3.0)
	var tw := create_tween()
	tw.tween_property(door2, "position:y", 3.8, 1.2)
	await tw.finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	win_rect.visible = true
