extends StaticBody2D


var column: int

var row: int

var area: Area2D


# Called when the node enters the scene tree for the first time.
func _ready():
	area = get_node("Area2D")

	

func jem() -> RigidBody2D:
	#var area: Area2D = get_node("Area2D")
	if !(area.jem == null || area.jem.is_queued_for_deletion()):
		return area.jem
	return null
	

func select_jem(a_is_select: bool):
	if jem() != null:
		jem().set_is_selected(a_is_select)
		

func destroy_self():
	if jem() != null:
		jem().queue_free()
	queue_free()
