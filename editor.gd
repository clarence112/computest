extends HSplitContainer


@export var lineNumCol:Color
@export var instrCol:Color
@export var regCol:Color
@export var addrCol:Color
@export var datCol:Color
@export var blkCol:Color


const SAVEABLE:PackedStringArray = ["*.tres"]
const LOADABLE:PackedStringArray = ["*.tres", "*.cl_asm", "*.a", "*.txt"]


enum {
	INST,
	REG,
	ADDR,
	DAT,
	BLK,
}


const INSTR:Array = [
	["NOP", [], "NOP\nDoes nothing"],
	["MOV", [REG, REG], "MOV [SRC REG] [DEST REG]\nMoves values from SRC to DEST registers"],
	["SET", [REG, DAT], "SET [REG] [VALUE]\nSets the given register to the given value"],
	["JMP", [ADDR], "JMP [ADDRESS]\nJumps execution to the given address"],
	["JLT", [ADDR], "JLT [ADDRESS]\nJumps execution to the given address if A < B"],
	["JGT", [ADDR], "JGT [ADDRESS]\nJumps execution to the given address if A > B"],
	["JEQ", [ADDR], "JEQ [ADDRESS]\nJumps execution to the given address if A == B"],
	["JSR", [ADDR], "JSR [ADDRESS]\nJumps execution to the given address, storing the current address\non the stack to be returned to with RET"],
	["RET", [], "RET\nJumps execution to the address at the top of the stack"],
	["ADD", [], "ADD\nSets the ALU to integer addition mode"],
	["SUB", [], "SUB\nSets the ALU to integer subtraction mode"],
	["MUL", [], "MUL\nSets the ALU to integer multiplication mode"],
	["DIV", [], "DIV\nSets the ALU to integer division mode"],
	["MOD", [], "MOD\nSets the ALU to integer modulo mode"],
	["FPADD", [], "FPADD\nSets the ALU to floating point addition mode"],
	["FPSUB", [], "FPSUB\nSets the ALU to floating point subtraction mode"],
	["FPMUL", [], "FPMUL\nSets the ALU to floating point multiplication mode"],
	["FPDIV", [], "FPDIV\nSets the ALU to floating point division mode"],
	["FPMOD", [], "FPMOD\nSets the ALU to floating point modulo mode"],
	["FLR", [], "FLR\nSets the ALU to floor mode, converting floats to ints"],
	["CIL", [], "CIL\nSets the ALU to ceiling mode, converting floats to ints"],
	["RND", [], "RND\nSets the ALU to round mode, converting floats to ints"],
	["ITF", [], "ITF\nSets the ALU to int-to-float mode, converting ints to floats"],
	["OR", [], "OR\nSets the ALU to bitwise or mode"],
	["NOT", [], "NOT\nSets the ALU to bitwise not mode"],
	["XOR", [], "XOR\nSets the ALU to bitwise xor mode"],
	["AND", [], "AND\nSets the ALU to bitwise and mode"],
	["BSL", [], "BSL\nSets the ALU to bitshift left mode"],
	["BSR", [], "BSR\nSets the ALU to bitshift right mode"],
	["BCPY", [BLK, ADDR, BLK, ADDR, DAT], "BCPY [SRC TYPE] [SRC ADDRESS] [DEST TYPE] [DEST ADDRESS] [COUNT]\nCopies COUNT words of memory from SRC to DEST, starting from ADDRESS\nIf COUNT <= 0, stops on the first null/0 word"],
	["BWRT", [BLK, ADDR, BLK, ADDR, DAT], "BWRT [SRC TYPE] [SRC ADDRESS] [DEST TYPE] [DEST ADDRESS] [COUNT]\nCopies COUNT words of memory from SRC to DEST\nDevices will read/write to the same address repeatedly, RAM address will be incremented\nIf COUNT <= 0, stops on the first null/0 word"],
	["PUSH", [REG, BLK, ADDR], "PUSH [SRC REG] [DEST TYPE] [DEST ADDRESS]\nCopies SRC register to DEST RAM or device"],
	["PULL", [BLK, ADDR, REG], "PULL [SRC TYPE] [SRC ADDRESS] [DEST REG]\nCopes SRC RAM or device to DEST register"],
	["ITS", [REG, ADDR], "ITS [SRC REG] [DEST ADDRESS]\nConverts the integer in REG to a null-terminated string, storing it in RAM at ADDRESS"],
	["FTS", [REG, ADDR], "FTS [SRC REG] [DEST ADDRESS]\nConverts the float in REG to a null-terminated string, storing it in RAM at ADDRESS"],
	["CTXT", [ADDR], "CTXT [ADDR]\nSwitches contexts to ADDR\nIf in a protected context, always switch to context 0"],
	["HLT", [DAT], "HLT [STAT]\nStops execution, with STAT representing an exit code\nExecution can be resumed from this point by external sources"],
	["XCPT", [DAT], "XCPT [STAT]\nStops execution, with STAT representing an exit code\nExecution CANNOT be resumed from this point without resetting the processor"],
]
const REGS := [
	"A", "B", "C", "D", "SA", "SB", "SC", "SD",
	"ACCA", "ACCB", "ACCC", "ACCD", "DEVADDR",
	"DEVBUF", "PCOUNT", "ALUMODE", "JREL", "OFFS",
	"SIZE", "STACKP",
]
const BLKS := [
	"RAM", "DEV",
]


var mem:MemoryCard
var editing:int = 0
var filepath:String


@onready var linens:VBoxContainer = $ScrollContainer/HBoxContainer/VBoxContainer
@onready var lines:VBoxContainer = $ScrollContainer/HBoxContainer/VBoxContainer2
@onready var tabs:TabContainer = $ScrollContainer2/TabContainer
@onready var cpu:CPU = $"../main/cpu"
@onready var fd:FileDialog = $"../FileDialog"


func redraw() -> void:
	mem.is_dat.resize(mem.data.size())
	for i in linens.get_children():
		i.queue_free()
	for i in lines.get_children():
		i.queue_free()
	var i:int = 0
	var intrtypes:Array[int]
	var curline:HBoxContainer
	while i < mem.data.size():
		var val = mem.data[i]
		var lbl := Button.new()
		if intrtypes.size() > 0:
			lbl.pressed.connect(edit.bind(i))
			var type = intrtypes.pop_front()
			match type:
				REG:
					lbl.add_theme_color_override(&"font_color", regCol)
					if val >= REGS.size():
						lbl.text = "R" + str(val)
					else:
						lbl.text = REGS[val]
				ADDR:
					lbl.add_theme_color_override(&"font_color", addrCol)
					lbl.text = "$" + str(val)
				DAT:
					lbl.add_theme_color_override(&"font_color", datCol)
					lbl.text = str(val)
				BLK:
					lbl.add_theme_color_override(&"font_color", blkCol)
					if val >= BLKS.size():
						lbl.text = "B" + str(val)
					else:
						lbl.text = BLKS[val]
			@warning_ignore("unassigned_variable")
			curline.add_child(lbl)
		else:
			lbl.text = "$" + str(i)
			lbl.add_theme_color_override(&"font_color", lineNumCol)
			lbl.pressed.connect(pInst.bind(i))
			linens.add_child(lbl)
			curline = HBoxContainer.new()
			lines.add_child(curline)
			lbl = Button.new()
			lbl.pressed.connect(edit.bind(i))
			if mem.is_dat[i] or val >= INSTR.size():
				lbl.add_theme_color_override(&"font_color", datCol)
				lbl.text = str(val)
			else:
				lbl.add_theme_color_override(&"font_color", instrCol)
				lbl.text = INSTR[val][0]
				intrtypes.append_array(INSTR[val][1])
			curline.add_child(lbl)
		i += 1
	if intrtypes.size() > 0:
		match intrtypes[0]:
			INST:
				tabs.current_tab = 0
			REG:
				tabs.current_tab = 1
			ADDR:
				tabs.current_tab = 2
			DAT:
				tabs.current_tab = 3
			BLK:
				tabs.current_tab = 4
	else:
		tabs.current_tab = 0


func _ready() -> void:
	for i in INSTR.size():
		var inst = INSTR[i][0]
		var desc = INSTR[i][2]
		var b := Button.new()
		$ScrollContainer2/TabContainer/Instructions.add_child(b)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", instrCol)
		b.text = inst
		b.tooltip_text = desc
		b.pressed.connect(pInst.bind(i))
	for i in REGS.size():
		var b := Button.new()
		$ScrollContainer2/TabContainer/Registers.add_child(b)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", regCol)
		b.text = REGS[i]
		b.pressed.connect(pInst.bind(i))
	for i in BLKS.size():
		var b := Button.new()
		$ScrollContainer2/TabContainer/Blocks.add_child(b)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", blkCol)
		b.text = BLKS[i]
		b.pressed.connect(pInst.bind(i))
	_sync_mem()


func load_card():
	if ResourceLoader.exists(filepath):
		var dat:Resource = ResourceLoader.load(filepath)
		if dat is MemoryCard:
			cpu.bios_rom = dat
			_sync_mem()
			cpu.startup()
	elif FileAccess.file_exists(filepath):
		assemble()


func assemble() -> void:
	var f := FileAccess.open(filepath, FileAccess.READ)
	var t := f.get_as_text()
	f.close()
	var ta := t.split("\n", false)
	for i in ta.size():
		ta[i] = ta[i].strip_edges()
		ta[i] = ta[i].remove_chars("\r\n")
	var raw:PackedStringArray = []
	for i in ta:
		if "\"" in i:
			var r:int = 0
			var instr := false
			var line:PackedStringArray = [""]
			var tord := ""
			while r < i.length():
				var ch := i[r]
				if instr:
					match ch:
						"\"":
							instr = false
							r += 1
							tord = tord.c_unescape()
							for c in tord:
								line.append(str(ord(c)))
						"\\":
							tord += ch
							tord += i[r + 1]
							r += 2
						_:
							tord += ch
							r += 1
				else:
					match ch:
						"\"":
							instr = true
							tord = ""
							r += 1
						" ":
							line.append("")
							r += 1
						_:
							line[-1] += ch
							r += 1
			assert(!instr)
			if instr:
				push_error("Imbalanced string on line: ", i)
				return
			raw.append_array(line)
		else:
			raw.append_array(i.split(" ", false))
	while raw.has(""):
		raw.erase("")
	for i in raw.size():
		var l := raw[i].to_upper()
		if BLKS.has(l):
			raw[i] = str(BLKS.find(l))
		elif REGS.has(l):
			raw[i] = str(REGS.find(l))
		else:
			for s in INSTR.size():
				if l == INSTR[s][0]:
					raw[i] = str(s)
					break
	var linecounter:int = 0
	var lbls:Dictionary[String, int] = {}
	for i in raw:
		if i[-1] == ":":
			lbls[i.remove_chars(":")] = linecounter
		else:
			linecounter += 1
	linecounter = 0
	while linecounter < raw.size():
		if raw[linecounter][-1] == ":":
			raw.remove_at(linecounter)
		else:
			linecounter += 1
	var compiled:PackedInt64Array
	for i in raw:
		if i.is_valid_int():
			compiled.append(i.to_int())
		elif i.is_valid_hex_number(true):
			compiled.append(i.hex_to_int())
		elif (i[0] == "%") and (i.erase(0) in lbls):
			compiled.append(lbls[i.erase(0)])
		else:
			print(lbls)
			push_error("invalid token: ", i)
			return
	var dat = MemoryCard.new()
	dat.data.assign(compiled)
	cpu.bios_rom = dat
	_sync_mem()
	cpu.startup()


func save_card():
	if is_instance_valid(mem):
		ResourceSaver.save(mem, filepath)
		_sync_mem()
		cpu.startup()


func _sync_mem():
	if is_instance_valid(cpu.bios_rom):
		mem = cpu.bios_rom
	else:
		mem = MemoryCard.new()
		mem.data = cpu.firm.duplicate()
		cpu.bios_rom = mem
	redraw()


func pInst(inst:int) -> void:
	mem.data.append(inst)
	redraw()


func pAddr() -> void:
	mem.data.append(int($ScrollContainer2/TabContainer/Address/SpinBox.value))
	redraw()


func pDat() -> void:
	mem.data.append(int($ScrollContainer2/TabContainer/Data/SpinBox.value))
	mem.is_dat.resize(mem.data.size())
	mem.is_dat[-1] = true
	redraw()


func edit(inst:int) -> void:
	editing = inst
	$"../PopupPanel/VBoxContainer/SpinBox".value = mem.data[inst]
	$"../PopupPanel".show()


func dedit() -> void:
	mem.data[editing] = int($"../PopupPanel/VBoxContainer/SpinBox".value)
	$"../PopupPanel".hide()
	redraw()


func ddel() -> void:
	mem.data.remove_at(editing)
	mem.is_dat.remove_at(editing)
	$"../PopupPanel".hide()
	redraw()


func _on_data_value_changed(value: float) -> void:
	if value < 1:
		return
	$ScrollContainer2/TabContainer/Data/LineEdit.text = char(int(value))


func _on_data_text_changed(new_text: String) -> void:
	if new_text.length() == 0:
		return
	$ScrollContainer2/TabContainer/Data/SpinBox.set_value_no_signal(ord(new_text[0]))


func _pString() -> void:
	for i in $ScrollContainer2/TabContainer/String/LineEdit.text:
		var v := ord(i)
		mem.data.append(v)
		mem.is_dat.resize(mem.data.size())
		mem.is_dat[-1] = true
	if $ScrollContainer2/TabContainer/String/CheckButton2.button_pressed:
		mem.data.append(ord("\r"))
		mem.data.append(ord("\n"))
		mem.is_dat.resize(mem.data.size())
		mem.is_dat[-1] = true
		mem.is_dat[-2] = true
	if $ScrollContainer2/TabContainer/String/CheckButton.button_pressed:
		mem.data.append(0)
		mem.is_dat.resize(mem.data.size())
		mem.is_dat[-1] = true
	redraw()


func _on_file_index_pressed(index: int) -> void:
	fd.filters = SAVEABLE
	match index:
		0:
			fd.filters = LOADABLE
			fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			fd.popup()
			filepath = await fd.file_selected
			load_card()
		1:
			if not ResourceLoader.exists(filepath):
				fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
				fd.popup()
				filepath = await fd.file_selected
			save_card()
		2:
			fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			fd.popup()
			filepath = await fd.file_selected
			save_card()
		4:
			filepath = ""
			mem = MemoryCard.new()
			mem.data = []
			cpu.bios_rom = mem
	redraw()
