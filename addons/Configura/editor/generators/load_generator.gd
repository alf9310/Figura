@tool
class_name LoadGenerator
extends RefCounted

func build(root: VBoxContainer,scene_root: Node,theme: Theme):
	# if no theme is selected use "default" otherwise use custom path
	root.theme = theme
		
	# Back Button Generation
	var btn = Button.new()
	btn.name = "BackButton"
	btn.text = "back"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(btn)
	btn.owner = scene_root

	# ScrollBox Generation
	var scroll = ScrollContainer.new()
	scroll.name ="scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	scroll.owner = scene_root
	
	var list = VBoxContainer.new()
	list.name = "optionsList"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	list.owner = scene_root
