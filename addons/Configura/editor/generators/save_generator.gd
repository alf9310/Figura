@tool
class_name SaveGenerator
extends RefCounted

func build(scene_root:Node, root:CharacterNameSaver):
	print("Building VboxContainer")
	var vCon = VBoxContainer.new()
	vCon.name = "LayoutContainer"
	vCon.size_flags_horizontal =Control.SIZE_SHRINK_CENTER
	vCon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(vCon)
	vCon.owner = scene_root
	
	var tooltip = RichTextLabel.new()
	tooltip.name = "Tooltip"
	tooltip.text = "Please enter a name for the character:"
	tooltip.custom_minimum_size = Vector2(500,25)
	vCon.add_child(tooltip)
	tooltip.owner = scene_root
	
	print("Building Save Controls")
	var Hcon = HBoxContainer.new()
	Hcon.name = "ControlContainter"
	vCon.add_child(Hcon)
	Hcon.owner = scene_root
	
	var input = LineEdit.new()
	input.name = "Input"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Hcon.add_child(input)
	input.owner = scene_root
	
	var btn = Button.new()
	btn.name = "SaveButton"
	btn.text = "Save"
	Hcon.add_child(btn)
	btn.owner =scene_root
	
	pass
