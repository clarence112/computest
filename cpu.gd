class_name CPU
extends Node


const STACKSIZE:int = 128
const RAMSIZE:int = 65536
var loops:int = 1000
@export var loadmode := true
@export var bios_rom:MemoryCard


enum {
	A,
	B,
	C,
	D,
	SA,
	SB,
	SC,
	SD,
	ACCA,
	ACCB,
	ACCC,
	ACCD,
	DEVADDR,
	DEVBUF,
	PCOUNT,
	ALUMODE,
	JREL,
}
var regs:Array[int] = [
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
]
enum {
	RAM,
	DEV,
}
enum {
	NOP,
	MOV,
	SET,
	JMP,
	JLT,
	JGT,
	JEQ,
	JSR,
	RET,
	ADD,
	SUB,
	MUL,
	DIV,
	MOD,
	FPADD,
	FPSUB,
	FPMUL,
	FPDIV,
	FPMOD,
	FLR,
	CIL,
	RND,
	ITF,
	OR,
	NOT,
	XOR,
	AND,
	BSL,
	BSR,
	BCPY,
	BWRT,
	PUSH,
	PULL,
	HLT,
	XCPT,
}
enum {
	SOK,
	SSTACKOVERFLOW
}


var ram:PackedInt64Array = []

var firm:Array[int] = [
	ADD,				#0
	SET, DEVADDR, 0,	#1
	SET, A, 0,			#4
	SET, B, 1000,		#7
	SET, C, 0,			#10
	SET, D, 1,			#13
	MOV, ACCB, A,		#16
	JGT, 30,			#19
	MOV, ACCB, C,		#21
	PUSH, A, DEV, 0,	#24
	JMP, 16,			#28
	HLT,				#30
]


var stack:Array[int] = []
var pc:int = 0
var running := false
var stat:int = SOK
var devs:Array[Device] = []
var convhold:PackedByteArray = []


func adddev(d:Device) -> void:
	devs.push_back(d)
	d.address = devs.size()


func _fmtout():
	$"../Label".text = (
		"A       " + str(regs[A]) +
		"\nB       " + str(regs[B]) +
		"\nC       " + str(regs[C]) +
		"\nD       " + str(regs[D]) +
		"\nSA      " + str(regs[SA]) +
		"\nSB      " + str(regs[SB]) +
		"\nSC      " + str(regs[SC]) +
		"\nSD      " + str(regs[SD]) +
		"\nACCA    " + str(regs[ACCA]) +
		"\nACCB    " + str(regs[ACCB]) +
		"\nACCC    " + str(regs[ACCC]) +
		"\nACCD    " + str(regs[ACCD]) +
		"\nDEVADDR " + str(regs[DEVADDR]) +
		"\nDEVBUF  " + str(regs[DEVBUF]) +
		"\nPCOUNT  " + str(regs[PCOUNT]) +
		"\nALUMODE " + str(regs[ALUMODE]) +
		"\nStatus  " + str(stat)
	)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ram.resize(RAMSIZE)
	convhold.resize(8)
	adddev($"../simpledev")
	startup()


func startup() -> void:
	if loadmode && is_instance_valid(bios_rom):
		firm = bios_rom.data.duplicate()
	for i in firm.size():
		ram[i] = firm[i]


func gram(addr:int) -> int:
	var s = ram.size()
	if addr >= s:
		return randi_range(NOP, XCPT + 1)
	else:
		return ram[addr]


func sram(addr:int, val:int) -> void:
	var s = ram.size()
	if addr < s:
		ram[addr] = val


func gdev() -> Device:
	return devs[regs[DEVADDR] % devs.size()]


func _process(_delta: float) -> void:
	if running:
		for _i in loops:
			gdev().register = regs[DEVBUF]
			var instr = gram(pc)
			var opa = gram(pc + 1)
			var opb = gram(pc + 2)
			var opc = gram(pc + 3)
			var opd = gram(pc + 4)
			var ope = gram(pc + 5)
			regs[PCOUNT] = pc
			match instr:
				NOP:
					pc += 1
				MOV:
					opa = clampi(opa, 0, regs.size() - 1)
					opb = clampi(opb, 0, regs.size() - 1)
					regs[opb] = regs[opa]
					pc += 3
				SET:
					regs[opa] = opb
					pc += 3
				JMP:
					if regs[JREL] == 0:
						pc = opa
					else:
						pc += opa
				JLT:
					if regs[A] < regs[B]:
						if regs[JREL] == 0:
							pc = opa
						else:
							pc += opa
					else:
						pc += 2 
				JGT:
					if regs[A] > regs[B]:
						if regs[JREL] == 0:
							pc = opa
						else:
							pc += opa
					else:
						pc += 2
				JEQ:
					if regs[A] == regs[B]:
						if regs[JREL] == 0:
							pc = opa
						else:
							pc += opa
					else:
						pc += 2
				JSR:
					stack.push_back(pc + 1)
					if regs[JREL] == 0:
						pc = opa
					else:
						pc += opa
					var s = stack.size()
					if s > STACKSIZE:
						running = false
						stat = SSTACKOVERFLOW
				RET:
					var s = stack.size()
					if s > STACKSIZE:
						running = false
						stat = SSTACKOVERFLOW
					elif s > 0:
						pc = stack.pop_back()
					else:
						pc = randi_range(0, ram.size())
				ADD:
					regs[ALUMODE] = ADD
					pc += 1
				SUB:
					regs[ALUMODE] = SUB
					pc += 1
				MUL:
					regs[ALUMODE] = MUL
					pc += 1
				DIV:
					regs[ALUMODE] = DIV
					pc += 1
				MOD:
					regs[ALUMODE] = MOD
					pc += 1
				OR:
					regs[ALUMODE] = OR
					pc += 1
				NOT:
					regs[ALUMODE] = NOT
					pc += 1
				XOR:
					regs[ALUMODE] = XOR
					pc += 1
				AND:
					regs[ALUMODE] = AND
					pc += 1
				BSL:
					regs[ALUMODE] = BSL
					pc += 1
				BSR:
					regs[ALUMODE] = BSR
					pc += 1
				BCPY:
					var dev := gdev()
					for i in clampi(ope, 0, 1024):
						var val:int = 0
						if opa == RAM:
							val = gram(opb + i)
						elif opa == DEV:
							val = dev.getmem(opb + i)
						if opc == RAM:
							sram(opd + i, val)
						elif opc == DEV:
							dev.setmem(opd + i, val)
					pc += 6
				BWRT:
					var dev := gdev()
					for i in clampi(ope, 0, 1024):
						var val:int = 0
						if opa == RAM:
							val = gram(opb + i)
						elif opa == DEV:
							val = dev.getmem(opb)
						if opc == RAM:
							sram(opd + i, val)
						elif opc == DEV:
							dev.setmem(opd, val)
				PUSH:
					opa = clampi(opa, 0, regs.size() - 1)
					if opb == RAM:
						sram(opc, regs[opa])
					elif opb == DEV:
						gdev().setmem(opc, regs[opa])
					pc += 4
				PULL:
					opc = clampi(opc, 0, regs.size() - 1)
					if opa == RAM:
						regs[opc] = gram(opb)
					elif opa == DEV:
						regs[opc] = gdev().getmem(opb)
					pc += 4
				HLT:
					running = false
					stat = opa
					pc += 2
					break
				XCPT, _:
					running = false
					break
			match regs[ALUMODE]:
				SUB:
					regs[ACCA] = regs[A] - regs[B]
					regs[ACCB] = regs[C] - regs[D]
					regs[ACCC] = regs[A] - regs[C]
					regs[ACCD] = regs[B] - regs[D]
				MUL:
					regs[ACCA] = regs[A] * regs[B]
					regs[ACCB] = regs[C] * regs[D]
					regs[ACCC] = regs[A] * regs[C]
					regs[ACCD] = regs[B] * regs[D]
				DIV:
					if regs[B] != 0:
						@warning_ignore("integer_division")
						regs[ACCA] = floori(regs[A] / regs[B])
					if regs[D] != 0:
						@warning_ignore("integer_division")
						regs[ACCB] = floori(regs[C] / regs[D])
					if regs[C] != 0:
						@warning_ignore("integer_division")
						regs[ACCC] = floori(regs[A] / regs[C])
					if regs[D] != 0:
						@warning_ignore("integer_division")
						regs[ACCD] = floori(regs[B] / regs[D])
				MOD:
					if regs[B] != 0:
						regs[ACCA] = regs[A] % regs[B]
					if regs[D] != 0:
						regs[ACCB] = regs[C] % regs[D]
					if regs[C] != 0:
						regs[ACCC] = regs[A] % regs[C]
					if regs[D] != 0:
						regs[ACCD] = regs[B] % regs[D]
				OR:
					regs[ACCA] = regs[A] | regs[B]
					regs[ACCB] = regs[C] | regs[D]
					regs[ACCC] = regs[A] | regs[C]
					regs[ACCD] = regs[B] | regs[D]
				NOT:
					regs[ACCA] = ~ regs[A]
					regs[ACCB] = ~ regs[C]
					regs[ACCC] = ~ regs[A]
					#Why A a second time? ACCC operates on A+C,
					#but NOT takes only one number. Since A is the
					#"primary" of the pair, it shows up twice.
					#Weird hardware quirks? Just accept the fanasy of it all.
					regs[ACCD] = ~ regs[B]
				XOR:
					regs[ACCA] = regs[A] ^ regs[B]
					regs[ACCB] = regs[C] ^ regs[D]
					regs[ACCC] = regs[A] ^ regs[C]
					regs[ACCD] = regs[B] ^ regs[D]
				AND:
					regs[ACCA] = regs[A] & regs[B]
					regs[ACCB] = regs[C] & regs[D]
					regs[ACCC] = regs[A] & regs[C]
					regs[ACCD] = regs[B] & regs[D]
				BSL:
					regs[ACCA] = regs[A] << regs[B]
					regs[ACCB] = regs[C] << regs[D]
					regs[ACCC] = regs[A] << regs[C]
					regs[ACCD] = regs[B] << regs[D]
				BSR:
					regs[ACCA] = regs[A] >> regs[B]
					regs[ACCB] = regs[C] >> regs[D]
					regs[ACCC] = regs[A] >> regs[C]
					regs[ACCD] = regs[B] >> regs[D]
				FPADD, FPSUB, FPMUL, FPDIV, FPMOD, FLR, CIL, RND, ITF:
					var tA := raw_to_float(regs[A])
					var tB := raw_to_float(regs[B])
					var tC := raw_to_float(regs[C])
					var tD := raw_to_float(regs[D])
					var tACCA:float
					var tACCB:float
					var tACCC:float
					var tACCD:float
					var conv := true
					match regs[ALUMODE]:
						FPADD:
							tACCA = tA + tB
							tACCB = tC + tD
							tACCC = tA + tC
							tACCD = tB + tD
						FPSUB:
							tACCA = tA - tB
							tACCB = tC - tD
							tACCC = tA - tC
							tACCD = tB - tD
						FPMUL:
							tACCA = tA * tB
							tACCB = tC * tD
							tACCC = tA * tC
							tACCD = tB * tD
						FPDIV:
							if tB != 0.0:
								tACCA = tA / tB
							if tD != 0.0:
								tACCB = tC / tD
							if tC != 0.0:
								tACCC = tA / tC
							if tD != 0.0:
								tACCD = tB / tD
						FPMOD:
							if tB != 0.0:
								tACCA = fmod(tA, tB)
							if tD != 0.0:
								tACCB = fmod(tC, tD)
							if tC != 0.0:
								tACCC = fmod(tA, tC)
							if tD != 0.0:
								tACCD = fmod(tB, tD)
						FLR:
							conv = false
							regs[ACCA] = floori(tA)
							regs[ACCB] = floori(tC)
							regs[ACCC] = floori(tA)
							regs[ACCD] = floori(tB)
						CIL:
							conv = false
							regs[ACCA] = ceili(tA)
							regs[ACCB] = ceili(tC)
							regs[ACCC] = ceili(tA)
							regs[ACCD] = ceili(tB)
						RND:
							conv = false
							regs[ACCA] = roundi(tA)
							regs[ACCB] = roundi(tC)
							regs[ACCC] = roundi(tA)
							regs[ACCD] = roundi(tB)
						ITF:
							tACCA = float(regs[A])
							tACCB = float(regs[C])
							tACCC = float(regs[A])
							tACCD = float(regs[B])
					if conv:
						regs[ACCA] = float_to_raw(tACCA)
						regs[ACCB] = float_to_raw(tACCB)
						regs[ACCC] = float_to_raw(tACCC)
						regs[ACCD] = float_to_raw(tACCD)
				ADD, _:
					regs[ACCA] = regs[A] + regs[B]
					regs[ACCB] = regs[C] + regs[D]
					regs[ACCC] = regs[A] + regs[C]
					regs[ACCD] = regs[B] + regs[D]
		_fmtout()
		$"../Label2".text = str(stack)


func float_to_raw(i:float) -> int:
	convhold.encode_double(0, i)
	return convhold.decode_s64(0)


func raw_to_float(i:int) -> float:
	convhold.encode_s64(0, i)
	return convhold.decode_double(0)


func run() -> void:
	#OS.alert("test")
	running = true
