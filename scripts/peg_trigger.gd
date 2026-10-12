#class_name PegTrigger

extends Area2D

signal peg_entered(a_peg: StaticBody2D)
signal peg_exited(a_peg: StaticBody2D)
signal jem_deleted(a_peg: StaticBody2D)

var jem: RigidBody2D
var is_mouse_here: bool
var parent_name: String
var shape: CollisionShape2D

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("mouse_entered", on_mouse_entered)
	connect("mouse_exited", on_mouse_exit)
	shape = get_node("shape")
	parent_name = get_parent().name
	

func _process(_delta):
	if Input.is_action_just_pressed("ui_touch") and is_mouse_here:
		on_mouse_click()
	if Input.is_action_just_released("ui_touch") and is_mouse_here:
		on_mouse_release()
	set_jem()
#	var temp_jem: RigidBody2D
#	temp_jem = overlapping_body()
#	if temp_jem != jem:
#		jem = temp_jem


func overlapping_body() -> RigidBody2D:
	var temp_jem: RigidBody2D
	if get_overlapping_bodies() != null && !get_overlapping_bodies().is_empty():
		if get_overlapping_bodies()[0].is_in_group("jem"):
			temp_jem = get_overlapping_bodies()[0]
	return temp_jem
	

func overlapping_area() -> Area2D:
	var temp_area: Area2D
	if get_overlapping_areas() != null && !get_overlapping_areas().is_empty():
		if get_overlapping_areas()[0].is_in_group("jem"):
			temp_area = get_overlapping_areas()[0]
	return temp_area


func overlapping_jem() -> RigidBody2D:
	var area = overlapping_area()
	var temp_jem: RigidBody2D
	if area != null:
		temp_jem = area.get_parent()
		if temp_jem.is_in_group("jem"):
			return temp_jem
	return null
	
func set_jem():
	var temp_jem: RigidBody2D
	temp_jem = overlapping_jem()
	if temp_jem != jem:
		jem = temp_jem

	
	
#func on_area_entered(body: RigidBody2D):
	#if (body.collision_layer != 1) and (body.linear_velocity.y > 0):
		#jem = body
		#print_jem_name(jem)


#func on_area_exited(body: RigidBody2D):
	#pass


func on_mouse_click():
	return
	#delete_jem()


func delete_jem():
	if !(jem == null || jem.is_queued_for_deletion()):
		jem.queue_free()
		jem = null
		jem_deleted.emit(get_parent())
	

func on_mouse_release():
	pass
#	print_debug("Mouse released " + parent_name)
	

func on_mouse_entered():
	is_mouse_here = true
	if jem != null:
		pass
		#print_jem_name(jem)
	else: print_debug("jem is null")
	peg_entered.emit(get_parent())


func on_mouse_exit():
	is_mouse_here = false
	peg_exited.emit(get_parent())
	
	
func print_jem_name(a_jem: RigidBody2D):
	var temp_name: String = jem_name()
	if temp_name != null:
		print(temp_name)
	else:
		print("jem is null")


#func jem_name(a_jem: RigidBody2D) -> String:
	#var sprite_name: String
	#if a_jem != null:
		#var sprite: Sprite2D = a_jem.get_node("sprite")
		#sprite_name = filename_from_path(path_from_sprite(sprite))
		##sprite_name = str(get_parent().column) + ":" + str(get_parent().row)
	#return sprite_name	


func jem_name() -> String:
	var sprite_name: String
	if jem != null:
		var sprite: Sprite2D = jem.get_node("sprite")
		sprite_name = filename_from_path(path_from_sprite(sprite))
		#sprite_name = str(get_parent().column) + ":" + str(get_parent().row)
	return sprite_name	


func filename_from_path(path: String) -> String:
	var index: int = path.rfind("/", path.length()) + 1
	path = path.erase(0, index)
	path = path.erase(path.find(".", 0), path.length())
	return path


func path_from_sprite(sprite: Sprite2D) -> String:
	return sprite.texture.resource_path
	
	
func feature_name_from_index(a_feature_index: int) -> String:
	var sprite: Sprite2D = feature_node_from_index(a_feature_index)
	var name: String = filename_from_path(path_from_sprite(sprite))
	return name


func feature_node_from_index(a_index: int) -> Sprite2D:
	var base_dir: String = "features/"
	var fname: String = "0" + str(a_index)
	var sprite: Sprite2D
	if jem != null:
		sprite = jem.get_node(base_dir + fname)
	return sprite
	
