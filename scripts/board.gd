extends Node2D

#size is actual width and height (as opposed to tile count)
signal pegs_positioned(size: Vector2)
signal jems_requested(a_jem_count: int)
signal no_matches_found()

#region Globals 
var pegs: Array[Array]
var new_jems: Array[RigidBody2D]
var missing_jems: Array[StaticBody2D]
var blocks: Array[StaticBody2D]
var size: Vector2i
var is_jems_requested: bool
var is_jem_request_fulfilled: bool
var tile_width: float
var spacing: float
var padding: float = 0.1
var swap_time: float = 0.2
var fall_timer: Timer
const fall_time: float = 1.0
var is_poling_available: bool
var is_falling_long_enough: bool
var is_initialized: bool
var swap_peg: StaticBody2D
var swap_co_peg: StaticBody2D
var peg_under_mouse: StaticBody2D
var all_peg_sets: Array[Array]
var all_matched_sets: Array[Array]
enum BoardState {STATIC, FALLING, SWAPPING}
var board_state: BoardState
const feature_count: int = 4
var match_logic_type: int = 0
var all_potential_triplets: Dictionary #Actually Dictionary{Vector2i:Array[Array[StaticBody2D]]}
var hint_pegs: Array[StaticBody2D]

#endregion


#region Initialization
# Called when the node enters the scene tree for the first time.
func _ready():
	missing_jems = []
	missing_jems.clear()
	all_peg_sets = []
	all_matched_sets = []
	fall_timer = Timer.new()
	fall_timer.connect("timeout", on_fall_timer_timeout)
	add_child(fall_timer)
	set_board_state(BoardState.FALLING)


func initialize(a_pegs: Array[StaticBody2D], a_blocks: Array[StaticBody2D], a_size: Vector2):
	if is_non_empty_array(a_pegs) && a_size != null && a_pegs.size() == (a_size.x * a_size.y):
		clear_board()
		size = a_size
		blocks = a_blocks
		setup_2d_pegs_array(a_pegs)
		define_scale(pegs[0][0])
		setup_peg_sets()
		is_initialized = true
		load_all_potential_triplets()


func clear_board():
	var children: Array = get_children()
	for n in get_children():
		if n.is_in_group("peg"):
			n.destroy_self()
		if n.is_in_group("boarder_block"):
			n.queue_free()
		if n.is_in_group("jem"):
			n.queue_free()

func setup_2d_pegs_array(a_pegs: Array[StaticBody2D]):
	pegs = new_n_x_m_array(size)
	var index: int = 0
	var i_peg: StaticBody2D
	for i_row: int in range(size.y):
		for i_col: int in range(size.x):
			index = i_row * size.x + i_col
			i_peg = a_pegs[index]
			i_peg.column = i_col
			i_peg.row = i_row
			pegs[i_col][i_row] = i_peg


func setup_peg_sets():
	all_peg_sets = []
	var i_set: Array[Array]
	for col: Array[StaticBody2D] in pegs:
		for peg: StaticBody2D in col:
			i_set = jem_sets_to_evaluate(peg)
			for ii_set in i_set:
				all_peg_sets.append(ii_set)


#Returns a set of sets of jems; each set of jems is to be evaluated as a possilbe matched set	
func jem_sets_to_evaluate(a_seed_peg: StaticBody2D) -> Array[Array]:
	var set_of_sets: Array[Array] = []
	var i_set: Array[StaticBody2D]
	for count: int in [3, 4, 5]:
		i_set = linear_set(a_seed_peg, count, true)
		if i_set.size() == count:
			set_of_sets.append(i_set)
	for count: int in [3, 4, 5]:
		i_set = linear_set(a_seed_peg, count, false)
		if i_set.size() == count:
			set_of_sets.append(i_set)
	return set_of_sets


func setup_tiles():
	setup_pegs()
	setup_blocks()
	pole_pegs_for_missing_jems()


func setup_pegs():
	var width: int = size.x
	var height: int = size.y
	var area: Area2D
	for row: Array[StaticBody2D] in pegs:
		for peg: StaticBody2D in row:
			area = peg.get_node("Area2D")
			area.peg_entered.connect(on_peg_entered)
			area.peg_exited.connect(on_peg_exited)
			area.jem_deleted.connect(on_delete_jem)
			add_child(peg)
			peg.position = Vector2(peg.column * spacing, peg.row * spacing)	
	pegs_positioned.emit(Vector2(width * spacing, height * spacing))	


func on_delete_jem(_a_peg: StaticBody2D):
	is_poling_available = true
	

func set_match_type(a_type: int):
	match_logic_type = a_type
	do_matching()


func setup_blocks():
	var block: StaticBody2D
	var index: int = 0
	var width: int = size.x
	var height: int = size.y
	for i in height:
		block = blocks[index]
		add_child(block)
		block.position = Vector2(-1 * spacing, i * spacing)
		index = index + 1
	for i in height:
		block = blocks[index]
		add_child(block)
		block.position = Vector2(width * spacing, i * spacing)
		index = index + 1
	for i in (width + 2):
		block = blocks[index]
		add_child(block)
		block.position = Vector2((i - 1) * spacing, height * spacing)
		index = index + 1
	for i in (width + 2):
		block = blocks[index]
		add_child(block)
		make_block_ethereal(block)
		block.position = Vector2((i - 1) * spacing, -1 * spacing)
		index = index + 1


func make_block_ethereal(a_block: StaticBody2D):
	a_block.collision_layer = 5
	a_block.get_node("sprite").z_index = 5


func place_jems():
	var column_counts = [0]	#index == column; value == count
	column_counts.resize(size.x)
	column_counts.fill(0)
	var col: int
	var value: int
	for i_peg: StaticBody2D in missing_jems:
		col = i_peg.column
		value = column_counts[col]
		column_counts[col] = value + 1
	#Go through column_counts - each item is a loop length, to add jems to the referenced column (the current index)
	var index: int = 0	#Index in jems
	var col_num: int = 0	#current column
	for i_col in column_counts: 
		for i_th in i_col:
			add_jem_to_column(new_jems[index], col_num, i_th)
			index = index + 1
		col_num = col_num + 1


#endregion


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if board_state == BoardState.FALLING && is_all_jems_sleeping():
		set_board_state(BoardState.STATIC)
	if is_poling_available:
		pole_pegs_for_missing_jems()
	if is_jems_requested && is_jem_request_fulfilled:
		is_jems_requested = false
		is_jem_request_fulfilled = false
		place_jems()
	process_clicks()


func process_clicks():
#	if board_state == BoardState.FALLING || board_state == BoardState.SWAPPING:
	if board_state == BoardState.SWAPPING || board_state == BoardState.FALLING:
		return
	if Input.is_action_just_pressed("ui_touch"):
		swap_peg = peg_under_mouse
		if swap_peg != null:
			clear_jem_selections()
			swap_peg.jem().set_is_selected(true)
	if Input.is_action_just_released("ui_touch"):
		swap_co_peg = peg_under_mouse
	if is_swapable_pair():
		clear_jem_selections()
		set_board_state(BoardState.SWAPPING)
		swap_jems(swap_peg, swap_co_peg)



#region Swapping and Matching
func is_swapable_pair() -> bool:
	if swap_peg == null || swap_co_peg == null:
		return false
	#Check to see pegs are neighbors
	var is_neighbors: bool
	is_neighbors = is_adjacent(Vector2(swap_peg.column, swap_peg.row), Vector2(swap_co_peg.column, swap_co_peg.row))
	return is_neighbors


func swap_jems(a_peg: StaticBody2D, a_co_peg: StaticBody2D):
	var jem: RigidBody2D = a_peg.get_node("Area2D").jem
	var co_jem: RigidBody2D = a_co_peg.get_node("Area2D").jem
	if jem == null || co_jem == null:
		return
	var tween = get_tree().create_tween()
	var co_tween = get_tree().create_tween()
	var jem_pos: Vector2 = jem.position
	var co_jem_pos: Vector2 = co_jem.position
	tween.finished.connect(on_swap_finished)
	tween.tween_property(jem, 'position', co_jem_pos, swap_time)
	co_tween.tween_property(co_jem, 'position', jem_pos, swap_time)


func unswap_jems(a_peg: StaticBody2D, a_co_peg: StaticBody2D):
	var jem: RigidBody2D = a_peg.get_node("Area2D").jem
	var co_jem: RigidBody2D = a_co_peg.get_node("Area2D").jem
	if jem == null || co_jem == null:
		return
	var tween = get_tree().create_tween()
	var co_tween = get_tree().create_tween()
	var jem_pos: Vector2 = jem.position
	var co_jem_pos: Vector2 = co_jem.position
	tween.tween_property(jem, 'position', co_jem_pos, swap_time)
	co_tween.tween_property(co_jem, 'position', jem_pos, swap_time)


func on_swap_finished():
	find_matched_sets()
	if is_match_found():
		process_matches()
	else:
		unswap_jems(swap_peg, swap_co_peg)
	set_board_state(BoardState.FALLING)	
	swap_peg = null
	swap_co_peg = null
#	

func is_match_found() -> bool:
	return !all_matched_sets.is_empty()


func do_matching():
	find_matched_sets()
	process_matches()



#endregion


#region Helpers

func new_n_x_m_array(a_size: Vector2) -> Array[Array]:
	var new_array: Array[Array] = []
	var row: Array[StaticBody2D]
	for n: int in range(a_size.x):
		row = []
		for m: int in range(a_size.y):
			row.append(null)
		new_array.append(row)
	return new_array


func print_peg_sets():
	var names: String = ""
	@warning_ignore("unused_variable")
	var area: Area2D
	for i_row: Array[StaticBody2D] in all_peg_sets:
		for i_peg in i_row:
			area = i_peg.get_node("Area2D")
			names = names + "[" + str(i_peg.column) + ":" + str(i_peg.row) + "]" + " "
		print(names)
		names = ""


func is_non_empty_array(a_array: Array) -> bool:
	return (a_array != null && !a_array.is_empty())


#endregion

#Add a jem to a_column column above the board, at stacked position a_ith
func add_jem_to_column(a_jem: RigidBody2D, a_column: int, a_ith: int):
	add_child(a_jem)
	a_jem.position = Vector2(a_column * spacing, -(a_ith + 2) * spacing)


#Check each peg for a null jem and log peg index in missing_jems
func pole_pegs_for_missing_jems():
	missing_jems.clear()
	var area: Area2D
	for row: Array[StaticBody2D] in pegs:
		for peg: StaticBody2D in row:
			area = peg.get_node("Area2D")
			if area.jem == null:
				missing_jems.append(peg)
	if !missing_jems.is_empty():
		request_jems()
		set_board_state(BoardState.FALLING)
	set_is_poling_available(false)


func set_all_jems_frozen(a_is_frozen: bool):
	var t_jems: Array[RigidBody2D] = current_jems()
	for jem: RigidBody2D in t_jems:
		jem.set_frozen(a_is_frozen)
	if a_is_frozen:
		align_all_jems()
			

func align_all_jems():
	var jem: RigidBody2D
	for row: Array[StaticBody2D] in pegs:
		for i_peg: StaticBody2D in row:
			jem = i_peg.jem()
			if jem != null:
				jem.position = i_peg.position


func current_jems() -> Array[RigidBody2D]:
	var jems: Array[RigidBody2D] = []
	for row: Array[StaticBody2D] in pegs:
		for peg: StaticBody2D in row:
			if !(peg.jem() == null || peg.jem().is_queued_for_deletion()):
				jems.append(peg.jem())
	return jems


#Send out a signal that jems are needed
func request_jems():
	jems_requested.emit(missing_jems.size())
	is_jems_requested = true
	set_is_poling_available(false)
	

#Accept the jems requested by request_jems()
func accept_jems(a_jems: Array[RigidBody2D]):
	new_jems = a_jems
	is_jem_request_fulfilled = true


# Takes a tile.tcsn and uses its width to set scale
func define_scale(tile: StaticBody2D):
	tile_width = tile.get_node("peg_shape").shape.get_rect().size.x
	spacing = tile_width + padding
	print_debug("peg width: " + str(tile_width))


func is_adjacent(a_vec1: Vector2i, a_vec2: Vector2i) -> bool:
	var value: int = absi(a_vec1.x - a_vec2.x) + abs(a_vec1.y - a_vec2.y)
	return value == 1


func resize_peg(a_peg: RigidBody2D):
	var col_shape: CollisionShape2D = a_peg.get_node("peg_shape")
	var trig_shape: CollisionShape2D = a_peg.get_node("Area2D/shape")
	var sprite: Sprite2D = a_peg.get_node("Sprite2D")
	col_shape.shape.extents = Vector2(30, 30)
	trig_shape.shape.extents = Vector2(20, 20)
	sprite.scale = Vector2(0.5, 0.5)


func on_fall_timer_timeout():
	fall_timer.stop()
	is_falling_long_enough = true


#Does every peg have a sleeping jem? (null jems count as not sleeping)
func is_all_jems_sleeping() -> bool:
	var is_all_sleeping: bool = false
	var area: Area2D
	if is_initialized:
		is_all_sleeping = true
		var jem: RigidBody2D
		for row: Array[StaticBody2D] in pegs:
			for i_peg: StaticBody2D in row:
				area = i_peg.get_node("Area2D")
				if area.jem == null || area.jem.is_queued_for_deletion():
					jem = null
				else:
					jem = i_peg.get_node("Area2D").jem
				is_all_sleeping = jem != null && is_jem_sleeping(jem)
				if !is_all_sleeping:
					return false
	return is_all_sleeping
	

func is_jem_sleeping(a_jem: RigidBody2D) -> bool:
	if a_jem == null:
		return false
	return abs(a_jem.linear_velocity.y) < 2.0
	

func set_is_poling_available(a_is_available: bool):
	is_poling_available = a_is_available


func is_board_state_static() -> bool:
	return board_state == BoardState.STATIC


func set_board_state(a_state: BoardState):
	board_state = a_state
	#print_debug("board_State: " + str(a_state))
	if board_state == BoardState.STATIC:
		set_all_jems_frozen(false)
		set_is_poling_available(true)
		do_matching()
	if board_state == BoardState.FALLING:
		set_all_jems_frozen(false)
		fall_timer.start(fall_time)
	if board_state == BoardState.SWAPPING:
		set_all_jems_frozen(true)
		#set_all_jems_frozen(false)
		
		
func on_peg_entered(a_peg: StaticBody2D):
	peg_under_mouse = a_peg


func on_peg_exited(_a_peg: StaticBody2D):
	peg_under_mouse = null
		


#region Matching
func is_matching_set(a_pegs: Array[StaticBody2D]) -> bool:
	return is_contiguous_set(a_pegs) && is_linear_set(a_pegs) && is_match_by_value(a_pegs)
	#return is_contiguous_set(a_pegs) && is_linear_set(a_pegs) && is_complex_match_by_value(a_pegs)
	

func is_horizontal_set(a_pegs: Array[StaticBody2D]) -> bool:
	for i: int in range(1, a_pegs.size()):
		if a_pegs[i - 1].row != a_pegs[i].row:
			return false
	return true


func is_vertical_set(a_pegs: Array[StaticBody2D]) -> bool:
	for i: int in range(1, a_pegs.size()):
		if a_pegs[i - 1].column != a_pegs[i].column:
			return false
	return true


func is_linear_set(a_pegs: Array[StaticBody2D]) -> bool:
	return is_horizontal_set(a_pegs) || is_vertical_set(a_pegs)


func is_match_by_value(a_pegs: Array[StaticBody2D]) -> bool:
	if match_logic_type == 0:
		return is_complex_match_by_value(a_pegs)
	if match_logic_type == 1:
		return is_simple_match_by_value(a_pegs)
	if match_logic_type == 2:
		return is_quasi_match_by_value(a_pegs)
	if match_logic_type == 3:
		return is_strict_match_by_value(a_pegs)
	return false


# Matches based on sprite object as opposed to feature sprites
func is_match_by_name_value(a_pegs: Array[StaticBody2D]) -> bool:
	var area: Area2D = a_pegs[0].area
	var first_name: String = area.jem_name()
	for i_peg: StaticBody2D in a_pegs:
		if i_peg.area.jem_name() != first_name:
			return false
	return true
	
# All alleles must match or none match to make a meta-match
func is_complex_match_by_value(a_pegs: Array[StaticBody2D]) -> bool:
	var allel_list: Array[String] = []
	for index: int in range(feature_count):
		allel_list.clear()
		for peg: StaticBody2D in a_pegs:
			allel_list.append(peg.area.feature_name_from_index(index))
		if !is_allele_complex_match_by_value(allel_list):
			return false
	return true

# No alleles must match to make a meta-match
func is_simple_match_by_value(a_pegs: Array[StaticBody2D]) -> bool:
	var allel_list: Array[String] = []
	for index: int in range(feature_count):
		allel_list.clear()
		for peg: StaticBody2D in a_pegs:
			allel_list.append(peg.area.feature_name_from_index(index))
		if !is_allele_simple_match_by_value(allel_list):
			return false
	return true


#If all pegs match excactly (like regualr match 3), return true
func is_strict_match_by_value(a_pegs: Array[StaticBody2D]) -> bool:
	var match_count: int = 0
	var allel_list: Array[String] = []
	for index: int in range(feature_count):
		allel_list.clear()
		for peg: StaticBody2D in a_pegs:
			allel_list.append(peg.area.feature_name_from_index(index))
		if !is_strict_allele_match(allel_list):
			return false
	return true


#If at least two allele sets strictly match, return true
func is_quasi_match_by_value(a_pegs: Array[StaticBody2D]) -> bool:
	var match_count: int = 0
	var allel_list: Array[String] = []
	for index: int in range(feature_count):
		allel_list.clear()
		for peg: StaticBody2D in a_pegs:
			allel_list.append(peg.area.feature_name_from_index(index))
		if is_strict_allele_match(allel_list):
			match_count = match_count + 1
	return match_count >= 2





#If all names in a_names are the same, return true
func is_strict_allele_match(a_names: Array[String]) -> bool:
	var base_name: String = a_names[0]
	for i_name: String in a_names:
		if i_name != base_name:
			return false
	return true

#If names in a_names match in the SET sense, return true
func is_allele_complex_match_by_value(a_names: Array[String]) -> bool:
	#Check for homogenous match
	var is_homogeneous_match: bool = true
	var is_heterogenous_match: bool = true
	var base_name: String = a_names[0]
	for i_name: String in a_names:
		if i_name != base_name:
			is_homogeneous_match = false
			break
	#Check for heterogenous match
	for i: int in a_names.size():
		for j: int in a_names.size():
			if i != j && a_names[i] == a_names[j]:
				is_heterogenous_match = false
				break
	return is_heterogenous_match || is_homogeneous_match


#If all names in a_names are different, return true
func is_allele_simple_match_by_value(a_names: Array[String]) -> bool:
	var is_heterogenous_match: bool = true
	#Check for heterogenous match
	for i: int in a_names.size():
		for j: int in a_names.size():
			if i != j && a_names[i] == a_names[j]:
				is_heterogenous_match = false
				break
	return is_heterogenous_match


# Is every peg in a_pegs adjacent to some other peg in a_pegs?
func is_contiguous_set(a_pegs: Array[StaticBody2D]) -> bool:
	var temp_pegs: Array[StaticBody2D] = Array(a_pegs)
	for i_peg:StaticBody2D in a_pegs:
		if !is_any_adjacent(i_peg, temp_pegs):
			return false
	return true


# Is a_peg adjacent to any member of a_pegs?
func is_any_adjacent(a_peg: StaticBody2D, a_pegs:Array[StaticBody2D]) -> bool:
	for i_peg: StaticBody2D in a_pegs:
		if is_pair_adjacent(a_peg, i_peg):
			return true
	return false	


func is_pair_adjacent(a_peg_1, a_peg_2: StaticBody2D) -> bool:
	var coord_1: Vector2 = Vector2(a_peg_1.column, a_peg_1.row)
	var coord_2: Vector2 = Vector2(a_peg_2.column, a_peg_2.row)
	return is_adjacent(coord_1, coord_2)
	

func find_matched_sets():
	for i_set: Array[StaticBody2D] in all_peg_sets:
		if is_matching_set(i_set):
			all_matched_sets.append(i_set)
			

func process_matches():
	if !all_matched_sets.is_empty(): clear_jem_selections()
	for i_set: Array[StaticBody2D] in all_matched_sets:
		for i_peg: StaticBody2D in i_set:
			i_peg.area.delete_jem()
	all_matched_sets = []


#Set returned is up to size a_length (including a_seed_peg) in row or column direction
func linear_set(a_seed_peg: StaticBody2D, a_length: int, a_is_horizontal: bool) -> Array[StaticBody2D]:
	if a_seed_peg.column == 5:
		pass
	var peg_set: Array[StaticBody2D] = [a_seed_peg]
	var i: int = 1
	var i_peg: StaticBody2D = a_seed_peg
	while i < a_length:
		if a_is_horizontal:
			i_peg = peg_to_right(i_peg)
		else:
			i_peg = peg_below(i_peg)
		if i_peg == null:
			return peg_set
		peg_set.append(i_peg)
		i = i + 1
	return peg_set


func peg_to_right(a_seed_peg: StaticBody2D) -> StaticBody2D:
	var col: int = a_seed_peg.column + 1
	var row: int = a_seed_peg.row
	#print_debug("Column: " + str(col))
	if col < size.x:
		return pegs[col][row]
	return null
	
	
func peg_below(a_seed_peg: StaticBody2D) -> StaticBody2D:
	var col: int = a_seed_peg.column
	var row: int = a_seed_peg.row + 1
	if row < size.y:
		return pegs[col][row]
	return null


func is_valid_col_row(a_col_row: Vector2i) -> bool:
	if a_col_row.x < 0: return false
	if a_col_row.y < 0: return false
	if a_col_row.x >= size.x: return false
	if a_col_row.y >= size.y: return false
	return true


func translated_peg(a_base_pos: Vector2i, a_vector: Vector2i) -> StaticBody2D:
	var pos: Vector2i = a_base_pos + a_vector
	if !is_valid_col_row(pos): return null
	return pegs[pos.x][pos.y]


func is_valid_triplet(a_triplet: Array[Vector2i]) -> bool:
	if a_triplet.size() != 3: return false
	for index: int in range(3):
		if !is_valid_col_row(a_triplet[index]): return false
	return true
	
	
func peg_triplet_from_vectors(a_vtriplet: Array[Vector2i]) -> Array[StaticBody2D]:
	var triplet: Array[StaticBody2D] = []
	if !is_valid_triplet(a_vtriplet): return triplet
	for pos: Vector2i in a_vtriplet:
		triplet.append(pegs[pos.x][pos.y])
	return triplet
	
	
func translated_vector_triplet(a_triplet: Array[Vector2i], a_base_coord: Vector2i) -> Array[Vector2i]:
	var triplet: Array[Vector2i] = []
	for coord: Vector2i in a_triplet:
		triplet.append(coord + a_base_coord)
	return triplet
	
	
func potential_triplets_template() -> Array[Array]: #Actually Array[Array[Vector2i]
	var all_triplets: Array[Array] = []
	all_triplets.append([Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(1, 0)])
	all_triplets.append([Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 0)])
	all_triplets.append([Vector2i(1, 0), Vector2i(0, 0), Vector2i(2, 0)])
	all_triplets.append([Vector2i(0, 0), Vector2i(2, 0), Vector2i(3, 0)])
	
	all_triplets.append([Vector2i(0, -2), Vector2i(0, -1), Vector2i(1, 0)])
	all_triplets.append([Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)])
	all_triplets.append([Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2)])
	
	all_triplets.append([Vector2i(1, -2), Vector2i(1, -1), Vector2i(0, 0)])
	all_triplets.append([Vector2i(1, -1), Vector2i(0, 0), Vector2i(1, 1)])
	all_triplets.append([Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 2)])
	
	all_triplets.append([Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 1)])
	all_triplets.append([Vector2i(0, -1), Vector2i(0, 1), Vector2i(0, 0)])
	all_triplets.append([Vector2i(0, 1), Vector2i(0, 0), Vector2i(0, 2)])
	all_triplets.append([Vector2i(0, 0), Vector2i(0, 2), Vector2i(0, 3)])
	
	all_triplets.append([Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 1)])
	all_triplets.append([Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)])
	all_triplets.append([Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 0)])
	
	all_triplets.append([Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 0)])
	all_triplets.append([Vector2i(-1, 1), Vector2i(0, 0), Vector2i(1, 1)])
	all_triplets.append([Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1)])
	
	return all_triplets


func load_all_potential_triplets():
	var pos: Vector2i
	var templates: Array[Array] = potential_triplets_template()
	var pos_triplet: Array[Vector2i]
	var translated_triplet: Array[Vector2i]
	var peg_triplet_set: Array[Array] #Actually Array[Array[StaticBody2D]]
	all_potential_triplets = Dictionary()
	for x: int in range(size.x - 1):
		for y: int in range(size.y - 1):
			pos = Vector2i(x, y)
			peg_triplet_set = []
			#for template_triplet: Array[Vector2i] in templates:
			for index: int in range(templates.size()):
				#translated_triplet = translated_vector_triplet(template_triplet, pos)
				var temp: Array[Vector2i] = array_forced_to_vector2i_array(templates[index])
				translated_triplet = translated_vector_triplet(temp, pos)
				if is_valid_triplet(translated_triplet):
					peg_triplet_set.append(peg_triplet_from_vectors(translated_triplet))
			all_potential_triplets[pos] = peg_triplet_set


func array_forced_to_vector2i_array(a_array: Array) -> Array[Vector2i]:
	var temp_array: Array[Vector2i] = []
	var temp_vector: Vector2i
	for index: int in range(a_array.size()):
		temp_vector = a_array[index]
		temp_array.append(temp_vector)
	return temp_array


func check_for_potential_matches():
	clear_jem_selections()
	var triplet_set: Array[Array]
	hint_pegs = []
	for pos: Vector2i in all_potential_triplets.keys():
		triplet_set = all_potential_triplets[pos]
		for triplet: Array[StaticBody2D] in triplet_set:
			if is_match_by_value(triplet):
				#hint_pegs.append(pegs[pos.x][pos.y])
				hint_pegs.append(swapped_peg(triplet))
				break


func respond_to_potential_matches():
		if hint_pegs.is_empty():
			print_debug("no matches found")
			no_matches_found.emit()
		else:
			var temp_node: StaticBody2D = hint_pegs[randi() % hint_pegs.size()]
			temp_node.select_jem(true)
			print_debug(str(temp_node.column) + " : " + str(temp_node.row))


#Given a triplet, determine which one was swapped in
func swapped_peg(a_triplet: Array[StaticBody2D]) -> StaticBody2D:
	#Check if swapped in on end
	if is_pair_adjacent(a_triplet[0], a_triplet[1]):
		return a_triplet[2]
	if is_pair_adjacent(a_triplet[1], a_triplet[2]):
		return a_triplet[0]
	if is_pair_adjacent(a_triplet[0], a_triplet[2]):
		return a_triplet[1]
	#Check if swapped in in middle
	if is_linear_set([a_triplet[0], a_triplet[1]]):
		return a_triplet[2]
	if is_linear_set([a_triplet[1], a_triplet[2]]):
		return a_triplet[0]
	if is_linear_set([a_triplet[0], a_triplet[2]]):
		return a_triplet[1]
	else:
		return null



func clear_jem_selections():
	for col: Array in pegs:
		for peg: StaticBody2D in col:
			peg.select_jem(false)

#endregion




	
