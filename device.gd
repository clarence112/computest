class_name Device
extends Label


var address:int = 0
var register:int = 0


var memory:Array[int] = [0, 0, 0, 0, 0]


func setmem(addr:int, val:int) -> void:
	text = "(" + str(address) + ", " + str(register) + ") " + str(addr) + ", " + str(val)
	memory[addr % memory.size()] = val


func getmem(addr:int) -> int:
	return memory[addr % memory.size()]
