extends Node

var feature_count

func is_match_by_value(a_pegs: Array[StaticBody2D]) -> bool:
	return true


func is_match_by_name_value(a_pegs: Array[StaticBody2D]) -> bool:
	var area: Area2D = a_pegs[0].area
	var first_name: String = area.jem_name()
	for i_peg: StaticBody2D in a_pegs:
		if i_peg.area.jem_name() != first_name:
			return false
	return true
	

func is_complex_match_by_value(a_pegs: Array[StaticBody2D]) -> bool:
	var allel_list: Array[String] = []
	for index: int in range(feature_count):
		allel_list.clear()
		for peg: StaticBody2D in a_pegs:
			allel_list.append(peg.area.feature_name_from_index(index))
		if !is_allele_complex_match_by_value(allel_list):
			return false
	return true

	
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
	
	
