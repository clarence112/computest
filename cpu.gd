class_name CPU
extends Node


const STACKSIZE:int = 128
const RAMSIZE:int = 65536
var loops:int = 10


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
	OR,
	NOT,
	XOR,
	AND,
	BSL,
	BSR,
	BCPY,
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


func adddev(d:Device):
	devs.push_back(d)
	d.address = devs.size()


func _fmtout():
	$"../Label".text = (
		"A       " + str(regs[0]) +
		"\nB       " + str(regs[1]) +
		"\nC       " + str(regs[2]) +
		"\nD       " + str(regs[3]) +
		"\nSA      " + str(regs[4]) +
		"\nSB      " + str(regs[5]) +
		"\nSC      " + str(regs[6]) +
		"\nSD      " + str(regs[7]) +
		"\nACCA    " + str(regs[8]) +
		"\nACCB    " + str(regs[9]) +
		"\nDEVADDR " + str(regs[10]) +
		"\nDEVBUF  " + str(regs[11]) +
		"\nPCOUNT  " + str(regs[12]) +
		"\nALUMODE " + str(regs[13])
	)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ram.resize(RAMSIZE)
	adddev($"../simpledev")
	startup()


func startup() -> void:
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


# Called every frame. 'delta' is the elapsed time since the previous frame.
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
					for i in clampi(ope, 0, 1024):
						var val:int = 0
						if opa == RAM:
							val = gram(opb + i)
						elif opa == DEV:
							val = gdev().getmem(opb + i)
						if opc == RAM:
							sram(opd + i, val)
						elif opc == DEV:
							gdev().setmem(opd + i, val)
					pc += 6
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
					regs[ACCA] = floori(regs[A] / regs[B])
					regs[ACCB] = floori(regs[C] / regs[D])
					regs[ACCC] = floori(regs[A] / regs[C])
					regs[ACCD] = floori(regs[B] / regs[D])
				MOD:
					regs[ACCA] = regs[A] % regs[B]
					regs[ACCB] = regs[C] % regs[D]
					regs[ACCC] = regs[A] % regs[C]
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
				ADD, _:
					regs[ACCA] = regs[A] + regs[B]
					regs[ACCB] = regs[C] + regs[D]
		_fmtout()
		$"../Label2".text = str(stack)


func run() -> void:
	#OS.alert("test")
	running = true
