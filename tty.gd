extends Device

const BUFFER_SIZE := 64
const LINES := Vector2i(80, 24)
const ON_COL := Color(1.0, 0.0, 0.0, 1.0)
const OFF_COL := Color(0.263, 0.0, 0.0, 1.0)
var inbuffer:Array[int] = []
var outbuffer:Array[int] = []
var screen:Array[String] = []
var cursor:Vector2i = Vector2i.ZERO
var loopback := false


@onready var display:Label = $vt100/Label
@onready var parent:Panel= $vt100
@onready var scroll:AnimationPlayer = $AnimationPlayer
@onready var caret:Label = $vt100/Label/cur
@onready var leds:Array[ColorRect] = [
	$vt100/TextureRect/HBoxContainer/ColorRect,
	$vt100/TextureRect/HBoxContainer/ColorRect2,
	$vt100/TextureRect/HBoxContainer/ColorRect3,
	$vt100/TextureRect/HBoxContainer/ColorRect4,
]


enum esc {
	NONE,
	ESC,
	SEQ,
}


var pc_escape := esc.NONE
var pc_params:Array[String] = [""]


func process_char(ch:int) -> void:
	match pc_escape:
		esc.ESC:
			if ch == ord("["):
				pc_params = [""]
				pc_escape = esc.SEQ
				return
			else:
				pc_escape = esc.NONE
		esc.SEQ:
			var chr := char(ch)
			if chr in "?=1234567890":
				pc_params[-1] += chr
				return
			elif chr == ";":
				pc_params.append("")
				return
			elif chr in "hlmrABCDHfgKJq":
				match chr:
					"h":
						if pc_params[0] == "?25":
							caret.show()
					"l":
						if pc_params[0] == "?25":
							caret.hide()
					"m":
						pass
					"r":
						pass
					"A":
						var i := 1
						if pc_params[0].is_valid_int():
							i = pc_params[0].to_int()
						cursor.y = clampi(cursor.y - i, 0, LINES.y - 1)
					"B":
						var i := 1
						if pc_params[0].is_valid_int():
							i = pc_params[0].to_int()
						cursor.y = clampi(cursor.y + i, 0, LINES.y - 1)
					"C":
						var i := 1
						if pc_params[0].is_valid_int():
							i = pc_params[0].to_int()
						cursor.x = clampi(cursor.x + i, 0, LINES.x - 1)
					"D":
						var i := 1
						if pc_params[0].is_valid_int():
							i = pc_params[0].to_int()
						cursor.x = clampi(cursor.x - i, 0, LINES.x - 1)
					"H", "f":
						pc_params.resize(2)
						var x := 0
						var y := 0
						if pc_params[0].is_valid_int():
							x = pc_params[0].to_int() - 1
						if pc_params[1].is_valid_int():
							y = pc_params[1].to_int() - 1
						x = clampi(x, 0, LINES.x - 1)
						y = clampi(y, 0, LINES.y - 1)
						cursor = Vector2i(x, y)
					"g":
						pass
					"K":
						pass #TODO
					"J":
						pass #TODO
					"q":
						match pc_params[0]:
							"1":
								leds[0].color = ON_COL
							"2":
								leds[1].color = ON_COL
							"3":
								leds[2].color = ON_COL
							"4":
								leds[3].color = ON_COL
							_:
								for i in leds:
									i.color = OFF_COL
				pc_escape = esc.NONE
				return
			else:
				pc_escape = esc.NONE
		_:
			pc_escape = esc.NONE
	match ch:
		0x07: #BEL
			$bell.play()
		0x08: #backspace
			if cursor.x <= 0:
				cursor.x = LINES.x - 1
				if cursor.y > 0:
					cursor.y -= 1
			else:
				cursor.x -= 1
		0x09: #tab
			pass #TODO
		0x0A: #LF
			if cursor.y >= LINES.y - 1:
				screen.append("".lpad(LINES.x))
			else:
				cursor.y += 1
		0x0C: #form feed
			pass #TODO
		0x0D: #CR
			cursor.x = 0
		0x1B: #escape
			pc_escape = esc.ESC
		_:
			setchar(ch)


func setchar(ch:int) -> void:
	if ch == 0:
		return
	if cursor.x >= LINES.x:
		if cursor.y >= LINES.y - 1:
			screen.append("".lpad(LINES.x))
			cursor.x = 0
		else:
			cursor.y += 1
			cursor.x = 0
	var idy := cursor.y - LINES.y
	screen[idy][cursor.x] = char(ch)
	cursor.x += 1


func escape(seq:String) -> void:
	inbuffer.append(27)
	sequ(seq)


func sequ(seq:String) -> void:
	for i in seq:
		inbuffer.append(ord(i))


func _input(event: InputEvent) -> void:
	if parent.has_focus():
		if event is InputEventKey:
			if event.pressed:
				get_viewport().set_input_as_handled()
				if inbuffer.size() >= BUFFER_SIZE:
					return
				if event.unicode:
					inbuffer.append(event.unicode)
				else:
					match event.keycode:
						Key.KEY_ESCAPE:
							escape("")
						Key.KEY_ENTER, Key.KEY_KP_ENTER:
							sequ("\r\n")
						Key.KEY_BACKSPACE:
							sequ("\b")
						Key.KEY_UP:
							escape("[A")
						Key.KEY_DOWN:
							escape("[B")
						Key.KEY_RIGHT:
							escape("[C")
						Key.KEY_LEFT:
							escape("[D")


func getmem(addr:int) -> int:
	match addr:
		ADDRESS_STANDARDS.DESCRIPTOR:
			return DEVICE_DESCRIPTOR.EXPANSION_PORT_SERIAL
		ADDRESS_STANDARDS.VENDOR_ID:
			return 0
		ADDRESS_STANDARDS.MODEL:
			return 0
		ADDRESS_STANDARDS.PORT_BUFFER_SIZE_IN, ADDRESS_STANDARDS.PORT_BUFFER_SIZE_OUT:
			return BUFFER_SIZE
		_:
			if inbuffer.size() > 0:
				var out:int = inbuffer.pop_front()
				return out
	return 0


func setmem(addr:int, val:int) -> void:
	outbuffer.append(val)


func _process(delta: float) -> void:
	process_buffer()
	while screen.size() < LINES.y:
		screen.append("".lpad(LINES.x))
	if scroll.is_playing():
		return
	update_text()
	if screen.size() > LINES.y:
		screen.remove_at(0)
		scroll.play(&"scroll")
	caret.position = cursor * Vector2i(10, 19)


func process_buffer() -> void:
	var buf:Array[int]
	if loopback:
		buf = inbuffer
	else:
		buf = outbuffer
	for i in buf:
		process_char(i)
	buf.clear()


func update_text() -> void:
	var text := ""
	for i in LINES.y:
		text += (screen[i] + "\n")
	if screen.size() > LINES.y:
		text += screen[LINES.y]
	display.text = text
	display.position = Vector2.ZERO
