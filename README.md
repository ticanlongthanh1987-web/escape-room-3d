# Escape Room 3D - bản kinh dị (Godot 4)

Game giải đố thoát phòng góc nhìn thứ nhất gồm 2 phòng, không khí tối và kinh dị.

## Cách chạy
1. Tải Godot 4.2 trở lên (bản Standard, không phải .NET) tại https://godotengine.org/download
2. Mở Godot -> Import -> chọn `project.godot`.
3. Mở `main.tscn` rồi bấm F5.

## Điều khiển
- WASD / phím mũi tên: di chuyển
- Chuột: nhìn xung quanh
- E: tương tác
- F: bật/tắt đèn pin (sau khi nhặt được)
- Esc: đóng bàn phím nhập mã

## Cấu trúc
- `main.gd`: dựng 2 phòng, đồ vật, giao diện và toàn bộ logic câu đố
- `player.gd`: di chuyển, camera, đèn pin, tia nhìn để tương tác
- `main.tscn`: scene chính (chỉ có một node gắn `main.gd`)
