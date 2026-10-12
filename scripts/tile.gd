extends RigidBody2D


var is_selected: bool
var selection_sprite: Sprite2D


func _ready():
	selection_sprite = get_node("hightlight")


func _integrate_forces(state):
	var vel = state.get_linear_velocity ()
	state.set_linear_velocity (Vector2 (0, vel.y))


func set_frozen(a_is_frozen):
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = a_is_frozen


func feature_node_from_index(a_index: int) -> Sprite2D:
	var base_dir: String = "features/"
	var fname: String = "0" + str(a_index)
	var sprite: Sprite2D
	sprite = get_node(base_dir + fname)
	return sprite


func set_is_selected(a_is_selected: bool):
	is_selected = a_is_selected
	selection_sprite.set_visible(is_selected)
	
