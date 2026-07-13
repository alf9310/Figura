@tool
class_name CharacterLoader
extends VBoxContainer

signal back_pressed
signal character_selected(state:CharacterState)


@onready var optionsList = $scroll/optionsList
@export var config: CharacterConfig

func _ready() -> void:
	var btn:Button = find_child("BackButton")
	btn.pressed.connect(func() -> void: back_pressed.emit())
	self.connect("back_pressed",clearOptions)

func load_saved_characters() -> void:
	clearOptions()
	
	var root = get_tree().get_root()
	
	# Try and open the saved characters folder from the save output
	var char_path = config.output_path + "/saved_characters/"
	var dir := DirAccess.open(char_path)
	var folder := DirAccess.open("user://")
	
	# If there is no save data, add placeholder
	if not folder.dir_exists_absolute(char_path):
		push_warning("no save data was found")
		make_placeholder()
		return
	
	# For each file, make a new character load row and save it
	for file:String in dir.get_files():
		var state: CharacterState = load(char_path+ "/" + file)
		var button := CharacterLoadRow.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		optionsList.add_child(button)
		button.init(state.metadata["name"],state.icon,state)
		button.pressed.connect(func() -> void: character_selected.emit(button.state))
		button.owner = root

func clearOptions() -> void:
	for child in optionsList.get_children():
		child.free()

## Make a placeholder if no save data was found
func make_placeholder() -> void:
	var panel = Panel.new()
	var root = get_tree().get_root()
	panel.name = "Placeholder"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	optionsList.add_child(panel)
	panel.owner = root
	
	var lbl = Label.new()
	lbl.text = "No Saved Characters Found."
	lbl.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.add_child(lbl)
	optionsList.owner = root
