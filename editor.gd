extends HSplitContainer


@export var lineNumCol:Color
@export var instrCol:Color
@export var regCol:Color
@export var addrCol:Color
@export var datCol:Color
@export var blkCol:Color


enum {
	INST,
	REG,
	ADDR,
	DAT,
	BLK,
}


const INSTR:Array = [
	["NOP", []],
	["MOV", [REG, REG]],
	["SET", [REG, DAT]],
	["JMP", [ADDR]],
	["JLT", [ADDR]],
	["JGT", [ADDR]],
	["JEQ", [ADDR]],
	["JSR", [ADDR]],
	["RET", []],
	["ADD", []],
	["SUB", []],
	["MUL", []],
	["DIV", []],
	["MOD", []],
	["OR", []],
	["NOT", []],
	["XOR", []],
	["AND", []],
	["BSL", []],
	["BSR", []],
	["BCPY", [BLK, ADDR, BLK, ADDR, DAT]],
	["PUSH", [REG, BLK, ADDR]],
	["PULL", [BLK, ADDR, REG]],
	["HLT", [DAT]],
	["XCPT", []],
]
const REGS := [
	"A", "B", "C", "D", "SA", "SB", "SC", "SD",
	"ACCA", "ACCB", "DEVADDR", "DEVBUF", "PCOUNT",
	"ALUMODE"
]
const BLKS := [
	"RAM", "DEV",
]


var mem:Array[int] = []
var isdat:Array[bool] = []
var editing:int = 0


@onready var linens:VBoxContainer = $ScrollContainer/HBoxContainer/VBoxContainer
@onready var lines:VBoxContainer = $ScrollContainer/HBoxContainer/VBoxContainer2
@onready var tabs:TabContainer = $ScrollContainer2/TabContainer


func redraw() -> void:
	isdat.resize(mem.size())
	for i in linens.get_children():
		i.queue_free()
	for i in lines.get_children():
		i.queue_free()
	var i:int = 0
	var intrtypes:Array[int]
	var curline:HBoxContainer
	while i < mem.size():
		var val = mem[i]
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
			if isdat[i] or val >= INSTR.size():
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
		var b := Button.new()
		$ScrollContainer2/TabContainer/Instructions.add_child(b)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", instrCol)
		b.text = inst
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
	mem = $"../main/cpu".ram
	redraw()


func pInst(inst:int) -> void:
	mem.append(inst)
	redraw()


func pAddr() -> void:
	mem.append(int($ScrollContainer2/TabContainer/Address/SpinBox.value))
	redraw()


func pDat() -> void:
	mem.append(int($ScrollContainer2/TabContainer/Data/SpinBox.value))
	isdat.resize(mem.size())
	isdat[-1] = true
	redraw()


func edit(inst:int) -> void:
	editing = inst
	$"../PopupPanel/VBoxContainer/SpinBox".value = mem[inst]
	$"../PopupPanel".popup()


func dedit() -> void:
	mem[editing] = int($"../PopupPanel/VBoxContainer/SpinBox".value)
	$"../PopupPanel".hide()
	redraw()


func ddel() -> void:
	mem.remove_at(editing)
	isdat.remove_at(editing)
	$"../PopupPanel".hide()
	redraw()
