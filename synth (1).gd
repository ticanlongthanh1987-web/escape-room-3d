extends RefCounted
# Tự tạo âm thanh bằng code (không cần file âm thanh bên ngoài).
# Muốn dùng âm thanh thật, bạn có thể thay các hàm này bằng file .wav / .ogg.

const RATE := 22050


static func _buf(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * seconds))
	return out


static func _make(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


# Gió rít + tiếng ù trầm, lặp liên tục (4 giây)
static func wind() -> AudioStreamWAV:
	var out := _buf(4.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in out.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.04
		lp2 += (lp - lp2) * 0.08
		var gust := 0.35 + 0.65 * pow(sin(PI * t / 4.0), 2.0)
		var drone := 0.07 * sin(TAU * 55.0 * t) + 0.04 * sin(TAU * 82.5 * t)
		out[i] = lp2 * 2.2 * gust + drone
	return _make(out, true)


# Một bước chân (thịch trầm)
static func step() -> AudioStreamWAV:
	var out := _buf(0.25)
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.12
		var env := exp(-t * 28.0)
		out[i] = (lp * 3.0 + 0.5 * sin(TAU * 70.0 * t)) * env * 0.8
	return _make(out)


# Tiếng thì thầm (nhiễu dải cao, nhấp nhô như âm tiết)
static func whisper() -> AudioStreamWAV:
	var dur := 2.6
	var out := _buf(dur)
	var a := 0.0
	var b := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var x := randf_range(-1.0, 1.0)
		a += (x - a) * 0.55
		b += (x - b) * 0.18
		var band := a - b
		var syll := pow(abs(sin(TAU * 2.2 * t + sin(t * 3.0))), 1.5)
		var env := pow(sin(PI * t / dur), 1.5)
		out[i] = band * syll * env * 1.6
	return _make(out)


# Tiếng "cạch" khi bấm nút
static func click() -> AudioStreamWAV:
	var out := _buf(0.08)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.5 + sin(TAU * 900.0 * t) * exp(-t * 60.0) * 0.4
	return _make(out)


# Tiếng "ting ting" khi nhặt đồ
static func pickup() -> AudioStreamWAV:
	var out := _buf(0.35)
	for i in out.size():
		var t := float(i) / RATE
		var f := 660.0
		if t >= 0.12:
			f = 990.0
		out[i] = sin(TAU * f * t) * exp(-fmod(t, 0.12) * 12.0) * 0.4
	return _make(out)


# Tiếng cửa kẽo kẹt / vật nặng trượt
static func door() -> AudioStreamWAV:
	var dur := 1.4
	var out := _buf(dur)
	var lp := 0.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.05
		var f := 90.0 + 40.0 * sin(TAU * 1.5 * t)
		phase += TAU * f / RATE
		var saw := fmod(phase, TAU) / PI - 1.0
		out[i] = (saw * 0.22 + lp * 2.5) * sin(PI * t / dur)
	return _make(out)


# Tiếng báo sai (vo vo trầm)
static func wrong() -> AudioStreamWAV:
	var out := _buf(0.5)
	for i in out.size():
		var t := float(i) / RATE
		var sq := 1.0
		if sin(TAU * 110.0 * t) < 0.0:
			sq = -1.0
		out[i] = sq * 0.22 * exp(-t * 4.0)
	return _make(out)


# Hợp âm trầm u ám (khi cỗ máy chạy / khi thoát được)
static func chime() -> AudioStreamWAV:
	var out := _buf(2.5)
	for i in out.size():
		var t := float(i) / RATE
		var v := sin(TAU * 220.0 * t) + sin(TAU * 261.6 * t) + sin(TAU * 311.1 * t)
		out[i] = v * 0.14 * exp(-t * 1.2)
	return _make(out)


# Nhịp tim, lặp liên tục (1 giây)
static func heartbeat() -> AudioStreamWAV:
	var out := _buf(1.0)
	for i in out.size():
		var t := float(i) / RATE
		var v := sin(TAU * 55.0 * t) * exp(-t * 16.0)
		if t >= 0.28:
			v += 0.7 * sin(TAU * 48.0 * (t - 0.28)) * exp(-(t - 0.28) * 16.0)
		out[i] = v * 0.9
	return _make(out, true)
