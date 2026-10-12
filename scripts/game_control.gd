extends Node


var tile_factory: Node
var board: Node
var game_size: Vector2
var pegs: Array[RigidBody2D]
var jems: Array[RigidBody2D]
var tile_width: int = 128
var viewport_size: Vector2
var camera: Camera2D
var hint_button: Button
var close_settings_button: Button
var match_type_dropdown: OptionButton
var puzzle_size_dropdown: OptionButton
var open_settings_button: Button
var no_more_matches_label: Label
var settings_container: VBoxContainer
var menu_bar: HBoxContainer
var marker: Sprite2D
var marker3: Sprite2D
var zoomf: float
var jem_mask: Sprite2D
var game_settings: Dictionary = {"match_logic_type": 0, "size": Vector2(6, 6)}

# Called when the node enters the scene tree for the first time.
func _ready():
	jem_mask = get_parent().get_node("JemMask")
	camera = get_parent().get_node("Camera2D")
	hint_button = find_child("HintButton")
	menu_bar = find_child("MenuBar")
	no_more_matches_label = find_child("NoMoreMatchesLabel")
	settings_container = find_child("SettingsContainer")
	open_settings_button = find_child("OpenSettingsButton")
	open_settings_button.pressed.connect(on_open_settings_button_pressed)
	close_settings_button = find_child("CloseSettingsButton")
	close_settings_button.pressed.connect(on_close_settings_button_pressed)
	match_type_dropdown = get_parent().find_child("MatchType")
	match_type_dropdown.item_selected.connect(on_match_type_selected)
	puzzle_size_dropdown = get_parent().find_child("PuzzleSize")
	puzzle_size_dropdown.item_selected.connect(on_puzzle_size_selected)
	game_size = Vector2(6, 6)
	tile_factory = get_node("tile_factory")
	board = get_node("board")
	hint_button.pressed.connect(on_hint_button_pressed)
	board.pegs_positioned.connect(on_pegs_positioned)
	board.jems_requested.connect(on_jems_requested)
	board.no_matches_found.connect(show_no_more_matches_label)
	for ibutton: Button in find_children("NewGameButton"):
		ibutton.button_down.connect(on_new_game_button_pressed)
	
	#on_match_type_selected(3)
	new_game()


func show_no_more_matches_label():
	no_more_matches_label.set_visible(true)
	get_tree().create_timer(3.0).connect("timeout", on_hide_no_more_matches_label_timeout)


func hide_no_more_matches_label():
	no_more_matches_label.set_visible(false)



func on_hide_no_more_matches_label_timeout():
	hide_no_more_matches_label()
	new_game()



func on_hint_button_pressed():
	if board.is_board_state_static():
		board.check_for_potential_matches()
		board.respond_to_potential_matches()


func on_new_game_button_pressed():
	open_settings_pane(false)
	new_game()


func apply_settings(a_settings: Dictionary):
	board.match_logic_type = a_settings["match_logic_type"]
	game_size = a_settings["size"]


func on_open_settings_button_pressed():
	open_settings_pane(true)


func on_close_settings_button_pressed():
	open_settings_pane(false)


func open_settings_pane(a_is_open: bool):
	settings_container.set_visible(a_is_open)
	menu_bar.set_visible(!a_is_open)	


	
func new_game():
	apply_settings(game_settings)
	zoomf = 6.0 / min(game_size.x, game_size.y) 
	camera.set_zoom(Vector2(zoomf, zoomf))
	tile_factory.reshuffle_textures()
	board.is_initialized = false
	board.initialize(tile_factory.new_pegs(game_size), tile_factory.new_blocks(game_size), game_size)
	board.setup_tiles()
	board.set_board_state(1)

	
func on_pegs_positioned(a_size: Vector2):
	position_board(a_size)
	setup_jem_mask(game_size)


func on_match_type_selected(a_index: int):
	#board.set_match_type(a_index)
	game_settings["match_logic_type"] = a_index
	tile_factory.match_logic_type = a_index


func on_puzzle_size_selected(a_index: int):
	game_settings["size"] = puzzle_size_from_index(a_index)


func puzzle_size_from_index(a_index: int) -> Vector2:
	if a_index == 0: return Vector2(4, 4)
	if a_index == 1: return Vector2(5, 5)
	if a_index == 2: return Vector2(6, 6)
	if a_index == 3: return Vector2(8, 8)
	if a_index == 4: return Vector2(10, 10)
	else: return Vector2(6, 6)
	

func position_board(a_size: Vector2):
	var camera_viewport: Viewport = camera.get_viewport()
	viewport_size = camera_viewport.get_visible_rect().size / zoomf
	print(viewport_size)
	#var x: int = 0.5 * (viewport_size.x - a_size.x + board.tile_width)
	var board_height = a_size.y + tile_width
	var center: Vector2 = camera.get_screen_center_position()
	var x = center.x  - 0.5 * (a_size.x - board.tile_width)
	#var y2: float =  center.y - (board_height - 0.5 * viewport_size.y) + 0.5 * board.tile_width
	var y2: float =  center.y - (board_height - 0.5 * viewport_size.y) + 1.4 * board.tile_width
	board.position = Vector2(x, y2)


func setup_jem_mask(a_size: Vector2):
	var height : float = jem_mask.texture.get_height()
	var scale: float = viewport_size.x / height
	var center: Vector2 = camera.get_screen_center_position()
	jem_mask.scale = Vector2(scale, scale)
	var effective_height: float = height * scale
	var y: float = board.position.y - 1.5 * tile_width - 0.5 * effective_height
	jem_mask.position = Vector2(center.x, y)

func on_jems_requested(a_jem_count: int):
	board.accept_jems(tile_factory.new_jems(a_jem_count))
