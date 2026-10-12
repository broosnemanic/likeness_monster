extends Node2D

var textures: Array[Resource] = []
var peg_texture: Resource
var jem_prefab
var peg_prefab
var block_prefab
var peg_script
var square
var offset: int = 200
var spacing: int
var peg_offset: int = 0
var jem_offset: int = 100
var height: int = 5
var width: int = 5
var pegs: Array[StaticBody2D]
var jems: Array[RigidBody2D]
var blocks: Array[StaticBody2D]
var feature_textures: Array[Array] = []
var allele_count: int = 4
var random_alleles_template: Array[int]
var match_logic_type: int = 0


# >[Setup]<

# Called when the node enters the scene tree for the first time.
func _ready():
	random_alleles_template = randomized_index_array(6)
	randomize()
	load_assets()
	initialize()


func reshuffle_textures():
	random_alleles_template = randomized_index_array(6)
	randomize_allele_textures()
	
	
# Prepare for new game
func initialize():
	initialize_containers()
	

func initialize_containers():
	pegs = [StaticBody2D.new()]
	blocks = [StaticBody2D.new()]
	jems = [RigidBody2D.new()]
	pegs.clear()
	blocks.clear()
	jems.clear()
	
	
func load_assets():
	load_scenes()
	load_textures()
	load_feature_textures()
	

func load_scenes():
	jem_prefab = preload("res://scenes/jem.tscn")
	peg_prefab = preload("res://scenes/peg.tscn")
	block_prefab = preload("res://scenes/boarder_block.tscn")


func load_textures():
	textures.append(load("res://icons/elephant.png"))
	textures.append(load("res://icons/giraffe.png"))
	textures.append(load("res://icons/hippo.png"))
	textures.append(load("res://icons/monkey.png"))
	textures.append(load("res://icons/panda.png"))
	textures.append(load("res://icons/parrot.png"))
	textures.append(load("res://icons/penguin.png"))
	textures.append(load("res://icons/pig.png"))
	peg_texture = load("res://icons/peg.png")


func load_feature_textures():
	var features: Array[Resource] = []
	features.append(load("res://icons/features/elephant_head.png"))
	features.append(load("res://icons/features/giraffe_head.png"))
	features.append(load("res://icons/features/pig_head.png"))
	features.append(load("res://icons/features/snek_head.png"))
	features.append(load("res://icons/features/robot_head.png"))
	features.append(load("res://icons/features/ant_head.png"))
	feature_textures.append(features)
	features = []
	features.append(load("res://icons/features/elephant_ears.png"))
	features.append(load("res://icons/features/giraffe_ears.png"))
	features.append(load("res://icons/features/pig_ears.png"))
	features.append(load("res://icons/features/snek_ears.png"))
	features.append(load("res://icons/features/robot_ears.png"))
	features.append(load("res://icons/features/ant_ears.png"))
	feature_textures.append(features)
	features = []
	features.append(load("res://icons/features/elephant_eyes.png"))
	features.append(load("res://icons/features/giraffe_eyes.png"))
	features.append(load("res://icons/features/pig_eyes.png"))
	features.append(load("res://icons/features/snek_eyes.png"))
	features.append(load("res://icons/features/robot_eyes.png"))
	features.append(load("res://icons/features/ant_eyes.png"))
	feature_textures.append(features)
	features = []
	features.append(load("res://icons/features/elephant_nose.png"))
	features.append(load("res://icons/features/giraffe_nose.png"))
	features.append(load("res://icons/features/pig_nose.png"))
	features.append(load("res://icons/features/snek_nose.png"))
	features.append(load("res://icons/features/robot_nose.png"))
	features.append(load("res://icons/features/ant_nose.png"))
	feature_textures.append(features)
	randomize_allele_textures()
	
	
#Randomizes which complete textures (e.g. pig) are *available*
func randomize_allele_textures():
	var index: int = 0
	for alleles: Array[Resource] in feature_textures:
		feature_textures[index] = randomized_allele_array(alleles, random_alleles_template)
		index = index + 1
	

# Why? We want to randomize the allels arrays but *all* in the same way*
func randomized_index_array(a_count: int) -> Array[int]:
	var temp_array: Array[int] = []
	temp_array.resize(a_count)
	temp_array.fill(a_count)
	var rand_i: int
	var is_inserted: bool = false
	for index: int in range(a_count):
		is_inserted = false
		while !is_inserted:
			rand_i = randi() % a_count
			if rand_i in temp_array:
				is_inserted= false
			else:
				temp_array[index] = rand_i
				is_inserted = true
	return temp_array


func randomized_allele_array(a_alleles: Array[Resource], a_template: Array[int]) -> Array[Resource]:
	var temp_array: Array[Resource] = []
	temp_array.resize(a_alleles.size())
	var i: int = 0
	for index: int in a_template:
		temp_array[index] = a_alleles[i]
		i = i + 1
	return temp_array
			
	
	
		
# >[End Setup]<

#>[Production]<

func new_pegs(size: Vector2i) -> Array[StaticBody2D]:
	pegs.clear()
	var temp_peg: StaticBody2D
	var count: int = size.x * size.y
	for n in count:
		temp_peg = new_peg()
		temp_peg.name = str(n)
		pegs.append(temp_peg)
	return pegs
	

func new_peg() -> StaticBody2D:
	var peg: StaticBody2D
	peg = peg_prefab.instantiate()
	return peg


func new_jems(a_count: int) -> Array[RigidBody2D]:
	var temp_jems: Array[RigidBody2D] = [RigidBody2D.new()]
	temp_jems.clear()
	for n in a_count: 
		temp_jems.append(new_jem())
	return temp_jems


func new_jem() -> RigidBody2D:
	var jem: RigidBody2D
	jem = jem_prefab.instantiate()
	assign_feature_textures(jem)
	return jem	


func assign_feature_textures(a_jem: RigidBody2D):
	var sprite: Sprite2D
	var texture: Resource
	var allele_index: int = randi() % allele_count
	for index: int in range(4):
		sprite = a_jem.feature_node_from_index(index)
		#texture = feature_textures[index][randi() % 4]
		allele_index = allele_index if match_logic_type == 3 else randi() % allele_count
		#texture = feature_textures[index][randi() % allele_count]
		texture = feature_textures[index][allele_index]
		sprite.texture = texture
		pass

func new_blocks(size: Vector2i) -> Array[StaticBody2D]:
	blocks.clear()
	#var count: int = size.x + 2 + (2 * size.y)
	var count: int = 2 * (size.x + 2) + (2 * size.y)
	for n in count:
		blocks.append(new_block())
	return blocks


func new_block() -> StaticBody2D:
	var block: StaticBody2D
	block = block_prefab.instantiate()
	return block
	
#>[End Production]<	

#>[Helpers]<

#func random_sprite() -> Sprite2D: 
	#var texture = textures[randi() % 8]
	#var sprite = Sprite2D.new()
	#sprite.texture = texture
	#sprite.name = "sprite"
	#return sprite


#fuc random_feature_sprite(a_feature_index: int) -> Sprite2D:
	#var spnrites: Array[Sprite2D] = feature_textures[a_feature_index]
	


func peg_sprite() -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = peg_texture
	sprite.name = "sprite"
	return sprite
	
#>[End Helpers]<	
