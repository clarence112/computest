extends Control


const charset:BitMap = preload("uid://b8mexmlpu5htb")


@export var on := Color(0xCCF8F2FF)
@export var off := Color(0x4a4c41ff)


var children:Array[ColorRect] = []
var letter:String = "A"


func _ready() -> void:
	children.assign(get_child(0).get_children())


func _process(delta: float) -> void:
	var id := ord(letter) % 256
	var char_pos = Vector2i(id % 10, floori(id / 10.0)) * Vector2i(5, 7)
	for i in children.size():
		var child := children[i]
		var subchar:Vector2i = Vector2i(i % 5, floori(i / 5.0)) + char_pos
		var value := int(charset.get_bit(subchar.x, subchar.y))
		child.color = child.color.lerp(off.lerp(on, value), delta * 10)
