extends Device


func _ready() -> void:
	memory = [0, 0, 0, 0, 0]


func setmem(addr:int, val:int) -> void:
	var s = self
	if s is Label:
		s.text = "(" + str(address) + ", " + str(register) + ") " + str(addr) + ", " + str(val)
		memory[addr % memory.size()] = val


func getmem(addr:int) -> int:
	if addr == 0:
		return DEVICE_DESCRIPTOR.GENERIC
	return memory[addr % memory.size()]
